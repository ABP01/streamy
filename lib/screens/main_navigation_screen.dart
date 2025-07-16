import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/bottom_navigation.dart';
import 'discover_screen.dart';
import 'search_screen.dart';
import 'tiktok_style_live_screen.dart';
import 'user_profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentNavIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _currentNavIndex = index;
    });

    switch (index) {
      case 0:
        // Home - Revenir à la page d'accueil
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        break;
      case 1:
        // Search - Navigation vers la page de recherche
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        ).then((_) {
          // Réinitialiser l'index quand on revient
          setState(() {
            _currentNavIndex = 0;
          });
        });
        break;
      case 2:
        // Live Streams - Navigation directe vers le défilement de lives
        _navigateDirectlyToLiveStreams();
        break;

      case 3:
        // Messages - Navigation vers les messages privés
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages privés - À venir'),
            backgroundColor: Color(0xFF6C5CE7),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        );
        setState(() {
          _currentNavIndex = 0;
        });
        break;
      case 4:
        // Profile - Navigation vers le profil utilisateur
        UserProfile mockUser = UserProfile(
          id: '1',
          email: 'user@example.com',
          username: 'user123',
          fullName: 'John Doe',
          avatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
          isVerified: true,
          bio: 'Gamer passionné',
          followers: 12000,
          following: 108,
          totalLikes: 86,
          createdAt: DateTime.now(),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(user: mockUser),
          ),
        ).then((_) {
          // Réinitialiser l'index quand on revient
          setState(() {
            _currentNavIndex = 0;
          });
        });
        break;
    }
  }

  void _navigateDirectlyToLiveStreams() {
    // Créer une liste de lives de démonstration
    List<StreamContent> liveStreams = [
      StreamContent(
        id: '1',
        title: 'Epic Gaming Marathon - Live Now!',
        thumbnail:
            'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=400&h=800&fit=crop',
        username: 'GamerPro2024',
        userAvatar:
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop&crop=face',
        category: 'Gaming',
        viewerCount: 15420,
        isLive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      StreamContent(
        id: '2',
        title: 'Music Production Session 🎵',
        thumbnail:
            'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=800&fit=crop',
        username: 'MusicMakerPro',
        userAvatar:
            'https://images.unsplash.com/photo-1494790108755-2616b332c2be?w=150&h=150&fit=crop&crop=face',
        category: 'Music',
        viewerCount: 8930,
        isLive: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
      StreamContent(
        id: '3',
        title: 'Digital Art Creation Live',
        thumbnail:
            'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=400&h=800&fit=crop',
        username: 'ArtistLife',
        userAvatar:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        category: 'Art',
        viewerCount: 5670,
        isLive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      StreamContent(
        id: '4',
        title: 'Cooking Challenge Live 🍳',
        thumbnail:
            'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=400&h=800&fit=crop',
        username: 'ChefMaster',
        userAvatar:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        category: 'Lifestyle',
        viewerCount: 12340,
        isLive: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      StreamContent(
        id: '5',
        title: 'Fitness Workout Session 💪',
        thumbnail:
            'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=800&fit=crop',
        username: 'FitnessGuru',
        userAvatar:
            'https://images.unsplash.com/photo-1566753323558-f4e0952af115?w=150&h=150&fit=crop&crop=face',
        category: 'Sports',
        viewerCount: 9876,
        isLive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];

    // Navigation directe vers le TikTok-style live screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TikTokStyleLiveScreen(liveStreams: liveStreams, initialIndex: 0),
      ),
    ).then((_) {
      setState(() {
        _currentNavIndex = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true, // Permet à la navbar de se superposer au contenu
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Désactive le swipe
        children: const [
          DiscoverScreen(),
          // On peut ajouter d'autres pages ici si nécessaire
        ],
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentNavIndex,
        onTap: _onNavItemTapped,
      ),
    );
  }
}
