import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/live_stream.dart';
import 'agora_backend_service.dart';

// --- Enumération pour trier les lives ---
enum LiveStreamSort { viewerCount, recent, popular }

// --- Modèle pour les stats ---
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
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    return h > 0
        ? '${h}h ${m}m ${s}s'
        : m > 0
        ? '${m}m ${s}s'
        : '${s}s';
  }
}

class LiveStreamService {
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  // --- Enumération pour trier les lives ---
  static const sortFieldMap = {
    LiveStreamSort.viewerCount: 'viewer_count',
    LiveStreamSort.recent: 'started_at',
    LiveStreamSort.popular: 'like_count',
  };

  // --- Récupérer les lives ---
  Future<List<LiveStream>> fetchLiveStreams({
    int limit = 20,
    int offset = 0,
    String? searchQuery,
    LiveStreamSort sort = LiveStreamSort.viewerCount,
  }) async {
    print('🔍 Récupération des lives actifs (limit: $limit, offset: $offset)');

    // Nettoyage préventif des lives "zombies" (anciens de plus de 4 heures)
    await _cleanupOldLives();

    dynamic query = _supabase
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

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('host_name', '%$searchQuery%');
      print('🔍 Recherche appliquée: $searchQuery');
    }

    query = query
        .order(sortFieldMap[sort]!, ascending: false)
        .range(offset, offset + limit - 1);

    final response = await query;

    print('📊 Résultats bruts de la DB: ${(response as List).length} lives');

    final liveStreams = response.map((json) {
      final user = json['users'];
      if (user != null) {
        json['host_name'] = user['full_name'] ?? user['username'];
        json['host_avatar'] = user['avatar'];
      }
      return LiveStream.fromJson(json);
    }).toList();

    // Filtrage supplémentaire pour s'assurer que seuls les vrais lives actifs sont retournés
    final activeLives = liveStreams.where((live) {
      final isActive =
          live.isLive && live.startedAt != null && live.endedAt == null;

      if (!isActive) {
        print(
          '⚠️ Live filtré: ${live.id} (isLive: ${live.isLive}, startedAt: ${live.startedAt}, endedAt: ${live.endedAt})',
        );
      }

      return isActive;
    }).toList();

    print('✅ Lives actifs retournés: ${activeLives.length}');

