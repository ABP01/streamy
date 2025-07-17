import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';

/// 🧪 Écran de test pour diagnostiquer les problèmes de caméra
class CameraTestScreen extends StatefulWidget {
  const CameraTestScreen({super.key});

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  RtcEngine? _engine;
  bool _cameraPreviewActive = false;
  String _statusMessage = 'Initialisation...';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _runCameraTest();
  }

  @override
  void dispose() {
    _cleanupEngine();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toLocal()}: $message');
      _statusMessage = message;
    });
    print('🧪 TEST: $message');
  }

  Future<void> _runCameraTest() async {
    try {
      _addLog('1. Vérification des permissions...');

      // Test des permissions
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;

      _addLog('   Caméra: ${cameraStatus.name}');
      _addLog('   Microphone: ${micStatus.name}');

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        _addLog('2. Demande de permissions...');
        final results = await [
          Permission.camera,
          Permission.microphone,
        ].request();

        if (!results[Permission.camera]!.isGranted) {
          _addLog('❌ Permission caméra refusée');
          return;
        }

        if (!results[Permission.microphone]!.isGranted) {
          _addLog('❌ Permission microphone refusée');
          return;
        }
      }

      _addLog('✅ Permissions accordées');
      _addLog('3. Initialisation du moteur Agora...');

      // Initialisation Agora
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: AppConfig.agoraAppId));

      _addLog('✅ Moteur Agora initialisé');
      _addLog('4. Configuration de la vidéo...');

      // Configuration vidéo
      await _engine!.enableVideo();
      await _engine!.enableLocalVideo(true);

      _addLog('✅ Vidéo activée');
      _addLog('5. Démarrage de l\'aperçu...');

      // Démarrage de l'aperçu
      await _engine!.startPreview();

      setState(() {
        _cameraPreviewActive = true;
      });

      _addLog('✅ Aperçu de la caméra démarré avec succès!');
    } catch (e) {
      _addLog('❌ Erreur: $e');
    }
  }

  Future<void> _cleanupEngine() async {
    if (_engine != null) {
      await _engine!.stopPreview();
      await _engine!.release();
      _engine = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Test de Caméra',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Vue de la caméra
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple, width: 2),
              ),
              child: _cameraPreviewActive && _engine != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine!,
                          canvas: const VideoCanvas(
                            uid: 0,
                            renderMode: RenderModeType.renderModeHidden,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _cameraPreviewActive
                                ? Icons.videocam
                                : Icons.videocam_off,
                            size: 64,
                            color: _cameraPreviewActive
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Logs
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logs de diagnostic:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final isError = log.contains('❌');
                        final isSuccess = log.contains('✅');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: isError
                                  ? Colors.red
                                  : isSuccess
                                  ? Colors.green
                                  : Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Boutons d'action
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _logs.clear();
                        _cameraPreviewActive = false;
                      });
                      _cleanupEngine();
                      _runCameraTest();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    child: const Text('Recommencer le test'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
