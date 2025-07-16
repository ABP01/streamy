// import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/story.dart';
import '../models/stream_content.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/story_widget.dart';
import '../widgets/stream_card_widget.dart';
// import 'user_profile_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['Popular', 'Nearby', 'Games', 'Shows'];

  // Données de démonstration pour les stories
  final List<Story> _stories = [
    Story(
      id: '1',
      userName: 'Your Story',
      userAvatar:
          'https://images.unsplash.com/photo-1494790108755-2616c9d1cb72?w=100&h=100&fit=crop&crop=face',
      isOwnStory: true,
    ),
    Story(
      id: '2',
      userName: 'Brody',
      userAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face',
      isLive: true,
    ),
    Story(
      id: '3',
      userName: 'Johnny',
      userAvatar:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&crop=face',
      isLive: false,
    ),
    Story(
      id: '4',
      userName: 'Caroline',
      userAvatar:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&crop=face',
      isLive: false,
    ),
    Story(
      id: '5',
      userName: 'Mr Bon',
      userAvatar:
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face',
      isLive: false,
    ),
  ];

  // Données de démonstration pour les streams
  final List<StreamContent> _streamContents = [
    StreamContent(
      id: '1',
      title: 'Epic Gaming Session',
      category: 'Game',
      thumbnail:
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=400&h=600&fit=crop',
      viewerCount: 910,
      streamerName: 'GamerPro',
      streamerAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=50&h=50&fit=crop&crop=face',
      isLive: true,
    ),
    StreamContent(
      id: '2',
      title: 'Be a star streamer',
      category: 'Show',
      thumbnail:
          'https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=400&h=300&fit=crop',
      viewerCount: 0,
      streamerName: 'StarStreamer',
      streamerAvatar:
          'https://images.unsplash.com/photo-1494790108755-2616c9d1cb72?w=50&h=50&fit=crop&crop=face',
      isLive: false,
      isPromoted: true,
    ),
    StreamContent(
      id: '3',
      title: 'Gaming Championship',
      category: 'Game',
      thumbnail:
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=400&h=600&fit=crop',
      viewerCount: 1826,
      streamerName: 'ProGamer',
      streamerAvatar:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=50&h=50&fit=crop&crop=face',
      isLive: true,
    ),
    StreamContent(
      id: '4',
      title: 'Podcast Review',
      category: 'Review',
      thumbnail:
          'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=400&h=600&fit=crop',
      viewerCount: 1826,
      streamerName: 'ReviewMaster',
      streamerAvatar:
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=50&h=50&fit=crop&crop=face',
      isLive: true,
    ),
    StreamContent(
      id: '5',
      title: 'Music Session',
      category: 'Music',
      thumbnail:
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=300&fit=crop',
      viewerCount: 1826,
      streamerName: 'MusicLover',
      streamerAvatar:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=50&h=50&fit=crop&crop=face',
      isLive: true,
    ),
    StreamContent(
      id: '6',
      title: 'Game Tournament',
      category: 'Game',
      thumbnail:
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=400&h=300&fit=crop',
      viewerCount: 0,
      streamerName: 'TournamentPro',
      streamerAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=50&h=50&fit=crop&crop=face',
      isLive: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            // Section des stories
            _buildStoriesSection(),

            const SizedBox(height: 20),

            // Section des catégories
            _buildCategoriesSection(),

            const SizedBox(height: 20),

            // Grille de contenus
            Expanded(child: _buildContentGrid()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 0,
        onTap: (index) {
          // TODO: Implémenter la navigation
        },
      ),
    );
  }

  Widget _buildStoriesSection() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StoryWidget(story: story),
          );
        },
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedCategoryIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF5B67F7)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.grey.shade600),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 0 && isSelected) ...[
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (index == 1 && isSelected) ...[
                      const Icon(Icons.near_me, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                    ],
                    if (index == 2 && isSelected) ...[
                      const Icon(Icons.games, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                    ],
                    if (index == 3 && isSelected) ...[
                      const Icon(
                        Icons.show_chart,
                        color: Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _categories[index],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _streamContents.length,
        itemBuilder: (context, index) {
          final content = _streamContents[index];
          return StreamCardWidget(
            content: content,
            onTap: () {
              // Navigation vers le détail du stream
            },
          );
        },
      ),
    );
  }
}
