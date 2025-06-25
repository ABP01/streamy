import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../env.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/reaction_provider.dart';
import '../services/agora_token_service.dart';

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
  RtcEngine? _engine;
  late AgoraTokenService _tokenService;
  String? _agoraToken;
  String? _error;
  bool _isMuted = false;
  bool _isFrontCamera = true;
  int _viewerCount = 1;

  @override
  void initState() {
    super.initState();
    _tokenService = AgoraTokenService(Env.backendUrl!);
    _initAgora();
  }

  Future<void> _renewToken() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final tokenData = await _tokenService.fetchAgoraToken(
        channelName: widget.channelId,
        supabaseAccessToken: auth.accessToken ?? '',
        isBroadcaster: widget.isHost,
      );
      if (!mounted) return;
      final newToken = tokenData?['token'] ?? '';
      if (newToken.isNotEmpty && _engine != null) {
        await _engine!.renewToken(newToken);
        setState(() {
          _agoraToken = newToken;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Erreur lors du renouvellement du token Agora : $e";
      });
    }
  }

  Future<void> _initAgora() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final tokenData = await _tokenService.fetchAgoraToken(
        channelName: widget.channelId,
        supabaseAccessToken: auth.accessToken ?? '',
        isBroadcaster: widget.isHost,
      );
      if (!mounted) return;
      _agoraToken = tokenData?['token'] ?? '';
      final uid = tokenData?['uid'] ?? 0;
      if (_agoraToken == null || _agoraToken!.isEmpty) {
        setState(() {
          _error =
              "Impossible de récupérer le token Agora. Veuillez réessayer.";
        });
        return;
      }
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: Env.agoraAppId!,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      await engine.enableVideo();
      await engine.enableAudio();
      await engine.setClientRole(
        role: widget.isHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      );
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, uid) {
            if (!mounted) return;
            setState(() => _localUid = uid);
          },
          onUserJoined: (connection, uid, _) {
            if (!mounted) return;
            setState(() {
              _remoteUids.add(uid);
              _viewerCount = _remoteUids.length + 1;
            });
          },
          onUserOffline: (connection, uid, reason) {
            if (!mounted) return;
            setState(() {
              _remoteUids.remove(uid);
              _viewerCount = _remoteUids.length + 1;
            });
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() {
              _error = "Erreur Agora: $msg ($err)";
            });
          },
          onTokenPrivilegeWillExpire: (connection, token) async {
            await _renewToken();
          },
        ),
      );
      await engine.joinChannel(
        token: _agoraToken ?? '',
        channelId: widget.channelId,
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: widget.isHost
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          publishCameraTrack: widget.isHost,
          publishMicrophoneTrack: widget.isHost,
        ),
      );
      if (!mounted) return;
      setState(() {
        _engine = engine;
        _viewerCount = _remoteUids.length + 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Erreur lors de l'initialisation du live : $e";
      });
    }
  }

  void _toggleMute() async {
    if (_engine != null) {
      await _engine!.muteLocalAudioStream(!_isMuted);
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  void _switchCamera() async {
    if (_engine != null) {
      await _engine!.switchCamera();
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
    }
  }

  @override
  void dispose() {
    if (_engine != null) {
      _engine!.leaveChannel();
      _engine!.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String roleLabel = widget.isHost ? 'Host' : 'Viewer';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                'Live: ${widget.channelId}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.isHost ? Colors.orange : Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.remove_red_eye, color: Colors.white70, size: 18),
            SizedBox(width: 2),
            Text(
              '$_viewerCount',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
        actions: [
          if (widget.isHost && _engine != null) ...[
            IconButton(
              icon: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
              ),
              tooltip: _isMuted ? 'Activer le micro' : 'Couper le micro',
              onPressed: _toggleMute,
            ),
            IconButton(
              icon: Icon(Icons.cameraswitch, color: Colors.white),
              tooltip: 'Changer de caméra',
              onPressed: _switchCamera,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _engine = null;
                        _localUid = null;
                        _remoteUids.clear();
                        _viewerCount = 1;
                      });
                      _initAgora();
                    },
                    child: Text('Réessayer'),
                  ),
                ],
              ),
            )
          else ...[
            // Vidéo principale (remote ou local)
            Positioned.fill(
              child: _engine == null
                  ? const Center(child: CircularProgressIndicator())
                  : (_remoteUids.isNotEmpty
                        ? AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: _engine!,
                              canvas: VideoCanvas(uid: _remoteUids.first),
                              connection: RtcConnection(
                                channelId: widget.channelId,
                              ),
                            ),
                          )
                        : AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: _engine!,
                              canvas: const VideoCanvas(uid: 0),
                            ),
                          )),
            ),
            // Miniature de la propre vidéo (si remote présent)
            if (_remoteUids.isNotEmpty && _engine != null)
              Positioned(
                right: 16,
                top: 16,
                width: 120,
                height: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine!,
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
              child: Builder(
                builder: (context) => MultiProvider(
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
            ),
          ],
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
  String? _error;
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: Colors.red)),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        setState(() => _error = null);
                        // On relance la récupération des messages/réactions en réinitialisant le provider
                        // (on peut appeler notifyListeners ou re-créer le provider si besoin)
                        // Ici, on force juste la reconstruction du widget, ce qui relancera les streams
                      },
                    ),
                  ],
                ),
              ),
            // Affichage des réactions récentes animées
            SizedBox(
              height: 40,
              child: AnimatedList(
                key: ValueKey(reaction.reactions.length),
                scrollDirection: Axis.horizontal,
                initialItemCount: reaction.reactions.length > 10
                    ? 10
                    : reaction.reactions.length,
                itemBuilder: (context, index, animation) {
                  final r = reaction.reactions.reversed.toList()[index];
                  return ScaleTransition(
                    scale: animation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Text(
                        r['type'] ?? '',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  );
                },
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
                    onSubmitted: (value) async {
                      if (_error != null || value.trim().isEmpty) return;
                      await chat.sendMessage(auth.user?.id ?? '', value.trim());
                      _controller.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () async {
                    if (_error != null || _controller.text.trim().isEmpty)
                      return;
                    await chat.sendMessage(
                      auth.user?.id ?? '',
                      _controller.text.trim(),
                    );
                    _controller.clear();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                  onPressed: _error != null
                      ? null
                      : () => reaction.sendReaction(auth.user?.id ?? '', '❤️'),
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_up, color: Colors.lightBlue),
                  onPressed: _error != null
                      ? null
                      : () => reaction.sendReaction(auth.user?.id ?? '', '👍'),
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_down, color: Colors.redAccent),
                  onPressed: _error != null
                      ? null
                      : () => reaction.sendReaction(auth.user?.id ?? '', '👎'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
