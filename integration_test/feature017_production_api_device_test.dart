// Real production API smoke for Feature 017.
// Credentials are supplied only at execution time with --dart-define.
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _tenant = String.fromEnvironment('F017_TENANT', defaultValue: 'demo');
const _email = String.fromEnvironment(
  'F017_EMAIL',
  defaultValue: 'reviewer.employee@elabqrihr.com',
);
const _password = String.fromEnvironment('F017_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Feature 017 employee production journey uses bounded reminders',
      (tester) async {
    expect(_password, isNotEmpty,
        reason:
            'Supply F017_PASSWORD only through --dart-define at execution.');

    final storage = TokenStorage();
    final client = ApiClient(
      baseUrl: 'https://api.abqrihr.systems/api/v1',
      tokenStorage: storage,
    );

    final session = await client.login(
      tenantSlug: _tenant,
      email: _email,
      password: _password,
    );
    expect(session.tenantId, isNotEmpty);

    final reminders = await client.getAttendanceReminderFeed();
    expect(reminders['feedRevision'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(reminders['items'], isA<List<dynamic>>());

    final advances = await client.listMyAdvances();
    expect(advances.items, isNotNull);

    final corrections = await client.dio.get<Map<String, dynamic>>(
      '/requests',
      queryParameters: const {
        'type': 'attendance_correction',
        'limit': 25,
      },
    );
    expect(corrections.data?['items'], isA<List<dynamic>>());

    final settlements = await client.dio.get<Map<String, dynamic>>(
      '/final-settlements',
      queryParameters: const {'limit': 25},
    );
    expect(settlements.data?['items'], isA<List<dynamic>>());

    await storage.clearSession();
  });
}
