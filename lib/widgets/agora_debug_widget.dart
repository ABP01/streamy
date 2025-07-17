import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/agora_validation_test.dart';

class AgoraDebugWidget extends StatelessWidget {
  const AgoraDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                'AGORA DEBUG',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.orange),
              ),
            ],
          ),
          const Divider(color: Colors.orange),
          const SizedBox(height: 8),

          // Configuration
          _buildConfigItem(
            'App ID',
            AppConfig.agoraAppId.isNotEmpty ? '✅ Configuré' : '❌ Manquant',
          ),
          _buildConfigItem(
            'Token requis',
            AppConfig.useAgoraToken ? '✅ Activé' : '⚠️ Désactivé',
          ),
          _buildConfigItem(
            'Mode debug',
            kDebugMode ? '✅ Activé' : '❌ Désactivé',
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    AgoraValidationTest.runTests();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tests exécutés - voir console'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Lancer tests'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Copier les infos de debug
                    final debugInfo =
                        '''
App ID: ${AppConfig.agoraAppId}
Token: ${AppConfig.useAgoraToken}
Mode: Debug
Timestamp: ${DateTime.now()}
                    ''';

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            _DebugInfoScreen(debugInfo: debugInfo),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Infos détaillées'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(
            value,
            style: TextStyle(
              color: value.startsWith('✅')
                  ? Colors.green
                  : value.startsWith('⚠️')
                  ? Colors.orange
                  : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugInfoScreen extends StatelessWidget {
  final String debugInfo;

  const _DebugInfoScreen({required this.debugInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informations de debug'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration Agora',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                debugInfo,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Solutions recommandées:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Vérifiez que l\'App ID Agora est correct'),
            const Text('• En mode développement, désactivez useAgoraToken'),
            const Text('• Testez avec un canal simple avant les lives'),
            const Text('• Vérifiez les permissions caméra/micro'),
          ],
        ),
      ),
    );
  }
}
