import 'package:flutter/material.dart';

import '../models/models.dart';

class LivePlayerWidget extends StatefulWidget {
  final LiveStream live;
  final bool isActive;

  const LivePlayerWidget({
    super.key,
    required this.live,
    required this.isActive,
  });

  @override
  State<LivePlayerWidget> createState() => _LivePlayerWidgetState();
}

class _LivePlayerWidgetState extends State<LivePlayerWidget> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image de fond ou placeholder
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            image: widget.live.thumbnail != null
                ? DecorationImage(
                    image: NetworkImage(widget.live.thumbnail!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: widget.live.thumbnail == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.live_tv, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'Live en cours',
                        style: TextStyle(color: Colors.grey[400], fontSize: 18),
                      ),
                    ],
                  ),
                )
              : null,
        ),

        // Overlay d'assombrissement pour améliorer la lisibilité
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
        ),

        // Badge LIVE
        if (widget.live.isLive)
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Nombre de viewers
        Positioned(
          top: 50,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.live.formattedViewerCount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Simulation d'un player vidéo en plein écran
        if (widget.isActive)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                // Actions de contrôle du player
                print('Player tapped for live: ${widget.live.title}');
              },
              child: Container(color: Colors.transparent),
            ),
          ),
      ],
    );
  }
}
