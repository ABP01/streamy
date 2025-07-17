import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../screens/messaging_screen.dart';
import '../screens/search_users_screen.dart';
import '../screens/tiktok_style_live_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/cache_service.dart';
import '../services/swipe_navigation_service.dart';

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

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialiser le cache
      await CacheService.init();

      // Précharger les lives
      _lives = await SwipeNavigationService.preloadLives(count: 20);

      // Initialiser les pages
      _pages.addAll([
        TikTokStyleLiveScreen(initialLives: _lives),
        const SearchUsersScreen(),
        const MessagingScreen(),
        UserProfileScreen(
          userId: Supabase.instance.client.auth.currentUser?.id ?? '',
        ),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur initialisation: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.purple),
              SizedBox(height: 16),
              Text(
                'Chargement de Streamy...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_pages.isEmpty) {
      return widget.fallbackWidget ??
          const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Erreur de chargement',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _currentIndex == 0
          ? null // Pas de bottom nav pour l'expérience TikTok
          : _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        elevation: 0,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Découvrir'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
