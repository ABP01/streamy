import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/co_host.dart';
import '../models/models.dart';
import '../services/co_host_service.dart';
import '../widgets/co_host_widget.dart';

/// Écran de live streaming dans le style TikTok avec défilement vertical
///
/// Permet de naviguer entre différents lives en swipant verticalement,
/// avec affichage des contrôles, réactions et interfaces de cadeaux.
class TikTokStyleLiveScreen extends StatefulWidget {
  /// Liste des streams à afficher
  final List<StreamContent> liveStreams;

  /// Index du stream initial à afficher
  final int initialIndex;

  const TikTokStyleLiveScreen({
    super.key,
    required this.liveStreams,
    this.initialIndex = 0,
  });

  @override
  State<TikTokStyleLiveScreen> createState() => _TikTokStyleLiveScreenState();
}

/// État de l'écran TikTok Style Live Screen
class _TikTokStyleLiveScreenState extends State<TikTokStyleLiveScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════
  // CONTRÔLEURS ET VARIABLES D'ÉTAT
  // ═══════════════════════════════════════════════════════════════

  /// Contrôleur pour le champ de texte de chat
  final TextEditingController _messageController = TextEditingController();

  /// Liste des messages de chat pour chaque stream
  final Map<String, List<Map<String, String>>> _chatMessages = {};

  /// Contrôleur pour la navigation entre les lives
  late PageController _pageController;

  /// Index du live actuellement affiché
  int _currentIndex = 0;

  /// Contrôleur d'animation pour les réactions (cœurs flottants)
  late AnimationController _reactionController;

  /// Contrôleur d'animation pour le chat (non utilisé actuellement)
  late AnimationController _chatController;

  /// Liste des cœurs flottants actuellement animés
  List<Widget> _floatingHearts = [];

  /// Timer pour les fonctionnalités automatiques (auto-join)
  Timer? _autoJoinTimer;

  /// Indique si le champ de texte a le focus
  bool _isTextFieldFocused = false;

  /// FocusNode pour le champ de texte
  final FocusNode _textFieldFocusNode = FocusNode();

  // ═══════════════════════════════════════════════════════════════
  // CYCLE DE VIE DU WIDGET
  // ═══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    // Initialiser l'index du stream de départ
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Configurer les contrôleurs d'animation
    _initializeAnimationControllers();

    // Passer en mode plein écran immersif (style TikTok)
    _enableImmersiveMode();

    // Auto-rejoindre le live actuel après que le widget soit construit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoJoinCurrentLive();
      _initializeChatMessages(); // Initialiser quelques messages d'exemple
      _setupFocusListener(); // Configurer l'écoute du focus
    });
  }

  @override
  void dispose() {
    // Nettoyer les ressources
    _pageController.dispose();
    _reactionController.dispose();
    _chatController.dispose();
    _messageController.dispose();
    _textFieldFocusNode.dispose();
    _autoJoinTimer?.cancel();

    // Restaurer l'interface système normale
    _restoreSystemUI();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTHODES D'INITIALISATION
  // ═══════════════════════════════════════════════════════════════

  /// Initialise les contrôleurs d'animation pour les effets visuels
  void _initializeAnimationControllers() {
    _reactionController = AnimationController(
      duration: const Duration(
        milliseconds: 2000,
      ), // Animation de 2 secondes pour les cœurs
      vsync: this,
    );

    _chatController = AnimationController(
      duration: const Duration(
        milliseconds: 300,
      ), // Animation rapide pour le chat
      vsync: this,
    );
  }

  /// Active le mode plein écran immersif (masque la barre de statut et navigation)
  void _enableImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  /// Configure l'écoute du focus sur le champ de texte
  void _setupFocusListener() {
    _textFieldFocusNode.addListener(() {
      setState(() {
        _isTextFieldFocused = _textFieldFocusNode.hasFocus;
      });
    });
  }

  /// Restaure l'interface système normale (barre de statut visible)
  void _restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ═══════════════════════════════════════════════════════════════
  // GESTIONNAIRES D'ÉVÉNEMENTS
  // ═══════════════════════════════════════════════════════════════

  /// Méthode pour basculer l'affichage des contrôles
  /// Retire également le focus du champ de texte si il est actif
  void _toggleControls() {
    // Si le champ de texte a le focus, le retirer
    if (_isTextFieldFocused) {
      _textFieldFocusNode.unfocus();
    }
    // Fonctionnalité de basculement des contrôles conservée pour d'éventuelles améliorations futures
  }

  // ═══════════════════════════════════════════════════════════════
  // CONSTRUCTION DE L'INTERFACE UTILISATEUR
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fond noir pour style TikTok
      body: GestureDetector(
        // Interactions gestuelles
        onTap: _toggleControls, // Tap simple pour basculer les contrôles
        onDoubleTap:
            _sendHeartReaction, // Double tap pour envoyer une réaction cœur
        // PageView vertical pour navigation entre les lives (style TikTok)
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical, // Défilement vertical comme TikTok
          itemCount: widget.liveStreams.length,

          // Callback appelé lors du changement de page
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });

            // Feedback haptique pour une meilleure UX
            HapticFeedback.selectionClick();

            // Auto-rejoindre le nouveau live
            _autoJoinCurrentLive();
          },

          // Construction de chaque page de live
          itemBuilder: (context, index) {
            final stream = widget.liveStreams[index];

            return Stack(
              fit: StackFit.expand,
              children: [
                // Couches empilées pour l'interface complète
                _buildStreamBackground(stream), // Arrière-plan (image/vidéo)
                _buildOverlay(stream), // Overlay avec contrôles
                ..._floatingHearts, // Cœurs flottants animés
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CONSTRUCTION DES COMPOSANTS VISUELS
  // ═══════════════════════════════════════════════════════════════

  /// Construit l'arrière-plan du stream avec image et dégradé
  Widget _buildStreamBackground(StreamContent stream) {
    return Container(
      decoration: BoxDecoration(
        // Image de fond du stream
        image: DecorationImage(
          image: NetworkImage(stream.thumbnail),
          fit: BoxFit.cover,
          onError: (error, stackTrace) {
            // Gestion silencieuse des erreurs de chargement d'image
            debugPrint('Erreur de chargement image: $error');
          },
        ),
      ),

      // Overlay avec dégradé pour améliorer la lisibilité du texte
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3), // Assombrir le haut
              Colors.transparent, // Zone centrale claire
              Colors.black.withOpacity(
                0.7,
              ), // Assombrir le bas pour les contrôles
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  /// Construit l'overlay principal contenant header et contrôles
  Widget _buildOverlay(StreamContent stream) {
    return Positioned.fill(
      child: Column(
        children: [
          // En-tête avec informations du streamer
          _buildHeader(stream),

          // Espace flexible pour pousser les contrôles en bas
          const Spacer(),

          // Contrôles et informations en bas de l'écran
          _buildBottomControls(stream),
        ],
      ),
    );
  }

  /// Construit l'en-tête avec avatar, nom du streamer, badge LIVE et nombre de viewers
  Widget _buildHeader(StreamContent stream) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar du streamer avec bordure
            _buildStreamerAvatar(stream),
            const SizedBox(width: 12),

            // Informations du streamer (nom + badge LIVE)
            Expanded(child: _buildStreamerInfo(stream)),

            // Nombre de viewers avec icône
            _buildViewerCount(stream),
            const SizedBox(width: 8),

            // Indicateur co-hosts en temps réel
            _buildCoHostIndicator(stream),
          ],
        ),
      ),
    );
  }

  /// Construit l'avatar du streamer avec bordure blanche
  Widget _buildStreamerAvatar(StreamContent stream) {
    return Container(
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
    );
  }

  /// Construit les informations du streamer (nom + badge LIVE)
  Widget _buildStreamerInfo(StreamContent stream) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nom du streamer
        Text(
          stream.username,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),

        // Badge LIVE si le stream est en direct
        if (stream.isLive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }

  /// Construit l'affichage du nombre de viewers
  Widget _buildViewerCount(StreamContent stream) {
    return Container(
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
    );
  }

  /// Construit l'indicateur de co-hosts avec données en temps réel
  Widget _buildCoHostIndicator(StreamContent stream) {
    return StreamBuilder<List<CoHost>>(
      stream: CoHostService.getActiveCoHostsStream(stream.id),
      builder: (context, snapshot) {
        final coHosts = snapshot.data ?? <CoHost>[];

        // Masquer l'indicateur s'il n'y a pas de co-hosts
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

  /// Construit les contrôles en bas de l'écran avec chat et boutons d'action
  Widget _buildBottomControls(StreamContent stream) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Petite liste de chat - affichée uniquement s'il y a des messages
          if (_chatMessages[stream.id]?.isNotEmpty ?? false)
            _buildChatList(stream),
          if (_chatMessages[stream.id]?.isNotEmpty ?? false)
            const SizedBox(height: 12),

          // Champ de texte et boutons d'action horizontaux
          _buildActionButtons(stream),

          // Espace pour la zone de sécurité du bas
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  /// Construit une petite liste de chat avec les derniers messages
  Widget _buildChatList(StreamContent stream) {
    final messages = _chatMessages[stream.id] ?? [];

    // Prendre seulement les 3 derniers messages pour l'affichage
    final displayMessages = messages.length > 3
        ? messages.sublist(messages.length - 3)
        : messages;

    return Container(
      height: 90, // Hauteur fixe pour 3 messages
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      child: displayMessages.isEmpty
          ? const Center(
              child: Text(
                'Aucun message pour le moment...',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          : ListView.builder(
              itemCount: displayMessages.length,
              itemBuilder: (context, index) {
                final message = displayMessages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${message['username']}: ',
                              style: const TextStyle(
                                color: Color(0xFF6C5CE7),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: message['message'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Construit la rangée de boutons d'action avec champ de texte
  Widget _buildActionButtons(StreamContent stream) {
    return Row(
      children: [
        // Champ de texte pour écrire des messages
        Expanded(
          flex: _isTextFieldFocused ? 4 : 3, // S'élargit quand focalisé
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isTextFieldFocused
                    ? Colors.blue.withOpacity(0.7)
                    : Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _messageController,
              focusNode: _textFieldFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Saisissez votre message...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (text) {
                _sendMessage(stream, text);
                _textFieldFocusNode.unfocus(); // Retirer le focus après envoi
              },
            ),
          ),
        ),

        // Bouton d'envoi (affiché uniquement quand le champ de texte est focalisé)
        if (_isTextFieldFocused) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              _sendMessage(stream, _messageController.text);
              _textFieldFocusNode.unfocus(); // Retirer le focus après envoi
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],

        // Boutons d'action (masqués quand le champ de texte est focalisé)
        if (!_isTextFieldFocused) ...[
          const SizedBox(width: 12),

          // Bouton de cadeaux
          _buildActionButton(
            icon: Icons.card_giftcard,
            color: Colors.amber,
            onTap: () => _showGiftInterface(stream),
          ),
          const SizedBox(width: 12),

          // Bouton co-host
          _buildActionButton(
            icon: Icons.people,
            color: const Color(0xFF6C5CE7),
            onTap: () => _showCoHostInterface(stream),
          ),
          const SizedBox(width: 12),

          // Bouton de partage
          _buildActionButton(
            icon: Icons.share,
            onTap: () => _shareStream(stream),
          ),
        ],
      ],
    );
  }

  /// Construit un bouton d'action circulaire avec icône
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
          color: Colors.black.withOpacity(0.5), // Fond semi-transparent
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 24),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTHODES UTILITAIRES
  // ═══════════════════════════════════════════════════════════════

  /// Formate le nombre de viewers avec suffixes K/M pour les grands nombres
  String _formatViewerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SYSTÈME DE RÉACTIONS ET ANIMATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Envoie une réaction cœur avec animation flottante
  void _sendHeartReaction() {
    // Feedback haptique pour une meilleure expérience utilisateur
    HapticFeedback.lightImpact();

    // Créer et ajouter un cœur flottant animé
    final heart = _createFloatingHeart();
    setState(() {
      _floatingHearts.add(heart);
    });

    // Programmer la suppression du cœur après l'animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _floatingHearts.remove(heart);
        });
      }
    });
  }

  /// Crée un widget de cœur flottant avec animation personnalisée
  Widget _createFloatingHeart() {
    final random = Random();

    // Position horizontale aléatoire pour varier l'effet
    final leftPosition =
        random.nextDouble() * (MediaQuery.of(context).size.width - 100) + 50;

    return Positioned(
      left: leftPosition,
      bottom: 100, // Position de départ en bas de l'écran
      child: TweenAnimationBuilder<double>(
        duration: const Duration(seconds: 3), // Durée de l'animation
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            // Mouvement combiné : montée avec oscillation sinusoïdale
            offset: Offset(
              sin(value * 2 * pi) * 20, // Oscillation horizontale
              -value * 300, // Montée verticale
            ),
            child: Opacity(
              opacity: 1 - value, // Disparition progressive
              child: Transform.scale(
                scale: 0.5 + value * 0.5, // Légère augmentation de taille
                child: const Icon(Icons.favorite, color: Colors.red, size: 40),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GESTION DES LIVES ET AUTO-JOIN
  // ═══════════════════════════════════════════════════════════════

  /// Initialise quelques messages d'exemple pour les streams
  void _initializeChatMessages() {
    final sampleMessages = [
      {'username': 'Alex_94', 'message': 'Salut tout le monde! 👋'},
      {'username': 'Marie_L', 'message': 'Excellent live! 🔥'},
      {'username': 'Tom_G', 'message': 'Continue comme ça! 💪'},
    ];

    for (final stream in widget.liveStreams) {
      _chatMessages[stream.id] = List.from(sampleMessages);
    }
  }

  /// Envoie un message dans le chat du stream actuel
  void _sendMessage(StreamContent stream, String text) {
    if (text.trim().isEmpty) return;

    final message = {'username': 'Vous', 'message': text.trim()};

    setState(() {
      if (_chatMessages[stream.id] == null) {
        _chatMessages[stream.id] = [];
      }
      _chatMessages[stream.id]!.add(message);

      // Garder seulement les 10 derniers messages pour éviter la surcharge
      if (_chatMessages[stream.id]!.length > 10) {
        _chatMessages[stream.id]!.removeAt(0);
      }
    });

    _messageController.clear();
  }

  /// Rejoint automatiquement le live actuellement affiché
  /// Cette méthode simule la connexion automatique lors du défilement
  void _autoJoinCurrentLive() {
    // Vérifications de sécurité
    if (!mounted || _currentIndex >= widget.liveStreams.length) return;

    final currentStream = widget.liveStreams[_currentIndex];

    // Simulation de la connexion au live
    // Dans une implémentation réelle, ceci déclencherait la connexion Agora/WebRTC
    debugPrint('Auto-joined live: ${currentStream.title}');

    // TODO: Implémenter la vraie logique de connexion
    // - Rejoindre le canal Agora
    // - Mettre à jour les statistiques de viewer
    // - Notifier le backend de la connexion
  }

  // ═══════════════════════════════════════════════════════════════
  // INTERFACES DE CHAT ET INTERACTION
  // ═══════════════════════════════════════════════════════════════

  /// Construit l'interface de chat en bas de l'écran
  /// Note: Le chat principal a été supprimé, seul le bouton cadeaux reste

  // ═══════════════════════════════════════════════════════════════
  // INTERFACES MODALES ET INTERACTIONS AVANCÉES
  // ═══════════════════════════════════════════════════════════════

  /// Affiche l'interface de sélection et d'envoi de cadeaux
  void _showGiftInterface(StreamContent stream) {
    // Vérification de sécurité : empêcher l'hôte d'envoyer des cadeaux à lui-même
    if (_isCurrentUserHost(stream)) {
      _showHostRestrictionMessage();
      return;
    }

    // Afficher l'interface modale de cadeaux
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftInterfaceOverlay(streamId: stream.id),
    );
  }

  /// Affiche un message d'information pour les restrictions d'hôte
  void _showHostRestrictionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Les hôtes ne peuvent pas envoyer de cadeaux à eux-mêmes',
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Vérifie si l'utilisateur actuel est l'hôte du stream
  bool _isCurrentUserHost(StreamContent stream) {
    // Récupération de l'ID de l'utilisateur connecté via Supabase
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Si aucun utilisateur connecté, considérer comme visiteur
    if (currentUserId == null) return false;

    // Comparaison avec l'ID de l'hôte du stream
    return currentUserId == stream.hostId;
  }

  /// Affiche un placeholder pour la fonction de partage
  void _shareStream(StreamContent stream) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonction de partage à venir'),
        backgroundColor: Color(0xFF6C5CE7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Affiche l'interface de gestion des co-hosts
  void _showCoHostInterface(StreamContent stream) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Permet un contrôle complet de la hauteur
      builder: (context) => _buildCoHostModal(stream),
    );
  }

  /// Construit le contenu de la modale co-host
  Widget _buildCoHostModal(StreamContent stream) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Barre de manipulation (handle bar)
          _buildModalHandle(),

          // En-tête de la modale
          _buildCoHostModalHeader(stream),

          // Widget de gestion des co-hosts
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
    );
  }

  /// Construit la barre de manipulation de la modale
  Widget _buildModalHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Construit l'en-tête de la modale co-host
  Widget _buildCoHostModalHeader(StreamContent stream) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.people, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            _isCurrentUserHost(stream) ? 'Gérer les co-hosts' : 'Co-hosts',
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
