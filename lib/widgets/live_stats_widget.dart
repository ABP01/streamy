import 'package:flutter/material.dart';

import '../services/live_stream_service.dart';

class LiveStatsWidget extends StatefulWidget {
  final String liveId;
  final bool isHost;
  final VoidCallback? onClose;

  const LiveStatsWidget({
    super.key,
    required this.liveId,
    this.isHost = false,
    this.onClose,
  });

  @override
  State<LiveStatsWidget> createState() => _LiveStatsWidgetState();
}

class _LiveStatsWidgetState extends State<LiveStatsWidget>
    with TickerProviderStateMixin {
  final LiveStreamService _liveService = LiveStreamService();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    if (mounted && widget.onClose != null) {
      widget.onClose!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(_slideAnimation),
            child: _buildStatsPanel(),
          ),
        );
      },
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Statistiques du Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _close,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Statistiques en temps réel
          StreamBuilder<LiveStats>(
            stream: _liveService.watchLiveStats(widget.liveId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorWidget();
              }

              if (!snapshot.hasData) {
                return _buildLoadingWidget();
              }

              return _buildStatsContent(snapshot.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(LiveStats stats) {
    return Column(
      children: [
        // Statistiques principales en grille
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              icon: Icons.visibility,
              label: 'Spectateurs',
              value: stats.viewerCount.toString(),
              subtitle: '${stats.activeViewers} actifs',
              color: Colors.blue,
            ),
            _buildStatCard(
              icon: Icons.favorite,
              label: 'J\'aime',
              value: stats.likeCount.toString(),
              color: Colors.red,
            ),
            _buildStatCard(
              icon: Icons.card_giftcard,
              label: 'Cadeaux',
              value: stats.giftCount.toString(),
              color: Colors.purple,
            ),
            _buildStatCard(
              icon: Icons.chat,
              label: 'Messages',
              value: stats.messageCount.toString(),
              color: Colors.green,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Durée du live
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Durée du live : ',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                stats.formattedDuration,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        if (widget.isHost) ...[
          const SizedBox(height: 20),
          _buildHostOnlyStats(stats),
        ],
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHostOnlyStats(LiveStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations hôte',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Engagement rate
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Engagement : ',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${_calculateEngagementRate(stats).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Actions rapides pour l'hôte
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Exporter les statistiques
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Exporter', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Partager le live
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Partager', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.2),
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Chargement des statistiques...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Erreur lors du chargement',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Recharger
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  double _calculateEngagementRate(LiveStats stats) {
    if (stats.viewerCount == 0) return 0.0;

    final totalInteractions =
        stats.likeCount + stats.messageCount + stats.giftCount;
    return (totalInteractions / (stats.viewerCount * 3)) * 100;
  }
}
