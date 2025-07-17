import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_router.dart';

/// 🚀 Widget d'accès rapide à tous les écrans de l'application
class QuickScreenAccessWidget extends StatelessWidget {
  const QuickScreenAccessWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Accès rapide aux écrans',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Écrans principaux
          _buildSectionTitle('📱 Écrans principaux'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScreenCard(
                  context,
                  'Lives',
                  Icons.live_tv,
                  AppRouter.tikTokLive,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScreenCard(
                  context,
                  'Découvrir',
                  Icons.explore,
                  AppRouter.discover,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScreenCard(
                  context,
                  'Messages',
                  Icons.message,
                  AppRouter.messaging,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScreenCard(
                  context,
                  'Profil',
                  Icons.person,
                  AppRouter.profile,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Écrans utilitaires
          _buildSectionTitle('🔧 Outils & Paramètres'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScreenCard(
                  context,
                  'Recherche',
                  Icons.search,
                  AppRouter.searchUsers,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScreenCard(
                  context,
                  'Paramètres',
                  Icons.settings,
                  AppRouter.settingsRoute,
                  Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScreenCard(
                  context,
                  'Recherche Avancée',
                  Icons.person_search,
                  AppRouter.userSearch,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScreenCard(
                  context,
                  'Lives Verticaux',
                  Icons.video_library,
                  AppRouter.verticalLive,
                  Colors.indigo,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Actions rapides
          _buildSectionTitle('⚡ Actions rapides'),
          const SizedBox(height: 12),
          _buildActionButton(
            context,
            'Guide de navigation',
            Icons.help_outline,
            Colors.cyan,
            () => _showNavigationGuide(context),
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            context,
            'Démarrer un Live',
            Icons.videocam,
            Colors.red,
            () => _startLive(context),
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            context,
            'Actualiser l\'application',
            Icons.refresh,
            Colors.blue,
            () => _refreshApp(context),
          ),

          const SizedBox(height: 20),

          // Bouton fermer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Fermer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildScreenCard(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        AppRouter.navigateTo(context, route);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  void _startLive(BuildContext context) {
    Navigator.pop(context);
    // TODO: Intégrer avec FloatingLiveButton logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Utilise le bouton "Go Live" pour démarrer un stream'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showNavigationGuide(BuildContext context) {
    Navigator.pop(context);
    AppRouter.navigateTo(context, AppRouter.helpNavigation);
  }

  void _refreshApp(BuildContext context) {
    Navigator.pop(context);
    // Redémarrer la navigation principale
    AppRouter.navigateAndClear(context, AppRouter.home);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Application actualisée !'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// 📱 Méthode d'aide pour afficher le widget d'accès rapide
class QuickAccessHelper {
  static void showQuickAccess(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickScreenAccessWidget(),
    );
  }
}
