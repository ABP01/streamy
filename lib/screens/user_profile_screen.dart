import 'package:flutter/material.dart';

import '../models/models.dart';

class UserProfileScreen extends StatefulWidget {
  final UserProfile user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  int _selectedContentIndex = 0;
  List<StreamContent> _userStreams = [];
  List<String> _userTags = [
    'Game',
    'Dota 2',
    'Mobile Legend',
    'PUBG',
    'Clash Royale',
    'Clash of Clans',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserStreams();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadUserStreams() {
    // Simuler le chargement des streams de l'utilisateur
    setState(() {
      _userStreams = [
        StreamContent(
          id: '1',
          title: 'Epic Gaming Session',
          thumbnail:
              'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=400&h=600&fit=crop',
          username: widget.user.username ?? 'User',
          userAvatar: widget.user.avatar,
          category: 'Game',
          viewerCount: 910,
          isLive: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        StreamContent(
          id: '2',
          title: 'Mobile Legends Tournament',
          thumbnail:
              'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=400&h=600&fit=crop',
          username: widget.user.username ?? 'User',
          userAvatar: widget.user.avatar,
          category: 'Game',
          viewerCount: 910,
          isLive: false,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        StreamContent(
          id: '3',
          title: 'Clash Royale Strategies',
          thumbnail:
              'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=300&fit=crop',
          username: widget.user.username ?? 'User',
          userAvatar: widget.user.avatar,
          category: 'Game',
          viewerCount: 756,
          isLive: false,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        StreamContent(
          id: '4',
          title: 'PUBG Squad Gameplay',
          thumbnail:
              'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=400&h=600&fit=crop',
          username: widget.user.username ?? 'User',
          userAvatar: widget.user.avatar,
          category: 'Game',
          viewerCount: 1200,
          isLive: false,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildProfileHeader(),
          _buildTagsSection(),
          _buildActionButtons(),
          _buildContentGrid(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications - À venir'),
                backgroundColor: Color(0xFF6C5CE7),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
          ),
        ),
      ],
      pinned: false,
      expandedHeight: 0,
    );
  }

  Widget _buildProfileHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Photo de profil
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: widget.user.avatar != null
                        ? DecorationImage(
                            image: NetworkImage(widget.user.avatar!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: widget.user.avatar == null
                        ? Colors.grey.shade700
                        : null,
                  ),
                  child: widget.user.avatar == null
                      ? Center(
                          child: Text(
                            (widget.user.fullName?.isNotEmpty == true)
                                ? widget.user.fullName![0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 20),
                // Statistiques
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('86', 'Posts'),
                      _buildStatColumn('108', 'Following'),
                      _buildStatColumn('12K', 'Followers'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Nom et vérification
            Row(
              children: [
                Text(
                  widget.user.fullName ?? widget.user.username ?? 'Utilisateur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.user.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified,
                    color: Color(0xFF6C5CE7),
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Bio
            if (widget.user.bio != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Part of @odamaesport',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Live everyday 8pm - 11pm WIB',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedContentIndex = 0;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedContentIndex == 0
                      ? const Color(0xFF6C5CE7)
                      : Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Live Stream',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedContentIndex = 1;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedContentIndex == 1
                      ? const Color(0xFF6C5CE7)
                      : Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Stream Likes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _userTags
              .map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildContentGrid() {
    // Show different content based on selected button
    List<StreamContent> contentList = _selectedContentIndex == 0
        ? _userStreams
        : [];
    if (contentList.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Text(
            'Aucun contenu à afficher.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = contentList[index];
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: NetworkImage(item.thumbnail),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade800,
                        child: const Icon(
                          Icons.error,
                          color: Colors.white54,
                          size: 32,
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: contentList.length),
      ),
    );
  }
}
