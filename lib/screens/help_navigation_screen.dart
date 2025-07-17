import 'package:flutter/material.dart';

import '../utils/app_router.dart';
import '../widgets/quick_screen_access_widget.dart';

/// 📚 Écran d'aide et de navigation pour l'application Streamy
class HelpNavigationScreen extends StatelessWidget {
  const HelpNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Guide de navigation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎯 Bienvenue sur Streamy !',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Voici comment naviguer dans l\'application et accéder à tous les écrans disponibles.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Section Navigation principale
            _buildSection(
              '🏠 Navigation principale',
              'Utilisez la barre de navigation en bas pour accéder aux écrans principaux :',
              [
                _NavigationItem(
                  'Lives',
                  Icons.home,
                  'Regarder des streams en direct',
                  Colors.red,
                ),
                _NavigationItem(
                  'Découvrir',
                  Icons.explore,
                  'Explorer du contenu et des créateurs',
                  Colors.purple,
                ),
                _NavigationItem(
                  'Messages',
                  Icons.message,
                  'Chat privé avec d\'autres utilisateurs',
                  Colors.blue,
                ),
                _NavigationItem(
                  'Profil',
                  Icons.person,
                  'Votre profil et paramètres',
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Section Accès rapide
            _buildSection(
              '⚡ Accès rapide',
              'Plusieurs moyens d\'accéder rapidement aux écrans :',
              [
                _NavigationItem(
                  'Bouton 📱',
                  Icons.apps,
                  'Bouton en haut à droite - Accès à tous les écrans',
                  Colors.orange,
                ),
                _NavigationItem(
                  'Bouton Go Live',
                  Icons.videocam,
                  'Bouton flottant - Démarrer un live',
                  Colors.red,
                ),
                _NavigationItem(
                  'Menu ⋮',
                  Icons.more_vert,
                  'Menu dans certains écrans - Actions contextuelles',
                  Colors.grey,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Section Écrans disponibles
            _buildSection(
              '📱 Tous les écrans disponibles',
              'Liste complète des écrans que vous pouvez visiter :',
              [
                _NavigationItem(
                  'Recherche utilisateurs',
                  Icons.person_search,
                  'Trouver et suivre des créateurs',
                ),
                _NavigationItem(
                  'Recherche avancée',
                  Icons.search,
                  'Recherche détaillée de contenu',
                ),
                _NavigationItem(
                  'Lives verticaux',
                  Icons.video_library,
                  'Navigation TikTok-style',
                ),
                _NavigationItem(
                  'Paramètres',
                  Icons.settings,
                  'Configuration de l\'application',
                ),
                _NavigationItem(
                  'Chat privé',
                  Icons.chat,
                  'Messages privés avec un utilisateur',
                ),
                _NavigationItem(
                  'Profil utilisateur',
                  Icons.account_circle,
                  'Voir le profil d\'un autre utilisateur',
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Section Conseils
            _buildTipsSection(),

            const SizedBox(height: 30),

            // Boutons d'action
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    String description,
    List<_NavigationItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => _buildNavigationItem(item)),
      ],
    );
  }

  Widget _buildNavigationItem(_NavigationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (item.color ?? Colors.grey).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (item.color ?? Colors.grey).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color ?? Colors.grey, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.2),
            Colors.blue.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.yellow, size: 24),
              SizedBox(width: 8),
              Text(
                'Conseils de navigation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTip(
            '💡',
            'Utilisez le bouton "📱" en haut à droite pour un accès rapide à tous les écrans',
          ),
          _buildTip(
            '🔄',
            'Tirez vers le bas pour actualiser la plupart des écrans',
          ),
          _buildTip(
            '👆',
            'Appuyez longuement sur certains éléments pour plus d\'options',
          ),
          _buildTip(
            '🎥',
            'Swipez verticalement dans les lives pour passer au suivant',
          ),
          _buildTip('⚙️', 'Personnalisez votre expérience dans les Paramètres'),
        ],
      ),
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Ouvrir le widget d'accès rapide
              QuickAccessHelper.showQuickAccess(context);
            },
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Ouvrir l\'accès rapide'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => AppRouter.navigateToSettings(context),
            icon: const Icon(Icons.settings),
            label: const Text('Ouvrir les paramètres'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigationItem {
  final String title;
  final IconData icon;
  final String? description;
  final Color? color;

  _NavigationItem(this.title, this.icon, this.description, [this.color]);
}
