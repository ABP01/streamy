import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppConfig {
  // Configuration Agora
  static const String agoraAppId = kDebugMode
      ? '28918fa47b4042c28f962d26dc5f27dd'
      : 'YOUR_AGORA_APP_ID_PROD';

  // Mode de développement : désactiver l'authentification par token
  static const bool useAgoraToken = true;

  // Configuration Supabase
  static const String supabaseUrl = 'https://mgesuowulhtfumurrhvx.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZXN1b3d1bGh0ZnVtdXJyaHZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMDg5NzksImV4cCI6MjA2Nzg4NDk3OX0.pydGfp6050RqPMA0uNbGyDnssbIW88b5ESZMwk2DSG0';

  // Configuration de l'app
  static const int maxConcurrentViewers = 1000;
  static const int messageCooldownSeconds = 2;
  static const int maxMessageLength = 200;
  static const int giftsPerToken = 10;
  static const double videoQuality = 720.0;
  static const int maxLiveDurationHours = 12;

  // Configuration des gifts
  static const Map<String, Map<String, dynamic>> giftTypes = {
    'heart': {'cost': 1, 'animation': 'heart_animation', 'color': 0xFFE91E63},
    'star': {'cost': 5, 'animation': 'star_animation', 'color': 0xFFFFD700},
    'diamond': {
      'cost': 10,
      'animation': 'diamond_animation',
      'color': 0xFF00BCD4,
    },
    'crown': {'cost': 50, 'animation': 'crown_animation', 'color': 0xFF9C27B0},
    'rocket': {
      'cost': 100,
      'animation': 'rocket_animation',
      'color': 0xFFFF5722,
    },
  };
}

// Configuration des thèmes et couleurs
class AppTheme {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFFE84393);
  static const Color backgroundColor = Color(0xFF2D3436);
  static const Color surfaceColor = Color(0xFF636E72);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color successColor = Color(0xFF00B894);
  static const Color warningColor = Color(0xFFE17055);

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient darkGradient = LinearGradient(
    colors: [backgroundColor, Color(0xFF1E1E1E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Thème principal
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// Configuration des animations
class AppAnimations {
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration longDuration = Duration(milliseconds: 800);

  static const Curve elasticCurve = Curves.elasticOut;
  static const Curve bounceCurve = Curves.bounceOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
}

// Configuration des constantes
class AppConstants {
  // Dimensions
  static const double borderRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double iconSize = 24.0;
  static const double avatarSize = 40.0;

  // Espacement
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // Limites
  static const int maxViewersPerLive = 10000;
  static const int messageDisplayTime = 5; // secondes

  // Configuration du chat
  static const int maxRecentMessages = 50;
  static const int chatRefreshInterval = 1; // secondes
}

// Utilitaires pour l'interface
class AppUtils {
  // Formatage des nombres
  static String formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }

  // Formatage du temps
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  // Formatage de l'heure relative
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'à l\'instant';
    }
  }

  // Validation des entrées
  static bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  static bool isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username);
  }

  // Couleurs aléatoires pour les utilisateurs
  static Color getUserColor(String userId) {
    final colors = [
      const Color(0xFF3498DB),
      const Color(0xFFE74C3C),
      const Color(0xFF2ECC71),
      const Color(0xFFF39C12),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
      const Color(0xFFE67E22),
      const Color(0xFF34495E),
    ];

    final hash = userId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  // Vibration haptique
  static void hapticFeedback() {
    HapticFeedback.mediumImpact();
  }
}

// Widget de base pour les avatars
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? username;
  final double size;
  final bool showOnlineIndicator;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.username,
    this.size = AppConstants.avatarSize,
    this.showOnlineIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: AppUtils.getUserColor(username ?? ''),
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
          child: imageUrl == null
              ? Text(
                  username?.isNotEmpty == true
                      ? username![0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        if (showOnlineIndicator)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
