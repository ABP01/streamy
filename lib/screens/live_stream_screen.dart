import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/live_stream.dart';
import '../services/live_stream_service.dart';
import '../widgets/enhanced_chat_widget.dart';
import '../widgets/gift_animations.dart';
import '../widgets/live_stats_widget.dart';
import '../widgets/reaction_animations.dart' as reactions;

class LiveStreamScreen extends StatefulWidget {
  final String liveId;
  final bool isHost;

  const LiveStreamScreen({
    super.key,
    required this.liveId,
    required this.isHost,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with TickerProviderStateMixin {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final GlobalKey _reactionKey = GlobalKey();
  final GlobalKey _giftKey = GlobalKey();
  final PageController _pageController = PageController();

  LiveStream? _currentLive;
  bool _isLoading = true;
  bool _isConnected = false;
  bool _showChat = true;
  bool _showStats = false;
  bool _showTutorial = false;
  int _currentTutorialStep = 0;
  Timer? _heartbeatTimer;
  Timer? _statsTimer;
  Timer? _liveDurationTimer;
  Duration _liveDuration = Duration.zero;

  // Variables pour les contrôles de l'interface
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeLiveStream();
    _setupHeartbeat();
    _setupStatsUpdate();
    _setupControlsTimer();
    _setupLiveDurationTimer();
    if (widget.isHost) {
      _checkAndShowTutorial();
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _statsTimer?.cancel();
    _controlsTimer?.cancel();
    _liveDurationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeLiveStream() async {
    try {
      final lives = await _liveStreamService.fetchLiveStreams();
      final live = lives.where((l) => l.id == widget.liveId).firstOrNull;
      if (live != null) {
        setState(() {
          _currentLive = live;
          _isLoading = false;
        });

        // Rejoindre le live
        await _liveStreamService.joinLive(widget.liveId, 'current_user_id');
        setState(() {
          _isConnected = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Gérer l'erreur
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _setupHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        // Heartbeat personnalisé - à implémenter
        print('Heartbeat envoyé pour ${widget.liveId}');
      }
    });
  }

  void _setupStatsUpdate() {
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentLive != null) {
        _updateLiveStats();
      }
    });
  }

  void _setupControlsTimer() {
    _resetControlsTimer();
  }

  void _setupLiveDurationTimer() {
    _liveDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _liveDuration = _liveDuration + const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('host_tutorial_seen') ?? false;

    if (!hasSeenTutorial && widget.isHost) {
      // Attendre un délai pour que l'interface se charge
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showTutorial = true;
          });
        }
      });
    }
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('host_tutorial_seen', true);
    setState(() {
      _showTutorial = false;
    });
  }

  void _nextTutorialStep() {
    if (_currentTutorialStep < 2) {
      setState(() {
        _currentTutorialStep++;
      });
    } else {
      _completeTutorial();
    }
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  Future<void> _updateLiveStats() async {
    try {
      final lives = await _liveStreamService.fetchLiveStreams();
      final updatedLive = lives.where((l) => l.id == widget.liveId).firstOrNull;
      if (updatedLive != null && mounted) {
        setState(() {
          _currentLive = updatedLive;
        });
      }
    } catch (e) {
      // Ignorer les erreurs de mise à jour silencieuses
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _resetControlsTimer();
    }
  }

  void _handleGiftSent(String giftId, String giftType, int quantity) {
    // Envoyer le cadeau via le service
    // _liveStreamService.sendGift(widget.liveId, giftId, giftType, quantity);

    // Afficher une réaction
    // _reactionKey.currentState?.addReaction(reactions.ReactionType.gift);
  }

  void _handleReaction(reactions.ReactionType type) {
    // _reactionKey.currentState?.addReaction(type);

    // Envoyer la réaction au serveur (à implémenter)
    switch (type) {
      case reactions.ReactionType.heart:
        print('❤️ Réaction coeur envoyée');
        break;
      case reactions.ReactionType.like:
        print('👍 Like envoyé');
        break;
      default:
        print('Réaction envoyée: $type');
        break;
    }
  }

  void _endLive() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Terminer le live ?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Êtes-vous sûr de vouloir terminer ce live ?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (widget.isHost) ...[
              _buildSummaryRow('Durée', _formatDuration(_liveDuration)),
              _buildSummaryRow(
                'Spectateurs',
                '${_currentLive?.viewerCount ?? 0}',
              ),
              _buildSummaryRow('Likes', '${_currentLive?.likeCount ?? 0}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continuer le live',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              if (widget.isHost) {
                // Terminer le live côté backend
                try {
                  await _liveStreamService.endLiveStream(widget.liveId);
                } catch (e) {
                  print('Erreur lors de la fin du live: $e');
                }

                // Afficher un écran de résumé
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _buildLiveSummaryScreen(),
                    ),
                  );
                }
              } else {
                // Spectateur quitte le live
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(widget.isHost ? 'Terminer' : 'Quitter'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSummaryScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Résumé du live',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),

            const SizedBox(height: 24),

            const Text(
              'Live terminé !',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Félicitations pour votre live !',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Durée totale',
                    _formatDuration(_liveDuration),
                  ),
                  const Divider(color: Colors.white30),
                  _buildSummaryRow(
                    'Spectateurs max',
                    '${_currentLive?.viewerCount ?? 0}',
                  ),
                  const Divider(color: Colors.white30),
                  _buildSummaryRow(
                    'Total des likes',
                    '${_currentLive?.likeCount ?? 0}',
                  ),
                  const Divider(color: Colors.white30),
                  _buildSummaryRow(
                    'Cadeaux reçus',
                    '0',
                  ), // TODO: ajouter gift count
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Retour à l\'accueil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.purple)),
      );
    }

    if (_currentLive == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Live introuvable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Fond vidéo (à remplacer par Agora)
            _buildVideoBackground(),

            // Overlay de réactions
            reactions.ReactionAnimationWidget(
              key: _reactionKey,
              liveId: widget.liveId,
              child: const SizedBox.expand(),
            ),

            // Interface utilisateur
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildUIOverlay(),
            ),

            // Chat (toujours visible en bas)
            if (_showChat) _buildChatOverlay(),

            // Stats pour l'hôte
            if (widget.isHost && _showStats) _buildStatsOverlay(),

            // Animations de cadeaux
            GiftAnimationWidget(
              key: _giftKey,
              liveId: widget.liveId,
              userId: 'current_user_id', // À remplacer
              onGiftSent: _handleGiftSent,
            ),

            // Overlay spécial hôte avec stats et durée
            if (widget.isHost) _buildHostOverlay(),

            // Tutoriel pour nouveaux hôtes
            if (_showTutorial) _buildTutorialOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple.withOpacity(0.3),
            Colors.pink.withOpacity(0.3),
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: _buildPlaceholderVideo(), // Plus de thumbnail
    );
  }

  Widget _buildPlaceholderVideo() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade800, Colors.pink.shade800],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'Vidéo en direct',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUIOverlay() {
    return Column(
      children: [
        // Barre du haut
        _buildTopBar(),

        const Spacer(),

        // Contrôles du bas
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Bouton retour
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),

            const SizedBox(width: 16),

            // Informations du live
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentLive!.hostName ?? 'Live en cours',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentLive!.viewerCount}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Boutons d'action pour l'hôte
            if (widget.isHost) ...[
              GestureDetector(
                onTap: () => setState(() => _showStats = !_showStats),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _endLive,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Bouton de toggle chat
          GestureDetector(
            onTap: () => setState(() => _showChat = !_showChat),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showChat ? Icons.chat : Icons.chat_outlined,
                color: Colors.white,
              ),
            ),
          ),

          const Spacer(),

          // Boutons de réaction
          Row(
            children: [
              reactions.FloatingLikesWidget(
                onTap: () => _handleReaction(reactions.ReactionType.heart),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _handleReaction(reactions.ReactionType.star),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: MediaQuery.of(context).size.height * 0.5,
      child: EnhancedChatWidget(liveId: widget.liveId, isHost: widget.isHost),
    );
  }

  Widget _buildStatsOverlay() {
    return Positioned(
      top: 100,
      right: 16,
      child: LiveStatsWidget(
        liveId: widget.liveId,
        onClose: () => setState(() => _showStats = false),
      ),
    );
  }

  Widget _buildHostOverlay() {
    final duration = _formatDuration(_liveDuration);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Durée du live
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: Colors.white, size: 8),
                const SizedBox(width: 6),
                Text(
                  'EN DIRECT • $duration',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Stats rapides pour l'hôte
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow(
                  Icons.visibility,
                  '${_currentLive!.viewerCount}',
                  'spectateurs',
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                  Icons.favorite,
                  '${_currentLive!.likeCount}',
                  'likes',
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                  Icons.card_giftcard,
                  '0',
                  'cadeaux',
                ), // TODO: ajouter gift count
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTutorialOverlay() {
    final tutorialSteps = [
      {
        'title': 'Bienvenue dans votre live !',
        'description':
            'Vous êtes maintenant en direct. Vos spectateurs peuvent vous voir et vous entendre.',
        'icon': Icons.live_tv,
      },
      {
        'title': 'Interagissez avec votre audience',
        'description':
            'Répondez aux messages du chat et utilisez les réactions pour créer de l\'engagement.',
        'icon': Icons.chat_bubble,
      },
      {
        'title': 'Surveillez vos statistiques',
        'description':
            'Gardez un œil sur le nombre de spectateurs et la durée de votre live en haut à gauche.',
        'icon': Icons.analytics,
      },
    ];

    final currentStep = tutorialSteps[_currentTutorialStep];

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  currentStep['icon'] as IconData,
                  color: Colors.purple,
                  size: 48,
                ),

                const SizedBox(height: 16),

                Text(
                  currentStep['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  currentStep['description'] as String,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    if (_currentTutorialStep > 0)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentTutorialStep--;
                          });
                        },
                        child: const Text('Précédent'),
                      ),

                    const Spacer(),

                    // Indicateurs de progression
                    Row(
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentTutorialStep
                                ? Colors.purple
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    ElevatedButton(
                      onPressed: _nextTutorialStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                      child: Text(
                        _currentTutorialStep < 2 ? 'Suivant' : 'Commencer',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: _completeTutorial,
                  child: const Text(
                    'Passer le tutoriel',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
