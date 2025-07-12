import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/live_stream.dart';
import '../config/app_config.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  // Envoyer un message avec gestion avancée
  Future<LiveStreamMessage> sendMessage({
    required String liveId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    if (content.length > AppConfig.maxMessageLength) {
      throw Exception('Message trop long (max ${AppConfig.maxMessageLength} caractères)');
    }

    // Vérifier le cooldown
    final lastMessage = await _getLastUserMessage(liveId, user.id);
    if (lastMessage != null) {
      final timeDiff = DateTime.now().difference(lastMessage.createdAt);
      if (timeDiff.inSeconds < AppConfig.messageCooldownSeconds) {
        throw Exception('Attendez ${AppConfig.messageCooldownSeconds} secondes avant d\'envoyer un autre message');
      }
    }

    // Obtenir les infos utilisateur
    final userProfile = await _getUserProfile(user.id);
    
    try {
      final messageId = _uuid.v4();
      final message = LiveStreamMessage(
        id: messageId,
        liveId: liveId,
        userId: user.id,
        username: userProfile['username'] ?? userProfile['full_name'] ?? 'Utilisateur',
        userAvatar: userProfile['avatar'],
        message: content,
        createdAt: DateTime.now(),
        type: type,
        metadata: metadata,
      );

      await _supabase.from('live_messages').insert(message.toJson());

      return message;
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du message: $e');
    }
  }

  // Récupérer les messages d'un live avec pagination
  Future<List<LiveStreamMessage>> getMessages({
    required String liveId,
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      var query = _supabase
          .from('live_messages')
          .select()
          .eq('live_id', liveId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final response = await query;
      
      return (response as List)
          .map((json) => LiveStreamMessage.fromJson(json))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des messages: $e');
    }
  }

  // Stream des messages en temps réel
  Stream<LiveStreamMessage> watchMessages(String liveId) {
    return _supabase
        .from('live_messages')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .order('created_at', ascending: true)
        .map((data) => data.map((json) => LiveStreamMessage.fromJson(json)))
        .expand((messages) => messages);
  }

  // Supprimer un message (modérateurs/host seulement)
  Future<void> deleteMessage(String messageId, String userId) async {
    try {
      // Vérifier les permissions
      final canDelete = await _canDeleteMessage(messageId, userId);
      if (!canDelete) {
        throw Exception('Permission refusée');
      }

      await _supabase
          .from('live_messages')
          .delete()
          .eq('id', messageId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du message: $e');
    }
  }

  // Envoyer un message de réaction (like, gift, etc.)
  Future<void> sendReaction({
    required String liveId,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    try {
      await sendMessage(
        liveId: liveId,
        content: '',
        type: _getMessageTypeFromString(type),
        metadata: {
          'reaction_type': type,
          ...?data,
        },
      );
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi de la réaction: $e');
    }
  }

  // Signaler un message
  Future<void> reportMessage({
    required String messageId,
    required String reason,
    String? details,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    try {
      await _supabase.from('message_reports').insert({
        'id': _uuid.v4(),
        'message_id': messageId,
        'reporter_id': user.id,
        'reason': reason,
        'details': details,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors du signalement: $e');
    }
  }

  // Obtenir les statistiques du chat
  Future<ChatStats> getChatStats(String liveId) async {
    try {
      final totalMessages = await _supabase
          .from('live_messages')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('live_id', liveId);

      final activeUsers = await _supabase
          .from('live_messages')
          .select('user_id')
          .eq('live_id', liveId)
          .gte('created_at', DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String());

      final uniqueUsers = (activeUsers as List)
          .map((msg) => msg['user_id'])
          .toSet()
          .length;

      return ChatStats(
        totalMessages: totalMessages.count ?? 0,
        activeUsers: uniqueUsers,
        messagesPerMinute: await _getMessagesPerMinute(liveId),
      );
    } catch (e) {
      throw Exception('Erreur lors du chargement des statistiques: $e');
    }
  }

  // Méthodes privées
  Future<LiveStreamMessage?> _getLastUserMessage(String liveId, String userId) async {
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
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('username, full_name, avatar, is_verified, is_moderator')
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      return {'username': 'Utilisateur', 'full_name': 'Utilisateur'};
    }
  }

  Future<bool> _canDeleteMessage(String messageId, String userId) async {
    try {
      // Récupérer le message
      final message = await _supabase
          .from('live_messages')
          .select('user_id, live_id')
          .eq('id', messageId)
          .single();

      // L'utilisateur peut supprimer son propre message
      if (message['user_id'] == userId) return true;

      // Vérifier si l'utilisateur est modérateur
      final userProfile = await _getUserProfile(userId);
      if (userProfile['is_moderator'] == true) return true;

      // Vérifier si l'utilisateur est le host du live
      final live = await _supabase
          .from('lives')
          .select('host_id')
          .eq('id', message['live_id'])
          .single();

      return live['host_id'] == userId;
    } catch (e) {
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
      final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
      final response = await _supabase
          .from('live_messages')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('live_id', liveId)
          .gte('created_at', oneMinuteAgo.toIso8601String());

      return (response.count ?? 0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  // Filtrage et modération automatique
  Future<bool> _isMessageAppropriate(String content) async {
    // TODO: Implémenter la modération automatique
    // - Filtrage des mots inappropriés
    // - Détection de spam
    // - Vérification de liens malveillants
    return true;
  }

  // Gestion des emojis personnalisés et reactions
  Future<List<String>> getAvailableEmojis(String liveId) async {
    try {
      final response = await _supabase
          .from('live_emojis')
          .select('emoji_code')
          .eq('live_id', liveId);

      return (response as List).map((emoji) => emoji['emoji_code'] as String).toList();
    } catch (e) {
      return [];
    }
  }
}

// Classe pour les statistiques du chat
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
    final userProfile = await _getUserProfile(user.id);
    
    final messageData = {
      'live_id': liveId,
      'user_id': user.id,
      'user_name': userProfile?.displayName ?? 'Anonyme',
      'user_avatar': userProfile?.avatar,
      'content': content,
      'type': type.name,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('messages')
        .insert(messageData)
        .select()
        .single();

    return Message.fromJson(response);
  }

  // Stream des messages en temps réel
  static Stream<List<Message>> getMessagesStream(String liveId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .order('created_at')
        .map((data) => data.map((json) => Message.fromJson(json)).toList());
  }

  // Obtenir l'historique des messages
  static Future<List<Message>> getMessageHistory(
    String liveId, {
    int limit = 50,
    DateTime? before,
  }) async {
    var query = _supabase
        .from('messages')
        .select('*')
        .eq('live_id', liveId)
        .order('created_at', ascending: false)
        .limit(limit);

    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final response = await query;
    return (response as List)
        .map((json) => Message.fromJson(json))
        .toList()
        .reversed
        .toList();
  }

  // Supprimer un message (modération)
  static Future<void> deleteMessage(String messageId) async {
    await _supabase
        .from('messages')
        .delete()
        .eq('id', messageId);
  }

  // Modérer un message
  static Future<void> moderateMessage(String messageId, bool isModerated) async {
    await _supabase
        .from('messages')
        .update({'is_moderated': isModerated})
        .eq('id', messageId);
  }

  // Envoyer une réaction
  static Future<Reaction> sendReaction({
    required String liveId,
    required ReactionType type,
    double? positionX,
    double? positionY,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    final userProfile = await _getUserProfile(user.id);
    
    final reactionData = {
      'live_id': liveId,
      'user_id': user.id,
      'user_name': userProfile?.displayName ?? 'Anonyme',
      'type': type.name,
      'position_x': positionX,
      'position_y': positionY,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('reactions')
        .insert(reactionData)
        .select()
        .single();

    // Incrémenter le compteur de likes du live
    if (type == ReactionType.like) {
      await _supabase.rpc('increment_like_count', params: {'live_id': liveId});
    }

    return Reaction.fromJson(response);
  }

  // Stream des réactions en temps réel
  static Stream<List<Reaction>> getReactionsStream(String liveId) {
    return _supabase
        .from('reactions')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .gte('created_at', DateTime.now().subtract(const Duration(seconds: 10)).toIso8601String())
        .map((data) => data.map((json) => Reaction.fromJson(json)).toList());
  }

  // Méthodes privées
  static Future<Message?> _getLastUserMessage(String liveId, String userId) async {
    final response = await _supabase
        .from('messages')
        .select('*')
        .eq('live_id', liveId)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (response.isEmpty) return null;
    return Message.fromJson(response.first);
  }

  static Future<UserProfile?> _getUserProfile(String userId) async {
    final response = await _supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single();

    return UserProfile.fromJson(response);
  }
}
