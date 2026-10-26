import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Formats an instant in the branch's server-authoritative IANA timezone.
///
/// Attendance authorization remains on the server. This formatter prevents a
/// travelling employee's device timezone from making the approved schedule
/// look like a different local shift.
class BranchTimeFormatter {
  const BranchTimeFormatter._();

  static String formatRange({
    required DateTime startsAt,
    required DateTime endsAt,
    required String? timezone,
    String locale = 'ar',
  }) {
    final format = DateFormat('hh:mm a', locale);
    if (timezone == null || timezone.isEmpty) {
      return '${format.format(startsAt)} - ${format.format(endsAt)}';
    }

    try {
      final location = tz.getLocation(timezone);
      final startAtBranch = tz.TZDateTime.from(startsAt.toUtc(), location);
      final endAtBranch = tz.TZDateTime.from(endsAt.toUtc(), location);
      return '${format.format(startAtBranch)} - ${format.format(endAtBranch)}';
    } catch (_) {
      return '${format.format(startsAt)} - ${format.format(endsAt)}';
    }
  }
}
