import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/models.dart';
import '../config/app_config.dart';

class AnimationService {
  // Animations pour les réactions
  static Widget buildReactionAnimation({
    required ReactionType type,
    required Animation<double> animation,
    double? startX,
    double? startY,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Positioned(
          left: (startX ?? 50) + (animation.value * 100),
          bottom: (startY ?? 100) + (animation.value * 200),
          child: Opacity(
            opacity: 1.0 - animation.value,
            child: Transform.scale(
              scale: 1.0 + (animation.value * 0.5),
              child: _getReactionIcon(type),
            ),
          ),
        );
      },
    );
  }

  // Animations pour les gifts
  static Widget buildGiftAnimation({
    required String giftType,
    required Animation<double> animation,
    int quantity = 1,
  }) {
    final giftConfig = AppConfig.giftTypes[giftType];
    if (giftConfig == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: List.generate(quantity.clamp(1, 5), (index) {
            final delay = index * 0.1;
            final adjustedValue = (animation.value - delay).clamp(0.0, 1.0);
            
            return Positioned(
              left: MediaQuery.of(context).size.width / 2 - 25 + (index * 10),
              bottom: 100 + (adjustedValue * 300),
              child: Opacity(
                opacity: adjustedValue > 0 ? (1.0 - adjustedValue) : 0.0,
                child: Transform.scale(
                  scale: adjustedValue > 0 ? (1.0 + adjustedValue * 2) : 0.0,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(giftConfig['color'] as int),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(giftConfig['color'] as int).withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getGiftIcon(giftType),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // Animation de notification pour les nouveaux followers
  static Widget buildFollowerNotification({
    required String userName,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Positioned(
          top: 100 + (animation.value * 50),
          left: 20,
          right: 20,
          child: Opacity(
            opacity: animation.value < 0.5 ? animation.value * 2 : (1 - animation.value) * 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$userName vous suit maintenant !',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Animation de flottement pour les messages VIP
  static Widget buildVipMessageAnimation({
    required Message message,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -animation.value * 10),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.8),
                  Colors.orange.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${message.userName}: ${message.content}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Animation de particules pour les effets spéciaux
  static Widget buildParticleEffect({
    required Animation<double> animation,
    required Color color,
    int particleCount = 20,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: List.generate(particleCount, (index) {
            final angle = (index / particleCount) * 2 * math.pi;
            final radius = animation.value * 150;
            final x = radius * math.cos(angle);
            final y = radius * math.sin(angle);
            
            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + x,
              top: MediaQuery.of(context).size.height / 2 + y,
              child: Opacity(
                opacity: 1.0 - animation.value,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // Méthodes helper pour les icônes
  static Widget _getReactionIcon(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return const Icon(Icons.favorite, color: Colors.red, size: 24);
      case ReactionType.love:
        return const Icon(Icons.favorite, color: Colors.pink, size: 24);
      case ReactionType.wow:
        return const Icon(Icons.sentiment_very_satisfied, color: Colors.yellow, size: 24);
      case ReactionType.laugh:
        return const Icon(Icons.sentiment_very_satisfied, color: Colors.green, size: 24);
      case ReactionType.fire:
        return const Icon(Icons.local_fire_department, color: Colors.orange, size: 24);
      case ReactionType.clap:
        return const Icon(Icons.back_hand, color: Colors.blue, size: 24);
    }
  }

  static IconData _getGiftIcon(String giftType) {
    switch (giftType) {
      case 'heart':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'diamond':
        return Icons.diamond;
      case 'crown':
        return Icons.workspace_premium;
      case 'rocket':
        return Icons.rocket_launch;
      default:
        return Icons.card_giftcard;
    }
  }
}
