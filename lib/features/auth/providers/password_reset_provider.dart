import 'dart:async';
import 'package:flutter/material.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/global/core/services/toast_service.dart';

class PasswordResetProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _resetEmail;
  String? get resetEmail => _resetEmail;

  String? _resetCode;
  String? get resetCode => _resetCode;

  int _resendTimerSeconds = 0;
  Timer? _resendTimer;

  int get resendTimerSeconds => _resendTimerSeconds;
  bool get canResendCode => _resendTimerSeconds == 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<bool> forgotPassword(String email) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.forgotPasswordUrl,
      body: {'email': email},
    );

    if (response.isSuccess) {
      _resetEmail = email;
      isSuccess = true;
      ToastService.showSuccess("OTP sent to your email!");
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Failed to send OTP');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<bool> verifyResetOtp(String email, String code) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.verifyResetOtpUrl,
      body: {'email': email, 'code': code},
    );

    if (response.isSuccess) {
      isSuccess = true;
      _resetEmail = email;
      _resetCode = code;
      ToastService.showSuccess("OTP verified successfully!");
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'OTP verification failed');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<bool> resetPassword(String email, String code, String newPassword) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.resetPasswordUrl,
      body: {'email': email, 'code': code, 'newPassword': newPassword},
    );

    if (response.isSuccess) {
      isSuccess = true;
      _resetEmail = null;
      ToastService.showSuccess("Password reset successfully!");
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Password reset failed');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  void startResendTimer() {
    _resendTimerSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        _resendTimerSeconds--;
        notifyListeners();
      } else {
        _resendTimer?.cancel();
      }
    });
    notifyListeners();
  }
}
