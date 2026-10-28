import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/services/feedback_service.dart';

void main() {
  test('uses the configured Google Forms responder URL over HTTPS', () {
    expect(
      FeedbackService.feedbackFormUrl,
      'https://docs.google.com/forms/d/e/1FAIpQLSfLA1Q_pQDzUU9SiQygXEqBHpW7dyFFAffIcIiSh0CaKxusHg/viewform?usp=header',
    );
    expect(FeedbackService.responderUri, isNotNull);
    expect(FeedbackService.responderUri!.scheme, 'https');
    expect(FeedbackService.responderUri!.host, 'docs.google.com');
    expect(FeedbackService.responderUri!.queryParameters['usp'], 'header');
  });
}
