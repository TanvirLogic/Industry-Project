class LessonEntity {
  final String title;
  final String duration;
  final bool isLocked;

  const LessonEntity({
    required this.title,
    required this.duration,
    this.isLocked = true,
  });
}
