// Export des modèles principaux
export 'live_stream.dart';

// Modèle utilisateur
class User {
  final String id;
  final String email;
  final String? username;
  final String? fullName;
  final String? avatar;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int totalLikes;
  final int totalGifts;
  final int tokensBalance;
  final bool isVerified;
  final bool isModerator;
  final Map<String, dynamic>? preferences;
  final DateTime createdAt;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.email,
    this.username,
    this.fullName,
    this.avatar,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.totalLikes = 0,
    this.totalGifts = 0,
    this.tokensBalance = 0,
    this.isVerified = false,
    this.isModerator = false,
    this.preferences,
    required this.createdAt,
    this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      followersCount: json['followers'] as int? ?? 0,
      followingCount: json['following'] as int? ?? 0,
      totalLikes: json['total_likes'] as int? ?? 0,
      totalGifts: json['total_gifts'] as int? ?? 0,
      tokensBalance: json['tokens_balance'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isModerator: json['is_moderator'] as bool? ?? false,
      preferences: json['preferences'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar': avatar,
      'bio': bio,
      'followers': followersCount,
      'following': followingCount,
      'total_likes': totalLikes,
      'total_gifts': totalGifts,
      'tokens_balance': tokensBalance,
      'is_verified': isVerified,
      'is_moderator': isModerator,
      'preferences': preferences,
      'created_at': createdAt.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}

// Modèle de message (pour compatibilité avec l'ancien code)
class Message {
  final String id;
  final String liveId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final bool isModerated;
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    required this.liveId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.type = MessageType.text,
    required this.createdAt,
    this.isModerated = false,
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      liveId: json['live_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Anonyme',
      userAvatar: json['user_avatar'] as String?,
      content: json['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      isModerated: json['is_moderated'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'live_id': liveId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'content': content,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'is_moderated': isModerated,
      'metadata': metadata,
    };
  }
}

enum MessageType { text, gift, join, leave, like, system, moderator }

class Gift {
  final String id;
  final String liveId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String receiverId;
  final String giftType;
  final int quantity;
  final int totalCost;
  final DateTime sentAt;
  final Map<String, dynamic>? animation;

  Gift({
    required this.id,
    required this.liveId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.receiverId,
    required this.giftType,
    this.quantity = 1,
    required this.totalCost,
    required this.sentAt,
    this.animation,
  });

  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] as String,
      liveId: json['live_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderAvatar: json['sender_avatar'] as String?,
      receiverId: json['receiver_id'] as String,
      giftType: json['gift_type'] as String,
      quantity: json['quantity'] as int? ?? 1,
      totalCost: json['total_cost'] as int,
      sentAt: DateTime.parse(json['sent_at'] as String),
      animation: json['animation'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'live_id': liveId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'receiver_id': receiverId,
      'gift_type': giftType,
      'quantity': quantity,
      'total_cost': totalCost,
      'sent_at': sentAt.toIso8601String(),
      'animation': animation,
    };
  }
}

class Reaction {
  final String id;
  final String liveId;
  final String userId;
  final String userName;
  final ReactionType type;
  final DateTime createdAt;
  final double? positionX;
  final double? positionY;

  Reaction({
    required this.id,
    required this.liveId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.createdAt,
    this.positionX,
    this.positionY,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      id: json['id'] as String,
      liveId: json['live_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      type: ReactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ReactionType.like,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      positionX: json['position_x'] as double?,
      positionY: json['position_y'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'live_id': liveId,
      'user_id': userId,
      'user_name': userName,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'position_x': positionX,
      'position_y': positionY,
    };
  }
}

enum ReactionType { like, love, wow, laugh, fire, clap }

class UserProfile {
  final String id;
  final String email;
  final String? username;
  final String? fullName;
  final String? avatar;
  final String? bio;
  final int followers;
  final int following;
  final int totalLikes;
  final int totalGifts;
  final int tokensBalance;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool isVerified;
  final bool isModerator;
  final Map<String, dynamic>? preferences;

  UserProfile({
    required this.id,
    required this.email,
    this.username,
    this.fullName,
    this.avatar,
    this.bio,
    this.followers = 0,
    this.following = 0,
    this.totalLikes = 0,
    this.totalGifts = 0,
    this.tokensBalance = 0,
    required this.createdAt,
    this.lastSeen,
    this.isVerified = false,
    this.isModerator = false,
    this.preferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      followers: json['followers'] as int? ?? 0,
      following: json['following'] as int? ?? 0,
      totalLikes: json['total_likes'] as int? ?? 0,
      totalGifts: json['total_gifts'] as int? ?? 0,
      tokensBalance: json['tokens_balance'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      isVerified: json['is_verified'] as bool? ?? false,
      isModerator: json['is_moderator'] as bool? ?? false,
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar': avatar,
      'bio': bio,
      'followers': followers,
      'following': following,
      'total_likes': totalLikes,
      'total_gifts': totalGifts,
      'tokens_balance': tokensBalance,
      'created_at': createdAt.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
      'is_verified': isVerified,
      'is_moderator': isModerator,
      'preferences': preferences,
    };
  }

  String get displayName => fullName ?? username ?? email.split('@').first;
}

// Modèle pour les stories
class Story {
  final String id;
  final String userId;
  final String username;
  final String? avatar;
  final String? title;
  final bool isLive;
  final bool isViewed;
  final DateTime createdAt;

  Story({
    required this.id,
    required this.userId,
    required this.username,
    this.avatar,
    this.title,
    this.isLive = false,
    this.isViewed = false,
    required this.createdAt,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      avatar: json['avatar'] as String?,
      title: json['title'] as String?,
      isLive: json['is_live'] as bool? ?? false,
      isViewed: json['is_viewed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'avatar': avatar,
      'title': title,
      'is_live': isLive,
      'is_viewed': isViewed,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Modèle pour les contenus de stream
class StreamContent {
  final String id;
  final String title;
  final String thumbnail;
  final String username;
  final String? userAvatar;
  final String? hostId; // ID de l'hôte du stream
  final String category;
  final int viewerCount;
  final bool isLive;
  final DateTime createdAt;
  final Duration? duration;

  StreamContent({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.username,
    this.userAvatar,
    this.hostId,
    required this.category,
    this.viewerCount = 0,
    this.isLive = false,
    required this.createdAt,
    this.duration,
  });

  factory StreamContent.fromJson(Map<String, dynamic> json) {
    return StreamContent(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnail: json['thumbnail'] as String,
      username: json['username'] as String,
      userAvatar: json['user_avatar'] as String?,
      hostId: json['host_id'] as String?,
      category: json['category'] as String,
      viewerCount: json['viewer_count'] as int? ?? 0,
      isLive: json['is_live'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnail': thumbnail,
      'username': username,
      'user_avatar': userAvatar,
      'host_id': hostId,
      'category': category,
      'viewer_count': viewerCount,
      'is_live': isLive,
      'created_at': createdAt.toIso8601String(),
      'duration': duration?.inSeconds,
    };
  }
}

// Modèle pour les catégories de contenu
class ContentCategory {
  final String id;
  final String name;
  final String icon;
  final bool isSelected;

  ContentCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.isSelected = false,
  });

  ContentCategory copyWith({bool? isSelected}) {
    return ContentCategory(
      id: id,
      name: name,
      icon: icon,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
