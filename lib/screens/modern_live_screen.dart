import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../services/live_stream_service.dart';
import '../widgets/enhanced_live_player.dart';
import '../widgets/live_stats_widget.dart';

/// Écran de live moderne avec interface épurée style TikTok
class ModernLiveScreen extends StatefulWidget {
  final String liveId;
  final bool isHost;

  const ModernLiveScreen({
    super.key,
    required this.liveId,
    required this.isHost,
  });

  @override
  State<ModernLiveScreen> createState() => _ModernLiveScreenState();
}

class _ModernLiveScreenState extends State<ModernLiveScreen>
    with TickerProviderStateMixin {
  // Services
  final LiveStreamService _liveService = LiveStreamService();

  // État du live
  LiveStream? _currentLive;
  bool _isLoading = true;
  bool _isConnected = false;
  String? _connectionStatus;

  // Contrôles UI
  bool _showControls = true;
  bool _showChat = false;
  bool _showStats = false;

  // Animations
  late AnimationController _controlsController;
  late AnimationController _chatController;
  late AnimationController _heartController;
  late Animation<double> _controlsOpacity;
  late Animation<Offset> _chatSlide;
  late Animation<double> _heartScale;

  // Timers
  Timer? _controlsTimer;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadLiveData();
    _setupTimers();
    _startControlsAutoHide();
  }

  @override
  void dispose() {
    _controlsController.dispose();
    _chatController.dispose();
    _heartController.dispose();
    _controlsTimer?.cancel();
    _statsTimer?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _controlsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _chatController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _heartController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _controlsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controlsController, curve: Curves.easeInOut),
    );

    _chatSlide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _chatController, curve: Curves.easeOutCubic),
        );

    _heartScale = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );

    // Montrer les contrôles au démarrage
    _controlsController.forward();
  }

  Future<void> _loadLiveData() async {
    try {
      final lives = await _liveService.fetchLiveStreams();
      final live = lives.where((l) => l.id == widget.liveId).firstOrNull;

      if (live != null) {
        setState(() {
          _currentLive = live;
          _isLoading = false;
        });
      } else {
        _showError('Live introuvable');
      }
    } catch (e) {
      _showError('Erreur de chargement: $e');
    }
  }

  void _setupTimers() {
    // Mise à jour des stats toutes les 10 secondes
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isConnected && mounted) {
        _updateLiveStats();
      }
    });
  }

  Future<void> _updateLiveStats() async {
    try {
      final lives = await _liveService.fetchLiveStreams();
      final updatedLive = lives.where((l) => l.id == widget.liveId).firstOrNull;

      if (updatedLive != null && mounted) {
        setState(() {
          _currentLive = updatedLive;
        });
      }
    } catch (e) {
      // Ignorer les erreurs de mise à jour silencieuses
    }
  }

  void _startControlsAutoHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls) {
        _hideControls();
      }
    });
  }

  void _hideControls() {
    setState(() {
      _showControls = false;
    });
    _controlsController.reverse();
  }

  void _showControlsMethod() {
    setState(() {
      _showControls = true;
    });
    _controlsController.forward();
    _startControlsAutoHide();
  }

  void _toggleControls() {
    HapticFeedback.lightImpact();
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsMethod();
    }
  }

  void _toggleChat() {
    HapticFeedback.lightImpact();
    setState(() {
      _showChat = !_showChat;
    });

    if (_showChat) {
      _chatController.forward();
    } else {
      _chatController.reverse();
    }
  }

  void _toggleStats() {
    HapticFeedback.lightImpact();
    setState(() {
      _showStats = !_showStats;
    });
  }

  void _onDoubleTap() {
    // Animation de cœur
    _heartController.forward().then((_) {
      _heartController.reset();
    });

    // Envoyer un like
    _sendLike();

    HapticFeedback.mediumImpact();
  }

  Future<void> _sendLike() async {
    try {
      await _liveService.incrementLikeCount(widget.liveId);
      if (mounted) {
        setState(() {
          _currentLive = _currentLive?.copyWith(
            likeCount: (_currentLive?.likeCount ?? 0) + 1,
          );
        });
      }
    } catch (e) {
      // Ignorer les erreurs de like
    }
  }

  void _showError(String message) {
    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exitLive() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => _buildExitDialog(),
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_currentLive == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          onDoubleTap: _onDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Player vidéo
              _buildVideoPlayer(),

              // Animation de cœur
              _buildHeartAnimation(),

              // Contrôles supérieurs
              _buildTopControls(),

              // Contrôles inférieurs
              _buildBottomControls(),

              // Chat flottant
              _buildFloatingChat(),

              // Stats pour host
              if (widget.isHost && _showStats) _buildHostStats(),

              // Indicateur de statut
              _buildStatusIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            const Text(
              'Chargement du live...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return EnhancedLivePlayer(
      live: _currentLive!,
      isActive: true,
      onPlayerTap: _toggleControls,
      onError: _showError,
      onStatusChange: (status) {
        setState(() {
          _connectionStatus = status;
          _isConnected = status == 'En direct';
        });
      },
    );
  }

  Widget _buildHeartAnimation() {
    return AnimatedBuilder(
      animation: _heartScale,
      builder: (context, child) {
        return Center(
          child: Transform.scale(
            scale: _heartScale.value,
            child: const Icon(Icons.favorite, color: Colors.red, size: 100),
          ),
        );
      },
    );
  }

  Widget _buildTopControls() {
    return AnimatedBuilder(
      animation: _controlsOpacity,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsOpacity.value,
          child: Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Bouton retour
                _buildControlButton(icon: Icons.arrow_back, onTap: _exitLive),

                const Spacer(),

                // Info live
                if (_currentLive != null) _buildLiveInfo(),

                const Spacer(),

                // Boutons hôte
                if (widget.isHost) ...[
                  _buildControlButton(
                    icon: Icons.analytics,
                    onTap: _toggleStats,
                    isActive: _showStats,
                  ),
                  const SizedBox(width: 8),
                  _buildControlButton(
                    icon: Icons.call_end,
                    onTap: _exitLive,
                    color: Colors.red,
                  ),
                ] else ...[
                  _buildControlButton(
                    icon: Icons.chat,
                    onTap: _toggleChat,
                    isActive: _showChat,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return AnimatedBuilder(
      animation: _controlsOpacity,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsOpacity.value,
          child: Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Info streamer
                Expanded(child: _buildStreamerInfo()),

                const SizedBox(width: 16),

                // Actions rapides
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.favorite,
                      count: _currentLive?.likeCount ?? 0,
                      onTap: _onDoubleTap,
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.visibility,
                      count: _currentLive?.viewerCount ?? 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor
              : Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
          border: isActive ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 20),
      ),
    );
  }

  Widget _buildLiveInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isConnected ? 'LIVE' : 'OFF',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentLive?.hostName ?? 'Streamer',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _connectionStatus ?? 'Chargement...',
            style: TextStyle(color: Colors.grey[300], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            AppUtils.formatNumber(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingChat() {
    if (!_showChat) return const SizedBox.shrink();

    return SlideTransition(
      position: _chatSlide,
      child: Positioned(
        right: 16,
        top: 80,
        bottom: 120,
        width: MediaQuery.of(context).size.width * 0.7,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chat en cours de développement',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostStats() {
    return Positioned(
      left: 16,
      top: 80,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: LiveStatsWidget(liveId: widget.liveId),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_connectionStatus == null) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      left: 50,
      right: 50,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isConnected ? Colors.green : Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _connectionStatus!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExitDialog() {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.isHost ? 'Terminer le live ?' : 'Quitter le live ?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        widget.isHost
            ? 'Êtes-vous sûr de vouloir terminer ce live ? Tous les spectateurs seront déconnectés.'
            : 'Êtes-vous sûr de vouloir quitter ce live ?',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isHost ? Colors.red : AppTheme.primaryColor,
          ),
          child: Text(
            widget.isHost ? 'Terminer' : 'Quitter',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
