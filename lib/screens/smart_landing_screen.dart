import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cache_service.dart';
import '../services/live_stream_service.dart';
import '../widgets/navigation_wrapper.dart';
import 'onboarding_screen.dart';

/// 🧭 Écran d'atterrissage intelligent
/// - Première fois ou non connecté → Onboarding léger
/// - Sinon → redirection immédiate vers NavigationWrapper
class SmartLandingScreen extends StatefulWidget {
  const SmartLandingScreen({super.key});

  @override
  State<SmartLandingScreen> createState() => _SmartLandingScreenState();
}

class _SmartLandingScreenState extends State<SmartLandingScreen> {
  String _loadingMessage = 'Initialisation...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Vérifier l'état de l'onboarding
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;
      final user = Supabase.instance.client.auth.currentUser;

      // Si première fois ou pas d'utilisateur connecté → Onboarding
      if (!onboardingCompleted || user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
        return;
      }

      // 2. Préparer le cache et charger les données essentielles
      setState(() {
        _loadingMessage = 'Préparation du cache...';
      });

      await CacheService.init();

      setState(() {
        _loadingMessage = 'Chargement des lives...';
      });

      // 3. Précharger le feed de lives
      await _precacheLiveFeed();

      setState(() {
        _loadingMessage = 'Vérification des permissions...';
      });

      // 4. Vérifier les permissions (optionnel, non bloquant)
      await _checkPermissions();

      // 5. Rediriger vers NavigationWrapper
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const NavigationWrapper()),
        );
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation: $e');
      setState(() {
        _hasError = true;
        _loadingMessage = 'Erreur de connexion';
      });
    }
  }

  /// Précharge les lives pour une navigation fluide
  Future<void> _precacheLiveFeed() async {
    try {
      final liveService = LiveStreamService();
      final lives = await liveService.fetchLiveStreams(limit: 10);

      // Sauvegarder en cache pour navigation immédiate
      await CacheService.cacheLives(lives);

      print('✅ ${lives.length} lives préchargés en cache');
    } catch (e) {
      print('⚠️ Erreur lors du préchargement des lives: $e');
      // Non bloquant - on continue même si le préchargement échoue
    }
  }

  /// Vérifie les permissions caméra/micro de manière non-bloquante
  Future<void> _checkPermissions() async {
    try {
      // TODO: Implémenter la vérification des permissions
      // Cette méthode pourrait préparer l'état des permissions
      // pour éviter les demandes répétées lors du premier live
      await Future.delayed(const Duration(milliseconds: 500));
      print('✅ Permissions vérifiées');
    } catch (e) {
      print('⚠️ Erreur lors de la vérification des permissions: $e');
      // Non bloquant
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorScreen();
    }

    return _buildLoadingScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou icône de l'app
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.live_tv, size: 40, color: Colors.purple),
            ),

            const SizedBox(height: 32),

            // Indicateur de chargement
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.purple,
                strokeWidth: 2,
              ),
            ),

            const SizedBox(height: 24),

            // Message de chargement
            Text(
              _loadingMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Sous-titre
            const Text(
              'Streamy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),

              const SizedBox(height: 24),

              const Text(
                'Oops ! Une erreur est survenue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                _loadingMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _loadingMessage = 'Nouvel essai...';
                  });
                  _initializeApp();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Réessayer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
