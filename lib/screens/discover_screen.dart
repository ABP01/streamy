import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/live_stream.dart';
import '../services/live_stream_service.dart';
import '../widgets/live_card_widget.dart';
import 'live_stream_screen.dart';
import 'start_live_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  List<LiveStream> _allLives = [];
  List<LiveStream> _filteredLives = [];
  List<String> _categories = [
    'Tous',
    'Gaming',
    'Musique',
    'Art',
    'Sport',
    'Cuisine',
    'Tech',
    'Lifestyle',
  ];
  String _selectedCategory = 'Tous';
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupTabController();
    _loadLiveStreams();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _fabAnimationController.dispose();
    _tabController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _fabAnimationController = AnimationController(
      duration: AppAnimations.mediumDuration,
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: AppAnimations.elasticCurve,
      ),
    );
  }

  void _setupTabController() {
    _tabController = TabController(length: 3, vsync: this);
  }

  void _setupAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshLiveStreams();
      }
    });
  }

  Future<void> _loadLiveStreams() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final streams = await _liveStreamService.fetchLiveStreams(limit: 50);

      if (mounted) {
        setState(() {
          _allLives = streams.where((stream) => stream.isLive).toList();
          _filterLives();
          _isLoading = false;
        });

        if (_allLives.isNotEmpty) {
          _fabAnimationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _refreshLiveStreams() async {
    try {
      final streams = await _liveStreamService.fetchLiveStreams(limit: 50);

      if (mounted) {
        setState(() {
          _allLives = streams.where((stream) => stream.isLive).toList();
          _filterLives();
        });
      }
    } catch (e) {
      print('Erreur de rafraîchissement: $e');
    }
  }

  void _filterLives() {
    String searchQuery = _searchController.text.toLowerCase();
    setState(() {
      _filteredLives = _allLives.where((live) {
        bool matchesCategory =
            _selectedCategory == 'Tous' ||
            live.category?.toLowerCase() == _selectedCategory.toLowerCase();
        bool matchesSearch =
            searchQuery.isEmpty ||
            live.title.toLowerCase().contains(searchQuery) ||
            (live.description?.toLowerCase().contains(searchQuery) ?? false) ||
            (live.hostName?.toLowerCase().contains(searchQuery) ?? false);
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterLives();
  }

  void _onSearchChanged(String query) {
    _filterLives();
  }

  void _navigateToLive(LiveStream live) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(liveId: live.id, isHost: false),
      ),
    );
  }

  void _startLive() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StartLiveScreen()),
    ).then((_) => _refreshLiveStreams());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildSearchBar(),
            _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: _startLive,
          icon: const Icon(Icons.videocam),
          label: const Text('Go Live'),
          backgroundColor: AppTheme.primaryColor,
          elevation: 8,
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final user = Supabase.instance.client.auth.currentUser;
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Streamy',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),

          const Spacer(),

          // Indicateur de lives actifs
          if (_allLives.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(16),
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
                  const SizedBox(width: 8),
                  Text(
                    '${_allLives.length} LIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(width: 12),

          // Avatar utilisateur
          GestureDetector(
            onTap: () => _showUserMenu(),
            child: UserAvatar(
              username:
                  user?.userMetadata?['username'] ?? user?.email ?? 'User',
              size: 40,
              showOnlineIndicator: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Rechercher des lives...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: AppTheme.surfaceColor.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryColor,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'Pour vous'),
          Tab(text: 'En direct'),
          Tab(text: 'Populaires'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text(
              'Chargement des lives...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadLiveStreams,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildForYouTab(), _buildLiveTab(), _buildPopularTab()],
    );
  }

  Widget _buildForYouTab() {
    if (_filteredLives.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildCategoryFilter(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshLiveStreams,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _filteredLives.length,
              itemBuilder: (context, index) {
                return LiveCardWidget(
                  live: _filteredLives[index],
                  onTap: () => _navigateToLive(_filteredLives[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTab() {
    final liveLives = _filteredLives.where((live) => live.isLive).toList();

    if (liveLives.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: liveLives.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: LiveCardWidget(
            live: liveLives[index],
            onTap: () => _navigateToLive(liveLives[index]),
            isHorizontal: true,
          ),
        );
      },
    );
  }

  Widget _buildPopularTab() {
    final popularLives = List<LiveStream>.from(_filteredLives)
      ..sort(
        (a, b) => (b.viewerCount + b.likeCount).compareTo(
          a.viewerCount + a.likeCount,
        ),
      );

    if (popularLives.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: popularLives.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: LiveCardWidget(
            live: popularLives[index],
            onTap: () => _navigateToLive(popularLives[index]),
            isHorizontal: true,
            showRanking: true,
            ranking: index + 1,
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return GestureDetector(
            onTap: () => _onCategoryChanged(category),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.white30,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.live_tv, size: 64, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun live en cours',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Soyez le premier à commencer un live !',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startLive,
            icon: const Icon(Icons.videocam),
            label: const Text('Commencer un live'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: const Text(
                'Profil',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers le profil
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text(
                'Historique',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers l'historique
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Paramètres',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers les paramètres
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Déconnexion',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await Supabase.instance.client.auth.signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
