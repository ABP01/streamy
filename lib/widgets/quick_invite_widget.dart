import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/live_join_service.dart';

/// Widget pour inviter rapidement des utilisateurs à rejoindre un live
class QuickInviteWidget extends StatelessWidget {
  final String liveId;
  final String liveTitle;

  const QuickInviteWidget({
    super.key,
    required this.liveId,
    required this.liveTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre
          Row(
            children: [
              const Icon(Icons.share, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inviter des amis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      liveTitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ID du live
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ID du live :',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        liveId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyToClipboard(context, liveId),
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copier l\'ID',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Lien de partage
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lien de partage :',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LiveJoinService.generateShareableLink(liveId),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyToClipboard(
                        context,
                        LiveJoinService.generateShareableLink(liveId),
                      ),
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: Colors.blue,
                      ),
                      tooltip: 'Copier le lien',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Comment rejoindre :',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Ouvrir l\'app Streamy\n'
                  '2. Appuyer sur l\'icône 🔗 en haut\n'
                  '3. Coller l\'ID ou le lien\n'
                  '4. Appuyer sur "Rejoindre"',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareExternal(context),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Partager'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copié : $text'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareExternal(BuildContext context) {
    // TODO: Implémenter le partage système avec Share plugin
    Navigator.of(context).pop();

    final shareText =
        'Rejoins mon live sur Streamy !\n'
        'Titre: $liveTitle\n'
        'Lien: ${LiveJoinService.generateShareableLink(liveId)}\n'
        'Ou utilise l\'ID: $liveId';

    _copyToClipboard(context, shareText);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message de partage copié dans le presse-papier'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

/// Extension pour faciliter l'affichage du widget
extension QuickInviteExtension on BuildContext {
  void showQuickInvite(String liveId, String liveTitle) {
    showModalBottomSheet(
      context: this,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          QuickInviteWidget(liveId: liveId, liveTitle: liveTitle),
    );
  }
}
