import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../screens/messaging_screen.dart';
import '../screens/search_users_screen.dart';
import '../services/live_stream_service.dart';
import '../services/swipe_navigation_service.dart';
import '../widgets/live_overlay_widget.dart';
import '../widgets/live_player_widget.dart';

class TikTokStyleLiveScreen extends StatefulWidget {
  final List<LiveStream>? initialLives;
  final int initialIndex;

  const TikTokStyleLiveScreen({
    super.key,
    this.initialLives,
    this.initialIndex = 0,
  });

  @override
  State<TikTokStyleLiveScreen> createState() => _TikTokStyleLiveScreenState();
}

class _TikTokStyleLiveScreenState extends State<TikTokStyleLiveScreen> {
  late PageController _pageController;
  List<LiveStream> _lives = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  DateTime? _lastSwipeTime;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initializeLives();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeLives() async {
    if (widget.initialLives != null) {
      _lives = widget.initialLives!;
    } else {
      _lives = await SwipeNavigationService.preloadLives(count: 20);
    }

    if (_lives.isNotEmpty && _currentIndex < _lives.length) {
      await SwipeNavigationService.autoJoinLive(
        liveId: _lives[_currentIndex].id,
        direction: SwipeDirection.up,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _onPageChanged(int index) async {
    if (index == _currentIndex) return;

    final previousIndex = _currentIndex;
    _currentIndex = index;

    // Analytics du swipe
    if (_lastSwipeTime != null) {
      final timeSpent = DateTime.now().difference(_lastSwipeTime!);
      await SwipeNavigationService.trackSwipeAction(
        fromLiveId: _lives[previousIndex].id,
        toLiveId: index < _lives.length ? _lives[index].id : null,
        direction: index > previousIndex
            ? SwipeDirection.up
            : SwipeDirection.down,
        timeSpent: timeSpent,
      );
    }

    // Auto-leave du live précédent
    await SwipeNavigationService.cleanupPreviousLive(_lives[previousIndex].id);

    // Auto-join du nouveau live
    if (index < _lives.length) {
      await SwipeNavigationService.autoJoinLive(
        liveId: _lives[index].id,
        direction: index > previousIndex
            ? SwipeDirection.up
            : SwipeDirection.down,
      );
    }

    // Précharger plus de lives si on approche de la fin
    if (index >= _lives.length - 3) {
      await _loadMoreLives();
    }

    // Précharger les ressources du live suivant
    if (index + 1 < _lives.length) {
      SwipeNavigationService.preloadNextLiveResources(_lives[index + 1]);
    }

    _lastSwipeTime = DateTime.now();

    // Vibration feedback
    HapticFeedback.lightImpact();
  }

  Future<void> _loadMoreLives() async {
    try {
      final moreLives = await LiveStreamService().fetchLiveStreams(
        limit: 10,
        offset: _lives.length,
        sort: LiveStreamSort.viewerCount,
      );

      if (moreLives.isNotEmpty) {
        setState(() {
          _lives.addAll(moreLives);
        });
      }
    } catch (e) {
      print('Erreur chargement lives supplémentaires: $e');
    }
  }

  Future<void> _refreshLives() async {
    try {
      final newLives = await SwipeNavigationService.getRecommendedLives(
        limit: 20,
      );
      if (newLives.isNotEmpty) {
        setState(() {
          _lives = newLives;
          _currentIndex = 0;
        });
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      print('Erreur rafraîchissement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_lives.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.live_tv_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun live disponible',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshLives,
                child: const Text('Actualiser'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView principal pour la navigation verticale
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: _lives.length,
            itemBuilder: (context, index) {
              final live = _lives[index];
              return Stack(
                children: [
                  // Player vidéo en arrière-plan
                  LivePlayerWidget(
                    live: live,
                    isActive: index == _currentIndex,
                  ),

                  // Overlay avec informations et contrôles
                  LiveOverlayWidget(
                    live: live,
                    isActive: index == _currentIndex,
                    onRefresh: _refreshLives,
                  ),
                ],
              );
            },
          ),

          // Barre de navigation supérieure
          _buildTopBar(),

          // Indicateur de position
          _buildPositionIndicator(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bouton recherche
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchUsersScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.search, color: Colors.white, size: 28),
            ),

            // Logo/Titre
            const Text(
              'Streamy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Bouton messages
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MessagingScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.message, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionIndicator() {
    if (_lives.length <= 1) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.4,
      child: Column(
        children: List.generate(
          _lives.length.clamp(0, 5), // Limiter à 5 points max
          (index) => Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            width: 4,
            height: index == _currentIndex ? 16 : 8,
            decoration: BoxDecoration(
              color: index == _currentIndex
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
