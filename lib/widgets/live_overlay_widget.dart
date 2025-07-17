import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../screens/user_profile_screen.dart';
import '../services/gift_service.dart';
import '../services/live_stream_service.dart';
import '../widgets/enhanced_chat_widget.dart';

class LiveOverlayWidget extends StatefulWidget {
  final LiveStream live;
  final bool isActive;
  final VoidCallback? onRefresh;

  const LiveOverlayWidget({
    super.key,
    required this.live,
    required this.isActive,
    this.onRefresh,
  });

  @override
  State<LiveOverlayWidget> createState() => _LiveOverlayWidgetState();
}

class _LiveOverlayWidgetState extends State<LiveOverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late AnimationController _giftAnimationController;

  bool _showGiftPanel = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _giftAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _likeCount = widget.live.likeCount;
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    _giftAnimationController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    _likeCount++;
    _heartAnimationController.forward().then((_) {
      _heartAnimationController.reset();
    });

    // Envoyer le like au serveur
    _sendLike();

    // Vibration feedback
    HapticFeedback.lightImpact();
  }

  Future<void> _sendLike() async {
    try {
      await LiveStreamService().incrementLikeCount(widget.live.id);
    } catch (e) {
      print('Erreur envoi like: $e');
    }
  }

  Future<void> _sendGift(String giftType, int quantity) async {
    try {
      await GiftService.sendGift(
        liveId: widget.live.id,
        receiverId: widget.live.hostId,
        giftType: giftType,
        quantity: quantity,
      );

      _giftAnimationController.forward().then((_) {
        _giftAnimationController.reset();
      });

      setState(() {
        _showGiftPanel = false;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur envoi cadeau: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Stack(
        children: [
          // Zone transparente pour les gestes
          Positioned.fill(child: Container(color: Colors.transparent)),

          // Informations du live en bas
          Positioned(bottom: 100, left: 16, right: 80, child: _buildLiveInfo()),

          // Actions à droite
          Positioned(bottom: 100, right: 16, child: _buildActionButtons()),

          // Chat
          Positioned(
            bottom: 200,
            left: 16,
            right: 100,
            height: 200,
            child: EnhancedChatWidget(liveId: widget.live.id),
          ),

          // Animation des coeurs
          if (_heartAnimationController.isAnimating)
            Positioned.fill(child: _buildHeartAnimation()),

          // Animation des cadeaux
          if (_giftAnimationController.isAnimating)
            Positioned.fill(child: _buildGiftAnimation()),

          // Panel des cadeaux
          if (_showGiftPanel) Positioned.fill(child: _buildGiftPanel()),
        ],
      ),
    );
  }

  Widget _buildLiveInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profil de l'hôte
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    UserProfileScreen(userId: widget.live.hostId),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.live.hostAvatar != null
                    ? CachedNetworkImageProvider(widget.live.hostAvatar!)
                    : null,
                backgroundColor: Colors.grey[700],
                child: widget.live.hostAvatar == null
                    ? Text(
                        (widget.live.hostName ?? 'H')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.live.hostName ?? 'Hôte',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.live.formattedDuration,
                      style: TextStyle(color: Colors.grey[300], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Nom du streamer (plus de titre)
        Text(
          widget.live.hostName ?? 'Live Stream',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Durée du live
        const SizedBox(height: 4),
        Text(
          widget.live.formattedDuration,
          style: TextStyle(color: Colors.grey[300], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like
        _buildActionButton(
          icon: Icons.favorite,
          label: _formatCount(_likeCount),
          onTap: _onDoubleTap,
          color: Colors.red,
        ),

        const SizedBox(height: 16),

        // Commentaires
        _buildActionButton(
          icon: Icons.chat_bubble_outline,
          label: _formatCount(widget.live.giftCount),
          onTap: () {
            // Ouvrir le clavier de chat
          },
        ),

        const SizedBox(height: 16),

        // Cadeaux
        _buildActionButton(
          icon: Icons.card_giftcard,
          label: _formatCount(widget.live.giftCount),
          onTap: () {
            setState(() {
              _showGiftPanel = !_showGiftPanel;
            });
          },
          color: Colors.purple,
        ),

        const SizedBox(height: 16),

        // Partager
        _buildActionButton(
          icon: Icons.share,
          label: 'Partager',
          onTap: () {
            // Implémenter le partage
          },
        ),

        const SizedBox(height: 16),

        // Plus d'options
        _buildActionButton(
          icon: Icons.more_horiz,
          label: '',
          onTap: () {
            _showMoreOptions();
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 24),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeartAnimation() {
    return AnimatedBuilder(
      animation: _heartAnimationController,
      builder: (context, child) {
        return Positioned(
          bottom: 200 + (100 * _heartAnimationController.value),
          right: 50,
          child: Opacity(
            opacity: 1 - _heartAnimationController.value,
            child: Transform.scale(
              scale: 1 + (_heartAnimationController.value * 0.5),
              child: const Icon(Icons.favorite, color: Colors.red, size: 30),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGiftPanel() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 200,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Envoyer un cadeau',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showGiftPanel = false;
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 4,
                    children: [
                      _buildGiftItem('🌹', 'Rose', 10),
                      _buildGiftItem('💎', 'Diamant', 100),
                      _buildGiftItem('🎁', 'Cadeau', 50),
                      _buildGiftItem('👑', 'Couronne', 500),
                      _buildGiftItem('🚗', 'Voiture', 1000),
                      _buildGiftItem('🏠', 'Maison', 5000),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildGiftItem(String emoji, String name, int cost) {
    return GestureDetector(
      onTap: () => _sendGift(name.toLowerCase(), 1),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              '$cost 💰',
              style: TextStyle(color: Colors.grey[400], fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white),
              title: const Text(
                'Actualiser',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onRefresh?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text(
                'Signaler',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // Implémenter le signalement
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftAnimation() {
    return AnimatedBuilder(
      animation: _giftAnimationController,
      builder: (context, child) {
        return Positioned(
          bottom: 150 + (200 * _giftAnimationController.value),
          right: 30,
          child: Opacity(
            opacity: 1 - _giftAnimationController.value,
            child: Transform.scale(
              scale: 1 + (_giftAnimationController.value * 2),
              child: const Text('🎁', style: TextStyle(fontSize: 40)),
            ),
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}
