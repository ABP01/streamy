import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/live_stream.dart';
import '../config/app_config.dart';

class LiveStreamService {
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  // Récupérer tous les lives actifs avec pagination et filtrage amélioré
  Future<List<LiveStream>> fetchLiveStreams({
    int limit = 20,
    int offset = 0,
    String? category,
    String? searchQuery,
    LiveStreamSort sort = LiveStreamSort.viewerCount,
  }) async {
    var query = _supabase
        .from('lives')
        .select('''
          *,
          users!host_id (
            username,
            full_name,
            avatar,
            is_verified
          )
        ''')
        .eq('is_live', true);

    if (category != null && category != 'Tous') {
      query = query.eq('category', category);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
    }

    // Tri selon le critère choisi
    switch (sort) {
      case LiveStreamSort.viewerCount:
        query = query.order('viewer_count', ascending: false);
        break;
      case LiveStreamSort.recent:
        query = query.order('started_at', ascending: false);
        break;
      case LiveStreamSort.popular:
        query = query.order('like_count', ascending: false);
        break;
    }

    query = query.range(offset, offset + limit - 1);

    try {
      final response = await query;
      
      return (response as List).map((json) {
        // Enrichir avec les données utilisateur
        if (json['users'] != null) {
          json['host_name'] = json['users']['username'] ?? json['users']['full_name'];
          json['host_avatar'] = json['users']['avatar'];
        }
        return LiveStream.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des lives: $e');
    }
  }

  // Créer un nouveau live
  Future<LiveStream> createLiveStream({
    required String title,
    required String hostId,
    String? description,
    String? category,
    List<String>? tags,
    bool isPrivate = false,
    int maxViewers = 1000,
  }) async {
    final liveId = _uuid.v4();
    final agoraChannelId = 'live_$liveId';
    
    try {
      final response = await _supabase.from('lives').insert({
        'id': liveId,
        'title': title,
        'description': description,
        'host_id': hostId,
        'category': category ?? 'Général',
        'tags': tags,
        'is_private': isPrivate,
        'max_viewers': maxViewers,
        'is_live': true,
        'started_at': DateTime.now().toIso8601String(),
        'agora_channel_id': agoraChannelId,
        'viewer_count': 0,
        'like_count': 0,
        'gift_count': 0,
      }).select().single();

      return LiveStream.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la création du live: $e');
    }
  }

  // Mettre à jour un live
  Future<void> updateLiveStream(String liveId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('lives')
          .update(updates)
          .eq('id', liveId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du live: $e');
    }
  }

  // Terminer un live
  Future<void> endLiveStream(String liveId) async {
    try {
      await _supabase.from('lives').update({
        'is_live': false,
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', liveId);
      
      // Nettoyer les sessions actives
      await _cleanupLiveSession(liveId);
    } catch (e) {
      throw Exception('Erreur lors de la fin du live: $e');
    }
  }

  // Rejoindre un live (incrémenter viewer count)
  Future<void> joinLive(String liveId, String userId) async {
    try {
      // Vérifier si l'utilisateur n'est pas déjà connecté
      final existingSession = await _supabase
          .from('live_viewers')
          .select()
          .eq('live_id', liveId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingSession == null) {
        // Ajouter à la table des viewers
        await _supabase.from('live_viewers').insert({
          'live_id': liveId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
        });

        // Incrémenter le compteur
        await _supabase.rpc('increment_viewer_count', params: {'live_id': liveId});
        
        // Envoyer message de système
        await _sendSystemMessage(liveId, '$userId a rejoint le live');
      }
    } catch (e) {
      throw Exception('Erreur lors de la connexion au live: $e');
    }
  }

  // Quitter un live (décrémenter viewer count)
  Future<void> leaveLive(String liveId, String userId) async {
    try {
      // Supprimer de la table des viewers
      await _supabase
          .from('live_viewers')
          .delete()
          .eq('live_id', liveId)
          .eq('user_id', userId);

      // Décrémenter le compteur
      await _supabase.rpc('decrement_viewer_count', params: {'live_id': liveId});
      
      // Envoyer message de système
      await _sendSystemMessage(liveId, '$userId a quitté le live');
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion du live: $e');
    }
  }

  // Obtenir les statistiques d'un live
  Future<LiveStats> getLiveStats(String liveId) async {
    try {
      final response = await _supabase
          .from('lives')
          .select('viewer_count, like_count, gift_count, started_at')
          .eq('id', liveId)
          .single();

      final viewersResponse = await _supabase
          .from('live_viewers')
          .select('user_id')
          .eq('live_id', liveId);

      final messagesCount = await _supabase
          .from('live_messages')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('live_id', liveId);

      return LiveStats(
        viewerCount: response['viewer_count'] as int,
        likeCount: response['like_count'] as int,
        giftCount: response['gift_count'] as int,
        messageCount: messagesCount.count ?? 0,
        duration: DateTime.now().difference(
          DateTime.parse(response['started_at'] as String),
        ),
        activeViewers: (viewersResponse as List).length,
      );
    } catch (e) {
      throw Exception('Erreur lors du chargement des statistiques: $e');
    }
  }

  // Obtenir les lives d'un utilisateur
  Future<List<LiveStream>> getUserLives(String userId, {bool includeEnded = false}) async {
    try {
      var query = _supabase
          .from('lives')
          .select('''
            *,
            users!host_id (
              username,
              full_name,
              avatar
            )
          ''')
          .eq('host_id', userId);

      if (!includeEnded) {
        query = query.eq('is_live', true);
      }

      query = query.order('started_at', ascending: false);

      final response = await query;
      
      return (response as List).map((json) {
        if (json['users'] != null) {
          json['host_name'] = json['users']['username'] ?? json['users']['full_name'];
          json['host_avatar'] = json['users']['avatar'];
        }
        return LiveStream.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des lives utilisateur: $e');
    }
  }

  // Rechercher des lives
  Future<List<LiveStream>> searchLives(String query, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('lives')
          .select('''
            *,
            users!host_id (
              username,
              full_name,
              avatar
            )
          ''')
          .eq('is_live', true)
          .or('title.ilike.%$query%,description.ilike.%$query%,category.ilike.%$query%')
          .order('viewer_count', ascending: false)
          .limit(limit);

      return (response as List).map((json) {
        if (json['users'] != null) {
          json['host_name'] = json['users']['username'] ?? json['users']['full_name'];
          json['host_avatar'] = json['users']['avatar'];
        }
        return LiveStream.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors de la recherche: $e');
    }
  }

  // Méthodes privées
  Future<void> _cleanupLiveSession(String liveId) async {
    try {
      // Supprimer tous les viewers
      await _supabase
          .from('live_viewers')
          .delete()
          .eq('live_id', liveId);

      // Marquer les messages comme archivés
      await _supabase
          .from('live_messages')
          .update({'is_archived': true})
          .eq('live_id', liveId);
    } catch (e) {
      // Log l'erreur mais ne pas faire échouer la fonction principale
      print('Erreur lors du nettoyage de session: $e');
    }
  }

  Future<void> _sendSystemMessage(String liveId, String message) async {
    try {
      await _supabase.from('live_messages').insert({
        'id': _uuid.v4(),
        'live_id': liveId,
        'user_id': 'system',
        'username': 'Système',
        'message': message,
        'type': 'system',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log l'erreur mais ne pas faire échouer la fonction principale
      print('Erreur lors de l\'envoi du message système: $e');
    }
  }

  // Stream pour écouter les changements en temps réel
  Stream<List<LiveStream>> watchLiveStreams() {
    return _supabase
        .from('lives')
        .stream(primaryKey: ['id'])
        .eq('is_live', true)
        .order('viewer_count', ascending: false)
        .map((data) => data.map((json) => LiveStream.fromJson(json)).toList());
  }

  // Stream pour écouter les statistiques d'un live
  Stream<LiveStats> watchLiveStats(String liveId) {
    return _supabase
        .from('lives')
        .stream(primaryKey: ['id'])
        .eq('id', liveId)
        .map((data) {
          if (data.isEmpty) throw Exception('Live non trouvé');
          final live = data.first;
          return LiveStats(
            viewerCount: live['viewer_count'] as int,
            likeCount: live['like_count'] as int,
            giftCount: live['gift_count'] as int,
            messageCount: 0, // À calculer séparément si nécessaire
            duration: DateTime.now().difference(
              DateTime.parse(live['started_at'] as String),
            ),
            activeViewers: live['viewer_count'] as int,
          );
        });
  }
}

// Énumération pour les options de tri
enum LiveStreamSort {
  viewerCount,
  recent,
  popular,
}

// Classe pour les statistiques d'un live
class LiveStats {
  final int viewerCount;
  final int likeCount;
  final int giftCount;
  final int messageCount;
  final Duration duration;
  final int activeViewers;

  LiveStats({
    required this.viewerCount,
    required this.likeCount,
    required this.giftCount,
    required this.messageCount,
    required this.duration,
    required this.activeViewers,
  });

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
            is_verified
          )
        ''')
        .eq('is_live', true)
        .order('viewer_count', ascending: false)
        .order('started_at', ascending: false);

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }

    final response = await query.range(offset, offset + limit - 1);
    
    return (response as List).map((json) {
      // Merge user data into live stream data
      final userData = json['users'] as Map<String, dynamic>?;
      if (userData != null) {
        json['host_name'] = userData['full_name'] ?? userData['username'];
        json['host_avatar'] = userData['avatar'];
      }
      return LiveStream.fromJson(json);
    }).toList();
  }

  // Créer un nouveau live
  static Future<LiveStream> createLiveStream({
    required String title,
    String? description,
    String? category,
    List<String>? tags,
    bool isPrivate = false,
    int maxViewers = 1000,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    final liveData = {
      'title': title,
      'description': description,
      'host_id': user.id,
      'category': category,
      'tags': tags,
      'is_live': true,
      'is_private': isPrivate,
      'max_viewers': maxViewers,
      'started_at': DateTime.now().toIso8601String(),
      'viewer_count': 0,
      'like_count': 0,
      'gift_count': 0,
    };

    final response = await _supabase
        .from('lives')
        .insert(liveData)
        .select()
        .single();

    return LiveStream.fromJson(response);
  }

  // Terminer un live
  static Future<void> endLiveStream(String liveId) async {
    await _supabase
        .from('lives')
        .update({
          'is_live': false,
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', liveId);
  }

  // Rejoindre un live (incrémenter viewer_count)
  static Future<void> joinLive(String liveId) async {
    await _supabase.rpc('increment_viewer_count', params: {'live_id': liveId});
  }

  // Quitter un live (décrémenter viewer_count)
  static Future<void> leaveLive(String liveId) async {
    await _supabase.rpc('decrement_viewer_count', params: {'live_id': liveId});
  }

  // Obtenir les statistiques d'un live
  static Future<Map<String, dynamic>> getLiveStats(String liveId) async {
    final response = await _supabase
        .from('lives')
        .select('viewer_count, like_count, gift_count, started_at')
        .eq('id', liveId)
        .single();

    return response;
  }

  // Stream des updates en temps réel pour un live
  static Stream<LiveStream> getLiveUpdates(String liveId) {
    return _supabase
        .from('lives')
        .stream(primaryKey: ['id'])
        .eq('id', liveId)
        .map((data) => LiveStream.fromJson(data.first));
  }

  // Mettre à jour les métadonnées d'un live
  static Future<void> updateLiveMetadata(
    String liveId,
    Map<String, dynamic> metadata,
  ) async {
    await _supabase
        .from('lives')
        .update({'metadata': metadata})
        .eq('id', liveId);
  }

  // Signaler un live
  static Future<void> reportLive(String liveId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    await _supabase.from('reports').insert({
      'live_id': liveId,
      'reporter_id': user.id,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Bloquer un utilisateur dans un live
  static Future<void> blockUserFromLive(String liveId, String userId) async {
    await _supabase.from('live_blocks').insert({
      'live_id': liveId,
      'blocked_user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Rechercher des lives
  static Future<List<LiveStream>> searchLiveStreams(String query) async {
    final response = await _supabase
        .from('lives')
        .select('''
          *,
          users!host_id (
            username,
            full_name,
            avatar,
            is_verified
          )
        ''')
        .eq('is_live', true)
        .or('title.ilike.%$query%,description.ilike.%$query%')
        .order('viewer_count', ascending: false)
        .limit(20);

    return (response as List).map((json) {
      final userData = json['users'] as Map<String, dynamic>?;
      if (userData != null) {
        json['host_name'] = userData['full_name'] ?? userData['username'];
        json['host_avatar'] = userData['avatar'];
      }
      return LiveStream.fromJson(json);
    }).toList();
  }

  // Obtenir les lives d'un utilisateur spécifique
  static Future<List<LiveStream>> getUserLiveStreams(
    String userId, {
    bool onlyActive = false,
    int limit = 10,
  }) async {
    var query = _supabase
        .from('lives')
        .select('*')
        .eq('host_id', userId)
        .order('started_at', ascending: false)
        .limit(limit);

    if (onlyActive) {
      query = query.eq('is_live', true);
    }

    final response = await query;
    return (response as List).map((json) => LiveStream.fromJson(json)).toList();
  }
}
