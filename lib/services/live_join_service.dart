import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/live_stream_screen.dart';
import 'live_stream_service.dart';

/// Service dédié pour faciliter la jointure de lives
class LiveJoinService {
  static final _supabase = Supabase.instance.client;
  static final _liveStreamService = LiveStreamService();

  /// Rejoindre un live avec son ID
  static Future<bool> joinLiveById(
    BuildContext context,
    String liveId, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _showLoadingDialog(context);
    }

    try {
      // Vérifier que l'utilisateur est connecté
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (showLoading) Navigator.of(context).pop();
        _showErrorDialog(
          context,
          'Vous devez être connecté pour rejoindre un live',
        );
        return false;
      }

      // Récupérer les informations du live
      final lives = await _liveStreamService.fetchLiveStreams();
      final live = lives.where((l) => l.id == liveId).firstOrNull;

      if (live == null) {
        if (showLoading) Navigator.of(context).pop();
        _showErrorDialog(context, 'Live introuvable avec l\'ID: $liveId');
        return false;
      }

      if (!live.isLive) {
        if (showLoading) Navigator.of(context).pop();
        _showErrorDialog(context, 'Ce live n\'est plus actif');
        return false;
      }

      // Rejoindre le live
      await _liveStreamService.joinLive(liveId, user.id);

      if (showLoading) Navigator.of(context).pop();

      // Naviguer vers l'écran de live
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LiveStreamScreen(liveId: liveId, isHost: false),
        ),
      );

      return true;
    } catch (e) {
      if (showLoading) Navigator.of(context).pop();
      _showErrorDialog(context, 'Erreur lors de la connexion au live: $e');
      return false;
    }
  }

  /// Rejoindre un live via un lien partagé
  static Future<bool> joinLiveFromUrl(BuildContext context, String url) async {
    try {
      // Extraire l'ID du live depuis l'URL
      final uri = Uri.parse(url);
      String? liveId;

      // Formats d'URL supportés:
      // https://streamy.app/live/[LIVE_ID]
      // streamy://live/[LIVE_ID]
      // [LIVE_ID] (ID direct)

      if (uri.pathSegments.isNotEmpty) {
        if (uri.pathSegments.contains('live')) {
          final index = uri.pathSegments.indexOf('live');
          if (index + 1 < uri.pathSegments.length) {
            liveId = uri.pathSegments[index + 1];
          }
        }
      } else if (uri.host.isEmpty && uri.path.isNotEmpty) {
        // URL simple sans domaine
        liveId = uri.path.replaceAll('/', '');
      }

      if (liveId == null || liveId.isEmpty) {
        _showErrorDialog(context, 'Lien invalide');
        return false;
      }

      return await joinLiveById(context, liveId);
    } catch (e) {
      _showErrorDialog(context, 'Impossible de traiter le lien: $e');
      return false;
    }
  }

  /// Afficher un dialog pour saisir l'ID d'un live
  static void showJoinLiveDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejoindre un live'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez l\'ID du live ou collez un lien de partage :',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'ID du live ou lien',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final input = controller.text.trim();
              if (input.isNotEmpty) {
                // Tenter de rejoindre via URL d'abord, puis via ID direct
                bool success = false;
                if (input.contains('://') || input.contains('.')) {
                  success = await joinLiveFromUrl(context, input);
                } else {
                  success = await joinLiveById(context, input);
                }

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connexion au live réussie!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
  }

  /// Générer un lien de partage pour un live
  static String generateShareableLink(String liveId) {
    return 'https://streamy.app/live/$liveId';
  }

  /// Copier le lien de partage dans le presse-papier
  static Future<void> shareLive(BuildContext context, String liveId) async {
    try {
      final link = generateShareableLink(liveId);
      // TODO: Implémenter le partage système
      // await Share.share(link, subject: 'Rejoins mon live sur Streamy!');

      // Pour l'instant, afficher le lien
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Partager le live'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Partagez ce lien pour inviter des spectateurs :'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  link,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ou partagez simplement l\'ID du live :',
                style: TextStyle(fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  liveId,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorDialog(context, 'Erreur lors du partage: $e');
    }
  }

  /// Méthodes utilitaires privées
  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Connexion au live...'),
          ],
        ),
      ),
    );
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
