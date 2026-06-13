import 'package:edtech/features/courses/data/entities/course_entity.dart';

class CourseModel extends CourseEntity {
  const CourseModel({
    required super.id,
    required super.title,
    required super.description,
    required super.instructorName,
    required super.instructorTitle,
    super.level,
    super.language,
    super.price,
    super.rating,
    super.videosCount,
    super.resourcesCount,
    super.thumbnailUrl,
    super.modules,
    super.reviews,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      instructorName: json['instructor_name'] ?? '',
      instructorTitle: json['instructor_title'] ?? '',
    );
  }
}
