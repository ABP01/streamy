import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../env.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/reaction_provider.dart';

class LivePage extends StatefulWidget {
  final String channelId;
  final String liveId;
  final bool isHost;
  const LivePage({
    super.key,
    required this.channelId,
    required this.liveId,
    required this.isHost,
  });

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  int? _localUid;
  final List<int> _remoteUids = [];
  late final RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: Env.agoraAppId!));
    await _engine.enableVideo();
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, uid) {
          setState(() => _localUid = uid);
        },
        onUserJoined: (connection, uid, _) {
          setState(() => _remoteUids.add(uid));
        },
        onUserOffline: (connection, uid, reason) {
          setState(() => _remoteUids.remove(uid));
        },
      ),
    );
    await _engine.joinChannel(
      token: '', // Pas de token pour le moment
      channelId: widget.channelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Live: ${widget.channelId}')),
      body: Stack(
        children: [
          // Vidéo principale (remote ou local)
          Positioned.fill(
            child: _remoteUids.isNotEmpty
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: _remoteUids.first),
                      connection: RtcConnection(channelId: widget.channelId),
                    ),
                  )
                : AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
          ),
          // Miniature de la propre vidéo (si remote présent)
          if (_remoteUids.isNotEmpty)
            Positioned(
              right: 16,
              top: 16,
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: VideoCanvas(uid: _localUid ?? 0),
                  ),
                ),
              ),
            ),
          // Message si personne n'est connecté
          if (_remoteUids.isEmpty && _localUid == null)
            const Center(child: CircularProgressIndicator()),
          // Chat overlay
          Align(
            alignment: Alignment.bottomCenter,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => ChatProvider(widget.liveId),
                ),
                ChangeNotifierProvider(
                  create: (_) => ReactionProvider(widget.liveId),
                ),
              ],
              child: _ChatAndReactionWidget(isHost: widget.isHost),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAndReactionWidget extends StatefulWidget {
  final bool isHost;
  const _ChatAndReactionWidget({required this.isHost});

  @override
  State<_ChatAndReactionWidget> createState() => _ChatAndReactionWidgetState();
}

class _ChatAndReactionWidgetState extends State<_ChatAndReactionWidget> {
  final TextEditingController _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);
    final reaction = Provider.of<ReactionProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return SafeArea(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Affichage des réactions récentes
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: reaction.reactions.reversed.take(10).map((r) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Text(
                      r['type'] ?? '',
                      style: const TextStyle(fontSize: 24),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Chat
            SizedBox(
              height: 140,
              child: chat.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      reverse: true,
                      itemCount: chat.messages.length,
                      itemBuilder: (context, index) {
                        final msg =
                            chat.messages[chat.messages.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  msg['content'] ?? '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () async {
                    await chat.sendMessage(
                      auth.user?.id ?? '',
                      _controller.text,
                    );
                    _controller.clear();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                  onPressed: () =>
                      reaction.sendReaction(auth.user?.id ?? '', '❤️'),
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_up, color: Colors.lightBlue),
                  onPressed: () =>
                      reaction.sendReaction(auth.user?.id ?? '', '👍'),
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_down, color: Colors.redAccent),
                  onPressed: () =>
                      reaction.sendReaction(auth.user?.id ?? '', '👎'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
