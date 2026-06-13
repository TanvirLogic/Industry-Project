import 'package:flutter/material.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/global/core/services/toast_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpProvider extends ChangeNotifier {
  bool _inProgress = false;
  bool get inProgress => _inProgress;

  bool _isPasswordObscure = true;
  bool get isPasswordObscure => _isPasswordObscure;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void togglePasswordVisibility() {
    _isPasswordObscure = !_isPasswordObscure;
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String username,
    required String email,
    required String dob,
    required String password,
    String? phone,
    required int gender,
    required String role,
  }) async {
    bool isSuccess = false;
    _inProgress = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.signUpUrl,
      body: {
        'name': name,
        'username': username,
        'email': email,
        'dob': dob,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'gender': gender,
        'role': role,
      },
    );

    if (response.isSuccess) {
      isSuccess = true;
      _errorMessage = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_used_email', email);
      ToastService.showSuccess("Registration successful. Please verify your email.");
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Registration failed');
    }

    _inProgress = false;
    notifyListeners();
    return isSuccess;
  }
}
