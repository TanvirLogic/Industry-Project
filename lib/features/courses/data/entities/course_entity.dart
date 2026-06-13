import 'module_entity.dart';
import 'review_entity.dart';

class CourseEntity {
  final String id;
  final String title;
  final String description;
  final String instructorName;
  final String instructorTitle;
  final String level;
  final String language;
  final double price;
  final double rating;
  final int videosCount;
  final int resourcesCount;
  final String thumbnailUrl;
  final List<ModuleEntity> modules;
  final List<ReviewEntity> reviews;

  const CourseEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorName,
    required this.instructorTitle,
    this.level = '',
    this.language = '',
    this.price = 0,
    this.rating = 0,
    this.videosCount = 0,
    this.resourcesCount = 0,
    this.thumbnailUrl = '',
    this.modules = const [],
    this.reviews = const [],
  });
}
