import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:attend_mobile/features/attendance/presentation/branch_time_formatter.dart';

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    await initializeDateFormatting('en');
  });

  test('formats a Riyadh branch schedule independently of device timezone', () {
    final result = BranchTimeFormatter.formatRange(
      startsAt: DateTime.utc(2026, 9, 20, 8),
      endsAt: DateTime.utc(2026, 9, 20, 16),
      timezone: 'Asia/Riyadh',
      locale: 'en',
    );

    expect(result, '11:00 AM - 07:00 PM');
  });

  test('gracefully falls back to raw dates without throwing on invalid timezone', () {
    final result = BranchTimeFormatter.formatRange(
      startsAt: DateTime.utc(2026, 9, 20, 8),
      endsAt: DateTime.utc(2026, 9, 20, 16),
      timezone: 'Invalid/NonExistent_Zone',
      locale: 'en',
    );

    expect(result, contains('-'));
  });
}
