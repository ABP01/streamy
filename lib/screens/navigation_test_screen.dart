import 'package:flutter/material.dart';

import '../utils/app_router.dart';

/// 🧪 Écran de test pour vérifier l'accès à tous les écrans
class NavigationTestScreen extends StatelessWidget {
  const NavigationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Test de Navigation',
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
              '🧪 Test d\'Accès aux Écrans',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Testez l\'accès à tous les écrans de l\'application. Chaque bouton devrait fonctionner correctement.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Tests écrans principaux
            _buildTestSection(context, '📱 Écrans Principaux', [
              _TestItem('TikTok Lives', AppRouter.tikTokLive, Colors.red),
              _TestItem('Découvrir', AppRouter.discover, Colors.purple),
              _TestItem('Messages', AppRouter.messaging, Colors.blue),
              _TestItem('Profil', AppRouter.profile, Colors.green),
            ]),

            const SizedBox(height: 20),

            // Tests écrans secondaires
            _buildTestSection(context, '🔧 Écrans Secondaires', [
              _TestItem(
                'Recherche Utilisateurs',
                AppRouter.searchUsers,
                Colors.orange,
              ),
              _TestItem('Recherche Avancée', AppRouter.userSearch, Colors.teal),
              _TestItem('Paramètres', AppRouter.settingsRoute, Colors.grey),
              _TestItem(
                'Lives Verticaux',
                AppRouter.verticalLive,
                Colors.indigo,
              ),
              _TestItem('Guide d\'Aide', AppRouter.helpNavigation, Colors.cyan),
            ]),

            const SizedBox(height: 20),

            // Tests avec arguments
            _buildTestSection(context, '⚙️ Tests avec Arguments', [
              _TestItem('Live Stream (Host)', null, Colors.red, () {
                AppRouter.navigateTo(
                  context,
                  AppRouter.liveStream,
                  arguments: {'liveId': 'test-live-123', 'isHost': true},
                );
              }),
              _TestItem('Live Stream (Viewer)', null, Colors.orange, () {
                AppRouter.navigateTo(
                  context,
                  AppRouter.liveStream,
                  arguments: {'liveId': 'test-live-456', 'isHost': false},
                );
              }),
            ]),

            const SizedBox(height: 30),

            // Résultats des tests
            _buildTestResults(context),

            const SizedBox(height: 20),

            // Actions de test
            _buildTestActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection(
    BuildContext context,
    String title,
    List<_TestItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _buildTestButton(context, item)),
      ],
    );
  }

  Widget _buildTestButton(BuildContext context, _TestItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          try {
            if (item.customAction != null) {
              item.customAction!();
            } else if (item.route != null) {
              AppRouter.navigateTo(context, item.route!);
            }

            // Marquer comme testé avec succès
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${item.title} - Navigation réussie'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
          } catch (e) {
            // Marquer comme échoué
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ ${item.title} - Erreur: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: item.color.withOpacity(0.2),
          foregroundColor: Colors.white,
          side: BorderSide(color: item.color, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              item.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.play_arrow, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResults(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Résultats des Tests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Les résultats des tests s\'affichent dans les notifications en bas.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '✅ Vert = Navigation réussie',
            style: TextStyle(color: Colors.green, fontSize: 14),
          ),
          const Text(
            '❌ Rouge = Erreur de navigation',
            style: TextStyle(color: Colors.red, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTestActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _runAllTests(context),
            icon: const Icon(Icons.play_circle_filled),
            label: const Text('Lancer tous les tests'),
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
            onPressed: () => AppRouter.navigateToMainApp(context),
            icon: const Icon(Icons.home),
            label: const Text('Retour à l\'application'),
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

  void _runAllTests(BuildContext context) {
    // Ici on pourrait implémenter un test automatique
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧪 Tests automatiques - À implémenter'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

class _TestItem {
  final String title;
  final String? route;
  final Color color;
  final VoidCallback? customAction;

  _TestItem(this.title, this.route, this.color, [this.customAction]);
}
