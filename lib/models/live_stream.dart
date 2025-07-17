import 'package:flutter/material.dart';

enum MessageType { text, gift, system, like, join, leave }

enum LiveStatus { pending, live, ended }

class LiveStream {
  final String id;
  final String hostId;
  final String? hostName;
  final String? hostAvatar;
  final int viewerCount;
  final int likeCount;
  final int giftCount;
  final bool isLive;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool isPrivate;
  final int maxViewers;
  final Map<String, dynamic>? metadata;
  final String? agoraChannelId;
  final String? agoraToken;
  final double? duration;
  final List<LiveStreamMessage>? recentMessages;

  LiveStream({
    required this.id,
    required this.hostId,
    this.hostName,
    this.hostAvatar,
    this.viewerCount = 0,
    this.likeCount = 0,
    this.giftCount = 0,
    this.isLive = false,
    this.startedAt,
    this.endedAt,
    this.isPrivate = false,
    this.maxViewers = 1000,
    this.metadata,
    this.agoraChannelId,
    this.agoraToken,
    this.duration,
    this.recentMessages,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      id: json['id'] as String,
      hostId: json['host_id'] as String? ?? '',
      hostName: json['host_name'] as String?,
      hostAvatar: json['host_avatar'] as String?,
      viewerCount: json['viewer_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      giftCount: json['gift_count'] as int? ?? 0,
      isLive: json['is_live'] as bool? ?? false,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'])
          : null,
      isPrivate: json['is_private'] as bool? ?? false,
      maxViewers: json['max_viewers'] as int? ?? 1000,
      metadata: json['metadata'] as Map<String, dynamic>?,
      agoraChannelId: json['agora_channel_id'] as String?,
      agoraToken: json['agora_token'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      recentMessages: json['recent_messages'] != null
          ? (json['recent_messages'] as List)
                .map((msg) => LiveStreamMessage.fromJson(msg))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host_id': hostId,
      'host_name': hostName,
      'host_avatar': hostAvatar,
      'viewer_count': viewerCount,
      'like_count': likeCount,
      'gift_count': giftCount,
      'is_live': isLive,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'is_private': isPrivate,
      'max_viewers': maxViewers,
      'metadata': metadata,
      'agora_channel_id': agoraChannelId,
      'agora_token': agoraToken,
      'duration': duration,
      'recent_messages': recentMessages?.map((e) => e.toJson()).toList(),
    };
  }

  LiveStream copyWith({
    String? id,
    String? hostId,
    String? hostName,
    String? hostAvatar,
    int? viewerCount,
    int? likeCount,
    int? giftCount,
    bool? isLive,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? isPrivate,
    int? maxViewers,
    Map<String, dynamic>? metadata,
    String? agoraChannelId,
    String? agoraToken,
    double? duration,
    List<LiveStreamMessage>? recentMessages,
  }) {
    return LiveStream(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      giftCount: giftCount ?? this.giftCount,
      isLive: isLive ?? this.isLive,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      isPrivate: isPrivate ?? this.isPrivate,
      maxViewers: maxViewers ?? this.maxViewers,
      metadata: metadata ?? this.metadata,
      agoraChannelId: agoraChannelId ?? this.agoraChannelId,
      agoraToken: agoraToken ?? this.agoraToken,
      duration: duration ?? this.duration,
      recentMessages: recentMessages ?? this.recentMessages,
    );
  }

  // ⏱️ Formatted duration for UI (00:00 / 1:23:45)
  String get formattedDuration {
    if (startedAt == null) return '0:00';
    final now = endedAt ?? DateTime.now();
    final duration = now.difference(startedAt!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // 👁 Formatted viewers like 12.4K or 1.2M
  String get formattedViewerCount {
    if (viewerCount < 1000) return viewerCount.toString();
    if (viewerCount < 1000000)
      return '${(viewerCount / 1000).toStringAsFixed(1)}K';
    return '${(viewerCount / 1000000).toStringAsFixed(1)}M';
  }

  // ✅ Helpers
  bool get isEnded => endedAt != null;
  bool get isOngoing => isLive && startedAt != null && endedAt == null;
  LiveStatus get status => isEnded
      ? LiveStatus.ended
      : isOngoing
      ? LiveStatus.live
      : LiveStatus.pending;
}

class LiveStreamMessage {
  final String id;
  final String liveId;
  final String userId;
  final String? username;
  final String? userAvatar;
  final String message;
  final DateTime createdAt;
  final MessageType type;
  final Map<String, dynamic>? metadata;

  LiveStreamMessage({
    required this.id,
    required this.liveId,
    required this.userId,
    this.username,
    this.userAvatar,
    required this.message,
    required this.createdAt,
    this.type = MessageType.text,
    this.metadata,
  });

  factory LiveStreamMessage.fromJson(Map<String, dynamic> json) {
    return LiveStreamMessage(
      id: json['id'] as String,
      liveId: json['live_id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      userAvatar: json['user_avatar'] as String?,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at']),
      type: MessageType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => MessageType.text,
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'live_id': liveId,
      'user_id': userId,
      'username': username,
      'user_avatar': userAvatar,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'type': type.name,
      'metadata': metadata,
    };
  }
}

class LiveStreamGift {
  final String id;
  final String name;
  final String icon;
  final int cost;
  final String animation;
  final Color color;
  final Map<String, dynamic>? effects;

  LiveStreamGift({
    required this.id,
    required this.name,
    required this.icon,
    required this.cost,
    required this.animation,
    required this.color,
    this.effects,
  });

  factory LiveStreamGift.fromJson(Map<String, dynamic> json) {
    return LiveStreamGift(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      cost: json['cost'],
      animation: json['animation'],
      color: Color(json['color']),
      effects: json['effects'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'cost': cost,
      'animation': animation,
      'color': color.value,
      'effects': effects,
    };
  }
}
