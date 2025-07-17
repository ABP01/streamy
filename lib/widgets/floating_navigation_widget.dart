import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_router.dart';
import 'quick_screen_access_widget.dart';

/// 🎯 Widget de navigation flottante pour accès rapide aux écrans
class FloatingNavigationWidget extends StatefulWidget {
  const FloatingNavigationWidget({super.key});

  @override
  State<FloatingNavigationWidget> createState() =>
      _FloatingNavigationWidgetState();
}

class _FloatingNavigationWidgetState extends State<FloatingNavigationWidget>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Overlay pour fermer le menu
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleExpanded,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

        // Menu actions rapides
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isExpanded) ...[
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildQuickActionButton(
                      'Paramètres',
                      Icons.settings,
                      Colors.grey,
                      () => _navigateToScreen(AppRouter.settingsRoute),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildQuickActionButton(
                      'Recherche',
                      Icons.search,
                      Colors.orange,
                      () => _navigateToScreen(AppRouter.searchUsers),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildQuickActionButton(
                      'Tous les écrans',
                      Icons.apps,
                      Colors.purple,
                      () => QuickAccessHelper.showQuickAccess(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Bouton principal
                AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value * 2 * 3.14159,
                      child: FloatingActionButton(
                        onPressed: _toggleExpanded,
                        backgroundColor: _isExpanded
                            ? Colors.red
                            : Colors.purple,
                        foregroundColor: Colors.white,
                        child: Icon(
                          _isExpanded ? Icons.close : Icons.navigation,
                          size: 28,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          onPressed: () {
            _toggleExpanded();
            onPressed();
          },
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }

  void _navigateToScreen(String route) {
    AppRouter.navigateTo(context, route);
  }
}

/// 🎛️ Widget de contrôle d'état pour l'application
class AppStatusWidget extends StatelessWidget {
  final int livesCount;
  final bool isConnected;

  const AppStatusWidget({
    super.key,
    required this.livesCount,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConnected ? Colors.green : Colors.red,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '$livesCount lives',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
