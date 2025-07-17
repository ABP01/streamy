import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../services/agora_debug_service.dart';
import '../services/agora_error_handler.dart';
import '../services/live_stream_service.dart';

class LivePlayerWidget extends StatefulWidget {
  final LiveStream live;
  final bool isActive;
  final VoidCallback? onPlayerTap;
  final Function(String)? onError;

  const LivePlayerWidget({
    super.key,
    required this.live,
    required this.isActive,
    this.onPlayerTap,
    this.onError,
  });

  @override
  State<LivePlayerWidget> createState() => _LivePlayerWidgetState();
}

class _LivePlayerWidgetState extends State<LivePlayerWidget>
    with WidgetsBindingObserver {
  RtcEngine? _engine;
  bool _isConnected = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int? _remoteUid;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _initializeAgora();
    }
  }

  @override
  void didUpdateWidget(LivePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si le widget devient actif, initialiser Agora
    if (widget.isActive && !oldWidget.isActive && _engine == null) {
      _initializeAgora();
    }
    // Si le widget devient inactif, nettoyer les ressources
    else if (!widget.isActive && oldWidget.isActive) {
      _leaveChannel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_engine != null) {
      switch (state) {
        case AppLifecycleState.paused:
          _engine!.muteLocalAudioStream(true);
          _engine!.muteLocalVideoStream(true);
          break;
        case AppLifecycleState.resumed:
          _engine!.muteLocalAudioStream(!_isAudioEnabled);
          _engine!.muteLocalVideoStream(!_isVideoEnabled);
          break;
        default:
          break;
      }
    }
  }

  Future<void> _initializeAgora() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Créer et initialiser le moteur RTC
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: AppConfig.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      // Configuration des événements
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('📺 Rejoint le canal: ${connection.channelId}');
            setState(() {
              _isConnected = true;
              _isLoading = false;
            });
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            print('👤 Utilisateur rejoint: $uid');
            setState(() {
              _remoteUid = uid;
            });
          },
          onUserOffline:
              (
                RtcConnection connection,
                int uid,
                UserOfflineReasonType reason,
              ) {
                print('👤 Utilisateur parti: $uid');
                setState(() {
                  _remoteUid = null;
                });
              },
          onError: (ErrorCodeType err, String msg) {
            print('🚨 Erreur Agora: ${err.name} - $msg');
            AgoraDebugService.logAgoraError(err, msg);

            setState(() {
              _hasError = true;
              _errorMessage = AgoraErrorHandler.getErrorMessage(err);
              _isLoading = false;
            });

            widget.onError?.call(_errorMessage!);
          },
          onConnectionStateChanged:
              (
                RtcConnection connection,
                ConnectionStateType state,
                ConnectionChangedReasonType reason,
              ) {
                print('🔗 État connexion: ${state.name} - ${reason.name}');
              },
        ),
      );

      // Configuration pour spectateur
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine!.enableVideo();
      await _engine!.enableAudio();

      // Rejoindre le canal
      await _joinChannel();
    } catch (e) {
      print('❌ Erreur initialisation Agora: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Erreur de connexion: $e';
        _isLoading = false;
      });
      widget.onError?.call(_errorMessage!);
    }
  }

  Future<void> _joinChannel() async {
    try {
      final channelId = widget.live.agoraChannelId ?? widget.live.id;
      String? token;

      // Obtenir un token si nécessaire
      if (AppConfig.useAgoraToken) {
        final liveService = LiveStreamService();
        token = await liveService.getViewerToken(
          widget.live.id,
          'viewer_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      // Rejoindre le canal
      await _engine!.joinChannel(
        token: token ?? '',
        channelId: channelId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          audienceLatencyLevel:
              AudienceLatencyLevelType.audienceLatencyLevelLowLatency,
        ),
      );
    } catch (e) {
      print('❌ Erreur rejoindre canal: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Impossible de rejoindre le live';
        _isLoading = false;
      });
    }
  }

  Future<void> _leaveChannel() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      setState(() {
        _isConnected = false;
        _remoteUid = null;
      });
    }
  }

  Future<void> _dispose() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }
  }

  Widget _buildVideoView() {
    if (_remoteUid != null) {
      // Afficher le flux vidéo distant
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(
            channelId: widget.live.agoraChannelId ?? widget.live.id,
          ),
        ),
      );
    } else {
      // Pas de flux vidéo disponible
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple.withValues(alpha: 0.4),
            Colors.pink.withValues(alpha: 0.4),
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connexion au live...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ] else if (_hasError) ...[
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Erreur de connexion',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeAgora,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.agoraAppId.isNotEmpty
                      ? Colors.purple
                      : Colors.grey,
                ),
                child: const Text('Réessayer'),
              ),
            ] else if (_isConnected && _remoteUid == null) ...[
              const Icon(Icons.person_off, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'En attente du streamer...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ] else ...[
              const Icon(Icons.live_tv, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Live en préparation',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vue vidéo ou placeholder
        Positioned.fill(
          child: widget.isActive ? _buildVideoView() : _buildPlaceholder(),
        ),

        // Overlay d'assombrissement
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.6),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
        ),

        // Badge LIVE
        if (widget.live.isLive)
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.red : Colors.grey,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: _isConnected
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? 'LIVE' : 'OFFLINE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Nombre de viewers
        Positioned(
          top: 50,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.live.formattedViewerCount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Zone de tap pour contrôles
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onPlayerTap?.call();
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Indicateur de qualité de connexion
        if (widget.isActive)
          Positioned(
            bottom: 100,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConnected
                        ? Icons.signal_wifi_4_bar
                        : Icons.signal_wifi_off,
                    color: _isConnected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? 'HD' : 'OFF',
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
