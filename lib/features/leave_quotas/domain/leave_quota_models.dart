enum QuotaKey {
  dayOff('day_off'),
  timePermission('time_permission');

  final String value;
  const QuotaKey(this.value);

  static QuotaKey fromValue(String value) {
    return switch (value) {
      'day_off' => QuotaKey.dayOff,
      'time_permission' => QuotaKey.timePermission,
      _ => QuotaKey.dayOff,
    };
  }

  String get displayNameAr => switch (this) {
        QuotaKey.dayOff => 'رصيد الإجازات السنوية',
        QuotaKey.timePermission => 'رصيد أذونات الاستئذان',
      };
}

enum QuotaUnit {
  days('days'),
  minutes('minutes');

  final String value;
  const QuotaUnit(this.value);

  static QuotaUnit fromValue(String value) {
    return switch (value) {
      'days' => QuotaUnit.days,
      'minutes' => QuotaUnit.minutes,
      _ => QuotaUnit.days,
    };
  }

  String get labelAr => switch (this) {
        QuotaUnit.days => 'يوم',
        QuotaUnit.minutes => 'دقيقة',
      };
}

enum QuotaResetCycle {
  monthly('monthly'),
  annual('annual');

  final String value;
  const QuotaResetCycle(this.value);

  static QuotaResetCycle fromValue(String value) {
    return switch (value) {
      'monthly' => QuotaResetCycle.monthly,
      'annual' => QuotaResetCycle.annual,
      _ => QuotaResetCycle.monthly,
    };
  }

  String get labelAr => switch (this) {
        QuotaResetCycle.monthly => 'يتجدد شهرياً',
        QuotaResetCycle.annual => 'يتجدد سنوياً',
      };
}

class QuotaBalanceEntity {
  final QuotaKey quotaKey;
  final QuotaUnit unit;
  final int allowance;
  final QuotaResetCycle resetCycle;
  final String periodStart;
  final String periodEnd;
  final int granted;
  final int reserved;
  final int adjusted;
  final int remaining;

  const QuotaBalanceEntity({
    required this.quotaKey,
    required this.unit,
    required this.allowance,
    required this.resetCycle,
    required this.periodStart,
    required this.periodEnd,
    required this.granted,
    required this.reserved,
    required this.adjusted,
    required this.remaining,
  });

  factory QuotaBalanceEntity.fromJson(Map<String, dynamic> json) {
    return QuotaBalanceEntity(
      quotaKey: QuotaKey.fromValue(json['quotaKey'] as String? ?? 'day_off'),
      unit: QuotaUnit.fromValue(json['unit'] as String? ?? 'days'),
      allowance: (json['allowance'] as num?)?.toInt() ?? 0,
      resetCycle:
          QuotaResetCycle.fromValue(json['resetCycle'] as String? ?? 'monthly'),
      periodStart: json['periodStart'] as String? ?? '',
      periodEnd: json['periodEnd'] as String? ?? '',
      granted: (json['granted'] as num?)?.toInt() ?? 0,
      reserved: (json['reserved'] as num?)?.toInt() ?? 0,
      adjusted: (json['adjusted'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedRemaining {
    if (unit == QuotaUnit.days) {
      return '$remaining يوم';
    }
    final hours = remaining ~/ 60;
    final mins = remaining % 60;
    if (hours > 0 && mins > 0) {
      return '$hours ساعة و $mins دقيقة';
    } else if (hours > 0) {
      return '$hours ساعة';
    }
    return '$remaining دقيقة';
  }

  String get formattedAllowance {
    if (unit == QuotaUnit.days) {
      return '$allowance يوم';
    }
    final hours = allowance ~/ 60;
    final mins = allowance % 60;
    if (hours > 0 && mins > 0) {
      return '$hours ساعة و $mins دقيقة';
    } else if (hours > 0) {
      return '$hours ساعة';
    }
    return '$allowance دقيقة';
  }

  String get formattedReserved {
    if (unit == QuotaUnit.days) {
      return '$reserved يوم';
    }
    return '$reserved دقيقة';
  }
}
