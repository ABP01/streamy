class Story {
  final String id;
  final String userName;
  final String userAvatar;
  final bool isOwnStory;
  final bool isLive;

  Story({
    required this.id,
    required this.userName,
    required this.userAvatar,
    this.isOwnStory = false,
    this.isLive = false,
  });
}
