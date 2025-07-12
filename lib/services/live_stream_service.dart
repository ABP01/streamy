import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/live_stream.dart';

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
    String? category,
    String? searchQuery,
    LiveStreamSort sort = LiveStreamSort.viewerCount,
  }) async {
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

    if (category != null && category != 'Tous') {
      query = query.eq('category', category);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or(
        'title.ilike.%$searchQuery%,description.ilike.%$searchQuery%',
      );
    }

    query = query
        .order(sortFieldMap[sort]!, ascending: false)
        .range(offset, offset + limit - 1);

    final response = await query;

    return (response as List).map((json) {
      final user = json['users'];
      if (user != null) {
        json['host_name'] = user['full_name'] ?? user['username'];
        json['host_avatar'] = user['avatar'];
      }
      return LiveStream.fromJson(json);
    }).toList();
  }

  // --- Créer un nouveau live ---
  Future<LiveStream> createLiveStream({
    required String title,
    required String hostId,
    String? description,
    String? category,
    List<String>? tags,
    bool isPrivate = false,
    int maxViewers = 1000,
  }) async {
    final id = _uuid.v4();
    final response = await _supabase
        .from('lives')
        .insert({
          'id': id,
          'title': title,
          'description': description,
          'host_id': hostId,
          'category': category ?? 'Général',
          'tags': tags,
          'is_private': isPrivate,
          'max_viewers': maxViewers,
          'is_live': true,
          'started_at': DateTime.now().toIso8601String(),
          'agora_channel_id': 'live_$id',
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
    await _supabase
        .from('lives')
        .update({
          'is_live': false,
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', liveId);

    await _cleanupLiveSession(liveId);
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
        .or(
          'title.ilike.%$query%,description.ilike.%$query%,category.ilike.%$query%',
        )
        .order('viewer_count', ascending: false)
        .limit(limit);

    return (response as List).map((json) {
      final user = json['users'];
      if (user != null) {
        json['host_name'] = user['full_name'] ?? user['username'];
        json['host_avatar'] = user['avatar'];
      }
      return LiveStream.fromJson(json);
    }).toList();
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

  // --- Méthodes internes ---
  Future<void> _cleanupLiveSession(String liveId) async {
    try {
      await _supabase.from('live_viewers').delete().eq('live_id', liveId);
      await _supabase
          .from('live_messages')
          .update({'is_archived': true})
          .eq('live_id', liveId);
    } catch (e) {
      print('Erreur nettoyage session : $e');
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
}

// --- Enumération ---
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
