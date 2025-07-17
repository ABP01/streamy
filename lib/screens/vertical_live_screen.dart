import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/cache_service.dart';
import '../services/live_stream_service.dart';
import '../widgets/enhanced_chat_widget.dart';
import '../widgets/live_stats_widget.dart';

class VerticalLiveScreen extends StatefulWidget {
  final String? initialLiveId;

  const VerticalLiveScreen({super.key, this.initialLiveId});

  @override
  State<VerticalLiveScreen> createState() => _VerticalLiveScreenState();
}

class _VerticalLiveScreenState extends State<VerticalLiveScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final LiveStreamService _liveStreamService = LiveStreamService();

  List<LiveStream> _lives = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  late AnimationController _overlayController;
  late AnimationController _reactionController;

  bool _showOverlay = true;
  bool _showChat = true;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _reactionController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _loadInitialLives();
    _setupOverlayTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _overlayController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialLives() async {
    try {
      // Essayer de charger depuis le cache d'abord
      final cachedLives = await CacheService.getCachedLives();
      if (cachedLives != null && cachedLives.isNotEmpty) {
        setState(() {
          _lives = cachedLives;
          _isLoading = false;
        });

        // Si un live initial est spécifié, aller à sa position
        if (widget.initialLiveId != null) {
          final index = _lives.indexWhere(
            (live) => live.id == widget.initialLiveId,
          );
          if (index != -1) {
            _currentIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      }

      // Charger les lives frais depuis l'API
      final freshLives = await _liveStreamService.fetchLiveStreams(limit: 20);

      if (mounted) {
        setState(() {
          _lives = freshLives;
          _isLoading = false;
        });

        // Mettre en cache les nouveaux lives
        await CacheService.cacheLives(freshLives);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement: $e')));
      }
    }
  }

  Future<void> _loadMoreLives() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreLives = await _liveStreamService.fetchLiveStreams(
        limit: 10,
        offset: _lives.length,
      );

      if (mounted && moreLives.isNotEmpty) {
        setState(() {
          _lives.addAll(moreLives);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _setupOverlayTimer() {
    _overlayController.forward();

    // Cacher l'overlay automatiquement après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _overlayController.reverse();
        setState(() {
          _showOverlay = false;
        });
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });

    if (_showOverlay) {
      _overlayController.forward();
      _setupOverlayTimer();
    } else {
      _overlayController.reverse();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Charger plus de lives quand on approche de la fin
    if (index >= _lives.length - 3) {
      _loadMoreLives();
    }

    // Joindre le nouveau live
    _joinLive(_lives[index]);
  }

  Future<void> _joinLive(LiveStream live) async {
    try {
      // TODO: Obtenir l'ID de l'utilisateur actuel depuis l'authentification
      final userId = 'current_user_id'; // Remplacer par l'ID réel
      await _liveStreamService.joinLive(live.id, userId);
    } catch (e) {
      debugPrint('Erreur pour rejoindre le live: $e');
    }
  }

  void _triggerReaction(String reaction) {
    _reactionController.forward().then((_) {
      _reactionController.reset();
    });

    // TODO: Envoyer la réaction au serveur
    debugPrint('Réaction envoyée: $reaction');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    if (_lives.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.live_tv, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Aucun live disponible',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialLives,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleOverlay,
        child: Stack(
          children: [
            // Liste des lives en vertical
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: _lives.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _lives.length) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  );
                }

                return _buildLivePage(_lives[index]);
              },
            ),

            // Overlay avec les contrôles
            if (_showOverlay)
              FadeTransition(
                opacity: _overlayController,
                child: _buildOverlay(_lives[_currentIndex]),
              ),

            // Boutons d'interaction sur le côté droit
            Positioned(
              right: 16,
              bottom: 100,
              child: _buildInteractionButtons(_lives[_currentIndex]),
            ),

            // Chat en bas
            if (_showChat)
              Positioned(
                left: 0,
                right: 80,
                bottom: 0,
                height: 300,
                child: EnhancedChatWidget(liveId: _lives[_currentIndex].id),
              ),

            // Indicateur de position
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 16,
              child: _buildPositionIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePage(LiveStream live) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fond noir simple pour le live
          Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.videocam, color: Colors.white54, size: 100),
            ),
          ),

          // Overlay sombre pour la lisibilité
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // Contenu du live (vidéo/stream)
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LIVE',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    live.hostName ?? 'Live Stream',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(LiveStream live) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header avec info du streamer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: live.hostAvatar != null
                        ? CachedNetworkImageProvider(live.hostAvatar!)
                        : null,
                    child: live.hostAvatar == null
                        ? Text(
                            (live.hostName ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          live.hostName ?? 'Utilisateur inconnu',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Live • ${live.formattedDuration}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bouton suivre
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Implémenter follow/unfollow
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(60, 32),
                    ),
                    child: const Text('Suivre', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Footer avec info du live
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    live.hostName ?? 'Live Stream',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Afficher la durée du live au lieu de la description
                  const SizedBox(height: 8),
                  Text(
                    'En direct depuis ${live.formattedDuration}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  LiveStatsWidget(liveId: live.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButtons(LiveStream live) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInteractionButton(
          icon: Icons.favorite,
          count: live.likeCount,
          onTap: () => _triggerReaction('❤️'),
        ),
        const SizedBox(height: 16),
        _buildInteractionButton(
          icon: Icons.comment,
          count: 0, // TODO: Récupérer le nombre de commentaires
          onTap: () {
            setState(() {
              _showChat = !_showChat;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildInteractionButton(
          icon: Icons.share,
          onTap: () => _shareLive(live),
        ),
        const SizedBox(height: 16),
        _buildInteractionButton(
          icon: Icons.card_giftcard,
          onTap: () => _showGiftDialog(live),
        ),
      ],
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            if (count != null && count > 0)
              Text(
                _formatCount(count),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_currentIndex + 1}/${_lives.length}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  void _shareLive(LiveStream live) {
    // TODO: Implémenter le partage
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Partage - À implémenter')));
  }

  void _showGiftDialog(LiveStream live) {
    // TODO: Implémenter l'envoi de cadeaux
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Envoyer un cadeau',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Fonctionnalité de cadeaux à implémenter',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
