import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/live_stream.dart';
import '../services/agora_backend_service.dart';
import '../services/live_stream_service.dart';

/// 🎥 Écran de live pour l'hôte avec vue caméra locale
class HostLiveScreen extends StatefulWidget {
  final LiveStream live;

  const HostLiveScreen({super.key, required this.live});

  @override
  State<HostLiveScreen> createState() => _HostLiveScreenState();
}

class _HostLiveScreenState extends State<HostLiveScreen>
    with WidgetsBindingObserver {
  RtcEngine? _engine;
  bool _joined = false;
  bool _cameraEnabled = true;
  bool _micEnabled = true;
  bool _frontCamera = true;
  bool _showStats = true;

  // Statistiques en temps réel
  int _viewerCount = 0;
  int _likeCount = 0;
  int _giftCount = 0;
  Duration _liveDuration = Duration.zero;

  // Timers
  Timer? _statsTimer;
  Timer? _durationTimer;

  // État de l'interface
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  // Protection contre les clics multiples
  bool _isEndingLive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_engine != null) {
      switch (state) {
        case AppLifecycleState.paused:
          _engine!.disableVideo();
          break;
        case AppLifecycleState.resumed:
          if (_cameraEnabled) {
            _engine!.enableVideo();
          }
          break;
        default:
          break;
      }
    }
  }

  Future<void> _initializeLive() async {
    try {
      // 1. Vérifier les permissions
      final hasPermissions = await _checkPermissions();
      if (!hasPermissions) {
        _showPermissionError();
        return;
      }

      // 2. Initialiser Agora
      await _initializeAgora();

      // 3. Démarrer les timers
      _setupTimers();

      // 4. Démarrer le cache des contrôles
      _startControlsAutoHide();
    } catch (e) {
      print('Erreur lors de l\'initialisation du live: $e');
      _showError('Impossible de démarrer le live: $e');
    }
  }

  Future<bool> _checkPermissions() async {
    print('🔐 Vérification des permissions...');

    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    print('   - Caméra: ${cameraStatus.name}');
    print('   - Microphone: ${micStatus.name}');

    if (cameraStatus.isDenied || micStatus.isDenied) {
      print('⚠️ Permissions manquantes, demande en cours...');

      final results = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraGranted = results[Permission.camera]!.isGranted;
      final micGranted = results[Permission.microphone]!.isGranted;

      print('   - Caméra après demande: ${cameraGranted ? '✅' : '❌'}');
      print('   - Microphone après demande: ${micGranted ? '✅' : '❌'}');

      if (!cameraGranted || !micGranted) {
        print('❌ Permissions refusées par l\'utilisateur');
        return false;
      }

      return true;
    }

    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      print('❌ Permissions définitivement refusées');
      _showPermissionError();
      return false;
    }

    print('✅ Toutes les permissions sont accordées');
    return cameraStatus.isGranted && micStatus.isGranted;
  }

  Future<void> _initializeAgora() async {
    // Déclarer les variables au début pour qu'elles soient accessibles partout
    String token = '';
    final channelId = widget.live.agoraChannelId ?? widget.live.id;

    try {
      print('🔧 Initialisation du moteur Agora...');

      // Créer et initialiser le moteur Agora
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: AppConfig.agoraAppId));

      print(
        '✅ Moteur Agora créé avec App ID: ${AppConfig.agoraAppId.substring(0, 8)}...',
      );

      // Configuration des événements
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            print('✅ Hôte connecté au canal: ${connection.channelId}');
            setState(() {
              _joined = true;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            print('👤 Nouveau spectateur rejoint: $remoteUid');
            setState(() {
              _viewerCount++;
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            print('👤 Spectateur quitté: $remoteUid (raison: ${reason.name})');
            setState(() {
              _viewerCount = (_viewerCount - 1)
                  .clamp(0, double.infinity)
                  .toInt();
            });
          },
          onError: (err, msg) {
            print('❌ Erreur Agora: $err - $msg');
            _showError('Erreur de connexion: $msg');
          },
          onLocalVideoStateChanged: (source, state, error) {
            print(
              '📹 État vidéo locale changé: ${state.name} (erreur: ${error.name})',
            );
            if (state == LocalVideoStreamState.localVideoStreamStateFailed) {
              print('❌ Erreur vidéo locale: ${error.name}');
            }
          },
          onLocalAudioStateChanged: (connection, state, reason) {
            print(
              '🎤 État audio local changé: ${state.name} (raison: ${reason.name})',
            );
          },
        ),
      );

      // Configuration vidéo optimisée
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 24,
          bitrate: 1500,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

      // Activer et configurer la vidéo
      await _engine!.enableVideo();
      await _engine!.enableLocalVideo(true);

      // Activer l'audio
      await _engine!.enableAudio();
      await _engine!.enableLocalAudio(true);

      // Démarrer l'aperçu de la caméra AVANT de rejoindre le canal
      await _engine!.startPreview();

      print('🎥 Aperçu de la caméra démarré');

      // Obtenir le token pour l'hôte
      if (AppConfig.useAgoraToken) {
        try {
          final response = await AgoraBackendService.getHostToken(
            liveId: widget.live.agoraChannelId ?? widget.live.id,
            userId: Supabase.instance.client.auth.currentUser?.id ?? 'host',
          );
          token = response.token;
          print('✅ Token hôte obtenu: ${token.substring(0, 20)}...');
        } catch (e) {
          print('⚠️ Erreur lors de l\'obtention du token: $e');
          // Continuer sans token en mode développement
        }
      }

      // S'assurer qu'on n'est pas déjà dans un canal
      try {
        await _engine!.leaveChannel();
        print('🔄 Canal précédent quitté par précaution');
      } catch (e) {
        print('ℹ️ Aucun canal précédent à quitter: $e');
      }

      // Attendre un peu pour la stabilité
      await Future.delayed(const Duration(milliseconds: 500));

      print('🔗 Tentative de connexion au canal: $channelId');
      print(
        '🎫 Token utilisé: ${token.isEmpty ? 'Aucun (mode dev)' : 'Fourni'}',
      );

      // Rejoindre le canal en tant qu'hôte (broadcaster)
      await _engine!.joinChannel(
        token: token,
        channelId: channelId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );

      print('🎥 Live démarré avec succès! Canal: $channelId');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation Agora: $e');

      // Gestion spécifique des erreurs Agora
      if (e.toString().contains('-17')) {
        print(
          '🔄 Erreur -17 détectée (canal déjà rejoint), tentative de récupération...',
        );
        try {
          await _engine!.leaveChannel();
          await Future.delayed(const Duration(seconds: 1));

          // Nouvelle tentative après nettoyage
          await _engine!.joinChannel(
            token: token,
            channelId: channelId,
            uid: 0,
            options: const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishCameraTrack: true,
              publishMicrophoneTrack: true,
              autoSubscribeVideo: true,
              autoSubscribeAudio: true,
            ),
          );
          print('✅ Récupération réussie après erreur -17');
          return;
        } catch (retryError) {
          print('❌ Échec de la récupération: $retryError');
          _showError(
            'Impossible de se connecter au canal. Redémarrez l\'application.',
          );
        }
      } else if (e.toString().contains('Invalid App ID')) {
        _showError('Configuration Agora invalide. Vérifiez l\'App ID.');
      } else if (e.toString().contains('Permission')) {
        _showError('Permissions caméra/microphone refusées.');
      } else {
        _showError('Erreur d\'initialisation: $e');
      }
      throw e;
    }
  }

  void _setupTimers() {
    // Timer pour les statistiques
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateLiveStats();
    });

    // Timer pour la durée du live
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _liveDuration = DateTime.now().difference(widget.live.startedAt!);
      });
    });
  }

  Future<void> _updateLiveStats() async {
    try {
      final liveService = LiveStreamService();
      final stats = await liveService.getLiveStats(widget.live.id);

      setState(() {
        _viewerCount = stats.viewerCount;
        _likeCount = stats.likeCount;
        _giftCount = stats.giftCount;
      });
    } catch (e) {
      print('Erreur lors de la mise à jour des stats: $e');
    }
  }

  void _startControlsAutoHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _startControlsAutoHide();
    }
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _cameraEnabled = !_cameraEnabled;
    });
    await _engine!.enableLocalVideo(_cameraEnabled);
  }

  Future<void> _toggleMicrophone() async {
    setState(() {
      _micEnabled = !_micEnabled;
    });
    await _engine!.enableLocalAudio(_micEnabled);
  }

  Future<void> _switchCamera() async {
    setState(() {
      _frontCamera = !_frontCamera;
    });
    await _engine!.switchCamera();
  }

  Future<void> _endLive() async {
    // Protection contre les clics multiples
    if (_isEndingLive) {
      print('⚠️ Fermeture déjà en cours, ignoré');
      return;
    }

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Terminer le live ?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Êtes-vous sûr de vouloir terminer ce live ?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Durée', _formatDuration(_liveDuration)),
            _buildSummaryRow('Spectateurs', _viewerCount.toString()),
            _buildSummaryRow('Likes', _likeCount.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      // Marquer comme en cours de fermeture
      setState(() {
        _isEndingLive = true;
      });

      // Afficher un indicateur de chargement
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: Card(
                color: Colors.black54,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Fermeture du live...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      try {
        print('🔄 Début de la fermeture du live...');

        // Étape 1: Arrêter les timers et la publication locale
        print('⏹️ Arrêt des timers et de la publication...');
        _statsTimer?.cancel();
        _durationTimer?.cancel();
        _controlsTimer?.cancel();

        // Étape 2: Arrêter la publication vidéo/audio
        if (_engine != null) {
          await _engine!.muteLocalVideoStream(true);
          await _engine!.muteLocalAudioStream(true);
          await _engine!.stopPreview();
        }

        // Étape 3: Mettre à jour le statut dans la base de données
        print('💾 Mise à jour de la base de données...');
        final liveService = LiveStreamService();
        await liveService.endLiveStream(widget.live.id);

        // Étape 4: Quitter le canal et libérer les ressources Agora
        print('📤 Libération des ressources Agora...');
        await _cleanup();

        print('✅ Live fermé avec succès');

        // Fermer le dialog de loading et revenir à l'écran principal
        if (mounted) {
          Navigator.of(context).pop(); // Fermer le dialog de loading
          Navigator.of(context).popUntil((route) => route.isFirst);

          // Afficher un message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Live terminé avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur lors de la fermeture du live: $e');

        // En cas d'erreur, forcer le nettoyage local
        await _cleanup();

        if (mounted) {
          Navigator.of(context).pop(); // Fermer le dialog de loading
          Navigator.of(context).popUntil((route) => route.isFirst);

          // Afficher l'erreur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la fermeture: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
      } finally {
        // Réinitialiser l'état même en cas d'erreur
        if (mounted) {
          setState(() {
            _isEndingLive = false;
          });
        }
      }
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanup() async {
    print('🧹 Début du nettoyage des ressources...');

    try {
      // Arrêter tous les timers
      _statsTimer?.cancel();
      _durationTimer?.cancel();
      _controlsTimer?.cancel();
      print('⏹️ Timers arrêtés');

      // Nettoyage Agora avec timeout
      if (_engine != null) {
        print('📤 Nettoyage du moteur Agora...');

        try {
          // Arrêter la prévisualisation et les flux
          await _engine!.stopPreview().timeout(const Duration(seconds: 2));
          await _engine!
              .enableLocalVideo(false)
              .timeout(const Duration(seconds: 2));
          await _engine!
              .enableLocalAudio(false)
              .timeout(const Duration(seconds: 2));

          // Quitter le canal
          await _engine!.leaveChannel().timeout(const Duration(seconds: 3));
          print('📤 Canal quitté');

          // Libérer le moteur
          await _engine!.release().timeout(const Duration(seconds: 3));
          print('🗑️ Moteur Agora libéré');
        } catch (e) {
          print('⚠️ Erreur lors du nettoyage Agora (non-critique): $e');
          // Forcer la libération en cas d'erreur
          try {
            await _engine!.release();
          } catch (releaseError) {
            print('⚠️ Erreur lors de la libération forcée: $releaseError');
          }
        }

        _engine = null;
      }

      // Réinitialiser l'état
      if (mounted) {
        setState(() {
          _joined = false;
          _viewerCount = 0;
          _likeCount = 0;
        });
      }

      print('✅ Nettoyage terminé avec succès');
    } catch (e) {
      print('❌ Erreur lors du nettoyage: $e');
      // Même en cas d'erreur, on continue pour ne pas bloquer l'utilisateur
    }
  }

  void _showPermissionError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Permissions requises',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'L\'accès à la caméra et au microphone est nécessaire pour démarrer un live.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Vue de la caméra locale
            _buildCameraView(),

            // Overlay avec informations et contrôles
            if (_controlsVisible) _buildOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_joined) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6C5CE7), Color(0xFFE84393)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Démarrage du live...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Vérification des permissions...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraEnabled) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Text(
                'Caméra désactivée',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // Vérification supplémentaire pour s'assurer que le moteur est prêt
    if (_engine == null) {
      print('❌ Moteur Agora non initialisé pour la vue caméra');
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Erreur d\'initialisation caméra',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    print('🎥 Affichage de la vue caméra locale - UID: 0');

    // Vue de la caméra locale de l'hôte avec configuration améliorée
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeHidden,
          mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // En-tête avec informations du live
          _buildHeader(),

          const Spacer(),

          // Statistiques (si activées)
          if (_showStats) _buildStatsPanel(),

          const SizedBox(height: 20),

          // Contrôles en bas
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.visibility, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            _viewerCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDuration(_liveDuration),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.visibility, _viewerCount.toString(), 'Viewers'),
          _buildStatItem(Icons.favorite, _likeCount.toString(), 'Likes'),
          _buildStatItem(Icons.card_giftcard, _giftCount.toString(), 'Gifts'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Basculer caméra avant/arrière
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            onTap: _switchCamera,
          ),

          // Activer/désactiver micro
          _buildControlButton(
            icon: _micEnabled ? Icons.mic : Icons.mic_off,
            isActive: _micEnabled,
            onTap: _toggleMicrophone,
          ),

          // Activer/désactiver caméra
          _buildControlButton(
            icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
            isActive: _cameraEnabled,
            onTap: _toggleCamera,
          ),

          // Afficher/masquer statistiques
          _buildControlButton(
            icon: Icons.analytics,
            isActive: _showStats,
            onTap: () => setState(() => _showStats = !_showStats),
          ),

          // Terminer le live
          _buildControlButton(
            icon: _isEndingLive ? Icons.hourglass_empty : Icons.call_end,
            backgroundColor: _isEndingLive ? Colors.grey : Colors.red,
            onTap: _isEndingLive ? () {} : _endLive,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = true,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              (isActive
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.5)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white60,
          size: 24,
        ),
      ),
    );
  }
}
