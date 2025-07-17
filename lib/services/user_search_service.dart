import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'cache_service.dart';

class UserSearchService {
  static final _supabase = Supabase.instance.client;

  /// Rechercher des utilisateurs par nom d'utilisateur, nom complet ou email
  static Future<List<UserProfile>> searchUsers({
    required String query,
    int limit = 20,
    int offset = 0,
    bool includeSelf = false,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      // Vérifier d'abord le cache
      final cacheKey = 'search_${query.toLowerCase()}_${limit}_$offset';
      final cachedUsers = await CacheService.getCachedUsers(cacheKey);

      if (cachedUsers != null) {
        return cachedUsers.map((json) => UserProfile.fromJson(json)).toList();
      }

      final currentUser = _supabase.auth.currentUser;
      final searchTerm = '%${query.toLowerCase()}%';

      dynamic searchQuery = _supabase
          .from('users')
          .select('''
            id,
            email,
            username,
            full_name,
            avatar,
            bio,
            followers,
            following,
            total_likes,
            total_gifts,
            tokens_balance,
            created_at,
            last_seen,
            is_verified,
            is_moderator,
            preferences
          ''')
          .or(
            'username.ilike.$searchTerm,full_name.ilike.$searchTerm,email.ilike.$searchTerm',
          )
          .order('followers', ascending: false)
          .range(offset, offset + limit - 1);

      // Exclure l'utilisateur courant si demandé
      if (!includeSelf && currentUser != null) {
        searchQuery = searchQuery.neq('id', currentUser.id);
      }

      final response = await searchQuery;
      final users = (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();

      // Mettre en cache les résultats
      await CacheService.cacheUsers(
        users.map((user) => user.toJson()).toList(),
        cacheKey,
      );

      return users;
    } catch (e) {
      print('Erreur lors de la recherche d\'utilisateurs: $e');
      return [];
    }
  }

  /// Rechercher des utilisateurs populaires (suggestions)
  static Future<List<UserProfile>> getPopularUsers({
    int limit = 10,
    String? category,
  }) async {
    try {
      final cacheKey = 'popular_users_${category ?? 'all'}_$limit';
      final cachedUsers = await CacheService.getCachedUsers(cacheKey);

      if (cachedUsers != null) {
        return cachedUsers.map((json) => UserProfile.fromJson(json)).toList();
      }

      dynamic query = _supabase
          .from('users')
          .select('''
            id,
            email,
            username,
            full_name,
            avatar,
            bio,
            followers,
            following,
            total_likes,
            total_gifts,
            tokens_balance,
            created_at,
            last_seen,
            is_verified,
            is_moderator,
            preferences
          ''')
          .order('followers', ascending: false)
          .limit(limit);

      // Filtrer par catégorie si spécifiée
      if (category != null && category != 'all') {
        query = query.eq('category', category);
      }

      final response = await query;
      final users = (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();

      // Mettre en cache
      await CacheService.cacheUsers(
        users.map((user) => user.toJson()).toList(),
        cacheKey,
      );

      return users;
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs populaires: $e');
      return [];
    }
  }

  /// Rechercher des utilisateurs récemment actifs
  static Future<List<UserProfile>> getRecentlyActiveUsers({
    int limit = 10,
    Duration? within,
  }) async {
    try {
      final timeLimit = within ?? Duration(hours: 24);
      final cutoffTime = DateTime.now().subtract(timeLimit);

      final cacheKey = 'recent_users_${timeLimit.inHours}h_$limit';
      final cachedUsers = await CacheService.getCachedUsers(cacheKey);

      if (cachedUsers != null) {
        return cachedUsers.map((json) => UserProfile.fromJson(json)).toList();
      }

      final response = await _supabase
          .from('users')
          .select('''
            id,
            email,
            username,
            full_name,
            avatar,
            bio,
            followers,
            following,
            total_likes,
            total_gifts,
            tokens_balance,
            created_at,
            last_seen,
            is_verified,
            is_moderator,
            preferences
          ''')
          .gte('last_seen', cutoffTime.toIso8601String())
          .order('last_seen', ascending: false)
          .limit(limit);

      final users = (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();

      // Mettre en cache
      await CacheService.cacheUsers(
        users.map((user) => user.toJson()).toList(),
        cacheKey,
      );

      return users;
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs récents: $e');
      return [];
    }
  }

  /// Obtenir des suggestions d'utilisateurs basées sur les follows
  static Future<List<UserProfile>> getSuggestedUsers({int limit = 10}) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      final cacheKey = 'suggested_${currentUser.id}_$limit';
      final cachedUsers = await CacheService.getCachedUsers(cacheKey);

      if (cachedUsers != null) {
        return cachedUsers.map((json) => UserProfile.fromJson(json)).toList();
      }

      // Récupérer les utilisateurs suivis par les personnes que je suis
      final response = await _supabase.rpc(
        'get_suggested_users',
        params: {'current_user_id': currentUser.id, 'limit_count': limit},
      );

      final users = (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();

      // Mettre en cache
      await CacheService.cacheUsers(
        users.map((user) => user.toJson()).toList(),
        cacheKey,
      );

      return users;
    } catch (e) {
      print('Erreur lors de la récupération des suggestions: $e');
      return [];
    }
  }

  /// Rechercher des utilisateurs par proximité géographique (si disponible)
  static Future<List<UserProfile>> getNearbyUsers({
    required double latitude,
    required double longitude,
    double radiusKm = 50.0,
    int limit = 20,
  }) async {
    try {
      final cacheKey = 'nearby_${latitude}_${longitude}_${radiusKm}_$limit';
      final cachedUsers = await CacheService.getCachedUsers(
        cacheKey,
        maxAge: Duration(
          minutes: 10,
        ), // Cache plus court pour la géolocalisation
      );

      if (cachedUsers != null) {
        return cachedUsers.map((json) => UserProfile.fromJson(json)).toList();
      }

      final response = await _supabase.rpc(
        'get_nearby_users',
        params: {
          'lat': latitude,
          'lng': longitude,
          'radius_km': radiusKm,
          'limit_count': limit,
        },
      );

      final users = (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();

      // Mettre en cache
      await CacheService.cacheUsers(
        users.map((user) => user.toJson()).toList(),
        cacheKey,
      );

      return users;
    } catch (e) {
      print('Erreur lors de la recherche d\'utilisateurs à proximité: $e');
      return [];
    }
  }

  /// Obtenir les statistiques de recherche
  static Future<Map<String, int>> getSearchStats() async {
    try {
      final response = await _supabase.rpc('get_search_stats');
      return Map<String, int>.from(response);
    } catch (e) {
      print('Erreur lors de la récupération des stats de recherche: $e');
      return {'total_users': 0, 'verified_users': 0, 'active_users': 0};
    }
  }
}
