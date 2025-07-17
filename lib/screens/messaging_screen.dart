import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/messaging_service.dart';

class MessagingScreen extends StatefulWidget {
  final String? initialUserId;

  const MessagingScreen({super.key, this.initialUserId});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Conversation> _conversations = [];
  List<PrivateMessage> _messages = [];
  UserProfile? _selectedUser;
  bool _isLoadingConversations = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();

    if (widget.initialUserId != null) {
      _openConversationWithUser(widget.initialUserId!);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await MessagingService.getUserConversations();
      setState(() {
        _conversations = conversations;
        _isLoadingConversations = false;
      });
    } catch (e) {
      setState(() => _isLoadingConversations = false);
      print('Erreur chargement conversations: $e');
    }
  }

  Future<void> _openConversationWithUser(String userId) async {
    setState(() {
      _isLoadingMessages = true;
      _messages = [];
    });

    try {
      final messages = await MessagingService.getConversationMessages(
        otherUserId: userId,
      );

      // Marquer les messages comme lus
      final conversation = _conversations.firstWhere(
        (c) => c.participant1Id == userId || c.participant2Id == userId,
        orElse: () => Conversation(
          id: '',
          participant1Id: '',
          participant2Id: userId,
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      if (conversation.id.isNotEmpty) {
        await MessagingService.markMessagesAsRead(
          conversationId: conversation.id,
          senderId: userId,
        );
      }

      setState(() {
        _messages = messages.reversed
            .toList(); // Inverser pour affichage chronologique
        _isLoadingMessages = false;
      });

      // Scroll vers le bas
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() => _isLoadingMessages = false);
      print('Erreur chargement messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedUser == null) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      final message = await MessagingService.sendPrivateMessage(
        recipientId: _selectedUser!.id,
        content: content,
      );

      setState(() {
        _messages.add(message);
        _isSending = false;
      });

      // Scroll vers le bas
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Recharger les conversations pour mettre à jour l'ordre
      _loadConversations();
    } catch (e) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur envoi message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: _selectedUser != null
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: _selectedUser!.avatar != null
                        ? CachedNetworkImageProvider(_selectedUser!.avatar!)
                        : null,
                    backgroundColor: Colors.grey[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedUser!.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              )
            : const Text('Messages', style: TextStyle(color: Colors.white)),
      ),
      body: _selectedUser == null
          ? _buildConversationsList()
          : _buildChatInterface(),
    );
  }

  Widget _buildConversationsList() {
    if (_isLoadingConversations) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(color: Colors.grey[400], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez une conversation en recherchant des utilisateurs',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final otherUser =
            conversation.participant1Id != conversation.participant2Id
            ? (conversation.participant1 ?? conversation.participant2)
            : conversation.participant2;

        if (otherUser == null) return const SizedBox.shrink();

        return _buildConversationTile(conversation, otherUser);
      },
    );
  }

  Widget _buildConversationTile(
    Conversation conversation,
    UserProfile otherUser,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: otherUser.avatar != null
            ? CachedNetworkImageProvider(otherUser.avatar!)
            : null,
        backgroundColor: Colors.grey[700],
        child: otherUser.avatar == null
            ? Text(
                otherUser.displayName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(
        otherUser.displayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        conversation.lastMessage ?? 'Commencer une conversation',
        style: TextStyle(color: Colors.grey[400], fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing:
          conversation.unreadCount != null && conversation.unreadCount! > 0
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                conversation.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: () {
        setState(() {
          _selectedUser = otherUser;
        });
        _openConversationWithUser(otherUser.id);
      },
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        // Messages
        Expanded(
          child: _isLoadingMessages
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _messages.isEmpty
              ? Center(
                  child: Text(
                    'Aucun message encore.\nCommencez la conversation !',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
        ),

        // Input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(PrivateMessage message) {
    final isMyMessage =
        message.sender?.id == message.senderId; // Ajuster selon votre logique

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMyMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 12,
              backgroundImage: message.sender?.avatar != null
                  ? CachedNetworkImageProvider(message.sender!.avatar!)
                  : null,
              backgroundColor: Colors.grey[700],
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMyMessage ? Colors.purple : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 16,
              color: message.isRead ? Colors.blue : Colors.grey,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tapez votre message...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[800],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
