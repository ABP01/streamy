import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../screens/live_stream_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/search_users_screen.dart';
import '../screens/settings_screen.dart';
import '../services/live_stream_service.dart';
import '../services/swipe_navigation_service.dart';
import '../widgets/gift_shop_widget.dart';
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
  bool _isRefreshing = false;
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
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

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
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _startLive() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous devez être connecté pour démarrer un live'),
          ),
        );
        return;
      }

      // Fermer la modal
      Navigator.pop(context);

      // Créer le live
      final liveStreamService = LiveStreamService();
      final newLive = await liveStreamService.createLiveStream(hostId: user.id);

      // Navigation vers l'écran de live en tant qu'hôte
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LiveStreamScreen(liveId: newLive.id, isHost: true),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du démarrage du live: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
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
        body: RefreshIndicator(
          onRefresh: _refreshLives,
          color: Colors.purple,
          backgroundColor: Colors.grey[900],
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animation de l'icône
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 2),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: Opacity(
                          opacity: value,
                          child: const Icon(
                            Icons.live_tv_outlined,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Aucun live pour le moment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Tire vers le bas pour rafraîchir\nou lance le premier live !',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),

                  const SizedBox(height: 32),

                  // Bouton de rechargement
                  ElevatedButton.icon(
                    onPressed: _refreshLives,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Recharger',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bouton pour démarrer un live
                  OutlinedButton.icon(
                    onPressed: _startLive,
                    icon: const Icon(Icons.videocam, color: Colors.red),
                    label: const Text(
                      'Démarrer un live',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // RefreshIndicator pour swipe-to-refresh
          RefreshIndicator(
            onRefresh: _refreshLives,
            color: Colors.purple,
            backgroundColor: Colors.grey[900],
            child: PageView.builder(
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
          ),

          // Barre de navigation supérieure
          _buildTopBar(),

          // Indicateur de position
          _buildPositionIndicator(),

          // Bouton flottant pour démarrer un live
          _buildStartLiveButton(),
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

            // Boutons à droite
            Row(
              children: [
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
                  icon: const Icon(
                    Icons.message,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                // Bouton cadeaux/tokens
                IconButton(
                  onPressed: _showGiftShop,
                  icon: const Icon(
                    Icons.card_giftcard,
                    color: Colors.amber,
                    size: 28,
                  ),
                ),

                // Bouton menu/paramètres
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 28,
                  ),
                  color: Colors.grey[900],
                  onSelected: (String value) {
                    switch (value) {
                      case 'settings':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                        break;
                      case 'refresh':
                        _refreshLives();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Paramètres',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Actualiser',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartLiveButton() {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.purple, Colors.pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _startLive,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Future<void> _showGiftShop() async {
    if (_lives.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftShopWidget(
        liveId: _lives[_currentIndex].id,
        receiverId: _lives[_currentIndex].hostId,
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
