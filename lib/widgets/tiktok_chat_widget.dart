import 'package:flutter/material.dart';

import '../widgets/enhanced_chat_widget.dart';

/// Widget de chat optimisé pour l'interface TikTok-style
class TikTokChatWidget extends StatefulWidget {
  final String liveId;
  final bool isHost;
  final VoidCallback? onToggleChat;

  const TikTokChatWidget({
    super.key,
    required this.liveId,
    this.isHost = false,
    this.onToggleChat,
  });

  @override
  State<TikTokChatWidget> createState() => _TikTokChatWidgetState();
}

class _TikTokChatWidgetState extends State<TikTokChatWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isExpanded ? 280 : 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.05),
            Colors.black.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Widget de chat principal
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: EnhancedChatWidget(
                liveId: widget.liveId,
                isHost: widget.isHost,
                onToggleChat: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                  widget.onToggleChat?.call();
                },
              ),
            ),
          ),

          // Bouton toggle chat en haut à droite
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
                widget.onToggleChat?.call();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),

          // Overlay de style TikTok
          if (!_isExpanded)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Appuyez pour agrandir le chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
