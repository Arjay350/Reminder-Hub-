import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackService {
  FeedbackService._();

  static const String feedbackFormUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLSfLA1Q_pQDzUU9SiQygXEqBHpW7dyFFAffIcIiSh0CaKxusHg/viewform?usp=header';

  static Uri? get responderUri {
    final uri = Uri.tryParse(feedbackFormUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'docs.google.com' ||
        !uri.path.startsWith('/forms/d/e/') ||
        !uri.path.endsWith('/viewform')) {
      return null;
    }
    return uri;
  }

  static Future<bool> openFeedbackForm() async {
    final uri = responderUri;
    if (uri == null) {
      throw const FormatException('The feedback form URL is invalid.');
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      debugPrint('Could not open the feedback form: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
