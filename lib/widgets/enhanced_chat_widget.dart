import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../services/animation_service.dart';
import '../services/chat_service.dart';
import '../services/gift_service.dart';

class EnhancedChatWidget extends StatefulWidget {
  final String liveId;
  final bool isHost;
  final VoidCallback? onToggleChat;

  const EnhancedChatWidget({
    super.key,
    required this.liveId,
    this.isHost = false,
    this.onToggleChat,
  });

  @override
  State<EnhancedChatWidget> createState() => _EnhancedChatWidgetState();
}

class _EnhancedChatWidgetState extends State<EnhancedChatWidget>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  late AnimationController _reactionController;
  late AnimationController _giftController;
  late Stream<List<Reaction>> _reactionsStream;
  late Stream<List<Gift>> _giftsStream;
  final ChatService _chatService = ChatService();

  bool _isEmojiPickerVisible = false;
  bool _isGiftPanelVisible = false;
  bool _isChatExpanded = false;

  List<Reaction> _activeReactions = [];
  List<Gift> _activeGifts = [];

  @override
  void initState() {
    super.initState();
    _reactionController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _giftController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // TODO: Remplacer par un vrai stream de réactions si disponible
    _reactionsStream = const Stream.empty();
    _giftsStream = GiftService.getGiftsStream(widget.liveId);

    // Écouter les nouvelles réactions
    _reactionsStream.listen((reactions) {
      for (final reaction in reactions) {
        if (!_activeReactions.any((r) => r.id == reaction.id)) {
          setState(() {
            _activeReactions.add(reaction);
          });
          _animateReaction(reaction);
        }
      }
    });

    // Écouter les nouveaux gifts
    _giftsStream.listen((gifts) {
      for (final gift in gifts) {
        if (!_activeGifts.any((g) => g.id == gift.id)) {
          setState(() {
            _activeGifts.add(gift);
          });
          _animateGift(gift);
        }
      }
    });
  }

  @override
  void dispose() {
    _reactionController.dispose();
    _giftController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _animateReaction(Reaction reaction) {
    _reactionController.forward().then((_) {
      setState(() {
        _activeReactions.removeWhere((r) => r.id == reaction.id);
      });
      _reactionController.reset();
    });
  }

  void _animateGift(Gift gift) {
    _giftController.forward().then((_) {
      setState(() {
        _activeGifts.removeWhere((g) => g.id == gift.id);
      });
      _giftController.reset();
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await _chatService.sendMessage(liveId: widget.liveId, content: content);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _sendReaction(ReactionType type) async {
    try {
      await _chatService.sendReaction(
        liveId: widget.liveId,
        type: type.name, // Convertir ReactionType en String
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _sendGift(String giftType, int quantity) async {
    // Obtenir l'ID du host du live
    // Cette logique devrait être adaptée selon votre structure de données
    try {
      await GiftService.sendGift(
        liveId: widget.liveId,
        receiverId: 'host_id', // À adapter
        giftType: giftType,
        quantity: quantity,
      );
      setState(() {
        _isGiftPanelVisible = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animations des réactions
        ..._activeReactions.map(
          (reaction) => AnimationService.buildReactionAnimation(
            type: reaction.type,
            animation: _reactionController,
            startX: reaction.positionX,
            startY: reaction.positionY,
          ),
        ),

        // Animations des gifts
        ..._activeGifts.map(
          (gift) => AnimationService.buildGiftAnimation(
            giftType: gift.giftType,
            animation: _giftController,
            quantity: gift.quantity,
          ),
        ),

        // Interface du chat
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isChatExpanded
                ? MediaQuery.of(context).size.height * 0.6
                : 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
            child: Column(
              children: [
                // En-tête du chat
                if (_isChatExpanded) _buildChatHeader(),

                // Liste des messages
                Expanded(child: _buildMessagesList()),

                // Zone de saisie
                _buildInputArea(),
              ],
            ),
          ),
        ),

        // Panel des emojis
        if (_isEmojiPickerVisible) _buildEmojiPicker(),

        // Panel des gifts
        if (_isGiftPanelVisible) _buildGiftPanel(),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.chat, color: Colors.white),
          const SizedBox(width: 8),
          const Text(
            'Chat en direct',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.expand_less, color: Colors.white),
            onPressed: () {
              setState(() {
                _isChatExpanded = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<LiveStreamMessage>>(
      stream: _chatService.getMessages(liveId: widget.liveId).asStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data!;
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _buildMessageItem(messages[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageItem(LiveStreamMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar utilisateur
          CircleAvatar(
            radius: 12,
            backgroundImage: message.userAvatar != null
                ? NetworkImage(message.userAvatar!)
                : null,
            child: message.userAvatar == null
                ? Text(
                    (message.username ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 8),

          // Contenu du message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.username ?? 'Utilisateur',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  message.message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          // Actions de modération (si host)
          // Note: _handleMessageAction expects a Message, you may need to refactor it to accept LiveStreamMessage or handle conversion
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Bouton d'expansion du chat
          IconButton(
            icon: Icon(
              _isChatExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isChatExpanded = !_isChatExpanded;
              });
            },
          ),

          // Zone de texte
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Tapez votre message...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
                maxLength: AppConfig.maxMessageLength,
              ),
            ),
          ),

          // Bouton emoji
          IconButton(
            icon: const Icon(Icons.emoji_emotions, color: Colors.white),
            onPressed: () {
              setState(() {
                _isEmojiPickerVisible = !_isEmojiPickerVisible;
                _isGiftPanelVisible = false;
              });
            },
          ),

          // Bouton gift
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: Colors.amber),
            onPressed: () {
              setState(() {
                _isGiftPanelVisible = !_isGiftPanelVisible;
                _isEmojiPickerVisible = false;
              });
            },
          ),

          // Bouton envoyer
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: GridView.count(
          crossAxisCount: 6,
          children: ReactionType.values.map((type) {
            return GestureDetector(
              onTap: () => _sendReaction(type),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: _getReactionIcon(type)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGiftPanel() {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Envoyer un cadeau',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                children: AppConfig.giftTypes.entries.map((entry) {
                  final giftType = entry.key;
                  final config = entry.value;

                  return GestureDetector(
                    onTap: () => _sendGift(giftType, 1),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Color(config['color'] as int).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(config['color'] as int),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getGiftIcon(giftType),
                            color: Color(config['color'] as int),
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${config['cost']} 🪙',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getReactionIcon(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return const Icon(Icons.favorite, color: Colors.red, size: 24);
      case ReactionType.love:
        return const Icon(Icons.favorite, color: Colors.pink, size: 24);
      case ReactionType.wow:
        return const Icon(
          Icons.sentiment_very_satisfied,
          color: Colors.yellow,
          size: 24,
        );
      case ReactionType.laugh:
        return const Icon(
          Icons.sentiment_very_satisfied,
          color: Colors.green,
          size: 24,
        );
      case ReactionType.fire:
        return const Icon(
          Icons.local_fire_department,
          color: Colors.orange,
          size: 24,
        );
      case ReactionType.clap:
        return const Icon(Icons.back_hand, color: Colors.blue, size: 24);
    }
  }

  IconData _getGiftIcon(String giftType) {
    switch (giftType) {
      case 'heart':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'diamond':
        return Icons.diamond;
      case 'crown':
        return Icons.workspace_premium;
      case 'rocket':
        return Icons.rocket_launch;
      default:
        return Icons.card_giftcard;
    }
  }
}
