import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/live_stream.dart';
import '../services/live_stream_service.dart';
import 'live_stream_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final PageController _pageController = PageController();

  List<LiveStream> _liveStreams = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadLiveStreams();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _fabAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _fabAnimationController = AnimationController(
      duration: AppAnimations.mediumDuration,
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: AppAnimations.elasticCurve,
      ),
    );
  }

  void _setupAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshLiveStreams();
      }
    });
  }

  Future<void> _loadLiveStreams() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final streams = await _liveStreamService.fetchLiveStreams();

      if (mounted) {
        setState(() {
          _liveStreams = streams.where((stream) => stream.isLive).toList();
          _isLoading = false;
        });

        // Animer le FAB après le chargement
        if (_liveStreams.isNotEmpty) {
          _fabAnimationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _refreshLiveStreams() async {
    try {
      final streams = await _liveStreamService.fetchLiveStreams();

      if (mounted) {
        setState(() {
          _liveStreams = streams.where((stream) => stream.isLive).toList();
        });
      }
    } catch (e) {
      // Ignorer les erreurs de rafraîchissement silencieuses
      print('Erreur de rafraîchissement: $e');
    }
  }

  void _navigateToLive(LiveStream live) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          liveId: live.id,
          isHost: false, // Par défaut, l'utilisateur rejoint comme spectateur
        ),
      ),
    );
  }

  void _createNewLive() {
    // Naviguer vers l'écran de création de live
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateLiveSheet(
        onLiveCreated: (live) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LiveStreamScreen(liveId: live.id, isHost: true),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: _createNewLive,
          icon: const Icon(Icons.videocam),
          label: const Text('Go Live'),
          backgroundColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Row(
        children: [
          // Logo ou titre
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Streamy',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),

          const Spacer(),

          // Indicateur de lives actifs
          if (_liveStreams.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_liveStreams.length} LIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(width: 12),

          // Menu utilisateur
          CircleAvatar(
            backgroundColor: AppTheme.surfaceColor,
            child: IconButton(
              onPressed: () {
                // Ouvrir le menu utilisateur
                showModalBottomSheet(
                  context: context,
                  builder: (context) => _UserMenuSheet(),
                );
              },
              icon: const Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text(
              'Chargement des lives...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadLiveStreams,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_liveStreams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.live_tv, size: 64, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun live en cours',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Soyez le premier à commencer un live !',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createNewLive,
              icon: const Icon(Icons.videocam),
              label: const Text('Commencer un live'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Interface à la TikTok avec défilement vertical
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (index) {
        // Page changed
      },
      itemCount: _liveStreams.length,
      itemBuilder: (context, index) {
        final live = _liveStreams[index];
        return _buildLiveStreamCard(live, index);
      },
    );
  }

  Widget _buildLiveStreamCard(LiveStream live, int index) {
    return GestureDetector(
      onTap: () => _navigateToLive(live),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Image de fond - simplifié sans thumbnail
            _buildPlaceholderBackground(),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
            ),

            // Informations du live
            Positioned(
              left: 16,
              right: 80,
              bottom: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom de l'hôte
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: live.hostAvatar,
                        username: live.hostName,
                        size: 40,
                        showOnlineIndicator: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              live.hostName ?? 'Streamer',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              AppUtils.formatTimeAgo(
                                live.startedAt ?? DateTime.now(),
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nom du streamer (plus de titre)
                  Text(
                    live.hostName ?? 'Live Stream',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Durée du live (plus de description)
                  Text(
                    'En direct depuis ${live.formattedDuration}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Plus de tags - affichons les stats du live
                  Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.white70, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '${live.viewerCount} viewers',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.favorite, color: Colors.red, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '${live.likeCount}',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Statistiques sur le côté droit
            Positioned(
              right: 16,
              bottom: 100,
              child: Column(
                children: [
                  _buildStatButton(
                    Icons.remove_red_eye,
                    AppUtils.formatNumber(live.viewerCount),
                    () => _navigateToLive(live),
                  ),
                  const SizedBox(height: 20),
                  _buildStatButton(
                    Icons.favorite,
                    AppUtils.formatNumber(live.likeCount),
                    () => _navigateToLive(live),
                  ),
                  const SizedBox(height: 20),
                  _buildStatButton(
                    Icons.card_giftcard,
                    AppUtils.formatNumber(live.giftCount),
                    () => _navigateToLive(live),
                  ),
                ],
              ),
            ),

            // Badge LIVE
            Positioned(
              top: 50,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            // Indicateur de page
            if (_liveStreams.length > 1)
              Positioned(
                right: 8,
                top: MediaQuery.of(context).size.height * 0.4,
                child: Column(
                  children: List.generate(_liveStreams.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      width: 4,
                      height: i == index ? 20 : 8,
                      decoration: BoxDecoration(
                        color: i == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
      ),
    );
  }

  Widget _buildStatButton(IconData icon, String count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Sheet pour créer un nouveau live
class _CreateLiveSheet extends StatefulWidget {
  final Function(LiveStream) onLiveCreated;

  const _CreateLiveSheet({required this.onLiveCreated});

  @override
  State<_CreateLiveSheet> createState() => _CreateLiveSheetState();
}

class _CreateLiveSheetState extends State<_CreateLiveSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Titre
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Nouveau Live',
                  style: TextStyle(
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

          // Formulaire
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Titre du live',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'Entrez un titre accrocheur...',
                    ),
                    maxLength: 50,
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'Décrivez votre live...',
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),

                  const Spacer(),

                  ElevatedButton.icon(
                    onPressed: _isCreating ? null : _createLive,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.videocam),
                    label: Text(
                      _isCreating ? 'Création...' : 'Commencer le live',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  Future<void> _createLive() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Veuillez entrer un titre')));
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final liveStreamService = LiveStreamService();
      final live = await liveStreamService.createLiveStream(
        hostId: 'current_user_id', // À remplacer par l'ID utilisateur réel
        isPrivate: false,
      );

      Navigator.pop(context);
      widget.onLiveCreated(live);
    } catch (e) {
      setState(() {
        _isCreating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }
}

// Sheet pour le menu utilisateur
class _UserMenuSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: const Text('Profil', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // Naviguer vers le profil
            },
          ),

          ListTile(
            leading: const Icon(Icons.history, color: Colors.white),
            title: const Text(
              'Historique',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              // Naviguer vers l'historique
            },
          ),

          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white),
            title: const Text(
              'Paramètres',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              // Naviguer vers les paramètres
            },
          ),

          const Divider(color: Colors.grey),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              // Déconnexion
            },
          ),
        ],
      ),
    );
  }
}
