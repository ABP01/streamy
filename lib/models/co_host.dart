class CoHostRequest {
  final String id;
  final String liveId;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatar;
  final String hostId;
  final CoHostRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  CoHostRequest({
    required this.id,
    required this.liveId,
    required this.requesterId,
    required this.requesterName,
    this.requesterAvatar,
    required this.hostId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory CoHostRequest.fromJson(Map<String, dynamic> json) {
    return CoHostRequest(
      id: json['id'] as String,
      liveId: json['live_id'] as String,
      requesterId: json['requester_id'] as String,
      requesterName: json['requester_name'] as String,
      requesterAvatar: json['requester_avatar'] as String?,
      hostId: json['host_id'] as String,
      status: CoHostRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CoHostRequestStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'live_id': liveId,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_avatar': requesterAvatar,
      'host_id': hostId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}

enum CoHostRequestStatus { pending, accepted, rejected, canceled }

class CoHost {
  final String id;
  final String liveId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final DateTime joinedAt;
  final bool isActive;

  CoHost({
    required this.id,
    required this.liveId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.joinedAt,
    required this.isActive,
  });

  factory CoHost.fromJson(Map<String, dynamic> json) {
    return CoHost(
      id: json['id'] as String,
      liveId: json['live_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userAvatar: json['user_avatar'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'live_id': liveId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'joined_at': joinedAt.toIso8601String(),
      'is_active': isActive,
    };
  }
}
