import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static void d(String message) => _logger.d(message);
  static void i(String message) => _logger.i(message);
  static void w(String message) => _logger.w(message);
  static void e(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  static void logRequest(String method, String url, {Map<String, String>? headers, dynamic body}) {
    String logMessage = '🚀 API REQUEST: [$method] $url\n';
    if (headers != null) logMessage += 'Headers: $headers\n';
    if (body != null) logMessage += 'Body: $body';
    _logger.i(logMessage);
  }

  static void logResponse(String method, String url, int statusCode, dynamic body) {
    String logMessage = '✅ API RESPONSE: [$method] $url\n';
    logMessage += 'Status Code: $statusCode\n';
    logMessage += 'Body: $body';
    
    if (statusCode >= 200 && statusCode < 300) {
      _logger.i(logMessage);
    } else {
      _logger.e(logMessage);
    }
  }

  static void logError(String method, String url, dynamic error) {
    _logger.e('❌ API ERROR: [$method] $url\nError: $error');
  }
}
