import 'package:flutter/material.dart';

import '../models/models.dart';

class StoriesWidget extends StatelessWidget {
  final List<Story> stories;
  final VoidCallback? onAddStory;

  const StoriesWidget({super.key, required this.stories, this.onAddStory});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stories.length + 1, // +1 pour "Your Story"
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildYourStoryItem(context);
          }

          final story = stories[index - 1];
          return _buildStoryItem(context, story);
        },
      ),
    );
  }

  Widget _buildYourStoryItem(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your Story',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem(BuildContext context, Story story) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: story.isViewed
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFE17055), Color(0xFFFD79A8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border.all(
                color: story.isViewed
                    ? Colors.grey.shade600
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: story.avatar != null
                    ? DecorationImage(
                        image: NetworkImage(story.avatar!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: story.avatar == null ? Colors.grey.shade700 : null,
              ),
              child: story.avatar == null
                  ? Center(
                      child: Text(
                        story.username.isNotEmpty
                            ? story.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : story.isLive
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              story.username,
              style: TextStyle(
                color: story.isViewed ? Colors.grey.shade400 : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
