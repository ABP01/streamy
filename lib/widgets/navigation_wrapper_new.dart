import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../screens/discover_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/tiktok_style_live_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/cache_service.dart';
import '../services/live_stream_service.dart';
import '../widgets/floating_live_button.dart';

/// 🏠 NavigationWrapper - Page principale avec BottomNav et preloader
/// Tabs: Lives (TikTok style), Découvrir, Messages, Profil
class NavigationWrapper extends StatefulWidget {
  final Widget? fallbackWidget;

  const NavigationWrapper({super.key, this.fallbackWidget});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _currentIndex = 0;
  List<LiveStream> _lives = [];
  bool _isLoading = true;
  int _activeLivesCount = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialiser le cache
      await CacheService.init();

      // Précharger les lives pour une navigation fluide
      final liveService = LiveStreamService();
      final lives = await liveService.fetchLiveStreams(limit: 10);

      setState(() {
        _lives = lives;
        _activeLivesCount = lives.where((live) => live.isLive).length;
      });

      // Construire les pages avec les données chargées
      _pages = [
        TikTokStyleLiveScreen(initialLives: _lives, initialIndex: 0),
        const DiscoverScreen(),
        const MessagingScreen(),
        UserProfileScreen(
          userId: Supabase.instance.client.auth.currentUser?.id ?? '',
          isCurrentUser: true,
        ),
      ];

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors de l\'initialisation: $e');
      setState(() {
        _isLoading = false;
        _pages = [
          widget.fallbackWidget ??
              const Center(
                child: Text(
                  'Erreur de chargement',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          const DiscoverScreen(),
          const MessagingScreen(),
          UserProfileScreen(
            userId: Supabase.instance.client.auth.currentUser?.id ?? '',
            isCurrentUser: true,
          ),
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.purple),
              const SizedBox(height: 16),
              const Text(
                'Chargement des lives...',
                style: TextStyle(color: Colors.white70),
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
          // Contenu principal
          IndexedStack(index: _currentIndex, children: _pages),

          // Mini-barre de statut des lives actifs (seulement sur l'onglet Lives)
          if (_currentIndex == 0 && _activeLivesCount > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Colors.white, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      '$_activeLivesCount lives actifs',
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
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: const FloatingLiveButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.grey[900],
          selectedItemColor: Colors.purple,
          unselectedItemColor: Colors.white60,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              activeIcon: Icon(Icons.home),
              label: 'Lives',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              activeIcon: Icon(Icons.explore),
              label: 'Découvrir',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              activeIcon: Icon(Icons.message),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
