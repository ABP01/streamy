import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/messaging_screen.dart';
import '../services/follow_service.dart';
import '../services/user_search_service.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<UserProfile> _searchResults = [];
  List<UserProfile> _popularUsers = [];
  List<UserProfile> _recentUsers = [];
  List<UserProfile> _suggestedUsers = [];

  bool _isSearching = false;
  bool _isLoadingPopular = true;
  bool _isLoadingRecent = true;
  bool _isLoadingSuggested = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadPopularUsers(),
      _loadRecentUsers(),
      _loadSuggestedUsers(),
    ]);
  }

  Future<void> _loadPopularUsers() async {
    try {
      final users = await UserSearchService.getPopularUsers(limit: 20);
      setState(() {
        _popularUsers = users;
        _isLoadingPopular = false;
      });
    } catch (e) {
      setState(() => _isLoadingPopular = false);
    }
  }

  Future<void> _loadRecentUsers() async {
    try {
      final users = await UserSearchService.getRecentlyActiveUsers(limit: 20);
      setState(() {
        _recentUsers = users;
        _isLoadingRecent = false;
      });
    } catch (e) {
      setState(() => _isLoadingRecent = false);
    }
  }

  Future<void> _loadSuggestedUsers() async {
    try {
      final users = await UserSearchService.getSuggestedUsers(limit: 20);
      setState(() {
        _suggestedUsers = users;
        _isLoadingSuggested = false;
      });
    } catch (e) {
      setState(() => _isLoadingSuggested = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await UserSearchService.searchUsers(
        query: query,
        limit: 30,
      );
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Rechercher des utilisateurs...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _searchUsers('');
                    },
                  )
                : null,
          ),
          onChanged: _searchUsers,
        ),
      ),
      body: _searchController.text.isNotEmpty
          ? _buildSearchResults()
          : _buildDiscoverContent(),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Aucun utilisateur trouvé',
              style: TextStyle(color: Colors.grey[400], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildUserTile(_searchResults[index]);
      },
    );
  }

  Widget _buildDiscoverContent() {
    return Column(
      children: [
        // Tabs
        Container(
          color: Colors.black,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.purple,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Populaires'),
              Tab(text: 'Récents'),
              Tab(text: 'Suggestions'),
              Tab(text: 'À proximité'),
            ],
          ),
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUserList(_popularUsers, _isLoadingPopular),
              _buildUserList(_recentUsers, _isLoadingRecent),
              _buildUserList(_suggestedUsers, _isLoadingSuggested),
              _buildNearbyUsers(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(List<UserProfile> users, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Text(
          'Aucun utilisateur trouvé',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        return _buildUserTile(users[index]);
      },
    );
  }

  Widget _buildNearbyUsers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Fonctionnalité à venir',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Trouvez des utilisateurs près de chez vous',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserProfile user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 25,
            backgroundImage: user.avatar != null
                ? CachedNetworkImageProvider(user.avatar!)
                : null,
            backgroundColor: Colors.grey[700],
            child: user.avatar == null
                ? Text(
                    (user.username ?? user.fullName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 12),

          // Informations utilisateur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Colors.blue, size: 16),
                    ],
                  ],
                ),
                if (user.username != null)
                  Text(
                    '@${user.username}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${user.followers} abonnés',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Message
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MessagingScreen(initialUserId: user.id),
                    ),
                  );
                },
                icon: const Icon(Icons.message_outlined, color: Colors.white),
              ),

              // Follow/Unfollow
              _buildFollowButton(user),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(UserProfile user) {
    return FutureBuilder<bool>(
      future: FollowService.isFollowing(user.id),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;

        return ElevatedButton(
          onPressed: () async {
            try {
              if (isFollowing) {
                await FollowService.unfollowUser(user.id);
              } else {
                await FollowService.followUser(user.id);
              }
              setState(() {}); // Refresh pour mettre à jour le bouton
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey[700] : Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            isFollowing ? 'Suivi' : 'Suivre',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}
