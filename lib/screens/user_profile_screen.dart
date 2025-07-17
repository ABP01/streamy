import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/settings_screen.dart';
import '../services/follow_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.isCurrentUser = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Simuler le chargement du profil utilisateur
      // Dans un vrai projet, vous utiliseriez un service pour récupérer les données
      await Future.delayed(const Duration(seconds: 1));

      // Exemple de données simulées
      final profile = UserProfile(
        id: widget.userId,
        email: 'user@example.com',
        username: 'user_example',
        fullName: 'Utilisateur Exemple',
        avatar: null,
        bio:
            'Passionné de streaming et de technologie. J\'aime partager mes connaissances et découvrir de nouvelles choses.',
        followers: 1250,
        following: 345,
        totalLikes: 15620,
        totalGifts: 250,
        tokensBalance: 1000,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        isVerified: true,
        isModerator: false,
        preferences: {},
      );

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }

      // Charger le statut de follow si ce n'est pas l'utilisateur courant
      if (!widget.isCurrentUser) {
        _checkFollowStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    try {
      final isFollowing = await FollowService.isFollowing(widget.userId);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    } catch (e) {
      print('Erreur vérification follow: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoadingFollow) return;

    setState(() {
      _isLoadingFollow = true;
    });

    try {
      bool success;
      if (_isFollowing) {
        success = await FollowService.unfollowUser(widget.userId);
      } else {
        success = await FollowService.followUser(widget.userId);
      }

      if (success && mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          if (_userProfile != null) {
            _userProfile = UserProfile(
              id: _userProfile!.id,
              email: _userProfile!.email,
              username: _userProfile!.username,
              fullName: _userProfile!.fullName,
              avatar: _userProfile!.avatar,
              bio: _userProfile!.bio,
              followers: _isFollowing
                  ? _userProfile!.followers + 1
                  : _userProfile!.followers - 1,
              following: _userProfile!.following,
              totalLikes: _userProfile!.totalLikes,
              totalGifts: _userProfile!.totalGifts,
              tokensBalance: _userProfile!.tokensBalance,
              createdAt: _userProfile!.createdAt,
              lastSeen: _userProfile!.lastSeen,
              isVerified: _userProfile!.isVerified,
              isModerator: _userProfile!.isModerator,
              preferences: _userProfile!.preferences,
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowing
                  ? 'Vous suivez maintenant ${_userProfile?.displayName}'
                  : 'Vous ne suivez plus ${_userProfile?.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    if (_userProfile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Profil non trouvé',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
              ),
              actions: [
                if (!widget.isCurrentUser)
                  IconButton(
                    onPressed: () => _showMoreOptions(),
                    icon: const Icon(Icons.more_vert),
                  ),
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  tabs: const [
                    Tab(icon: Icon(Icons.video_library), text: 'Lives'),
                    Tab(icon: Icon(Icons.card_giftcard), text: 'Cadeaux'),
                    Tab(icon: Icon(Icons.info), text: 'À propos'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_buildLivesTab(), _buildGiftsTab(), _buildAboutTab()],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.withOpacity(0.3), Colors.black],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      _userProfile!.avatar != null &&
                          _userProfile!.avatar!.isNotEmpty
                      ? CachedNetworkImageProvider(_userProfile!.avatar!)
                      : null,
                  child:
                      _userProfile!.avatar == null ||
                          _userProfile!.avatar!.isEmpty
                      ? Text(
                          _userProfile!.displayName
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),

                // Nom et badge vérifié
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _userProfile!.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_userProfile!.isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Colors.blue, size: 24),
                    ],
                  ],
                ),

                // Username
                if (_userProfile!.username != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@${_userProfile!.username}',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],

                const SizedBox(height: 16),

                // Statistiques
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('Followers', _userProfile!.followers),
                    _buildStatColumn('Following', _userProfile!.following),
                    _buildStatColumn('Likes', _userProfile!.totalLikes),
                  ],
                ),

                const SizedBox(height: 20),

                // Boutons d'action
                if (!widget.isCurrentUser)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFollowButton(),
                      _buildMessageButton(),
                      _buildGiftButton(),
                    ],
                  ),

                // Bouton paramètres pour l'utilisateur actuel
                if (widget.isCurrentUser)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.settings),
                        label: const Text('Paramètres'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value) {
    return Column(
      children: [
        Text(
          _formatNumber(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildFollowButton() {
    return ElevatedButton(
      onPressed: _isLoadingFollow ? null : _toggleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey[700] : Colors.blue,
        foregroundColor: Colors.white,
      ),
      child: _isLoadingFollow
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Text(_isFollowing ? 'Suivi' : 'Suivre'),
    );
  }

  Widget _buildMessageButton() {
    return ElevatedButton.icon(
      onPressed: () {
        // TODO: Ouvrir le chat privé
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat privé - À implémenter')),
        );
      },
      icon: const Icon(Icons.message),
      label: const Text('Message'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildGiftButton() {
    return ElevatedButton.icon(
      onPressed: () => _showGiftDialog(),
      icon: const Icon(Icons.card_giftcard),
      label: const Text('Cadeau'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildLivesTab() {
    return const Center(
      child: Text(
        'Lives de l\'utilisateur\n(À implémenter)',
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildGiftsTab() {
    return const Center(
      child: Text(
        'Cadeaux reçus/envoyés\n(À implémenter)',
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAboutTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_userProfile!.bio != null) ...[
            const Text(
              'Bio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _userProfile!.bio!,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 20),
          ],

          const Text(
            'Informations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildInfoRow('Membre depuis', _formatDate(_userProfile!.createdAt)),
          _buildInfoRow('Total likes', _formatNumber(_userProfile!.totalLikes)),
          _buildInfoRow(
            'Total cadeaux',
            _formatNumber(_userProfile!.totalGifts),
          ),
          if (_userProfile!.isModerator)
            _buildInfoRow('Statut', 'Modérateur', color: Colors.orange),
          if (_userProfile!.isVerified)
            _buildInfoRow('Vérifié', 'Oui', color: Colors.blue),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: const Text(
                  'Signaler',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text(
                  'Bloquer',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGiftDialog() {
    // TODO: Implémenter la dialog de cadeaux
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Envoyer un cadeau',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Fonctionnalité de cadeaux à implémenter',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Signaler cet utilisateur',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Fonctionnalité de signalement à implémenter',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Signaler',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Bloquer cet utilisateur',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir bloquer cet utilisateur ?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bloquer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatDate(DateTime date) {
    final months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.black, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
