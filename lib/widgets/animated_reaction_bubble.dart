import 'package:flutter/material.dart';

class AnimatedReactionBubble extends StatefulWidget {
  final String emoji;
  final VoidCallback? onCompleted;
  final double startX;
  final double endX;
  final double startY;
  final double endY;
  final Duration duration;

  const AnimatedReactionBubble({
    Key? key,
    required this.emoji,
    this.onCompleted,
    this.startX = 0.0,
    this.endX = 0.0,
    this.startY = 0.0,
    this.endY = -150.0,
    this.duration = const Duration(milliseconds: 1200),
  }) : super(key: key);

  @override
  State<AnimatedReactionBubble> createState() => _AnimatedReactionBubbleState();
}

class _AnimatedReactionBubbleState extends State<AnimatedReactionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _xAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _yAnimation = Tween<double>(
      begin: widget.startY,
      end: widget.endY,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _xAnimation = Tween<double>(
      begin: widget.startX,
      end: widget.endX,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.2,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 0.3,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 0.7,
      ),
    ]).animate(_controller);
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0)),
    );
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.onCompleted != null) {
        widget.onCompleted!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _xAnimation.value,
          bottom: _yAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          ),
        );
      },
      child: Text(
        widget.emoji,
        style: const TextStyle(
          fontSize: 40,
          shadows: [
            Shadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}
