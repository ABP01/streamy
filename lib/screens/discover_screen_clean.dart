import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/content_categories_widget.dart';
import '../widgets/stories_widget.dart';
import '../widgets/stream_content_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<StreamContent> _streamContents = [];
  List<Story> _stories = [];
  List<ContentCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadStories(),
      _loadCategories(),
      _loadStreamContents(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadStories() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _stories = [
        Story(
          id: '1',
          userId: 'user1',
          username: 'john_doe',
          avatar:
              'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop&crop=face',
          isLive: true,
          isViewed: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        Story(
          id: '2',
          userId: 'user2',
          username: 'gaming_queen',
          avatar:
              'https://images.unsplash.com/photo-1494790108755-2616b332c2be?w=150&h=150&fit=crop&crop=face',
          isLive: false,
          isViewed: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        Story(
          id: '3',
          userId: 'user3',
          username: 'pro_player',
          avatar:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
          isLive: true,
          isViewed: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
      ];
    });
  }

  Future<void> _loadCategories() async {
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _categories = [
        ContentCategory(id: '1', name: 'Popular', icon: '🔥', isSelected: true),
        ContentCategory(id: '2', name: 'Gaming', icon: '🎮', isSelected: false),
        ContentCategory(id: '3', name: 'Music', icon: '🎵', isSelected: false),
        ContentCategory(id: '4', name: 'Sports', icon: '⚽', isSelected: false),
        ContentCategory(id: '5', name: 'Art', icon: '🎨', isSelected: false),
      ];
    });
  }

  Future<void> _loadStreamContents() async {
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _streamContents = [
        StreamContent(
          id: '1',
          title: 'Epic Gaming Session',
          thumbnail:
              'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=400&h=600&fit=crop',
          username: 'GamerPro',
          userAvatar:
              'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop&crop=face',
          category: 'Game',
          viewerCount: 1250,
          isLive: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        StreamContent(
          id: '2',
          title: 'Mobile Legends Tournament',
          thumbnail:
              'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=400&h=600&fit=crop',
          username: 'MLPro',
          userAvatar:
              'https://images.unsplash.com/photo-1494790108755-2616b332c2be?w=150&h=150&fit=crop&crop=face',
          category: 'Game',
          viewerCount: 850,
          isLive: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        StreamContent(
          id: '3',
          title: 'Music Production Live',
          thumbnail:
              'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=600&fit=crop',
          username: 'MusicMaker',
          userAvatar:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
          category: 'Music',
          viewerCount: 620,
          isLive: true,
          createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        ),
        StreamContent(
          id: '4',
          title: 'Digital Art Creation',
          thumbnail:
              'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=400&h=600&fit=crop',
          username: 'ArtistLife',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
          category: 'Art',
          viewerCount: 340,
          isLive: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
    });
  }

  void _onCategorySelected(ContentCategory category) {
    setState(() {
      _categories = _categories
          .map((cat) => cat.copyWith(isSelected: cat.id == category.id))
          .toList();
      // TODO: Filtrer les contenus selon la catégorie sélectionnée
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  snap: true,
                  title: const Text(
                    'Streamy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        // Notification - À implémenter
                      },
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: StoriesWidget(stories: _stories)),
                SliverToBoxAdapter(
                  child: ContentCategoriesWidget(
                    categories: _categories,
                    onCategorySelected: _onCategorySelected,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return StreamContentCard(
                        content: _streamContents[index],
                        onTap: () {
                          // Navigation vers le live - À implémenter
                        },
                      );
                    }, childCount: _streamContents.length),
                  ),
                ),
              ],
            ),
    );
  }
}
