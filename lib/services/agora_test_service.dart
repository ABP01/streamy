import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Service pour tester Agora avec un token temporaire
class AgoraTestService {
  // Token temporaire généré depuis la console Agora
  static const String tempToken =
      '007eJxTYOib+PXLv9N/S2PmTLw+PTUoL9rcuGGFVNie1RfLlpw0UdijwGBkYWlokZZoYp5kYmBilGxkkWZpZpRiZJaSbJpmZJ6Ssj6+KKMhkJHhicdhZkYGCATxWRhKUotLGBgAH4siCw==';
  static const String tempChannelName = 'test';

  /// Utilise le token temporaire pour les tests
  static String getTestToken() {
    if (kDebugMode) {
      print('🧪 UTILISATION DU TOKEN DE TEST');
      print('Canal: $tempChannelName');
      print('Token: ${tempToken.substring(0, 20)}...');
      print('⚠️  Ce token expire dans 24h');
      print('─' * 50);
      return tempToken;
    }
    return '';
  }

  /// Vérifie si on doit utiliser le token de test
  static bool shouldUseTestToken() {
    return kDebugMode && !AppConfig.useAgoraToken;
  }

  /// Retourne le nom du canal de test
  static String getTestChannelName() {
    return tempChannelName;
  }
}
