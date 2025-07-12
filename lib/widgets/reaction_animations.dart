import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

class ReactionAnimationWidget extends StatefulWidget {
  final Widget child;
  final String liveId;

  const ReactionAnimationWidget({
    super.key,
    required this.child,
    required this.liveId,
  });

  @override
  State<ReactionAnimationWidget> createState() => _ReactionAnimationWidgetState();
}

class _ReactionAnimationWidgetState extends State<ReactionAnimationWidget>
    with TickerProviderStateMixin {
  final List<ReactionAnimation> _activeReactions = [];
  late Timer _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _setupCleanupTimer();
  }

  void _setupCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _activeReactions.removeWhere((reaction) => reaction.isExpired);
      });
    });
  }

  @override
  void dispose() {
    _cleanupTimer.cancel();
    for (final reaction in _activeReactions) {
      reaction.dispose();
    }
    super.dispose();
  }

  void addReaction(ReactionType type, {Offset? position}) {
    final reaction = ReactionAnimation(
      type: type,
      startPosition: position ?? _getRandomPosition(),
      vsync: this,
    );
    
    setState(() {
      _activeReactions.add(reaction);
    });

    // Démarrer l'animation
    reaction.start();
  }

  Offset _getRandomPosition() {
    final random = math.Random();
    return Offset(
      random.nextDouble() * 300 + 50, // Entre 50 et 350
      random.nextDouble() * 100 + 100, // Entre 100 et 200
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Couche d'animations
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: _activeReactions.map((reaction) {
                return AnimatedBuilder(
                  animation: reaction.animationController,
                  builder: (context, child) {
                    return reaction.buildWidget();
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

enum ReactionType {
  heart,
  like,
  wow,
  laugh,
  star,
  fire,
  diamond,
  gift,
}

class ReactionAnimation {
  final ReactionType type;
  final Offset startPosition;
  final AnimationController animationController;
  late final Animation<double> moveUpAnimation;
  late final Animation<double> fadeAnimation;
  late final Animation<double> scaleAnimation;
  late final Animation<double> rotationAnimation;

  ReactionAnimation({
    required this.type,
    required this.startPosition,
    required TickerProvider vsync,
  }) : animationController = AnimationController(
          duration: const Duration(milliseconds: 2000),
          vsync: vsync,
        ) {
    _setupAnimations();
  }

  void _setupAnimations() {
    // Animation de montée
    moveUpAnimation = Tween<double>(
      begin: 0.0,
      end: -200.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOut,
    ));

    // Animation de fondu
    fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    ));

    // Animation d'échelle (grossit puis rétrécit)
    scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8),
        weight: 60,
      ),
    ]).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.elasticOut,
    ));

    // Animation de rotation légère
    rotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    ));
  }

  void start() {
    animationController.forward();
  }

  bool get isExpired => animationController.isCompleted;

  void dispose() {
    animationController.dispose();
  }

  Widget buildWidget() {
    final random = math.Random();
    final sidewaysMovement = (random.nextDouble() - 0.5) * 100; // Mouvement latéral aléatoire

    return Positioned(
      left: startPosition.dx + sidewaysMovement * animationController.value,
      top: startPosition.dy + moveUpAnimation.value,
      child: Transform.scale(
        scale: scaleAnimation.value,
        child: Transform.rotate(
          angle: rotationAnimation.value,
          child: Opacity(
            opacity: fadeAnimation.value,
            child: _buildReactionIcon(),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionIcon() {
    switch (type) {
      case ReactionType.heart:
        return const Icon(
          Icons.favorite,
          color: Colors.red,
          size: 36,
        );
      case ReactionType.like:
        return const Icon(
          Icons.thumb_up,
          color: Colors.blue,
          size: 36,
        );
      case ReactionType.wow:
        return const Text(
          '😮',
          style: TextStyle(fontSize: 36),
        );
      case ReactionType.laugh:
        return const Text(
          '😂',
          style: TextStyle(fontSize: 36),
        );
      case ReactionType.star:
        return const Icon(
          Icons.star,
          color: Colors.yellow,
          size: 36,
        );
      case ReactionType.fire:
        return const Text(
          '🔥',
          style: TextStyle(fontSize: 36),
        );
      case ReactionType.diamond:
        return const Icon(
          Icons.diamond,
          color: Colors.cyan,
          size: 36,
        );
      case ReactionType.gift:
        return const Icon(
          Icons.card_giftcard,
          color: Colors.purple,
          size: 36,
        );
    }
  }
}

// Widget pour les likes qui flottent
class FloatingLikesWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const FloatingLikesWidget({
    super.key,
    this.onTap,
  });

  @override
  State<FloatingLikesWidget> createState() => _FloatingLikesWidgetState();
}

class _FloatingLikesWidgetState extends State<FloatingLikesWidget>
    with TickerProviderStateMixin {
  final GlobalKey _containerKey = GlobalKey();
  final List<LikeAnimation> _likes = [];
  late Timer _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _setupCleanupTimer();
  }

  void _setupCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _likes.removeWhere((like) => like.isCompleted);
      });
    });
  }

  @override
  void dispose() {
    _cleanupTimer.cancel();
    for (final like in _likes) {
      like.dispose();
    }
    super.dispose();
  }

  void _addLike() {
    final like = LikeAnimation(vsync: this);
    setState(() {
      _likes.add(like);
    });
    like.start();
    
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _addLike,
      child: Container(
        key: _containerKey,
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            // Icône de like principal
            const Center(
              child: Icon(
                Icons.favorite_border,
                color: Colors.white,
                size: 32,
              ),
            ),
            
            // Likes animés
            ..._likes.map((like) => AnimatedBuilder(
              animation: like.controller,
              builder: (context, child) => like.buildWidget(),
            )).toList(),
          ],
        ),
      ),
    );
  }
}

