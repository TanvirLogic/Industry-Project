import 'package:flutter/material.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/features/courses/data/models/course_model.dart';

class CourseDetailProvider extends ChangeNotifier {
  CourseModel? _course;
  bool _isLoading = false;
  String? _errorMessage;

  CourseModel? get course => _course;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCourse(String courseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller().getRequest(
      url: Urls.courseDetailsUrl(courseId),
    );

    if (response.isSuccess) {
      _course = CourseModel.fromJson(response.responseData['data']);
    } else {
      _errorMessage = response.errorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }
}
