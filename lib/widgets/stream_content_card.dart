import 'package:flutter/material.dart';

import '../models/models.dart';

class StreamContentCard extends StatelessWidget {
  final StreamContent content;
  final VoidCallback? onTap;
  final double? aspectRatio;

  const StreamContentCard({
    super.key,
    required this.content,
    this.onTap,
    this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade900,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image de fond/thumbnail
              _buildThumbnail(),

              // Overlay gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),

              // Contenu superposé
              Positioned(top: 8, right: 8, child: _buildCategoryTag()),

              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: _buildContentInfo(),
              ),

              if (content.isLive)
                Positioned(top: 8, left: 8, child: _buildLiveIndicator()),

              Positioned(bottom: 8, right: 8, child: _buildViewerCount()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return content.thumbnail.isNotEmpty
        ? Image.network(
            content.thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade800,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 40,
                  ),
                ),
              );
            },
          )
        : Container(
            color: Colors.grey.shade800,
            child: Center(
              child: Icon(
                content.isLive ? Icons.videocam : Icons.play_circle_outline,
                color: Colors.white,
                size: 40,
              ),
            ),
          );
  }

  Widget _buildCategoryTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getCategoryColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        content.category,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (content.category.toLowerCase()) {
      case 'game':
      case 'gaming':
        return const Color(0xFFE17055);
      case 'music':
        return const Color(0xFF6C5CE7);
      case 'review':
        return const Color(0xFF00B894);
      case 'art':
        return const Color(0xFFE84393);
      case 'sport':
        return const Color(0xFF0984E3);
      default:
        return const Color(0xFF636E72);
    }
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildViewerCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Text(
            _formatViewerCount(content.viewerCount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.title.isNotEmpty)
          Text(
            content.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (content.userAvatar != null)
              CircleAvatar(
                radius: 8,
                backgroundImage: NetworkImage(content.userAvatar!),
                backgroundColor: Colors.grey.shade700,
              )
            else
              CircleAvatar(
                radius: 8,
                backgroundColor: Colors.grey.shade700,
                child: Text(
                  content.username.isNotEmpty
                      ? content.username[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                content.username,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatViewerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
