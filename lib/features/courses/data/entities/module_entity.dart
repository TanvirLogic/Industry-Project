import 'lesson_entity.dart';

class ModuleEntity {
  final String title;
  final String lessonsCount;
  final List<LessonEntity> lessons;

  const ModuleEntity({
    required this.title,
    required this.lessonsCount,
    this.lessons = const [],
  });
}
