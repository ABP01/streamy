import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../services/agora_debug_service.dart';
import '../services/agora_test_service.dart';

/// Test de validation de la configuration Agora
class AgoraValidationTest {
  static void runTests() {
    if (!kDebugMode) return;

    print('🚀 TESTS DE VALIDATION AGORA 🚀');
    print('');

    // Test 1: Configuration de base
    print('Test 1: Configuration de base');
    AgoraDebugService.testAgoraConfig();
    print('✅ Configuration testée');
    print('');

    // Test 2: Token de test
    print('Test 2: Token de test');
    final shouldUseTest = AgoraTestService.shouldUseTestToken();
    final testToken = AgoraTestService.getTestToken();
    final testChannel = AgoraTestService.getTestChannelName();

    print('Utilisation token test: $shouldUseTest');
    print('Canal de test: $testChannel');
    print('Token disponible: ${testToken.isNotEmpty ? "Oui" : "Non"}');
    print(
      '${shouldUseTest ? "✅" : "⚠️"} Token de test ${shouldUseTest ? "activé" : "désactivé"}',
    );
    print('');

    // Test 3: Validation du token format
    print('Test 3: Validation format token');
    final isValidFormat = AgoraDebugService.isValidTokenFormat(testToken);
    print('Format valide: $isValidFormat');
    print('${isValidFormat ? "✅" : "❌"} Format du token');
    print('');

    // Résumé
    print('📋 RÉSUMÉ DES TESTS');
    print('Mode debug: ${kDebugMode ? "✅" : "❌"}');
    print('Token requis: ${AppConfig.useAgoraToken ? "✅" : "⚠️"}');
    print('Token test: ${shouldUseTest ? "✅" : "⚠️"}');
    print('Token valide: ${isValidFormat ? "✅" : "❌"}');
    print('');

    if (shouldUseTest && isValidFormat) {
      print('🎉 PRÊT POUR LES TESTS!');
      print(
        'Vous pouvez maintenant créer un live avec le canal "$testChannel"',
      );
    } else if (!AppConfig.useAgoraToken) {
      print('📝 MODE SANS TOKEN ACTIVÉ');
      print('L\'application fonctionnera sans authentification token');
    } else {
      print('⚠️  PROBLÈMES DÉTECTÉS');
      print('Vérifiez la configuration ou utilisez le mode sans token');
    }

    print('=' * 60);
  }
}
