import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../screens/discover_screen.dart';
import '../screens/help_navigation_screen.dart';
import '../screens/live_stream_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/private_chat_screen.dart';
import '../screens/search_users_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/smart_landing_screen.dart';
import '../screens/tiktok_style_live_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/user_search_screen.dart';
import '../screens/vertical_live_screen.dart';
import '../widgets/navigation_wrapper.dart';

/// 🧭 Gestionnaire centralisé de navigation pour l'application Streamy
class AppRouter {
  // Routes nommées
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String discover = '/discover';
  static const String messaging = '/messaging';
  static const String profile = '/profile';
  static const String settingsRoute = '/settings';
  static const String searchUsers = '/search-users';
  static const String userSearch = '/user-search';
  static const String liveStream = '/live-stream';
  static const String tikTokLive = '/tiktok-live';
  static const String verticalLive = '/vertical-live';
  static const String privateChat = '/private-chat';
  static const String helpNavigation = '/help-navigation';

  /// Navigation vers un écran spécifique
  static Future<void> navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    await Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  /// Navigation avec remplacement de l'écran actuel
  static Future<void> navigateAndReplace(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    await Navigator.pushReplacementNamed(
      context,
      routeName,
      arguments: arguments,
    );
  }

  /// Navigation vers un écran et suppression de l'historique
  static Future<void> navigateAndClear(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    await Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Navigation vers le profil d'un utilisateur
  static Future<void> navigateToUserProfile(
    BuildContext context, {
    required String userId,
    bool isCurrentUser = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserProfileScreen(userId: userId, isCurrentUser: isCurrentUser),
      ),
    );
  }

  /// Navigation vers un live stream
  static Future<void> navigateToLiveStream(
    BuildContext context, {
    required String liveId,
    bool isHost = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(liveId: liveId, isHost: isHost),
      ),
    );
  }

  /// Navigation vers les lives TikTok style
  static Future<void> navigateToTikTokLive(
    BuildContext context, {
    List<LiveStream>? initialLives,
    int initialIndex = 0,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TikTokStyleLiveScreen(
          initialLives: initialLives,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  /// Navigation vers un chat privé
  static Future<void> navigateToPrivateChat(
    BuildContext context, {
    required UserProfile otherUser,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateChatScreen(otherUser: otherUser),
      ),
    );
  }

  /// Navigation vers les paramètres
  static Future<void> navigateToSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  /// Navigation vers la recherche d'utilisateurs
  static Future<void> navigateToSearchUsers(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchUsersScreen()),
    );
  }

  /// Navigation vers l'écran principal après connexion
  static Future<void> navigateToMainApp(BuildContext context) async {
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const NavigationWrapper()),
      (route) => false,
    );
  }

  /// Retour à l'écran précédent
  static void goBack(BuildContext context, {Object? result}) {
    Navigator.pop(context, result);
  }

  /// Retour à l'écran racine
  static void goBackToRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// Génération des routes pour l'application
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _buildRoute(const SmartLandingScreen());

      case onboarding:
        return _buildRoute(const OnboardingScreen());

      case home:
        return _buildRoute(const NavigationWrapper());

      case discover:
        return _buildRoute(const DiscoverScreen());

      case messaging:
        return _buildRoute(const MessagingScreen());

      case profile:
        final currentUser = Supabase.instance.client.auth.currentUser;
        return _buildRoute(
          UserProfileScreen(userId: currentUser?.id ?? '', isCurrentUser: true),
        );

      case settingsRoute:
        return _buildRoute(const SettingsScreen());

      case searchUsers:
        return _buildRoute(const SearchUsersScreen());

      case userSearch:
        return _buildRoute(const UserSearchScreen());

      case liveStream:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          LiveStreamScreen(
            liveId: args?['liveId'] ?? '',
            isHost: args?['isHost'] ?? false,
          ),
        );

      case tikTokLive:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          TikTokStyleLiveScreen(
            initialLives: args?['initialLives'],
            initialIndex: args?['initialIndex'] ?? 0,
          ),
        );

      case verticalLive:
        return _buildRoute(const VerticalLiveScreen());

      case privateChat:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          PrivateChatScreen(otherUser: args?['otherUser'] as UserProfile),
        );

      case helpNavigation:
        return _buildRoute(const HelpNavigationScreen());

      default:
        return _buildRoute(
          const Scaffold(
            body: Center(
              child: Text(
                'Page non trouvée',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            backgroundColor: Colors.black,
          ),
        );
    }
  }

  /// Construction d'une route avec transition personnalisée
  static MaterialPageRoute _buildRoute(Widget page) {
    return MaterialPageRoute(builder: (context) => page);
  }
}
