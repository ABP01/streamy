import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service pour communiquer avec le backend Node.js et obtenir les tokens Agora
class AgoraBackendService {
  // Utilisation du backend hébergé sur Render
  static const String _baseUrl =
      'https://streamy-backend-xyg8.onrender.com/api/agora';

  /// Réveille le backend Render s'il est en veille
  static Future<void> wakeUpBackend() async {
    try {
      debugPrint('🌅 Réveil du backend Render...');
      await http
          .get(Uri.parse('${_baseUrl.replaceAll('/api/agora', '')}/health'))
          .timeout(const Duration(seconds: 30)); // Long timeout pour le wake-up
      debugPrint('✅ Backend réveillé');
    } catch (e) {
      debugPrint('⚠️ Échec du réveil du backend: $e');
    }
  }

  /// Génère un token pour rejoindre un live en tant que spectateur
  static Future<AgoraTokenResponse> getViewerToken({
    required String liveId,
    required String userId,
  }) async {
    try {
      debugPrint(
        '🔄 Demande de token spectateur pour live: $liveId, user: $userId',
      );
      final response = await http
          .post(
            Uri.parse('$_baseUrl/live-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'liveId': liveId,
              'userId': userId,
              'role': 'viewer',
            }),
          )
          .timeout(const Duration(seconds: 15)); // Timeout plus long

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Token spectateur reçu pour live: $liveId');
          return AgoraTokenResponse.fromJson(data['data']);
        } else {
          throw Exception('Erreur serveur: ${data['message']}');
        }
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération du token spectateur: $e');
      rethrow;
    }
  }

  /// Génère un token pour démarrer un live en tant qu'hôte
  static Future<AgoraTokenResponse> getHostToken({
    required String liveId,
    required String userId,
  }) async {
    try {
      debugPrint('🔄 Demande de token hôte pour live: $liveId, user: $userId');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/live-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'liveId': liveId,
              'userId': userId,
              'role': 'host',
            }),
          )
          .timeout(const Duration(seconds: 15)); // Timeout plus long

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Token hôte reçu pour live: $liveId');
          return AgoraTokenResponse.fromJson(data['data']);
        } else {
          throw Exception('Erreur serveur: ${data['message']}');
        }
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération du token hôte: $e');
      rethrow;
    }
  }

  /// Teste la connexion au backend
  static Future<bool> testConnection() async {
    try {
      debugPrint('🔄 Test de connexion au backend: $_baseUrl/config');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/config'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 15),
          ); // Augmentation du timeout pour Render

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Connexion au backend réussie');
        debugPrint('📡 Configuration Agora: ${data['data']['isConfigValid']}');
        debugPrint('🔧 App ID configuré: ${data['data']['appId']}');
        debugPrint(
          '🔐 Certificat configuré: ${data['data']['certificateConfigured']}',
        );
        return data['success'] == true;
      } else {
        debugPrint(
          '❌ Backend non accessible (${response.statusCode}): ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Impossible de contacter le backend: $e');
      return false;
    }
  }

  /// Obtient des tokens de test pour le développement
  static Future<TestTokensResponse?> getTestTokens() async {
    if (!kDebugMode) {
      debugPrint('⚠️ Tokens de test non disponibles en production');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/test-tokens'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('🧪 Tokens de test reçus');
          return TestTokensResponse.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des tokens de test: $e');
      return null;
    }
  }

  /// Vérifie l'état du backend
  static Future<BackendHealthResponse> checkHealth() async {
    try {
      debugPrint('🔄 Vérification de l\'état du backend...');
      final response = await http
          .get(
            Uri.parse('${_baseUrl.replaceAll('/api/agora', '')}/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
          ); // Timeout plus long pour Render

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Backend opérationnel: ${data['message']}');
        return BackendHealthResponse.fromJson(data);
      } else {
        debugPrint(
          '❌ Backend inaccessible (${response.statusCode}): ${response.body}',
        );
        return BackendHealthResponse(
          success: false,
          message: 'Backend inaccessible (${response.statusCode})',
          status: 'unhealthy',
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur de connexion au backend: $e');
      return BackendHealthResponse(
        success: false,
        message: 'Erreur de connexion: $e',
        status: 'error',
      );
    }
  }

  /// Initialise le service et vérifie la connectivité
  static Future<bool> initialize() async {
    try {
      debugPrint('🚀 Initialisation du service Agora Backend...');

      // 1. Réveil du backend Render
      await wakeUpBackend();

      // 2. Test de la connexion
      final isConnected = await testConnection();

      // 3. Vérification de la santé
      final health = await checkHealth();

      if (isConnected && health.success) {
        debugPrint('✅ Service Agora Backend initialisé avec succès');
        return true;
      } else {
        debugPrint('⚠️ Service Agora Backend partiellement fonctionnel');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Échec de l\'initialisation du service Agora Backend: $e');
      return false;
    }
  }
}

/// Réponse contenant un token Agora
class AgoraTokenResponse {
  final String token;
  final String appId;
  final String channelName;
  final int uid;
  final String role;
  final String expiresAt;
  final String? liveId;

  AgoraTokenResponse({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.role,
    required this.expiresAt,
    this.liveId,
  });

  factory AgoraTokenResponse.fromJson(Map<String, dynamic> json) {
    return AgoraTokenResponse(
      token: json['token'] as String,
      appId: json['appId'] as String,
      channelName: json['channelName'] as String,
      uid: json['uid'] as int,
      role: json['role'] as String,
      expiresAt: json['expiresAt'] as String,
      liveId: json['liveId'] as String?,
    );
  }

  bool get isValid =>
      token.isNotEmpty && DateTime.now().isBefore(DateTime.parse(expiresAt));

  Duration get timeUntilExpiry =>
      DateTime.parse(expiresAt).difference(DateTime.now());
}

/// Réponse contenant des tokens de test
class TestTokensResponse {
  final String testChannel;
  final AgoraTokenResponse host;
  final AgoraTokenResponse viewer;
  final String note;

  TestTokensResponse({
    required this.testChannel,
    required this.host,
    required this.viewer,
    required this.note,
  });

  factory TestTokensResponse.fromJson(Map<String, dynamic> json) {
    return TestTokensResponse(
      testChannel: json['testChannel'] as String,
      host: AgoraTokenResponse.fromJson(json['host'] as Map<String, dynamic>),
      viewer: AgoraTokenResponse.fromJson(
        json['viewer'] as Map<String, dynamic>,
      ),
      note: json['note'] as String,
    );
  }
}

/// Réponse de santé du backend
class BackendHealthResponse {
  final bool success;
  final String message;
  final String status;
  final String? timestamp;

  BackendHealthResponse({
    required this.success,
    required this.message,
    required this.status,
    this.timestamp,
  });

  factory BackendHealthResponse.fromJson(Map<String, dynamic> json) {
    return BackendHealthResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      status: json['data']?['status'] as String? ?? 'unknown',
      timestamp: json['data']?['timestamp'] as String?,
    );
  }

  bool get isHealthy => success && status == 'healthy';
}
