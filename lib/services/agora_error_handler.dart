import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class AgoraErrorHandler {
  // Compteur pour éviter les tentatives infinies de reconnexion
  static int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 3;

  static String getErrorMessage(ErrorCodeType errorCode) {
    switch (errorCode) {
      case ErrorCodeType.errOk:
        return 'Succès';
      case ErrorCodeType.errInvalidArgument:
        return 'Argument invalide';
      case ErrorCodeType.errInvalidToken:
        return 'Token invalide ou expiré. Veuillez vous reconnecter.';
      case ErrorCodeType.errTokenExpired:
        return 'Token expiré. Reconnexion en cours...';
      case ErrorCodeType.errInvalidChannelName:
        return 'Nom de canal invalide';
      case ErrorCodeType.errNotInitialized:
        return 'SDK non initialisé';
      case ErrorCodeType.errInvalidAppId:
        return 'App ID invalide';
      case ErrorCodeType.errJoinChannelRejected:
        return 'Demande de rejoindre le canal rejetée';
      case ErrorCodeType.errLeaveChannelRejected:
        return 'Demande de quitter le canal rejetée';
      case ErrorCodeType.errResourceLimited:
        return 'Ressources limitées';
      case ErrorCodeType.errConnectionLost:
        return 'Connexion perdue. Reconnexion...';
      case ErrorCodeType.errConnectionInterrupted:
        return 'Connexion interrompue';
      default:
        return 'Erreur Agora: ${errorCode.name} (${errorCode.value})';
    }
  }

  static bool isRetryableError(ErrorCodeType errorCode) {
    switch (errorCode) {
      case ErrorCodeType.errInvalidToken:
      case ErrorCodeType.errTokenExpired:
      case ErrorCodeType.errConnectionLost:
      case ErrorCodeType.errConnectionInterrupted:
        return true;
      default:
        return false;
    }
  }

  static bool isTokenRelatedError(ErrorCodeType errorCode) {
    switch (errorCode) {
      case ErrorCodeType.errInvalidToken:
      case ErrorCodeType.errTokenExpired:
        return true;
      default:
        return false;
    }
  }

  static String getSuggestion(ErrorCodeType errorCode) {
    switch (errorCode) {
      case ErrorCodeType.errInvalidToken:
      case ErrorCodeType.errTokenExpired:
        return 'Le token d\'authentification est invalide. L\'application va tenter de se reconnecter automatiquement.';
      case ErrorCodeType.errInvalidAppId:
        return 'Configuration de l\'application incorrecte. Contactez le support.';
      case ErrorCodeType.errConnectionLost:
        return 'Vérifiez votre connexion internet et réessayez.';
      default:
        return 'Une erreur inattendue s\'est produite. Réessayez dans quelques instants.';
    }
  }

  /// Vérifie si on peut tenter une reconnexion
  static bool canAttemptReconnection() {
    return _reconnectionAttempts < _maxReconnectionAttempts;
  }

  /// Incrémente le compteur de tentatives de reconnexion
  static void incrementReconnectionAttempts() {
    _reconnectionAttempts++;
  }

  /// Remet à zéro le compteur de tentatives de reconnexion
  static void resetReconnectionAttempts() {
    _reconnectionAttempts = 0;
  }

  /// Retourne le nombre de tentatives restantes
  static int getRemainingAttempts() {
    return _maxReconnectionAttempts - _reconnectionAttempts;
  }
}

class AgoraConnectionState {
  static const int disconnected = 1;
  static const int connecting = 2;
  static const int connected = 3;
  static const int reconnecting = 4;
  static const int failed = 5;

  static String getStateDescription(int state) {
    switch (state) {
      case disconnected:
        return 'Déconnecté';
      case connecting:
        return 'Connexion...';
      case connected:
        return 'Connecté';
      case reconnecting:
        return 'Reconnexion...';
      case failed:
        return 'Connexion échouée';
      default:
        return 'État inconnu';
    }
  }
}
