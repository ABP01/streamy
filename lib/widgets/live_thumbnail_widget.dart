import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/models.dart';

class LiveThumbnailWidget extends StatelessWidget {
  final LiveStream live;
  final VoidCallback? onTap;
  final bool showStats;

  const LiveThumbnailWidget({
    super.key,
    required this.live,
    this.onTap,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Image de fond ou placeholder
              _buildThumbnail(),
              
              // Overlay avec gradient
              _buildOverlay(),
              
              // Informations en premier plan
              _buildInfo(),
              
              // Indicateur LIVE
              if (live.isLive) _buildLiveIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (live.thumbnail != null && live.thumbnail!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: live.thumbnail!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam,
          size: 48,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre du live
          Text(
            live.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          
          // Nom du streamer
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.white,
                child: live.hostAvatar != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: live.hostAvatar!,
                          width: 20,
                          height: 20,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => _buildHostIcon(),
                        ),
                      )
                    : _buildHostIcon(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  live.hostName ?? 'Streamer',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          if (showStats) ...[
            const SizedBox(height: 8),
            _buildStats(),
          ],
        ],
      ),
    );
  }

  Widget _buildHostIcon() {
    return Text(
      (live.hostName ?? 'U').substring(0, 1).toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Color(0xFF667eea),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        // Viewers
        _buildStatItem(
          Icons.visibility,
          _formatNumber(live.viewerCount),
        ),
        const SizedBox(width: 12),
        
        // Likes
        _buildStatItem(
          Icons.favorite,
          _formatNumber(live.likeCount),
        ),
        
        if (live.category != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              live.category!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.white70,
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveIndicator() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

// Widget pour afficher une grille de lives
class LiveGridWidget extends StatelessWidget {
  final List<LiveStream> lives;
  final Function(LiveStream) onLiveTap;
  final bool isLoading;

  const LiveGridWidget({
    super.key,
    required this.lives,
    required this.onLiveTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (lives.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Aucun live en cours',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: lives.length,
      itemBuilder: (context, index) {
        return LiveThumbnailWidget(
          live: lives[index],
          onTap: () => onLiveTap(lives[index]),
        );
      },
    );
  }
}