    return activeLives;
  }

  // --- Interagir avec un live ---
  Future<void> incrementLikeCount(String liveId) async {
    await _supabase.rpc('increment_like_count', params: {'live_id': liveId});
  }

  Future<void> incrementViewerCount(String liveId) async {
    await _supabase.rpc('increment_viewer_count', params: {'live_id': liveId});
  }

  Future<void> decrementViewerCount(String liveId) async {
    await _supabase.rpc('decrement_viewer_count', params: {'live_id': liveId});
  }

  // --- Créer un nouveau live avec token Agora ---
  Future<LiveStream> createLiveStream({required String hostId}) async {
    final id = _uuid.v4();
    // En mode test, utiliser le canal de test d'Agora
    final agoraChannelId = 'live_$id';

    // Générer le token Agora pour l'hôte si nécessaire
    String? agoraToken;
    if (AppConfig.useAgoraToken) {
      agoraToken = await generateAgoraToken(
        liveId: agoraChannelId,
        userId: hostId,
        isHost: true,
      );
    }

    final response = await _supabase
        .from('lives')
        .insert({
          'id': id,
          'host_id': hostId,
          'is_live': true,
          'started_at': DateTime.now().toIso8601String(),
          'agora_channel_id': agoraChannelId,
          'agora_token': agoraToken,
          'viewer_count': 0,
          'like_count': 0,
          'gift_count': 0,
        })
        .select()
        .single();

    return LiveStream.fromJson(response);
  }

  // --- Mettre fin à un live ---
  Future<void> endLiveStream(String liveId) async {
    print('🔚 Début de la fermeture du live: $liveId');

    try {
      // Étape 1: Marquer le live comme terminé dans la base de données
      print('💾 Mise à jour du statut du live...');
      await _supabase
          .from('lives')
          .update({
            'is_live': false,
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', liveId);

      print('✅ Statut du live mis à jour');

      // Étape 2: Nettoyage de la session (en parallèle pour plus d'efficacité)
      print('🧹 Nettoyage de la session...');
      await _cleanupLiveSession(liveId);

      print('✅ Live fermé avec succès: $liveId');
    } catch (e) {
      print('❌ Erreur lors de la fermeture du live $liveId: $e');

      // Même en cas d'erreur, essayer le nettoyage
      try {
        await _cleanupLiveSession(liveId);
        print('✅ Nettoyage effectué malgré l\'erreur de mise à jour');
      } catch (cleanupError) {
        print('❌ Erreur lors du nettoyage: $cleanupError');
      }

      // Re-lancer l'erreur pour que l'appelant soit informé
      rethrow;
    }
  }

  // --- Rejoindre / quitter un live ---
  Future<void> joinLive(String liveId, String userId) async {
    final existing = await _supabase
        .from('live_viewers')
        .select()
        .eq('live_id', liveId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('live_viewers').insert({
        'live_id': liveId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
      });

      await _supabase.rpc(
        'increment_viewer_count',
        params: {'live_id': liveId},
      );
      await _sendSystemMessage(liveId, '$userId a rejoint le live');
    }
  }

  Future<void> leaveLive(String liveId, String userId) async {
    await _supabase
        .from('live_viewers')
        .delete()
        .eq('live_id', liveId)
        .eq('user_id', userId);

    await _supabase.rpc('decrement_viewer_count', params: {'live_id': liveId});
    await _sendSystemMessage(liveId, '$userId a quitté le live');
  }

  // --- Statistiques live ---
  Future<LiveStats> getLiveStats(String liveId) async {
    final response = await _supabase
        .from('lives')
        .select('viewer_count, like_count, gift_count, started_at')
        .eq('id', liveId)
        .single();

    final activeUsers = await _supabase
        .from('live_viewers')
        .select('user_id')
        .eq('live_id', liveId);

    final messages = await _supabase
        .from('live_messages')
        .select('id')
        .eq('live_id', liveId);

    return LiveStats(
      viewerCount: response['viewer_count'] as int,
      likeCount: response['like_count'] as int,
      giftCount: response['gift_count'] as int,
      messageCount: (messages as List).length,
      duration: DateTime.now().difference(
        DateTime.parse(response['started_at']),
      ),
      activeViewers: (activeUsers as List).length,
    );
  }

  // --- Rechercher des lives ---
  Future<List<LiveStream>> searchLives(String query, {int limit = 20}) async {
    print('🔍 Recherche de lives actifs: "$query"');

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
        .ilike('users.full_name', '%$query%')
        .order('viewer_count', ascending: false)
        .limit(limit);

    print('📊 Résultats de recherche: ${response.length} lives trouvés');

    final liveStreams = response.map((json) {
      final user = json['users'];
      if (user != null) {
        json['host_name'] = user['full_name'] ?? user['username'];
        json['host_avatar'] = user['avatar'];
      }
      return LiveStream.fromJson(json);
    }).toList();

    // Filtrage supplémentaire pour s'assurer que seuls les vrais lives actifs sont retournés
    final activeLives = liveStreams.where((live) {
      final isActive =
          live.isLive && live.startedAt != null && live.endedAt == null;
      return isActive;
    }).toList();

    print('✅ Lives actifs trouvés: ${activeLives.length}');
    return activeLives;
  }

  // --- Watch en temps réel ---
  Stream<List<LiveStream>> watchLiveStreams() {
    return _supabase
        .from('lives')
        .stream(primaryKey: ['id'])
        .eq('is_live', true)
        .order('viewer_count', ascending: false)
        .map((data) => data.map((json) => LiveStream.fromJson(json)).toList());
  }

  Stream<LiveStats> watchLiveStats(String liveId) {
    return _supabase
        .from('lives')
        .stream(primaryKey: ['id'])
        .eq('id', liveId)
        .map((data) {
          if (data.isEmpty) throw Exception('Live non trouvé');
          final live = data.first;
          return LiveStats(
            viewerCount: live['viewer_count'],
            likeCount: live['like_count'],
            giftCount: live['gift_count'],
            messageCount: 0,
            duration: DateTime.now().difference(
              DateTime.parse(live['started_at']),
            ),
            activeViewers: live['viewer_count'],
          );
        });
  }

  // --- Générer un token Agora pour un canal ---
  Future<String> generateAgoraToken({
    required String liveId,
    required String userId,
    bool isHost = false,
  }) async {
    if (!AppConfig.useAgoraToken) {
      return '';
    }
    try {
      if (isHost) {
        final response = await AgoraBackendService.getHostToken(
          liveId: liveId,
          userId: userId,
        );
        return response.token;
      } else {
        final response = await AgoraBackendService.getViewerToken(
          liveId: liveId,
          userId: userId,
        );
        return response.token;
      }
    } catch (e) {
      print('Erreur lors de la récupération du token Agora via backend: $e');
      return '';
    }
  }

  // --- Obtenir un token pour rejoindre un live en tant que spectateur ---
  Future<String> getViewerToken(String liveId, String userId) async {
    try {
      // Si les tokens ne sont pas requis en mode dev, retourner immédiatement
      if (!AppConfig.useAgoraToken) {
        print('Mode sans token activé - retour token vide');
        return '';
      }

      // Récupérer les informations du live
      final response = await _supabase
          .from('lives')
          .select('agora_channel_id, id')
          .eq('id', liveId)
          .single();

      final channelId =
          response['agora_channel_id'] as String? ?? response['id'] as String;

      // Générer un token pour le spectateur
      return generateAgoraToken(
        liveId: channelId,
        userId: userId,
        isHost: false,
      );
    } catch (e) {
      print('Erreur lors de la récupération du token spectateur: $e');

      // En cas d'erreur, retourner un token vide en mode dev
      if (!AppConfig.useAgoraToken) {
        return '';
      }

      // En production, lever l'erreur
      throw e;
    }
  }

  // --- Renouveler le token Agora d'un live ---
  Future<String> renewAgoraToken(
    String liveId,
    String userId, {
    bool isHost = false,
  }) async {
    try {
      final response = await _supabase
          .from('lives')
          .select('agora_channel_id')
          .eq('id', liveId)
          .single();

      final channelId = response['agora_channel_id'] as String;

      final newToken = generateAgoraToken(
        liveId: channelId,
        userId: userId,
        isHost: isHost,
      );

      // Mettre à jour le token dans la base de données si c'est l'hôte
      if (isHost) {
        await _supabase
            .from('lives')
            .update({'agora_token': newToken})
            .eq('id', liveId);
      }

      return newToken;
    } catch (e) {
      print('Erreur lors du renouvellement du token: $e');
      return '';
    }
  }

  // --- Méthodes internes ---
  Future<void> _cleanupLiveSession(String liveId) async {
    print('🧹 Nettoyage de la session live: $liveId');

    try {
      // Exécuter les opérations de nettoyage en parallèle pour plus d'efficacité
      await Future.wait([
        // Supprimer tous les spectateurs du live
        _supabase.from('live_viewers').delete().eq('live_id', liveId),

        // Archiver les messages du live
        _supabase
            .from('live_messages')
            .update({'is_archived': true})
            .eq('live_id', liveId),
      ]);

      print('✅ Session nettoyée avec succès pour le live: $liveId');
    } catch (e) {
      print('❌ Erreur lors du nettoyage de la session $liveId: $e');

      // Tenter un nettoyage individuel en cas d'échec du parallèle
      try {
        print('🔄 Tentative de nettoyage individuel...');

        // Nettoyer les spectateurs
        try {
          await _supabase.from('live_viewers').delete().eq('live_id', liveId);
          print('✅ Spectateurs supprimés');
        } catch (viewerError) {
          print('⚠️ Erreur suppression spectateurs: $viewerError');
        }

        // Archiver les messages
        try {
          await _supabase
              .from('live_messages')
              .update({'is_archived': true})
              .eq('live_id', liveId);
          print('✅ Messages archivés');
        } catch (messageError) {
          print('⚠️ Erreur archivage messages: $messageError');
        }
      } catch (fallbackError) {
        print('❌ Échec du nettoyage de fallback: $fallbackError');
      }
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
      print('Erreur message système : $e');
    }
  }

  // --- Nettoyage automatique des lives "zombies" ---
  Future<void> _cleanupOldLives() async {
    try {
      // Chercher les lives marqués comme actifs mais démarrés il y a plus de 4 heures
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 4));

      final response = await _supabase
          .from('lives')
          .select('id, started_at')
          .eq('is_live', true)
          .lt('started_at', cutoffTime.toIso8601String());

      if (response.isNotEmpty) {
        print('🧹 Nettoyage de ${response.length} lives "zombies" détectés');

        // Marquer ces lives comme terminés
        for (final liveId in response.map((live) => live['id'] as String)) {
          await _supabase
              .from('lives')
              .update({
                'is_live': false,
                'ended_at': DateTime.now().toIso8601String(),
              })
              .eq('id', liveId);
        }

        print('✅ ${response.length} lives "zombies" nettoyés');
      }
    } catch (e) {
      print('⚠️ Erreur lors du nettoyage des lives zombies: $e');
      // Ne pas lever l'erreur pour ne pas bloquer la récupération des lives
    }
  }
}
