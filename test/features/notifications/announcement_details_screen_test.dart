import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/announcement_details_screen.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;

  setUp(() {
    apiClient = MockApiClient();
  });

  final sampleAnnouncement = <String, dynamic>{
    'id': 'ann-001',
    'title': 'إعلان عطلة رسمية',
    'body':
        'نحيطكم علماً بأن يوم الخميس القادم عطلة رسمية بمناسبة اليوم الوطني.',
    'sentAt': '2026-10-10T08:00:00Z',
  };

  testWidgets('renders announcement details in Arabic RTL', (tester) async {
    when(() => apiClient.readCompanyAnnouncement('ann-001'))
        .thenAnswer((_) async => sampleAnnouncement);

    await tester.pumpWidget(
      MaterialApp(
        home: AnnouncementDetailsScreen(
          announcementId: 'ann-001',
          apiClient: apiClient,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('إعلان عطلة رسمية'), findsOneWidget);
    expect(find.textContaining('نحيطكم علماً بأن يوم الخميس القادم عطلة رسمية'),
        findsOneWidget);
    expect(find.text('إعلان رسمي من إدارة الشركة'), findsOneWidget);
  });

  testWidgets('handles forbidden 403 or 404 response politely', (tester) async {
    when(() => apiClient.readCompanyAnnouncement('ann-403'))
        .thenThrow(const ApiException(
      statusCode: 403,
      message: 'Forbidden',
      code: 'FORBIDDEN',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: AnnouncementDetailsScreen(
          announcementId: 'ann-403',
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('لم يعد هذا الإعلان متاحاً لحسابك'),
        findsOneWidget);
  });
}
