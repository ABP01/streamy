import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/live_stream.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  /// Envoyer un message dans un live
  Future<LiveStreamMessage> sendMessage({
    required String liveId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    if (content.length > AppConfig.maxMessageLength) {
      throw Exception(
        'Message trop long (max ${AppConfig.maxMessageLength} caractères)',
      );
    }

    // Vérifier le cooldown
    final lastMessage = await _getLastUserMessage(liveId, user.id);
    if (lastMessage != null) {
      final timeDiff = DateTime.now().difference(lastMessage.createdAt);
      if (timeDiff.inSeconds < AppConfig.messageCooldownSeconds) {
        throw Exception(
          'Attendez ${AppConfig.messageCooldownSeconds} secondes avant d\'envoyer un autre message',
        );
      }
    }

    final userProfile = await _getUserProfile(user.id);

    final message = LiveStreamMessage(
      id: _uuid.v4(),
      liveId: liveId,
      userId: user.id,
      username:
          userProfile['username'] ?? userProfile['full_name'] ?? 'Utilisateur',
      userAvatar: userProfile['avatar'],
      message: content,
      createdAt: DateTime.now(),
      type: type,
      metadata: metadata,
    );

    await _supabase.from('live_messages').insert(message.toJson());
    return message;
  }

  /// Récupérer les messages avec pagination
  Future<List<LiveStreamMessage>> getMessages({
    required String liveId,
    int limit = 50,
    DateTime? before,
  }) async {
    dynamic query = _supabase
        .from('live_messages')
        .select()
        .eq('live_id', liveId);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }
    query = query.order('created_at', ascending: false).limit(limit);

    final response = await query;

    return (response as List)
        .map((json) => LiveStreamMessage.fromJson(json))
        .toList()
        .reversed
        .toList();
  }

  /// Écouter les nouveaux messages en temps réel
  Stream<LiveStreamMessage> watchMessages(String liveId) {
    return _supabase
        .from('live_messages')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .order('created_at')
        .map((data) => data.map((json) => LiveStreamMessage.fromJson(json)))
        .expand((messages) => messages);
  }

  /// Supprimer un message si autorisé
  Future<void> deleteMessage(String messageId, String userId) async {
    final canDelete = await _canDeleteMessage(messageId, userId);
    if (!canDelete) throw Exception('Permission refusée');

    await _supabase.from('live_messages').delete().eq('id', messageId);
  }

  /// Envoyer une réaction spéciale
  Future<void> sendReaction({
    required String liveId,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    await sendMessage(
      liveId: liveId,
      content: '',
      type: _getMessageTypeFromString(type),
      metadata: {'reaction_type': type, ...?data},
    );
  }

  /// Signaler un message
  Future<void> reportMessage({
    required String messageId,
    required String reason,
    String? details,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    await _supabase.from('message_reports').insert({
      'id': _uuid.v4(),
      'message_id': messageId,
      'reporter_id': user.id,
      'reason': reason,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Statistiques du chat
  Future<ChatStats> getChatStats(String liveId) async {
    final totalMessages = await _supabase
        .from('live_messages')
        .select('id')
        .eq('live_id', liveId);

    final recentUsers = await _supabase
        .from('live_messages')
        .select('user_id')
        .gte(
          'created_at',
          DateTime.now()
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
        )
        .eq('live_id', liveId);

    final uniqueUsers = (recentUsers as List)
        .map((msg) => msg['user_id'])
        .toSet()
        .length;

    return ChatStats(
      totalMessages: totalMessages.length,
      activeUsers: uniqueUsers,
      messagesPerMinute: await _getMessagesPerMinute(liveId),
    );
  }

  /// Récupérer les emojis personnalisés disponibles
  Future<List<String>> getAvailableEmojis(String liveId) async {
    try {
      final response = await _supabase
          .from('live_emojis')
          .select('emoji_code')
          .eq('live_id', liveId);

      return (response as List).map((e) => e['emoji_code'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------
  // MÉTHODES PRIVÉES
  // ---------------------------

  Future<LiveStreamMessage?> _getLastUserMessage(
    String liveId,
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('live_messages')
          .select()
          .eq('live_id', liveId)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response != null ? LiveStreamMessage.fromJson(response) : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    try {
      return await _supabase
          .from('users')
          .select('username, full_name, avatar, is_verified, is_moderator')
          .eq('id', userId)
          .single();
    } catch (_) {
      return {};
    }
  }

  Future<bool> _canDeleteMessage(String messageId, String userId) async {
    try {
      final message = await _supabase
          .from('live_messages')
          .select('user_id, live_id')
          .eq('id', messageId)
          .single();

      if (message['user_id'] == userId) return true;

      final profile = await _getUserProfile(userId);
      if (profile['is_moderator'] == true) return true;

      final live = await _supabase
          .from('lives')
          .select('host_id')
          .eq('id', message['live_id'])
          .single();

      return live['host_id'] == userId;
    } catch (_) {
      return false;
    }
  }

  MessageType _getMessageTypeFromString(String type) {
    switch (type) {
      case 'gift':
        return MessageType.gift;
      case 'like':
        return MessageType.like;
      case 'system':
        return MessageType.system;
      case 'join':
        return MessageType.join;
      case 'leave':
        return MessageType.leave;
      default:
        return MessageType.text;
    }
  }

  Future<double> _getMessagesPerMinute(String liveId) async {
    try {
      final response = await _supabase
          .from('live_messages')
          .select('id')
          .gte(
            'created_at',
            DateTime.now()
                .subtract(const Duration(minutes: 1))
                .toIso8601String(),
          )
          .eq('live_id', liveId);

      return response.length.toDouble();
    } catch (_) {
      return 0.0;
    }
  }
}

// ---------------------------
// CLASSE STATS CHAT
// ---------------------------
class ChatStats {
  final int totalMessages;
  final int activeUsers;
  final double messagesPerMinute;

  ChatStats({
    required this.totalMessages,
    required this.activeUsers,
    required this.messagesPerMinute,
  });
}
