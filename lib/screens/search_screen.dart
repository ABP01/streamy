import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/stream_content_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<StreamContent> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  // Données de démonstration pour les résultats de recherche
  final List<StreamContent> _allContent = [
    StreamContent(
      id: '1',
      title: 'Epic Gaming Session',
      category: 'Game',
      thumbnail:
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=400&h=600&fit=crop',
      viewerCount: 910,
      username: 'GamerPro',
      userAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=50&h=50&fit=crop&crop=face',
      isLive: true,
      createdAt: DateTime.now(),
    ),
    StreamContent(
      id: '2',
      title: 'Mobile Legends Tournament',
      category: 'Game',
      thumbnail:
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=400&h=600&fit=crop',
      viewerCount: 1500,
      username: 'ProGamer',
      userAvatar:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=50&h=50&fit=crop&crop=face',
      isLive: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    StreamContent(
      id: '3',
      title: 'Music Session Live',
      category: 'Music',
      thumbnail:
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=300&fit=crop',
      viewerCount: 750,
      username: 'MusicLover',
      userAvatar:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=50&h=50&fit=crop&crop=face',
      isLive: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    StreamContent(
      id: '4',
      title: 'Cooking Tutorial',
      category: 'Tutorial',
      thumbnail:
          'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=400&h=600&fit=crop',
      viewerCount: 320,
      username: 'ChefMaster',
      userAvatar:
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=50&h=50&fit=crop&crop=face',
      isLive: false,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    // Simuler une recherche avec un délai
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
          if (query.isEmpty) {
            _searchResults = [];
          } else {
            _searchResults = _allContent
                .where(
                  (content) =>
                      content.title.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      content.category.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      content.username.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Recherche',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher des streams, streamers...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                        icon: Icon(Icons.clear, color: Colors.grey.shade400),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _performSearch,
            ),
          ),

          // Contenu principal
          Expanded(child: _buildSearchContent()),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_searchQuery.isEmpty) {
      return _buildSuggestions();
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat pour "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez des mots-clés différents',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final content = _searchResults[index];
          return StreamContentCard(
            content: content,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ouvrir ${content.title}'),
                  backgroundColor: const Color(0xFF6C5CE7),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggestions populaires',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                      'Gaming',
                      'Mobile Legends',
                      'Music',
                      'Tutorial',
                      'PUBG',
                      'Live Stream',
                    ]
                    .map(
                      (tag) => GestureDetector(
                        onTap: () {
                          _searchController.text = tag;
                          _performSearch(tag);
                        },
                        child: Container(
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
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            'Trending maintenant',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _allContent.length,
              itemBuilder: (context, index) {
                final content = _allContent[index];
                return StreamContentCard(
                  content: content,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ouvrir ${content.title}'),
                        backgroundColor: const Color(0xFF6C5CE7),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
