import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'cache_service.dart';

class FollowService {
  static final _supabase = Supabase.instance.client;

  // === FOLLOW/UNFOLLOW ===

  /// Suivre un utilisateur
  static Future<bool> followUser(String targetUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non authentifié');

      // Vérifier si on ne suit pas déjà cette personne
      final existing = await _supabase
          .from('user_follows')
          .select()
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId)
          .maybeSingle();

      if (existing != null) {
        return true; // Déjà suivi
      }

      // Ajouter le follow
      await _supabase.from('user_follows').insert({
        'follower_id': currentUser.id,
        'following_id': targetUserId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Incrémenter le compteur de followers
      await _supabase.rpc(
        'increment_follower_count',
        params: {'user_id': targetUserId},
      );

      // Incrémenter le compteur de following pour l'utilisateur courant
      await _supabase.rpc(
        'increment_following_count',
        params: {'user_id': currentUser.id},
      );

      // Effacer le cache des utilisateurs
      await CacheService.clearUserCache(targetUserId);
      await CacheService.clearUserCache(currentUser.id);

      // Envoyer une notification (optionnel)
      await _sendFollowNotification(currentUser.id, targetUserId);

      return true;
    } catch (e) {
      print('Erreur lors du follow: $e');
      return false;
    }
  }

  /// Ne plus suivre un utilisateur
  static Future<bool> unfollowUser(String targetUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non authentifié');

      // Supprimer le follow
      await _supabase
          .from('user_follows')
          .delete()
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId);

      // Décrémenter le compteur de followers
      await _supabase.rpc(
        'decrement_follower_count',
        params: {'user_id': targetUserId},
      );

      // Décrémenter le compteur de following pour l'utilisateur courant
      await _supabase.rpc(
        'decrement_following_count',
        params: {'user_id': currentUser.id},
      );

      // Effacer le cache des utilisateurs
      await CacheService.clearUserCache(targetUserId);
      await CacheService.clearUserCache(currentUser.id);

      return true;
    } catch (e) {
      print('Erreur lors de l\'unfollow: $e');
      return false;
    }
  }

  /// Vérifier si on suit un utilisateur
  static Future<bool> isFollowing(String targetUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      final result = await _supabase
          .from('user_follows')
          .select()
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      return false;
    }
  }

  // === LISTES DE FOLLOWS ===

  /// Obtenir la liste des followers d'un utilisateur
  static Future<List<UserProfile>> getUserFollowers(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('user_follows')
          .select('''
            follower_id,
            users!follower_id (
              id, username, full_name, avatar, is_verified
            )
          ''')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((item) {
        final user = item['users'];
        return UserProfile.fromJson(user);
      }).toList();
    } catch (e) {
      print('Erreur récupération followers: $e');
      return [];
    }
  }

  /// Obtenir la liste des utilisateurs suivis
  static Future<List<UserProfile>> getUserFollowing(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('user_follows')
          .select('''
            following_id,
            users!following_id (
              id, username, full_name, avatar, is_verified
            )
          ''')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((item) {
        final user = item['users'];
        return UserProfile.fromJson(user);
      }).toList();
    } catch (e) {
      print('Erreur récupération following: $e');
      return [];
    }
  }

  // === RECHERCHE D'UTILISATEURS ===

  /// Rechercher des utilisateurs
  static Future<List<UserProfile>> searchUsers(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      final response = await _supabase
          .from('users')
          .select('*')
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .order('followers', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur recherche utilisateurs: $e');
      return [];
    }
  }

  /// Suggestions d'utilisateurs à suivre
  static Future<List<UserProfile>> getSuggestedUsers({int limit = 10}) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      // Récupérer les utilisateurs les plus populaires qu'on ne suit pas encore
      final response = await _supabase.rpc(
        'get_suggested_users',
        params: {'current_user_id': currentUser.id, 'limit_count': limit},
      );

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur suggestions utilisateurs: $e');

      // Fallback: récupérer les utilisateurs les plus populaires
      final response = await _supabase
          .from('users')
          .select('*')
          .order('followers', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    }
  }

  // === STATISTIQUES ===

  /// Obtenir les statistiques de follow d'un utilisateur
  static Future<Map<String, int>> getFollowStats(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('followers, following')
          .eq('id', userId)
          .single();

      return {
        'followers': response['followers'] as int? ?? 0,
        'following': response['following'] as int? ?? 0,
      };
    } catch (e) {
      return {'followers': 0, 'following': 0};
    }
  }

  /// Obtenir la liste des amis mutuels
  static Future<List<UserProfile>> getMutualFollows(
    String targetUserId, {
    int limit = 10,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      final response = await _supabase.rpc(
        'get_mutual_follows',
        params: {
          'user1_id': currentUser.id,
          'user2_id': targetUserId,
          'result_limit': limit,
        },
      );

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur amis mutuels: $e');
      return [];
    }
  }

  // === MÉTHODES PRIVÉES ===

  static Future<void> _sendFollowNotification(
    String followerId,
    String targetUserId,
  ) async {
    try {
      // Récupérer les infos du follower
      final followerProfile = await _supabase
          .from('users')
          .select('username, full_name, avatar')
          .eq('id', followerId)
          .single();

      // Envoyer la notification
      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'type': 'new_follower',
        'title': 'Nouveau follower',
        'message':
            '${followerProfile['full_name'] ?? followerProfile['username']} vous suit maintenant',
        'data': {
          'follower_id': followerId,
          'follower_username': followerProfile['username'],
          'follower_avatar': followerProfile['avatar'],
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Erreur envoi notification: $e');
    }
  }
}
