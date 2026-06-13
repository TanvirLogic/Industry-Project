class ReviewEntity {
  final String name;
  final String timeAgo;
  final int rating;
  final String comment;
  final String imageUrl;

  const ReviewEntity({
    required this.name,
    required this.timeAgo,
    required this.rating,
    required this.comment,
    required this.imageUrl,
  });
}
