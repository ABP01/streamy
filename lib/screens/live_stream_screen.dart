import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/enhanced_chat_widget.dart';
import '../widgets/reaction_animations.dart' as reactions;
import '../widgets/gift_animations.dart';
import '../widgets/live_stats_widget.dart';
import '../models/live_stream.dart';
import '../services/live_stream_service.dart';
import '../services/chat_service.dart';
import 'dart:async';

class LiveStreamScreen extends StatefulWidget {
  final String liveId;
  final bool isHost;

  const LiveStreamScreen({
    super.key,
    required this.liveId,
    required this.isHost,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with TickerProviderStateMixin {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final GlobalKey _reactionKey = GlobalKey();
  final GlobalKey _giftKey = GlobalKey();
  final PageController _pageController = PageController();
  
  LiveStream? _currentLive;
  bool _isLoading = true;
  bool _isConnected = false;
  bool _showChat = true;
  bool _showStats = false;
  Timer? _heartbeatTimer;
  Timer? _statsTimer;
  
  // Variables pour les contrôles de l'interface
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeLiveStream();
    _setupHeartbeat();
    _setupStatsUpdate();
    _setupControlsTimer();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _statsTimer?.cancel();
    _controlsTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeLiveStream() async {
    try {
      final lives = await _liveStreamService.fetchLiveStreams();
      final live = lives.where((l) => l.id == widget.liveId).firstOrNull;
      if (live != null) {
        setState(() {
          _currentLive = live;
          _isLoading = false;
        });
        
        // Rejoindre le live
        await _liveStreamService.joinLive(widget.liveId, 'current_user_id');
        setState(() {
          _isConnected = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Gérer l'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _setupHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        // Heartbeat personnalisé - à implémenter
        print('Heartbeat envoyé pour ${widget.liveId}');
      }
    });
  }

  void _setupStatsUpdate() {
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentLive != null) {
        _updateLiveStats();
      }
    });
  }

  void _setupControlsTimer() {
    _resetControlsTimer();
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  Future<void> _updateLiveStats() async {
    try {
      final lives = await _liveStreamService.fetchLiveStreams();
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

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _resetControlsTimer();
    }
  }

  void _handleGiftSent(String giftId, String giftType, int quantity) {
    // Envoyer le cadeau via le service
    // _liveStreamService.sendGift(widget.liveId, giftId, giftType, quantity);
    
    // Afficher une réaction
    // _reactionKey.currentState?.addReaction(reactions.ReactionType.gift);
  }

  void _handleReaction(reactions.ReactionType type) {
    // _reactionKey.currentState?.addReaction(type);
    
    // Envoyer la réaction au serveur (à implémenter)
    switch (type) {
      case reactions.ReactionType.heart:
        print('❤️ Réaction coeur envoyée');
        break;
      case reactions.ReactionType.like:
        print('👍 Like envoyé');
        break;
      default:
        print('Réaction envoyée: $type');
        break;
    }
  }

  void _endLive() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Terminer le live',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir terminer ce live ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Terminer le live (à implémenter)
              print('Live terminé: ${widget.liveId}');
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Terminer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.purple),
        ),
      );
    }

    if (_currentLive == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Live introuvable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Fond vidéo (à remplacer par Agora)
            _buildVideoBackground(),
            
            // Overlay de réactions
            reactions.ReactionAnimationWidget(
              key: _reactionKey,
              liveId: widget.liveId,
              child: const SizedBox.expand(),
            ),
            
            // Interface utilisateur
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildUIOverlay(),
            ),
            
            // Chat (toujours visible en bas)
            if (_showChat) _buildChatOverlay(),
            
            // Stats pour l'hôte
            if (widget.isHost && _showStats) _buildStatsOverlay(),
            
            // Animations de cadeaux
            GiftAnimationWidget(
              key: _giftKey,
              liveId: widget.liveId,
              userId: 'current_user_id', // À remplacer
              onGiftSent: _handleGiftSent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple.withOpacity(0.3),
            Colors.pink.withOpacity(0.3),
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: _currentLive!.thumbnail != null
          ? Image.network(
              _currentLive!.thumbnail!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderVideo();
              },
            )
          : _buildPlaceholderVideo(),
    );
  }

  Widget _buildPlaceholderVideo() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade800,
            Colors.pink.shade800,
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Vidéo en direct',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUIOverlay() {
    return Column(
      children: [
        // Barre du haut
        _buildTopBar(),
        
        const Spacer(),
        
        // Contrôles du bas
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Bouton retour
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Informations du live
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentLive!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentLive!.viewerCount}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Boutons d'action pour l'hôte
            if (widget.isHost) ...[
              GestureDetector(
                onTap: () => setState(() => _showStats = !_showStats),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _endLive,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Bouton de toggle chat
          GestureDetector(
            onTap: () => setState(() => _showChat = !_showChat),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showChat ? Icons.chat : Icons.chat_outlined,
                color: Colors.white,
              ),
            ),
          ),
          
          const Spacer(),
          
          // Boutons de réaction
          Row(
            children: [
              reactions.FloatingLikesWidget(
                onTap: () => _handleReaction(reactions.ReactionType.heart),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _handleReaction(reactions.ReactionType.star),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: MediaQuery.of(context).size.height * 0.5,
      child: EnhancedChatWidget(
        liveId: widget.liveId,
        isHost: widget.isHost,
      ),
    );
  }

  Widget _buildStatsOverlay() {
    return Positioned(
      top: 100,
      right: 16,
      child: LiveStatsWidget(
        liveId: widget.liveId,
        onClose: () => setState(() => _showStats = false),
      ),
    );
  }
}
