import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class MessagingService {
  static final _supabase = Supabase.instance.client;

  /// Envoyer un message privé
  static Future<PrivateMessage> sendPrivateMessage({
    required String recipientId,
    required String content,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Utilisateur non authentifié');
    }

    try {
      // Obtenir ou créer la conversation
      final conversationId = await _getOrCreateConversation(
        currentUser.id,
        recipientId,
      );

      // Insérer le message
      final response = await _supabase
          .from('private_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': currentUser.id,
            'recipient_id': recipientId,
            'content': content,
            'media_url': mediaUrl,
            'media_type': mediaType,
            'sent_at': DateTime.now().toIso8601String(),
          })
          .select('''
            *,
            sender:users!sender_id(id, username, full_name, avatar),
            recipient:users!recipient_id(id, username, full_name, avatar)
          ''')
          .single();

      // Mettre à jour la conversation
      await _updateConversationLastMessage(conversationId, content);

      return PrivateMessage.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du message: $e');
    }
  }

  /// Obtenir les messages d'une conversation
  static Future<List<PrivateMessage>> getConversationMessages({
    required String otherUserId,
    int limit = 50,
    int offset = 0,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Utilisateur non authentifié');
    }

    try {
      // Récupérer la conversation
      final conversation = await _getConversation(currentUser.id, otherUserId);
      if (conversation == null) return [];

      final response = await _supabase
          .from('private_messages')
          .select('''
            *,
            sender:users!sender_id(id, username, full_name, avatar),
            recipient:users!recipient_id(id, username, full_name, avatar)
          ''')
          .eq('conversation_id', conversation.id)
          .order('sent_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => PrivateMessage.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des messages: $e');
    }
  }

  /// Obtenir toutes les conversations de l'utilisateur
  static Future<List<Conversation>> getUserConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Utilisateur non authentifié');
    }

    try {
      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            participant1:users!participant1_id(id, username, full_name, avatar),
            participant2:users!participant2_id(id, username, full_name, avatar)
          ''')
          .or(
            'participant1_id.eq.${currentUser.id},participant2_id.eq.${currentUser.id}',
          )
          .order('last_message_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((json) {
        // Calculer le nombre de messages non lus
        final conversation = Conversation.fromJson(json);
        return conversation;
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des conversations: $e');
    }
  }

  /// Marquer les messages comme lus
  static Future<void> markMessagesAsRead({
    required String conversationId,
    required String senderId,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase
          .from('private_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .eq('sender_id', senderId)
          .eq('recipient_id', currentUser.id)
          .eq('is_read', false);
    } catch (e) {
      print('Erreur lors du marquage comme lu: $e');
    }
  }

  /// Stream des messages en temps réel pour une conversation
  static Stream<List<PrivateMessage>> getConversationMessagesStream({
    required String otherUserId,
  }) {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Note: Pour le stream, on pourrait utiliser la conversation_id
    // mais ici on filtre directement par participants
    return _supabase
        .from('private_messages')
        .stream(primaryKey: ['id'])
        .order('sent_at', ascending: false)
        .map((data) {
          return data
              .where((json) {
                final senderId = json['sender_id'] as String;
                final recipientId = json['recipient_id'] as String;
                return (senderId == currentUser.id &&
                        recipientId == otherUserId) ||
                    (senderId == otherUserId && recipientId == currentUser.id);
              })
              .map((json) => PrivateMessage.fromJson(json))
              .toList();
        });
  }

  /// Stream des conversations en temps réel
  static Stream<List<Conversation>> getConversationsStream() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((data) {
          return data
              .where((json) {
                final participant1Id = json['participant1_id'] as String;
                final participant2Id = json['participant2_id'] as String;
                return participant1Id == currentUser.id ||
                    participant2Id == currentUser.id;
              })
              .map((json) => Conversation.fromJson(json))
              .toList();
        });
  }

  /// Supprimer un message
  static Future<void> deleteMessage(String messageId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase
          .from('private_messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', currentUser.id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du message: $e');
    }
  }

  /// Bloquer un utilisateur
  static Future<void> blockUser(String userId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase.from('user_blocks').insert({
        'blocker_id': currentUser.id,
        'blocked_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors du blocage: $e');
    }
  }

  /// Débloquer un utilisateur
  static Future<void> unblockUser(String userId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', currentUser.id)
          .eq('blocked_id', userId);
    } catch (e) {
      throw Exception('Erreur lors du déblocage: $e');
    }
  }

  /// Vérifier si un utilisateur est bloqué
  static Future<bool> isUserBlocked(String userId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return false;

    try {
      final response = await _supabase
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', currentUser.id)
          .eq('blocked_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Obtenir le nombre de messages non lus
  static Future<int> getUnreadMessageCount() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return 0;

    try {
      final response = await _supabase
          .from('private_messages')
          .select('id')
          .eq('recipient_id', currentUser.id)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // Méthodes privées

  static Future<String> _getOrCreateConversation(
    String user1Id,
    String user2Id,
  ) async {
    // Chercher une conversation existante
    final existing = await _getConversation(user1Id, user2Id);
    if (existing != null) {
      return existing.id;
    }

    // Créer une nouvelle conversation
    final response = await _supabase
        .from('conversations')
        .insert({
          'participant1_id': user1Id,
          'participant2_id': user2Id,
          'created_at': DateTime.now().toIso8601String(),
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  static Future<Conversation?> _getConversation(
    String user1Id,
    String user2Id,
  ) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select('*')
          .or(
            'participant1_id.eq.$user1Id.and.participant2_id.eq.$user2Id,'
            'participant1_id.eq.$user2Id.and.participant2_id.eq.$user1Id',
          )
          .maybeSingle();

      return response != null ? Conversation.fromJson(response) : null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> _updateConversationLastMessage(
    String conversationId,
    String message,
  ) async {
    try {
      await _supabase
          .from('conversations')
          .update({
            'last_message': message,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (e) {
      print('Erreur lors de la mise à jour de la conversation: $e');
    }
  }
}
