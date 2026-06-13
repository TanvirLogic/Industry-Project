import 'package:flutter/material.dart';

/// Global SnackBar messenger — replaces deprecated fluttertoast.
///
/// Uses a [GlobalKey] wired to MaterialApp.scaffoldMessengerKey so providers
/// (which have no BuildContext) can show floating SnackBars anywhere.
class ToastService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final List<_QueuedToast> _pendingToasts = [];
  static bool _flushScheduled = false;

  static void showSuccess(String message) {
    _showSnackBar(message, Colors.green);
  }

  static void showError(String message) {
    final safeMessage = friendlyMessage(message);
    _showSnackBar(safeMessage, Colors.redAccent);
  }

  static void showInfo(String message) {
    _showSnackBar(message, Colors.blueAccent);
  }

  /// Shows a rounded, floating SnackBar at the bottom via the global key.
  static void _showSnackBar(String message, Color backgroundColor) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      _enqueueToast(message, backgroundColor);
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _enqueueToast(String message, Color backgroundColor) {
    _pendingToasts.add(_QueuedToast(message, backgroundColor));
    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      _flushPendingToasts();
    });
  }

  static void _flushPendingToasts() {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    for (final toast in List<_QueuedToast>.from(_pendingToasts)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(toast.message),
          backgroundColor: toast.backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    _pendingToasts.clear();
  }

  /// Returns a user-friendly message for raw error text.
  static String friendlyMessage(String rawMessage) {
    return _getFriendlyMessage(rawMessage);
  }

  static String _getFriendlyMessage(String rawMessage) {
    final lowerMessage = rawMessage.toLowerCase();

    if (lowerMessage.contains('connection error') ||
        lowerMessage.contains('socketexception') ||
        lowerMessage.contains('host lookup')) {
      return "Unable to connect. Please check your internet connection.";
    }

    if (lowerMessage.contains('timeout')) {
      return "The server is taking too long to respond. Please try again later.";
    }

    if (lowerMessage.contains('email_not_verified') ||
        lowerMessage.contains('email not verified')) {
      return "Please verify your email before signing in.";
    }

    if (lowerMessage.contains('session expired') ||
        lowerMessage.contains('token expired') ||
        lowerMessage.contains('refresh failed')) {
      return "Your session has expired. Please sign in again.";
    }

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection reset') ||
        lowerMessage.contains('host lookup')) {
      return "Unable to connect. Please check your internet connection.";
    }

    if (lowerMessage.contains('404')) {
      return "Requested resource not found.";
    }

    if (lowerMessage.contains('500') ||
        lowerMessage.contains('internal server error')) {
      return "Server is currently busy. Please try again in a moment.";
    }

    if (lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('forbidden')) {
      return "You do not have permission to perform this action.";
    }

    if (lowerMessage.contains('format-exception') ||
        lowerMessage.contains('unexpected character')) {
      return "Something went wrong. Please try again later.";
    }

    if (rawMessage.isEmpty) {
      return "An unexpected error occurred. Please try again.";
    }

    if (rawMessage.length > 100 || rawMessage.contains(':')) {
      return "An unexpected error occurred. Please try again.";
    }

    return rawMessage;
  }
}

class _QueuedToast {
  final String message;
  final Color backgroundColor;

  _QueuedToast(this.message, this.backgroundColor);
}
