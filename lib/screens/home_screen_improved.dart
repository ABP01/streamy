import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/live_stream.dart';
import '../services/live_join_service.dart';
import '../services/live_stream_service.dart';
import 'live_stream_screen.dart';
import 'start_live_screen.dart';
import 'user_profile_screen.dart';

class HomeScreenImproved extends StatefulWidget {
  const HomeScreenImproved({super.key});

  @override
  State<HomeScreenImproved> createState() => _HomeScreenImprovedState();
}

class _HomeScreenImprovedState extends State<HomeScreenImproved>
    with SingleTickerProviderStateMixin {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final PageController _pageController = PageController();

  List<LiveStream> _liveStreams = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  int _currentIndex = 0;

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

    _fabAnimationController.forward();
  }

  void _setupAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadLiveStreams(showLoading: false);
    });
  }

  Future<void> _loadLiveStreams({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final lives = await _liveStreamService.fetchLiveStreams();
      if (mounted) {
        setState(() {
          _liveStreams = lives;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Erreur lors du chargement des lives: $e';
        });
      }
    }
  }

  void _joinLive(LiveStream live) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(liveId: live.id, isHost: false),
      ),
    );
  }

  void _startLive() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour démarrer un live'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const StartLiveScreen()));

    if (result == true) {
      _loadLiveStreams();
    }
  }

  void _showUserProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const UserProfileScreen()));
  }

  void _showJoinLiveDialog() {
    LiveJoinService.showJoinLiveDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const UserAvatar(size: 35, showOnlineIndicator: true),
        onPressed: _showUserProfile,
      ),
      title: const Text(
        'Streamy',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.link, color: Colors.white),
          tooltip: 'Rejoindre un live',
          onPressed: _showJoinLiveDialog,
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          tooltip: 'Rechercher',
          onPressed: () {
            // TODO: Implémenter la recherche
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recherche - À venir')),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) async {
            switch (value) {
              case 'logout':
                await Supabase.instance.client.auth.signOut();
                break;
              case 'refresh':
                _loadLiveStreams();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('Actualiser'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Déconnexion'),
                ],
              ),
            ),
          ],
        ),
      ],
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
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLiveStreams,
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
            const Icon(Icons.videocam_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Aucun live en cours',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Soyez le premier à démarrer un live !',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startLive,
              icon: const Icon(Icons.videocam),
              label: const Text('Démarrer un live'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      itemCount: _liveStreams.length,
      itemBuilder: (context, index) {
        final live = _liveStreams[index];
        return _buildLiveCard(live, index);
      },
    );
  }

  Widget _buildLiveCard(LiveStream live, int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.darkGradient,
        image: live.thumbnail != null
            ? DecorationImage(
                image: NetworkImage(live.thumbnail!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Contenu principal
            Positioned(
              left: 16,
              bottom: 120,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nom de l'utilisateur
                  Row(
                    children: [
                      UserAvatar(
                        username: live.hostName ?? 'Utilisateur',
                        size: 40,
                        showOnlineIndicator: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              live.hostName ?? 'Utilisateur',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              live.startedAt != null
                                  ? AppUtils.formatTimeAgo(live.startedAt!)
                                  : 'En direct',
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

                  // Titre du live
                  Text(
                    live.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (live.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      live.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Stats du live
                  Row(
                    children: [
                      _buildStatChip(
                        Icons.visibility,
                        AppUtils.formatNumber(live.viewerCount),
                      ),
                      const SizedBox(width: 12),
                      _buildStatChip(
                        Icons.favorite,
                        AppUtils.formatNumber(live.likeCount),
                      ),
                      if (live.giftCount > 0) ...[
                        const SizedBox(width: 12),
                        _buildStatChip(
                          Icons.card_giftcard,
                          AppUtils.formatNumber(live.giftCount),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions à droite
            Positioned(
              right: 16,
              bottom: 120,
              child: Column(
                children: [
                  _buildActionButton(
                    Icons.play_arrow,
                    'Rejoindre',
                    () => _joinLive(live),
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(Icons.favorite_border, 'J\'aime', () {
                    // TODO: Implémenter like
                    AppUtils.hapticFeedback();
                  }),
                  const SizedBox(height: 16),
                  _buildActionButton(Icons.share, 'Partager', () {
                    // TODO: Implémenter partage
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Live ID: ${live.id}'),
                        action: SnackBarAction(
                          label: 'Copier',
                          onPressed: () {
                            // TODO: Copier dans le presse-papier
                          },
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Indicateur de page
            Positioned(
              right: 16,
              top: 100,
              child: Column(
                children: List.generate(
                  _liveStreams.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: i == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
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

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color ?? Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton(
        onPressed: _startLive,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
