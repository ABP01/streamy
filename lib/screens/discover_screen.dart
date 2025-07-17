import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/search_users_screen.dart';
import '../services/follow_service.dart';
import '../widgets/live_thumbnail_widget.dart';

/// 📺 Écran Découvrir - Pour explorer du contenu et des utilisateurs
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<LiveStream> _trendingLives = [];
  List<UserProfile> _suggestedUsers = [];
  List<String> _trendingTags = [];

  bool _isLoadingLives = true;
  bool _isLoadingUsers = true;
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDiscoverContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscoverContent() async {
    await Future.wait([
      _loadTrendingLives(),
      _loadSuggestedUsers(),
      _loadTrendingTags(),
    ]);
  }

  Future<void> _loadTrendingLives() async {
    try {
      setState(() => _isLoadingLives = true);
      // TODO: Implémenter la logique de récupération des lives tendances
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _trendingLives = []; // Temporaire
        _isLoadingLives = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des lives tendances: $e');
      setState(() => _isLoadingLives = false);
    }
  }

  Future<void> _loadSuggestedUsers() async {
    try {
      setState(() => _isLoadingUsers = true);
      final users = await FollowService.getSuggestedUsers(limit: 20);
      setState(() {
        _suggestedUsers = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des utilisateurs suggérés: $e');
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadTrendingTags() async {
    try {
      setState(() => _isLoadingTags = true);
      // TODO: Implémenter la logique de récupération des tags tendances
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() {
        _trendingTags = [
          '#music',
          '#gaming',
          '#art',
          '#dance',
          '#comedy',
          '#cooking',
        ];
        _isLoadingTags = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des tags tendances: $e');
      setState(() => _isLoadingTags = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Découvrir',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchUsersScreen(),
                ),
              );
            },
            icon: const Icon(Icons.search, color: Colors.white),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Tendances'),
            Tab(text: 'Utilisateurs'),
            Tab(text: 'Tags'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTrendingTab(), _buildUsersTab(), _buildTagsTab()],
      ),
    );
  }

  Widget _buildTrendingTab() {
    if (_isLoadingLives) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    if (_trendingLives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun live tendance pour le moment',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTrendingLives,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrendingLives,
      child: LiveGridWidget(
        lives: _trendingLives,
        onLiveTap: (live) {
          // TODO: Naviguer vers le live
        },
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_isLoadingUsers) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'Aucun utilisateur suggéré',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSuggestedUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSuggestedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _suggestedUsers.length,
        itemBuilder: (context, index) {
          final user = _suggestedUsers[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.purple,
            backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                ? NetworkImage(user.avatar!)
                : null,
            child: user.avatar == null || user.avatar!.isEmpty
                ? Text(
                    user.username?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 12),

          // Info utilisateur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username ?? 'Utilisateur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.bio != null)
                  Text(
                    user.bio!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '${user.followers} followers',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),

          // Bouton Follow
          ElevatedButton(
            onPressed: () async {
              // TODO: Implémenter le follow/unfollow
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Suivre'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsTab() {
    if (_isLoadingTags) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrendingTags,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _trendingTags.map((tag) => _buildTagChip(tag)).toList(),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
