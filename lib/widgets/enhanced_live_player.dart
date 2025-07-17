import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/agora_connection_manager.dart' as agora;

/// Widget de player vidéo live amélioré avec interface moderne
class EnhancedLivePlayer extends StatefulWidget {
  final LiveStream live;
  final bool isActive;
  final VoidCallback? onPlayerTap;
  final Function(String)? onError;
  final Function(String)? onStatusChange;

  const EnhancedLivePlayer({
    super.key,
    required this.live,
    required this.isActive,
    this.onPlayerTap,
    this.onError,
    this.onStatusChange,
  });

  @override
  State<EnhancedLivePlayer> createState() => _EnhancedLivePlayerState();
}

class _EnhancedLivePlayerState extends State<EnhancedLivePlayer>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // État de la connexion
  agora.ConnectionState _connectionState = agora.ConnectionState.disconnected;
  String? _errorMessage;
  int? _remoteUid;

  // Animations
  late AnimationController _loadingController;
  late AnimationController _errorController;
  late Animation<double> _loadingAnimation;
  late Animation<double> _errorShakeAnimation;

  // Gestionnaire de connexion Agora
  late agora.AgoraConnectionManager _connectionManager;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeConnectionManager();

    WidgetsBinding.instance.addObserver(this);

    if (widget.isActive) {
      _connectToLive();
    }
  }

  @override
  void didUpdateWidget(EnhancedLivePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _connectToLive();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disconnectFromLive();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadingController.dispose();
    _errorController.dispose();
    _connectionManager.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _errorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    _errorShakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _errorController, curve: Curves.elasticIn),
    );
  }

  void _initializeConnectionManager() {
    _connectionManager = agora.AgoraConnectionManager(
      onConnectionStateChanged: (state) {
        setState(() {
          _connectionState = state;
        });
        _handleConnectionStateChange(state);
      },
      onUserJoined: (uid) {
        setState(() {
          _remoteUid = uid;
        });
      },
      onUserLeft: (uid) {
        setState(() {
          _remoteUid = null;
        });
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
          _connectionState = agora.ConnectionState.failed;
        });
        _triggerErrorAnimation();
        widget.onError?.call(error);
      },
    );
  }

  void _handleConnectionStateChange(agora.ConnectionState state) {
    widget.onStatusChange?.call(_getStatusText(state));

    switch (state) {
      case agora.ConnectionState.connecting:
        _loadingController.repeat();
        break;
      case agora.ConnectionState.connected:
        _loadingController.stop();
        break;
      case agora.ConnectionState.failed:
      case agora.ConnectionState.disconnected:
        _loadingController.stop();
        break;
    }
  }

  String _getStatusText(agora.ConnectionState state) {
    switch (state) {
      case agora.ConnectionState.connecting:
        return 'Connexion en cours...';
      case agora.ConnectionState.connected:
        return 'En direct';
      case agora.ConnectionState.failed:
        return 'Connexion échouée';
      case agora.ConnectionState.disconnected:
        return 'Déconnecté';
    }
  }

  void _triggerErrorAnimation() {
    _errorController.forward().then((_) {
      _errorController.reverse();
    });
  }

  Future<void> _connectToLive() async {
    try {
      await _connectionManager.connectToLive(widget.live);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _connectionState = agora.ConnectionState.failed;
      });
    }
  }

  Future<void> _disconnectFromLive() async {
    await _connectionManager.disconnect();
    setState(() {
      _connectionState = agora.ConnectionState.disconnected;
      _remoteUid = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onPlayerTap?.call();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Vue vidéo principale
          _buildVideoView(),

          // Overlay de dégradé
          _buildGradientOverlay(),

          // Indicateurs d'état
          _buildStatusIndicators(),

          // Contrôles de debug (uniquement en développement)
          if (kDebugMode) _buildDebugOverlay(),
        ],
      ),
    );
  }

  Widget _buildVideoView() {
    if (_connectionState == agora.ConnectionState.connected &&
        _remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _connectionManager.engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(
            channelId: widget.live.agoraChannelId ?? widget.live.id,
          ),
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF6C5CE7).withOpacity(0.3),
            const Color(0xFFE84393).withOpacity(0.3),
            Colors.black.withOpacity(0.9),
          ],
        ),
      ),
      child: Center(child: _buildPlaceholderContent()),
    );
  }

  Widget _buildPlaceholderContent() {
    switch (_connectionState) {
      case agora.ConnectionState.connecting:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _loadingAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _loadingAnimation.value * 2 * 3.14159,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: CustomPaint(
                      painter: LoadingPainter(_loadingAnimation.value),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Connexion au live...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case agora.ConnectionState.failed:
        return AnimatedBuilder(
          animation: _errorShakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_errorShakeAnimation.value, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage ?? 'Erreur de connexion',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _connectToLive,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case agora.ConnectionState.connected:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'En attente du streamer...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        );

      case agora.ConnectionState.disconnected:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.live_tv, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'Live non disponible',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        );
    }
  }

  Widget _buildGradientOverlay() {
    return Container(
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
    );
  }

  Widget _buildStatusIndicators() {
    return Positioned(
      top: 16,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge LIVE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _connectionState == agora.ConnectionState.connected
                  ? Colors.red
                  : Colors.grey,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _connectionState == agora.ConnectionState.connected
                      ? 'LIVE'
                      : 'OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Qualité de connexion
          if (_connectionState == agora.ConnectionState.connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.signal_wifi_4_bar, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'HD',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DEBUG MODE',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'État: ${_connectionState.name}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Remote UID: $_remoteUid',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Canal: ${widget.live.agoraChannelId ?? widget.live.id}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter personnalisé pour l'animation de chargement
class LoadingPainter extends CustomPainter {
  final double progress;

  LoadingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      progress * 2 * 3.14159,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(LoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
