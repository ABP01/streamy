import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/follow_service.dart';
import 'private_chat_screen.dart';
import 'user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<UserProfile> _searchResults = [];
  List<UserProfile> _suggestedUsers = [];
  bool _isSearching = false;
  bool _isLoadingSuggestions = true;
  String _currentQuery = '';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSuggestedUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _currentQuery) {
      _currentQuery = query;
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      } else {
        _performSearch(query);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await FollowService.searchUsers(query);
      if (mounted && query == _currentQuery) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de recherche: $e')));
      }
    }
  }

  Future<void> _loadSuggestedUsers() async {
    try {
      final suggested = await FollowService.getSuggestedUsers(limit: 20);
      if (mounted) {
        setState(() {
          _suggestedUsers = suggested;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Rechercher des utilisateurs...',
              hintStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Résultats'),
            Tab(text: 'Suggestions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSearchResults(), _buildSuggestions()],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_currentQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Recherchez des utilisateurs',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Tapez un nom d\'utilisateur ou un nom complet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat pour "$_currentQuery"',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Essayez un autre terme de recherche',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_searchResults[index]);
      },
    );
  }

  Widget _buildSuggestions() {
    if (_isLoadingSuggestions) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    if (_suggestedUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucune suggestion disponible',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suggestedUsers.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_suggestedUsers[index]);
      },
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: user.avatar != null
              ? CachedNetworkImageProvider(user.avatar!)
              : null,
          child: user.avatar == null
              ? Text(
                  user.displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (user.isVerified)
              const Icon(Icons.verified, color: Colors.blue, size: 20),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.username != null)
              Text(
                '@${user.username}',
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 4),
            Text(
              '${user.followers} followers',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 120,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFollowButton(user),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _openPrivateChat(user),
                icon: const Icon(Icons.message, color: Colors.blue),
                tooltip: 'Message privé',
              ),
            ],
          ),
        ),
        onTap: () => _openUserProfile(user),
      ),
    );
  }

  Widget _buildFollowButton(UserProfile user) {
    return FutureBuilder<bool>(
      future: FollowService.isFollowing(user.id),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;

        return ElevatedButton(
          onPressed: () => _toggleFollow(user, isFollowing),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey[700] : Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(60, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            isFollowing ? 'Suivi' : 'Suivre',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow(
    UserProfile user,
    bool isCurrentlyFollowing,
  ) async {
    try {
      bool success;
      if (isCurrentlyFollowing) {
        success = await FollowService.unfollowUser(user.id);
      } else {
        success = await FollowService.followUser(user.id);
      }

      if (success && mounted) {
        setState(() {
          // Mettre à jour la liste locale
          final userIndex = _searchResults.indexWhere((u) => u.id == user.id);
          if (userIndex != -1) {
            _searchResults[userIndex] = UserProfile(
              id: user.id,
              email: user.email,
              username: user.username,
              fullName: user.fullName,
              avatar: user.avatar,
              bio: user.bio,
              followers: isCurrentlyFollowing
                  ? user.followers - 1
                  : user.followers + 1,
              following: user.following,
              totalLikes: user.totalLikes,
              totalGifts: user.totalGifts,
              tokensBalance: user.tokensBalance,
              createdAt: user.createdAt,
              lastSeen: user.lastSeen,
              isVerified: user.isVerified,
              isModerator: user.isModerator,
              preferences: user.preferences,
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyFollowing
                  ? 'Vous ne suivez plus ${user.displayName}'
                  : 'Vous suivez maintenant ${user.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openUserProfile(UserProfile user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: user.id),
      ),
    );
  }

  void _openPrivateChat(UserProfile user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateChatScreen(otherUser: user),
      ),
    );
  }
}
