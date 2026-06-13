import 'package:flutter/material.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';

class CourseListProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<dynamic> _courses = [];
  List<dynamic> get courses => _courses;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCourses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller().getRequest(
      url: Urls.courseDetailsUrl(''),
    );

    if (response.isSuccess) {
      _courses = response.responseData['data'] as List<dynamic>? ?? [];
    } else {
      _errorMessage = response.errorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }
}