class LikeAnimation {
  final AnimationController controller;
  late final Animation<double> moveUp;
  late final Animation<double> fade;
  late final Animation<double> scale;
  final math.Random _random = math.Random();
  late final double _startX;

  LikeAnimation({required TickerProvider vsync})
      : controller = AnimationController(
          duration: const Duration(milliseconds: 1500),
          vsync: vsync,
        ) {
    _startX = _random.nextDouble() * 60 + 10; // Position X aléatoire
    _setupAnimations();
  }

  void _setupAnimations() {
    moveUp = Tween<double>(
      begin: 40,
      end: -60,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    ));

    fade = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.6, 1.0),
    ));

    scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 70,
      ),
    ]).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.elasticOut,
    ));
  }

  void start() {
    controller.forward();
  }

  bool get isCompleted => controller.isCompleted;

  void dispose() {
    controller.dispose();
  }

  Widget buildWidget() {
    return Positioned(
      left: _startX,
      bottom: 40 - moveUp.value,
      child: Transform.scale(
        scale: scale.value,
        child: Opacity(
          opacity: fade.value,
          child: const Icon(
            Icons.favorite,
            color: Colors.red,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// Widget pour les confettis lors de gros événements
class ConfettiWidget extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onComplete;

  const ConfettiWidget({
    super.key,
    required this.isActive,
    this.onComplete,
  });

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.onComplete != null) {
        widget.onComplete!();
      }
    });

    if (widget.isActive) {
      _startConfetti();
    }
  }

  @override
  void didUpdateWidget(ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startConfetti();
    }
  }

  void _startConfetti() {
    _particles.clear();
    final random = math.Random();
    
    // Créer des particules
    for (int i = 0; i < 50; i++) {
      _particles.add(ConfettiParticle(
        startX: random.nextDouble() * 400,
        startY: -20,
        color: Color.fromRGBO(
          random.nextInt(255),
          random.nextInt(255),
          random.nextInt(255),
          1.0,
        ),
        size: random.nextDouble() * 8 + 4,
        velocityX: (random.nextDouble() - 0.5) * 200,
        velocityY: random.nextDouble() * 100 + 50,
        rotation: random.nextDouble() * 2 * math.pi,
      ));
    }
    
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive && _particles.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class ConfettiParticle {
  final double startX;
  final double startY;
  final Color color;
  final double size;
  final double velocityX;
  final double velocityY;
  final double rotation;

  ConfettiParticle({
    required this.startX,
    required this.startY,
    required this.color,
    required this.size,
    required this.velocityX,
    required this.velocityY,
    required this.rotation,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(1.0 - progress)
        ..style = PaintingStyle.fill;

      final x = particle.startX + (particle.velocityX * progress);
      final y = particle.startY + (particle.velocityY * progress) + 
                 (9.8 * progress * progress * 100); // Gravité

      if (y < size.height) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(particle.rotation * progress * 4);
        canvas.drawCircle(Offset.zero, particle.size, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
