import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../screens/discover_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/tiktok_style_live_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/cache_service.dart';
import '../services/live_stream_service.dart';
import '../utils/app_router.dart';
import '../widgets/floating_live_button.dart';

/// 🏠 NavigationWrapper amélioré - Navigation principale avec accès à tous les écrans
class NavigationWrapperImproved extends StatefulWidget {
  final Widget? fallbackWidget;

  const NavigationWrapperImproved({super.key, this.fallbackWidget});

  @override
  State<NavigationWrapperImproved> createState() =>
      _NavigationWrapperImprovedState();
}

class _NavigationWrapperImprovedState extends State<NavigationWrapperImproved> {
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

          // Menu d'accès rapide aux écrans (Drawer-like)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: _buildQuickAccessMenu(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: const FloatingLiveButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildQuickAccessMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white),
      ),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 50),
      onSelected: (value) => _handleMenuSelection(value),
      itemBuilder: (context) => [
        _buildMenuItem(
          'search_users',
          Icons.person_search,
          'Rechercher des utilisateurs',
        ),
        _buildMenuItem('user_search', Icons.search, 'Recherche avancée'),
        _buildMenuItem('settings', Icons.settings, 'Paramètres'),
        _buildMenuItem('vertical_live', Icons.video_library, 'Lives verticaux'),
        const PopupMenuDivider(),
        _buildMenuItem('refresh', Icons.refresh, 'Actualiser'),
        _buildMenuItem('help', Icons.help_outline, 'Aide'),
        _buildMenuItem('about', Icons.info_outline, 'À propos'),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String title,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(String value) async {
    switch (value) {
      case 'search_users':
        await AppRouter.navigateToSearchUsers(context);
        break;
      case 'user_search':
        await AppRouter.navigateTo(context, AppRouter.userSearch);
        break;
      case 'settings':
        await AppRouter.navigateToSettings(context);
        break;
      case 'vertical_live':
        await AppRouter.navigateTo(context, AppRouter.verticalLive);
        break;
      case 'refresh':
        _refreshCurrentScreen();
        break;
      case 'help':
        _showHelpDialog();
        break;
      case 'about':
        _showAboutDialog();
        break;
    }
  }

  void _refreshCurrentScreen() {
    setState(() {
      _isLoading = true;
    });
    _initializeApp();
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Aide - Navigation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🏠 Onglets principaux :',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Lives : Regarder des streams en direct',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '• Découvrir : Explorer du contenu',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '• Messages : Chat privé',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '• Profil : Votre compte',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),
              Text(
                '⚡ Actions rapides :',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Bouton ⋮ : Menu d\'accès rapide',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '• Bouton Go Live : Démarrer un live',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '• Swipe : Navigation dans les lives',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Compris !',
              style: TextStyle(color: Colors.purple),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Streamy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv, size: 64, color: Colors.purple),
            SizedBox(height: 16),
            Text(
              'Version 2.0',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Plateforme de streaming live sociale',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Développé avec Flutter 💙',
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.purple)),
          ),
        ],
      ),
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
