import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class CacheService {
  static const String _livesKey = 'cached_lives';
  static const String _usersKey = 'cached_users';
  static const String _messagesKey = 'cached_messages';
  static const String _giftsKey = 'cached_gifts';
  static const String _userProfileKey = 'cached_user_profile';

  static const Duration _cacheExpiration = Duration(minutes: 5);
  static const Duration _userProfileExpiration = Duration(hours: 1);

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ===== CACHE POUR LES LIVES =====

  static Future<void> cacheLives(List<LiveStream> lives) async {
    await init();
    final data = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': lives.map((live) => live.toJson()).toList(),
    };
    await _prefs!.setString(_livesKey, jsonEncode(data));
  }

  static Future<List<LiveStream>?> getCachedLives() async {
    await init();
    final cached = _prefs!.getString(_livesKey);
    if (cached == null) return null;

    try {
      final data = jsonDecode(cached);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        await clearLivesCache();
        return null;
      }

      final List<dynamic> livesJson = data['data'];
      return livesJson.map((json) => LiveStream.fromJson(json)).toList();
    } catch (e) {
      await clearLivesCache();
      return null;
    }
  }

  static Future<void> clearLivesCache() async {
    await init();
    await _prefs!.remove(_livesKey);
  }

  // ===== CACHE POUR LES UTILISATEURS =====

  static Future<void> cacheUser(UserProfile user) async {
    await init();
    final data = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': user.toJson(),
    };
    await _prefs!.setString('${_usersKey}_${user.id}', jsonEncode(data));
  }

  static Future<UserProfile?> getCachedUser(String userId) async {
    await init();
    final cached = _prefs!.getString('${_usersKey}_$userId');
    if (cached == null) return null;

    try {
      final data = jsonDecode(cached);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

      if (DateTime.now().difference(timestamp) > _userProfileExpiration) {
        await clearUserCache(userId);
        return null;
      }

      return UserProfile.fromJson(data['data']);
    } catch (e) {
      await clearUserCache(userId);
      return null;
    }
  }

  static Future<void> clearUserCache(String userId) async {
    await init();
    await _prefs!.remove('${_usersKey}_$userId');
  }

  // ===== CACHE POUR LES MESSAGES =====

  static Future<void> cacheMessages(
    String liveId,
    List<LiveStreamMessage> messages,
  ) async {
    await init();
    final data = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': messages.map((msg) => msg.toJson()).toList(),
    };
    await _prefs!.setString('${_messagesKey}_$liveId', jsonEncode(data));
  }

  static Future<List<LiveStreamMessage>?> getCachedMessages(
    String liveId,
  ) async {
    await init();
    final cached = _prefs!.getString('${_messagesKey}_$liveId');
    if (cached == null) return null;

    try {
      final data = jsonDecode(cached);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        await clearMessagesCache(liveId);
        return null;
      }

      final List<dynamic> messagesJson = data['data'];
      return messagesJson
          .map((json) => LiveStreamMessage.fromJson(json))
          .toList();
    } catch (e) {
      await clearMessagesCache(liveId);
      return null;
    }
  }

  static Future<void> clearMessagesCache(String liveId) async {
    await init();
    await _prefs!.remove('${_messagesKey}_$liveId');
  }

  // ===== CACHE POUR LE PROFIL UTILISATEUR COURANT =====

  static Future<void> cacheCurrentUserProfile(UserProfile profile) async {
    await init();
    final data = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': profile.toJson(),
    };
    await _prefs!.setString(_userProfileKey, jsonEncode(data));
  }

  static Future<UserProfile?> getCachedCurrentUserProfile() async {
    await init();
    final cached = _prefs!.getString(_userProfileKey);
    if (cached == null) return null;

    try {
      final data = jsonDecode(cached);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

      if (DateTime.now().difference(timestamp) > _userProfileExpiration) {
        await clearCurrentUserProfileCache();
        return null;
      }

      return UserProfile.fromJson(data['data']);
    } catch (e) {
      await clearCurrentUserProfileCache();
      return null;
    }
  }

  static Future<void> clearCurrentUserProfileCache() async {
    await init();
    await _prefs!.remove(_userProfileKey);
  }

  // ===== CACHE POUR LES LISTES D'UTILISATEURS =====

  static Future<void> cacheUsers(
    List<Map<String, dynamic>> users,
    String cacheKey,
  ) async {
    await init();
    final data = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': users,
    };
    await _prefs!.setString('users_list_$cacheKey', jsonEncode(data));
  }

  static Future<List<Map<String, dynamic>>?> getCachedUsers(
    String cacheKey, {
    Duration? maxAge,
  }) async {
    await init();
    final cached = _prefs!.getString('users_list_$cacheKey');
    if (cached == null) return null;

    try {
      final data = jsonDecode(cached);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      final age = maxAge ?? _cacheExpiration;

      if (DateTime.now().difference(timestamp) > age) {
        await _prefs!.remove('users_list_$cacheKey');
        return null;
      }

      return List<Map<String, dynamic>>.from(data['data']);
    } catch (e) {
      await _prefs!.remove('users_list_$cacheKey');
      return null;
    }
  }

  // ===== UTILITAIRES =====

  static Future<void> clearAllCache() async {
    await init();
    final keys = _prefs!
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_livesKey) ||
              key.startsWith(_usersKey) ||
              key.startsWith(_messagesKey) ||
              key.startsWith(_giftsKey) ||
              key.startsWith('users_list_') ||
              key == _userProfileKey,
        )
        .toList();

    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  static Future<Map<String, dynamic>> getCacheStats() async {
    await init();
    final keys = _prefs!.getKeys();

    return {
      'total_keys': keys.length,
      'cache_keys': keys
          .where(
            (key) =>
                key.startsWith(_livesKey) ||
                key.startsWith(_usersKey) ||
                key.startsWith(_messagesKey) ||
                key.startsWith(_giftsKey) ||
                key.startsWith('users_list_') ||
                key == _userProfileKey,
          )
          .length,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }
}
