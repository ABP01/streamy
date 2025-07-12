import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

// Modèle simple pour les cadeaux d'animation
class AnimatedGift {
  final String id;
  final String type;
  final String senderName;
  final int quantity;
  final int value;
  final DateTime timestamp;

  AnimatedGift({
    required this.id,
    required this.type,
    required this.senderName,
    required this.quantity,
    required this.value,
    required this.timestamp,
  });
}

class GiftAnimationWidget extends StatefulWidget {
  final String liveId;
  final String userId;
  final Function(String, String, int) onGiftSent; // giftId, giftName, quantity

  const GiftAnimationWidget({
    super.key,
    required this.liveId,
    required this.userId,
    required this.onGiftSent,
  });

  @override
  State<GiftAnimationWidget> createState() => _GiftAnimationWidgetState();
}

class _GiftAnimationWidgetState extends State<GiftAnimationWidget>
    with TickerProviderStateMixin {
  final List<GiftDisplayAnimation> _activeGifts = [];
  late Timer _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _setupCleanupTimer();
  }

  void _setupCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _activeGifts.removeWhere((gift) => gift.isCompleted);
      });
    });
  }

  @override
  void dispose() {
    _cleanupTimer.cancel();
    for (final gift in _activeGifts) {
      gift.dispose();
    }
    super.dispose();
  }

  void showGift(AnimatedGift gift) {
    HapticFeedback.mediumImpact();
    
    final animation = GiftDisplayAnimation(
      gift: gift,
      vsync: this,
    );
    
    setState(() {
      _activeGifts.add(animation);
    });
    
    animation.start();
  }

  void _showGiftAnimation(String giftType, int quantity, String senderName) {
    final gift = AnimatedGift(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: giftType,
      senderName: senderName,
      quantity: quantity,
      value: _getGiftValue(giftType) * quantity,
      timestamp: DateTime.now(),
    );
    
    showGift(gift);
  }

  void _showGiftSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelectorSheet(
        onGiftSelected: (giftType, quantity) {
          final giftId = DateTime.now().millisecondsSinceEpoch.toString();
          
          widget.onGiftSent(giftId, giftType, quantity);
          _showGiftAnimation(giftType, quantity, 'Vous');
        },
      ),
    );
  }

  int _getGiftValue(String giftType) {
    switch (giftType.toLowerCase()) {
      case 'coeur':
        return 1;
      case 'rose':
        return 5;
      case 'diamant':
        return 10;
      case 'couronne':
        return 50;
      case 'fusée':
        return 100;
      case 'château':
        return 500;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Bouton pour ouvrir le sélecteur de cadeaux
        Positioned(
          bottom: 120,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showGiftSelector,
            backgroundColor: Colors.purple.withOpacity(0.8),
            child: const Icon(Icons.card_giftcard, color: Colors.white),
          ),
        ),
        
        // Animations de cadeaux
        ..._activeGifts.map((gift) => AnimatedBuilder(
          animation: gift.controller,
          builder: (context, child) => gift.buildWidget(context),
        )).toList(),
      ],
    );
  }
}

class GiftDisplayAnimation {
  final AnimatedGift gift;
  final AnimationController controller;
  late final Animation<double> slideAnimation;
  late final Animation<double> scaleAnimation;
  late final Animation<double> fadeAnimation;
  late final Animation<double> rotationAnimation;

  GiftDisplayAnimation({
    required this.gift,
    required TickerProvider vsync,
  }) : controller = AnimationController(
          duration: const Duration(milliseconds: 3000),
          vsync: vsync,
        ) {
    _setupAnimations();
  }

  void _setupAnimations() {
    slideAnimation = Tween<double>(
      begin: 400.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));

    scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8),
        weight: 30,
      ),
    ]).animate(controller);

    fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(controller);

    rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }

  void start() {
    controller.forward();
  }

  bool get isCompleted => controller.isCompleted;

  void dispose() {
    controller.dispose();
  }

  Widget buildWidget(BuildContext context) {
    return Positioned(
      right: slideAnimation.value,
      top: MediaQuery.of(context).size.height * 0.3,
      child: Transform.scale(
        scale: scaleAnimation.value,
        child: Transform.rotate(
          angle: rotationAnimation.value * 0.1, // Rotation légère
          child: Opacity(
            opacity: fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.9),
                    Colors.pink.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGiftIcon(),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gift.senderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'a envoyé ${gift.quantity}x ${gift.type}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (gift.quantity > 1)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'x${gift.quantity}',
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
          ),
        ),
      ),
    );
  }

  Widget _buildGiftIcon() {
    switch (gift.type.toLowerCase()) {
      case 'coeur':
        return const Icon(Icons.favorite, color: Colors.red, size: 32);
      case 'rose':
        return const Text('🌹', style: TextStyle(fontSize: 32));
      case 'diamant':
        return const Icon(Icons.diamond, color: Colors.cyan, size: 32);
      case 'couronne':
        return const Text('👑', style: TextStyle(fontSize: 32));
      case 'fusée':
        return const Text('🚀', style: TextStyle(fontSize: 32));
      case 'château':
        return const Text('🏰', style: TextStyle(fontSize: 32));
      default:
        return const Icon(Icons.card_giftcard, color: Colors.white, size: 32);
    }
  }
}

class GiftSelectorSheet extends StatefulWidget {
  final Function(String giftType, int quantity) onGiftSelected;

  const GiftSelectorSheet({
    super.key,
    required this.onGiftSelected,
  });

  @override
  State<GiftSelectorSheet> createState() => _GiftSelectorSheetState();
}

class _GiftSelectorSheetState extends State<GiftSelectorSheet> {
  final List<GiftItem> _gifts = [
    GiftItem(name: 'Coeur', icon: '❤️', value: 1),
    GiftItem(name: 'Rose', icon: '🌹', value: 5),
    GiftItem(name: 'Diamant', icon: '💎', value: 10),
    GiftItem(name: 'Couronne', icon: '👑', value: 50),
    GiftItem(name: 'Fusée', icon: '🚀', value: 100),
    GiftItem(name: 'Château', icon: '🏰', value: 500),
  ];

  int _selectedQuantity = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Titre
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Envoyer un cadeau',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Sélecteur de quantité
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Quantité: ',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                _buildQuantitySelector(),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Grille de cadeaux
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _gifts.length,
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                return _buildGiftCard(gift);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _selectedQuantity > 1
                ? () => setState(() => _selectedQuantity--)
                : null,
            icon: const Icon(Icons.remove, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$_selectedQuantity',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _selectedQuantity < 99
                ? () => setState(() => _selectedQuantity++)
                : null,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCard(GiftItem gift) {
    final totalValue = gift.value * _selectedQuantity;
    
    return GestureDetector(
      onTap: () {
        widget.onGiftSelected(gift.name, _selectedQuantity);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.withOpacity(0.3),
              Colors.pink.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.purple.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              gift.icon,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 8),
            Text(
              gift.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${gift.value} ⭐',
              style: TextStyle(
                color: Colors.yellow[600],
                fontSize: 12,
              ),
            ),
            if (_selectedQuantity > 1) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $totalValue ⭐',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GiftItem {
  final String name;
  final String icon;
  final int value;

  GiftItem({
    required this.name,
    required this.icon,
    required this.value,
  });
}

// Widget pour afficher les cadeaux reçus en continu
class GiftStreamWidget extends StatefulWidget {
  final Stream<AnimatedGift> giftStream;

  const GiftStreamWidget({
    super.key,
    required this.giftStream,
  });

  @override
  State<GiftStreamWidget> createState() => _GiftStreamWidgetState();
}

class _GiftStreamWidgetState extends State<GiftStreamWidget>
    with TickerProviderStateMixin {
  late StreamSubscription<AnimatedGift> _subscription;
  final List<AnimatedGift> _recentGifts = [];

  @override
  void initState() {
    super.initState();
    _subscription = widget.giftStream.listen((gift) {
      setState(() {
        _recentGifts.insert(0, gift);
        if (_recentGifts.length > 5) {
          _recentGifts.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recentGifts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      top: MediaQuery.of(context).size.height * 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _recentGifts.map((gift) => _buildGiftItem(gift)).toList(),
      ),
    );
  }

  Widget _buildGiftItem(AnimatedGift gift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getGiftIcon(gift.type),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gift.senderName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                '${gift.quantity}x ${gift.type}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGiftIcon(String giftType) {
    switch (giftType.toLowerCase()) {
      case 'coeur':
        return '❤️';
      case 'rose':
        return '🌹';
      case 'diamant':
        return '💎';
      case 'couronne':
        return '👑';
      case 'fusée':
        return '🚀';
      case 'château':
        return '🏰';
      default:
        return '🎁';
    }
  }
}
