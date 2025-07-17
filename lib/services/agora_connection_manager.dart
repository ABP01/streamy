import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../services/agora_backend_service.dart';
import '../services/live_stream_service.dart';
import 'agora_debug_service.dart';
import 'agora_error_handler.dart';

/// Gestionnaire de connexion Agora centralisé et robuste
class AgoraConnectionManager {
  RtcEngine? _engine;
  String? _currentChannelId;
  String? _currentToken;
  bool _isConnecting = false;
  bool _isConnected = false;

  // Callbacks
  final Function(ConnectionState)? onConnectionStateChanged;
  final Function(int)? onUserJoined;
  final Function(int)? onUserLeft;
  final Function(String)? onError;

  // Gestion des reconnexions
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 3;

  AgoraConnectionManager({
    this.onConnectionStateChanged,
    this.onUserJoined,
    this.onUserLeft,
    this.onError,
  });

  RtcEngine? get engine => _engine;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  /// Initialise le moteur Agora RTC
  Future<void> _initializeEngine() async {
    if (_engine != null) return;

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: AppConfig.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      // Configuration des événements
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: _onJoinChannelSuccess,
          onLeaveChannel: _onLeaveChannel,
          onUserJoined: _onUserJoined,
          onUserOffline: _onUserOffline,
          onError: _onEngineError,
          onConnectionStateChanged: _onConnectionStateChanged,
          onTokenPrivilegeWillExpire: _onTokenPrivilegeWillExpire,
        ),
      );

      // Configuration audio/vidéo
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine!.enableVideo();
      await _engine!.enableAudio();

      debugPrint('✅ Moteur Agora initialisé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur initialisation Agora: $e');
      onError?.call('Erreur d\'initialisation: $e');
      rethrow;
    }
  }

  /// Se connecter à un live stream
  Future<void> connectToLive(LiveStream live) async {
    if (_isConnecting || _isConnected) {
      debugPrint('⚠️ Connexion déjà en cours ou établie');
      return;
    }

    try {
      _setConnectionState(ConnectionState.connecting);

      await _initializeEngine();

      final channelId = live.agoraChannelId ?? live.id;
      String? token;

      // Obtenir un token si nécessaire
      if (AppConfig.useAgoraToken) {
        token = await _getViewerToken(live.id);
        if (token.isEmpty) {
          throw Exception('Impossible d\'obtenir un token Agora');
        }
      }

      // Rejoindre le canal
      await _engine!.joinChannel(
        token: token ?? '',
        channelId: channelId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          audienceLatencyLevel:
              AudienceLatencyLevelType.audienceLatencyLevelLowLatency,
        ),
      );

      _currentChannelId = channelId;
      _currentToken = token;

      debugPrint('🔗 Connexion au canal: $channelId');
    } catch (e) {
      debugPrint('❌ Erreur connexion live: $e');
      _setConnectionState(ConnectionState.failed);
      onError?.call('Erreur de connexion: $e');

      // Tentative de reconnexion
      _scheduleReconnection(live);
    }
  }

  /// Se déconnecter du live actuel
  Future<void> disconnect() async {
    _reconnectionTimer?.cancel();
    _reconnectionAttempts = 0;

    if (_engine != null && _isConnected) {
      await _engine!.leaveChannel();
    }

    _setConnectionState(ConnectionState.disconnected);
    _currentChannelId = null;
    _currentToken = null;

    debugPrint('🔌 Déconnexion effectuée');
  }

  /// Libérer les ressources
  Future<void> dispose() async {
    _reconnectionTimer?.cancel();

    if (_engine != null) {
      if (_isConnected) {
        await _engine!.leaveChannel();
      }
      await _engine!.release();
      _engine = null;
    }

    debugPrint('🗑️ Ressources Agora libérées');
  }

  /// Obtenir un token pour spectateur
  Future<String> _getViewerToken(String liveId) async {
    try {
      final liveService = LiveStreamService();
      final userId = 'viewer_${DateTime.now().millisecondsSinceEpoch}';
      return await liveService.getViewerToken(liveId, userId);
    } catch (e) {
      debugPrint('⚠️ Erreur token viewer: $e');

      // Fallback avec backend
      try {
        final response = await AgoraBackendService.getViewerToken(
          liveId: liveId,
          userId: 'viewer_anonymous',
        );
        return response.token;
      } catch (backendError) {
        debugPrint('⚠️ Erreur backend token: $backendError');
        return '';
      }
    }
  }

  /// Programmer une reconnexion automatique
  void _scheduleReconnection(LiveStream live) {
    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      debugPrint('❌ Maximum de tentatives de reconnexion atteint');
      return;
    }

    _reconnectionAttempts++;
    final delay = Duration(seconds: _reconnectionAttempts * 2);

    debugPrint(
      '🔄 Reconnexion programmée dans ${delay.inSeconds}s (tentative $_reconnectionAttempts)',
    );

    _reconnectionTimer = Timer(delay, () {
      debugPrint('🔄 Tentative de reconnexion...');
      connectToLive(live);
    });
  }

  void _setConnectionState(ConnectionState state) {
    switch (state) {
      case ConnectionState.connecting:
        _isConnecting = true;
        _isConnected = false;
        break;
      case ConnectionState.connected:
        _isConnecting = false;
        _isConnected = true;
        _reconnectionAttempts = 0; // Reset counter on success
        break;
      case ConnectionState.failed:
      case ConnectionState.disconnected:
        _isConnecting = false;
        _isConnected = false;
        break;
    }

    onConnectionStateChanged?.call(state);
  }

  // === Événements Agora ===

  void _onJoinChannelSuccess(RtcConnection connection, int elapsed) {
    debugPrint('✅ Canal rejoint avec succès: ${connection.channelId}');
    _setConnectionState(ConnectionState.connected);
  }

  void _onLeaveChannel(RtcConnection connection, RtcStats stats) {
    debugPrint('👋 Canal quitté: ${connection.channelId}');
    _setConnectionState(ConnectionState.disconnected);
  }

  void _onUserJoined(RtcConnection connection, int remoteUid, int elapsed) {
    debugPrint('👤 Utilisateur rejoint: $remoteUid');
    onUserJoined?.call(remoteUid);
  }

  void _onUserOffline(
    RtcConnection connection,
    int remoteUid,
    UserOfflineReasonType reason,
  ) {
    debugPrint('👤 Utilisateur parti: $remoteUid (raison: ${reason.name})');
    onUserLeft?.call(remoteUid);
  }

  void _onEngineError(ErrorCodeType err, String msg) {
    debugPrint('🚨 Erreur Agora: ${err.name} - $msg');

    // Log pour debug
    AgoraDebugService.logAgoraError(err, msg);

    final errorMessage = AgoraErrorHandler.getErrorMessage(err);

    // Gestion spécifique des erreurs de token
    if (AgoraErrorHandler.isTokenRelatedError(err)) {
      _handleTokenError();
    } else {
      _setConnectionState(ConnectionState.failed);
      onError?.call(errorMessage);
    }
  }

  void _onConnectionStateChanged(
    RtcConnection connection,
    ConnectionStateType state,
    ConnectionChangedReasonType reason,
  ) {
    debugPrint('🔗 État connexion: ${state.name} (raison: ${reason.name})');

    switch (state) {
      case ConnectionStateType.connectionStateConnecting:
        _setConnectionState(ConnectionState.connecting);
        break;
      case ConnectionStateType.connectionStateConnected:
        _setConnectionState(ConnectionState.connected);
        break;
      case ConnectionStateType.connectionStateFailed:
        _setConnectionState(ConnectionState.failed);
        break;
      case ConnectionStateType.connectionStateDisconnected:
        _setConnectionState(ConnectionState.disconnected);
        break;
      default:
        break;
    }
  }

  void _onTokenPrivilegeWillExpire(RtcConnection connection, String token) {
    debugPrint('⚠️ Token va expirer, renouvellement...');
    _renewToken();
  }

  /// Gérer les erreurs de token
  Future<void> _handleTokenError() async {
    if (!AppConfig.useAgoraToken) {
      debugPrint('⚠️ Mode sans token - ignorer l\'erreur');
      return;
    }

    debugPrint('🔄 Renouvellement du token...');
    await _renewToken();
  }

  /// Renouveler le token
  Future<void> _renewToken() async {
    if (_currentChannelId == null) return;

    try {
      // Obtenir un nouveau token
      final newToken = await _getViewerToken(_currentChannelId!);

      if (newToken.isNotEmpty) {
        await _engine!.renewToken(newToken);
        _currentToken = newToken;
        debugPrint('✅ Token renouvelé avec succès');
      }
    } catch (e) {
      debugPrint('❌ Erreur renouvellement token: $e');
      onError?.call('Erreur de renouvellement du token');
    }
  }
}

/// États de connexion
enum ConnectionState { disconnected, connecting, connected, failed }
