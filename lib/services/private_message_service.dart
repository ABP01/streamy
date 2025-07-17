import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class PrivateMessageService {
  static final _supabase = Supabase.instance.client;

  // === ENVOI DE MESSAGES ===

  /// Envoyer un message privé
  static Future<PrivateMessage?> sendMessage({
    required String recipientId,
    required String content,
    String? mediaUrl,
    String? mediaType,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non authentifié');

      if (content.trim().isEmpty && mediaUrl == null) {
        throw Exception('Le message ne peut pas être vide');
      }

      // Créer ou récupérer la conversation
      final conversationId = await _getOrCreateConversation(
        currentUser.id,
        recipientId,
      );

      // Insérer le message
      final messageData = {
        'conversation_id': conversationId,
        'sender_id': currentUser.id,
        'recipient_id': recipientId,
        'content': content.trim(),
        'media_url': mediaUrl,
        'media_type': mediaType,
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': false,
      };

      final response = await _supabase
          .from('private_messages')
          .insert(messageData)
          .select('''
            *,
            sender:users!sender_id(id, username, full_name, avatar),
            recipient:users!recipient_id(id, username, full_name, avatar)
          ''')
          .single();

      // Mettre à jour la conversation
      await _updateConversationLastMessage(conversationId, content);

      // Envoyer une notification au destinataire
      await _sendMessageNotification(currentUser.id, recipientId, content);

      return PrivateMessage.fromJson(response);
    } catch (e) {
      print('Erreur envoi message privé: $e');
      return null;
    }
  }

  // === RÉCUPÉRATION DES MESSAGES ===

  /// Obtenir les messages d'une conversation
  static Future<List<PrivateMessage>> getConversationMessages(
    String otherUserId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      final response = await _supabase
          .from('private_messages')
          .select('''
            *,
            sender:users!sender_id(id, username, full_name, avatar),
            recipient:users!recipient_id(id, username, full_name, avatar)
          ''')
          .or(
            'and(sender_id.eq.${currentUser.id},recipient_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,recipient_id.eq.${currentUser.id})',
          )
          .order('sent_at', ascending: true)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => PrivateMessage.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur récupération messages: $e');
      return [];
    }
  }

  /// Stream des messages en temps réel pour une conversation
  static Stream<List<PrivateMessage>> getConversationMessagesStream(
    String otherUserId,
  ) {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Version simplifiée pour éviter les erreurs Supabase
    return _supabase
        .from('private_messages')
        .stream(primaryKey: ['id'])
        .order('sent_at')
        .map(
          (data) => data
              .where(
                (json) =>
                    (json['sender_id'] == currentUser.id &&
                        json['recipient_id'] == otherUserId) ||
                    (json['sender_id'] == otherUserId &&
                        json['recipient_id'] == currentUser.id),
              )
              .map((json) => PrivateMessage.fromJson(json))
              .toList(),
        );
  }

  // === GESTION DES CONVERSATIONS ===

  /// Obtenir la liste des conversations
  static Future<List<Conversation>> getConversations({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

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

      return (response as List)
          .map((json) => Conversation.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur récupération conversations: $e');
      return [];
    }
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
        .map(
          (data) => data
              .where(
                (json) =>
                    json['participant1_id'] == currentUser.id ||
                    json['participant2_id'] == currentUser.id,
              )
              .map((json) => Conversation.fromJson(json))
              .toList(),
        );
  }

  // === GESTION DES MESSAGES LUS ===

  /// Marquer les messages comme lus
  static Future<void> markMessagesAsRead(String otherUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase
          .from('private_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('sender_id', otherUserId)
          .eq('recipient_id', currentUser.id)
          .eq('is_read', false);
    } catch (e) {
      print('Erreur marquage messages lus: $e');
    }
  }

  /// Obtenir le nombre de messages non lus
  static Future<int> getUnreadMessagesCount() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return 0;

      final response = await _supabase
          .from('private_messages')
          .select('count(*)')
          .eq('recipient_id', currentUser.id)
          .eq('is_read', false);

      return response.first['count'] as int? ?? 0;
    } catch (e) {
      print('Erreur comptage messages non lus: $e');
      return 0;
    }
  }

  /// Obtenir le nombre de messages non lus pour une conversation
  static Future<int> getConversationUnreadCount(String otherUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return 0;

      final response = await _supabase
          .from('private_messages')
          .select('count(*)')
          .eq('sender_id', otherUserId)
          .eq('recipient_id', currentUser.id)
          .eq('is_read', false);

      return response.first['count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // === GESTION DES MÉDIAS ===

  /// Uploader un fichier média
  static Future<String?> uploadMedia(
    String filePath,
    String fileName,
    String mediaType,
  ) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      final file = File(filePath);
      await _supabase.storage
          .from('message-media')
          .upload('${currentUser.id}/$fileName', file);

      return _supabase.storage
          .from('message-media')
          .getPublicUrl('${currentUser.id}/$fileName');
    } catch (e) {
      print('Erreur upload média: $e');
      return null;
    }
  }

  // === BLOCAGE D'UTILISATEURS ===

  /// Bloquer un utilisateur
  static Future<bool> blockUser(String userId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      await _supabase.from('blocked_users').insert({
        'blocker_id': currentUser.id,
        'blocked_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Erreur blocage utilisateur: $e');
      return false;
    }
  }

  /// Débloquer un utilisateur
  static Future<bool> unblockUser(String userId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', currentUser.id)
          .eq('blocked_id', userId);

      return true;
    } catch (e) {
      print('Erreur déblocage utilisateur: $e');
      return false;
    }
  }

  /// Vérifier si un utilisateur est bloqué
  static Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      final result = await _supabase
          .from('blocked_users')
          .select()
          .or(
            'and(blocker_id.eq.${currentUser.id},blocked_id.eq.$userId),and(blocker_id.eq.$userId,blocked_id.eq.${currentUser.id})',
          )
          .maybeSingle();

      return result != null;
    } catch (e) {
      return false;
    }
  }

  // === MÉTHODES PRIVÉES ===

  static Future<String> _getOrCreateConversation(
    String userId1,
    String userId2,
  ) async {
    // Ordonner les IDs pour avoir une conversation unique
    final participant1 = userId1.compareTo(userId2) < 0 ? userId1 : userId2;
    final participant2 = userId1.compareTo(userId2) < 0 ? userId2 : userId1;

    // Chercher une conversation existante
    final existing = await _supabase
        .from('conversations')
        .select('id')
        .eq('participant1_id', participant1)
        .eq('participant2_id', participant2)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    // Créer une nouvelle conversation
    final response = await _supabase
        .from('conversations')
        .insert({
          'participant1_id': participant1,
          'participant2_id': participant2,
          'created_at': DateTime.now().toIso8601String(),
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  static Future<void> _updateConversationLastMessage(
    String conversationId,
    String lastMessage,
  ) async {
    try {
      await _supabase
          .from('conversations')
          .update({
            'last_message': lastMessage.length > 100
                ? '${lastMessage.substring(0, 100)}...'
                : lastMessage,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (e) {
      print('Erreur mise à jour conversation: $e');
    }
  }

  static Future<void> _sendMessageNotification(
    String senderId,
    String recipientId,
    String content,
  ) async {
    try {
      final senderProfile = await _supabase
          .from('users')
          .select('username, full_name, avatar')
          .eq('id', senderId)
          .single();

      await _supabase.from('notifications').insert({
        'user_id': recipientId,
        'type': 'private_message',
        'title': 'Nouveau message',
        'message':
            '${senderProfile['full_name'] ?? senderProfile['username']}: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}',
        'data': {
          'sender_id': senderId,
          'sender_username': senderProfile['username'],
          'sender_avatar': senderProfile['avatar'],
          'message_preview': content,
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Erreur envoi notification message: $e');
    }
  }
}
