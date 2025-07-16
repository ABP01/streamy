import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/co_host.dart';
import '../models/models.dart';
import '../services/co_host_service.dart';
import '../widgets/co_host_widget.dart';

class TikTokStyleLiveScreen extends StatefulWidget {
  final List<StreamContent> liveStreams;
  final int initialIndex;

  const TikTokStyleLiveScreen({
    super.key,
    required this.liveStreams,
    this.initialIndex = 0,
  });

  @override
  State<TikTokStyleLiveScreen> createState() => _TikTokStyleLiveScreenState();
}

class _TikTokStyleLiveScreenState extends State<TikTokStyleLiveScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  late AnimationController _reactionController;
  late AnimationController _chatController;
  Map<String, List<Map<String, String>>> _liveChatMessages =
      {}; // Messages par live
  List<Widget> _floatingHearts = [];
  Timer? _autoJoinTimer;
  final TextEditingController _chatTextController = TextEditingController();
  bool _showChatInput = false;
  final ScrollController _chatScrollController = ScrollController();
  bool _showSendButton = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Initialiser les contrôleurs d'animation
    _reactionController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _chatController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Mettre l'écran en plein écran
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Auto-rejoindre le live actuel après que le widget soit construit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoJoinCurrentLive();
    });

    // Démarrer les messages de chat simulés
    _startChatSimulation();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reactionController.dispose();
    _chatController.dispose();
    _chatTextController.dispose();
    _chatScrollController.dispose();
    _autoJoinTimer?.cancel();
    // Restaurer la barre de statut
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    // Les contrôles restent maintenant toujours visibles
    // Plus besoin de logique auto-hide
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTap: () =>
            _sendHeartReaction(), // Double tap pour envoyer une réaction
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.liveStreams.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            // Vibration légère pour le feedback
            HapticFeedback.selectionClick();
            // Auto-rejoindre le nouveau live
            _autoJoinCurrentLive();
          },
          itemBuilder: (context, index) {
            final stream = widget.liveStreams[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                // Arrière-plan du stream (image/vidéo)
                _buildStreamBackground(stream),

                // Overlay avec les contrôles (toujours visibles)
                _buildOverlay(stream),

                // Chat scrollable
                _buildScrollableChat(stream),

                // Coeurs flottants
                ..._floatingHearts,

                // Champ de chat en bas
                _buildChatInput(stream),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStreamBackground(StreamContent stream) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(stream.thumbnail),
          fit: BoxFit.cover,
          onError: (error, stackTrace) {
            // Gérer l'erreur de chargement d'image
          },
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(StreamContent stream) {
    return Positioned.fill(
      child: Column(
        children: [
          // Header avec info du streamer
          _buildHeader(stream),

          const Spacer(),

          // Contrôles et informations en bas
          _buildBottomControls(stream),
        ],
      ),
    );
  }

  Widget _buildHeader(StreamContent stream) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar du streamer
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: stream.userAvatar != null
                    ? DecorationImage(
                        image: NetworkImage(stream.userAvatar!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: stream.userAvatar == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Nom du streamer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (stream.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Nombre de viewers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatViewerCount(stream.viewerCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Indicateur co-hosts (en temps réel)
            _buildCoHostIndicator(stream),
          ],
        ),
      ),
    );
  }

  Widget _buildCoHostIndicator(StreamContent stream) {
    return StreamBuilder<List<CoHost>>(
      stream: CoHostService.getActiveCoHostsStream(stream.id),
      builder: (context, snapshot) {
        final coHosts = snapshot.data ?? <CoHost>[];

        if (coHosts.isEmpty) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _showCoHostInterface(stream),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${coHosts.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls(StreamContent stream) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre du stream
          Text(
            stream.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Catégorie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              stream.category,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Boutons d'action
          Row(
            children: [
              // Bouton de chat
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                onTap: () {
                  setState(() {
                    _showChatInput = !_showChatInput;
                  });
                },
              ),
              const SizedBox(width: 12),

              // Bouton de réaction coeur
              _buildActionButton(
                icon: Icons.favorite,
                color: Colors.red,
                onTap: () {
                  _sendHeartReaction();
                },
              ),
              const SizedBox(width: 12),

              // Bouton de cadeaux
              _buildActionButton(
                icon: Icons.card_giftcard,
                color: Colors.amber,
                onTap: () {
                  _showGiftInterface(stream);
                },
              ),
              const SizedBox(width: 12),

              // Bouton co-host
              _buildActionButton(
                icon: Icons.people,
                color: const Color(0xFF6C5CE7),
                onTap: () {
                  _showCoHostInterface(stream);
                },
              ),
              const SizedBox(width: 12),

              // Bouton de partage
              _buildActionButton(
                icon: Icons.share,
                onTap: () {
                  _shareStream(stream);
                },
              ),

              const Spacer(),
            ],
          ),

          // Safe area bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 24),
      ),
    );
  }

  String _formatViewerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  void _sendHeartReaction() {
    // Animation de réaction avec coeur
    HapticFeedback.lightImpact();

    // Créer un coeur flottant
    final heart = _createFloatingHeart();
    setState(() {
      _floatingHearts.add(heart);
    });

    // Supprimer le coeur après l'animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _floatingHearts.remove(heart);
        });
      }
    });
  }

  Widget _createFloatingHeart() {
    final random = Random();
    final leftPosition =
        random.nextDouble() * (MediaQuery.of(context).size.width - 100) + 50;

    return Positioned(
      left: leftPosition,
      bottom: 100,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(seconds: 3),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(sin(value * 2 * pi) * 20, -value * 300),
            child: Opacity(
              opacity: 1 - value,
              child: Transform.scale(
                scale: 0.5 + value * 0.5,
                child: const Icon(Icons.favorite, color: Colors.red, size: 40),
              ),
            ),
          );
        },
      ),
    );
  }

  void _autoJoinCurrentLive() {
    if (!mounted || _currentIndex >= widget.liveStreams.length) return;

    final currentStream = widget.liveStreams[_currentIndex];
    // Simuler la connexion au live (sans notification visuelle)
    // La connexion se fait en arrière-plan
    debugPrint('Auto-joined live: ${currentStream.title}');
  }

  void _startChatSimulation() {
    // Simuler des messages de chat qui apparaissent
    _autoJoinTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        final currentLiveId = widget.liveStreams[_currentIndex].id;
        final currentMessages = _liveChatMessages[currentLiveId] ?? [];
        if (currentMessages.length < 4) {
          _addChatMessage();
        }
      }
    });
  }

  void _addChatMessage() {
    final messages = [
      'Salut tout le monde! 👋',
      'Excellent live! 🔥',
      'Continue comme ça! 💪',
      'Trop bien! ❤️',
      'Top qualité! ⭐',
    ];

    final usernames = ['Alex_94', 'Marie_L', 'Tom_G', 'Lisa_K', 'Max_P'];
    final random = Random();
    final currentLiveId = widget.liveStreams[_currentIndex].id;

    final messageData = {
      'username': usernames[random.nextInt(usernames.length)],
      'message': messages[random.nextInt(messages.length)],
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    setState(() {
      if (_liveChatMessages[currentLiveId] == null) {
        _liveChatMessages[currentLiveId] = [];
      }
      _liveChatMessages[currentLiveId]!.add(messageData);
      // Garder un historique plus large pour le scroll
      if (_liveChatMessages[currentLiveId]!.length > 50) {
        _liveChatMessages[currentLiveId]!.removeAt(0);
      }
    });

    // Auto-scroll vers le bas pour voir le nouveau message
    if (_chatScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Widget _buildScrollableChat(StreamContent stream) {
    final chatMessages = _liveChatMessages[stream.id] ?? [];

    return Positioned(
      left: 16,
      right: 100, // Laisser de l'espace pour les boutons à droite
      bottom: 120, // Au-dessus du champ de texte
      height: 250, // Hauteur augmentée pour plus de visibilité
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.0),
              Colors.black.withOpacity(0.0),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView.builder(
          controller: _chatScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          itemCount: chatMessages.length,
          itemBuilder: (context, index) {
            final msgData = chatMessages[index];
            final isOwnMessage = msgData['username'] == 'Vous';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOwnMessage
                    ? const Color(0xFF6C5CE7).withOpacity(0.6)
                    : Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${msgData['username']}: ',
                      style: TextStyle(
                        color: isOwnMessage
                            ? Colors.white
                            : const Color(0xFF6C5CE7),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(
                      text: msgData['message'],
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatInput(StreamContent stream) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),

        child: Row(
          children: [
            // Champ de texte encore plus réduit
            Expanded(
              flex: 2, // Plus compact qu'avant (était flex: 3)
              child: TextField(
                controller: _chatTextController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Saississez un message...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18), // Plus compact
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, // Encore plus réduit
                    vertical: 6, // Encore plus réduit
                  ),
                ),
                onChanged: (text) {
                  setState(() {
                    _showSendButton = text.trim().isNotEmpty;
                  });
                },
                onTap: () {
                  // Scroll automatique vers le bas quand on tape
                  if (_chatScrollController.hasClients) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      _chatScrollController.animateTo(
                        _chatScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                  }
                },
                onSubmitted: (text) => _sendChatMessage(text, stream.id),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton Cadeaux (maintenant à la place de l'ancien bouton envoi)
            Container(
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _showGiftInterface(stream),
                icon: const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),

            // Bouton Envoi (apparaît seulement quand il y a du texte)
            if (_showSendButton) ...[
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF6C5CE7),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () =>
                      _sendChatMessage(_chatTextController.text, stream.id),
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _sendChatMessage(String message, String liveId) {
    if (message.trim().isEmpty) return;

    final messageData = {
      'username': 'Vous',
      'message': message.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    setState(() {
      if (_liveChatMessages[liveId] == null) {
        _liveChatMessages[liveId] = [];
      }
      // Ajouter le nouveau message à la fin
      _liveChatMessages[liveId]!.add(messageData);
      if (_liveChatMessages[liveId]!.length > 50) {
        // Supprimer le plus ancien
        _liveChatMessages[liveId]!.removeAt(0);
      }
    });

    _chatTextController.clear();
    setState(() {
      _showSendButton = false;
    });

    // Auto-scroll vers le bas
    if (_chatScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _showGiftInterface(StreamContent stream) {
    // Vérifier si l'utilisateur actuel est l'hôte du stream
    // Pour le moment, nous simulons la vérification avec l'ID de l'utilisateur actuel
    // Dans un vrai cas, vous récupéreriez l'ID de l'utilisateur connecté
    // depuis Supabase.instance.client.auth.currentUser?.id

    // Simulation : empêcher l'hôte d'envoyer des cadeaux
    // L'hôte ne peut pas s'envoyer des cadeaux à lui-même
    if (_isCurrentUserHost(stream)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les hôtes ne peuvent pas envoyer de cadeaux à eux-mêmes',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftInterfaceOverlay(streamId: stream.id),
    );
  }

  // Méthode pour vérifier si l'utilisateur actuel est l'hôte
  bool _isCurrentUserHost(StreamContent stream) {
    // Récupérer l'ID de l'utilisateur connecté
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Si pas d'utilisateur connecté, considérer comme visiteur (peut envoyer des cadeaux)
    if (currentUserId == null) return false;

    // Vérifier si l'utilisateur actuel est l'hôte du stream
    return currentUserId == stream.hostId;
  }

  void _shareStream(StreamContent stream) {
    // TODO: Implémenter le partage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonction de partage à venir'),
        backgroundColor: Color(0xFF6C5CE7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCoHostInterface(StreamContent stream) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    _isCurrentUserHost(stream)
                        ? 'Gérer les co-hosts'
                        : 'Co-hosts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Co-host widget
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CoHostWidget(
                  liveId: stream.id,
                  isHost: _isCurrentUserHost(stream),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget pour l'interface de cadeaux
class GiftInterfaceOverlay extends StatelessWidget {
  final String streamId;

  const GiftInterfaceOverlay({super.key, required this.streamId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header des cadeaux
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text(
                  'Envoyer un cadeau',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.grey),

          // Grille de cadeaux
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                final gifts = [
                  {'name': 'Rose', 'icon': '🌹', 'price': '1'},
                  {'name': 'Coeur', 'icon': '❤️', 'price': '2'},
                  {'name': 'Cadeau', 'icon': '🎁', 'price': '5'},
                  {'name': 'Diamant', 'icon': '💎', 'price': '10'},
                  {'name': 'Couronne', 'icon': '👑', 'price': '25'},
                  {'name': 'Fusée', 'icon': '🚀', 'price': '50'},
                ];

                final gift = gifts[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Vous avez envoyé ${gift['name']} !'),
                        backgroundColor: Colors.amber,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gift['icon']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gift['name']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${gift['price']} coins',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Balance de coins
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Votre balance: 100 coins',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
