class StreamContent {
  final String id;
  final String title;
  final String category;
  final String thumbnail;
  final int viewerCount;
  final String streamerName;
  final String streamerAvatar;
  final bool isLive;
  final bool isPromoted;

  StreamContent({
    required this.id,
    required this.title,
    required this.category,
    required this.thumbnail,
    required this.viewerCount,
    required this.streamerName,
    required this.streamerAvatar,
    this.isLive = false,
    this.isPromoted = false,
  });
}
