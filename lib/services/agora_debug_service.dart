import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

class AgoraDebugService {
  /// Affiche des informations de débogage pour les erreurs Agora
  static void logAgoraError(ErrorCodeType errorCode, String? message) {
    if (!kDebugMode) return;

    print('🚨 ERREUR AGORA 🚨');
    print('Code d\'erreur: ${errorCode.name}');
    print('Message: $message');
    print('Solution suggérée: ${getSuggestion(errorCode)}');
    print('─' * 50);
  }

  /// Retourne une suggestion de solution pour chaque type d'erreur
  static String getSuggestion(ErrorCodeType errorCode) {
    switch (errorCode) {
      case ErrorCodeType.errInvalidToken:
        return '''
1. Vérifiez que l'App ID Agora est correct
2. Désactivez l'authentification token en mode dev (AppConfig.useAgoraToken = false)
3. Vérifiez que le certificat Agora est correct
4. Assurez-vous que le token n'est pas expiré''';

      case ErrorCodeType.errTokenExpired:
        return 'Le token a expiré. Générez un nouveau token avec une durée de validité plus longue.';

      case ErrorCodeType.errInvalidChannelName:
        return 'Le nom du canal doit contenir uniquement des caractères alphanumériques, traits d\'union et underscores.';

      case ErrorCodeType.errInvalidAppId:
        return 'Vérifiez l\'App ID dans AppConfig. Il doit être un string de 32 caractères.';

      case ErrorCodeType.errConnectionLost:
        return 'Problème de réseau. Vérifiez la connexion internet.';

      default:
        return 'Erreur inconnue. Consultez la documentation Agora.';
    }
  }

  /// Test la configuration Agora de base
  static void testAgoraConfig() {
    if (!kDebugMode) return;

    print('🔧 TEST CONFIGURATION AGORA 🔧');
    print('App ID: ${_hidePartialString(_getAppId())}');
    print('Token requis: ${_isTokenRequired()}');
    print('Mode debug: ${kDebugMode}');
    print('─' * 50);
  }

  static String _getAppId() {
    // Importer depuis AppConfig sans créer de dépendance circulaire
    return '28918fa47b4042c28f962d26dc5f27dd';
  }

  static bool _isTokenRequired() {
    // En mode dev, on peut désactiver les tokens
    return kDebugMode ? false : true;
  }

  static String _hidePartialString(String str) {
    if (str.length <= 8) return str;
    return '${str.substring(0, 4)}...${str.substring(str.length - 4)}';
  }

  /// Valide un token Agora (format basique)
  static bool isValidTokenFormat(String? token) {
    if (token == null || token.isEmpty) return false;

    // Un token Agora valide contient généralement des points (JWT style)
    // et fait au moins 50 caractères
    return token.contains('.') && token.length > 50;
  }

  /// Suggestions pour résoudre les problèmes de token
  static void debugTokenIssue(String? token, String channelId) {
    if (!kDebugMode) return;

    print('🔍 DEBUG TOKEN 🔍');
    print('Channel ID: $channelId');
    print('Token fourni: ${token?.isNotEmpty == true ? 'Oui' : 'Non'}');
    print('Token valide (format): ${isValidTokenFormat(token)}');

    if (token?.isEmpty == true) {
      print('⚠️  Token vide détecté!');
      print('Solutions:');
      print('1. Activer le mode sans token (AppConfig.useAgoraToken = false)');
      print('2. Implémenter la génération de token côté serveur');
      print('3. Utiliser un token statique pour les tests');
    }

    print('─' * 50);
  }
}
