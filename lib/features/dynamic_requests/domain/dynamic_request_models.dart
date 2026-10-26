enum FieldKind {
  shortText,
  longText,
  integer,
  decimal,
  date,
  time,
  dateTime,
  singleChoice,
  multipleChoice,
  boolean,
  attachment,
  employeeReference,
}

class ChoiceOption {
  final String code;
  final String labelAr;

  const ChoiceOption({required this.code, required this.labelAr});

  factory ChoiceOption.fromJson(Map<String, dynamic> json) {
    return ChoiceOption(
      code: json['code'] as String? ?? '',
      labelAr: json['labelAr'] as String? ?? json['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'labelAr': labelAr,
      };
}

class RequestSelectorOption {
  final String value;
  final String label;
  final String? subtitle;
  final Map<String, dynamic>? metadata;

  const RequestSelectorOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.metadata,
  });

  factory RequestSelectorOption.fromJson(Map<String, dynamic> json) =>
      RequestSelectorOption(
        value: json['value']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        subtitle: json['subtitle'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'value': value,
        'label': label,
        if (subtitle != null) 'subtitle': subtitle,
        if (metadata != null) 'metadata': metadata,
      };
}

class RequestFieldDataSource {
  final String source;
  final bool searchEnabled;
  final Map<String, dynamic>? filter;

  const RequestFieldDataSource({
    required this.source,
    this.searchEnabled = true,
    this.filter,
  });

  factory RequestFieldDataSource.fromJson(Map<String, dynamic> json) =>
      RequestFieldDataSource(
        source: json['source'] as String? ?? 'employees',
        searchEnabled: json['searchEnabled'] as bool? ?? true,
        filter: json['filter'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'searchEnabled': searchEnabled,
        if (filter != null) 'filter': filter,
      };
}

class FieldValidationRule {
  final num? min;
  final num? max;
  final int? minLength;
  final int? maxLength;
  final String? pattern;

  const FieldValidationRule({
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
    this.pattern,
  });

  factory FieldValidationRule.fromJson(Map<String, dynamic> json) =>
      FieldValidationRule(
        min: json['min'] as num?,
        max: json['max'] as num?,
        minLength: json['minLength'] as int?,
        maxLength: json['maxLength'] as int?,
        pattern: json['pattern'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (minLength != null) 'minLength': minLength,
        if (maxLength != null) 'maxLength': maxLength,
        if (pattern != null) 'pattern': pattern,
      };
}

class ConditionalVisibilityRule {
  final String dependsOnFieldKey;
  final String operator;
  final dynamic value;
  final List<dynamic>? values;

  const ConditionalVisibilityRule({
    required this.dependsOnFieldKey,
    this.operator = 'equals',
    this.value,
    this.values,
  });

  factory ConditionalVisibilityRule.fromJson(Map<String, dynamic> json) =>
      ConditionalVisibilityRule(
        dependsOnFieldKey: json['dependsOnFieldKey'] as String? ?? '',
        operator: json['operator'] as String? ?? 'equals',
        value: json['value'],
        values: json['values'] as List<dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'dependsOnFieldKey': dependsOnFieldKey,
        'operator': operator,
        if (value != null) 'value': value,
        if (values != null) 'values': values,
      };

  bool evaluate(Map<String, dynamic> currentFormValues) {
    final parentValue = currentFormValues[dependsOnFieldKey];
    switch (operator) {
      case 'equals':
        return parentValue?.toString() == value?.toString();
      case 'not_equals':
        return parentValue?.toString() != value?.toString();
      case 'in':
        if (values != null) {
          return values!.any((v) => v?.toString() == parentValue?.toString());
        }
        return false;
      case 'not_in':
        if (values != null) {
          return !values!.any((v) => v?.toString() == parentValue?.toString());
        }
        return true;
      case 'is_empty':
        return parentValue == null || parentValue.toString().trim().isEmpty;
      case 'is_not_empty':
        return parentValue != null && parentValue.toString().trim().isNotEmpty;
      default:
        return true;
    }
  }
}

class RequestFieldDefinition {
  final String key;
  final int position;
  final FieldKind kind;
  final String labelAr;
  final String? helpTextAr;
  final bool required;
  final List<ChoiceOption> choiceOptions;
  final RequestFieldDataSource? dataSource;
  final FieldValidationRule? validation;
  final ConditionalVisibilityRule? conditionalVisibility;

  const RequestFieldDefinition({
    required this.key,
    required this.position,
    required this.kind,
    required this.labelAr,
    this.helpTextAr,
    this.required = false,
    this.choiceOptions = const [],
    this.dataSource,
    this.validation,
    this.conditionalVisibility,
  });

  factory RequestFieldDefinition.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String? ?? 'short_text';
    final kind = switch (rawKind) {
      'long_text' => FieldKind.longText,
      'integer' => FieldKind.integer,
      'decimal' => FieldKind.decimal,
      'date' => FieldKind.date,
      'time' => FieldKind.time,
      'date_time' => FieldKind.dateTime,
      'single_choice' => FieldKind.singleChoice,
      'multiple_choice' => FieldKind.multipleChoice,
      'boolean' => FieldKind.boolean,
      'attachment' => FieldKind.attachment,
      'employee_reference' => FieldKind.employeeReference,
      _ => FieldKind.shortText,
    };

    final rawOptions = json['choiceOptions'] as List<dynamic>? ?? [];
    final choiceOptions = rawOptions
        .map((o) => ChoiceOption.fromJson(o as Map<String, dynamic>))
        .toList();

    return RequestFieldDefinition(
      key: json['key'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      kind: kind,
      labelAr: json['labelAr'] as String? ?? json['label'] as String? ?? '',
      helpTextAr: json['helpTextAr'] as String?,
      required: json['required'] as bool? ?? false,
      choiceOptions: choiceOptions,
      dataSource: json['dataSource'] != null
          ? RequestFieldDataSource.fromJson(
              json['dataSource'] as Map<String, dynamic>)
          : null,
      validation: json['validation'] != null
          ? FieldValidationRule.fromJson(
              json['validation'] as Map<String, dynamic>)
          : null,
      conditionalVisibility: json['conditionalVisibility'] != null
          ? ConditionalVisibilityRule.fromJson(
              json['conditionalVisibility'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'position': position,
        'kind': kind.name,
        'labelAr': labelAr,
        'helpTextAr': helpTextAr,
        'required': required,
        'choiceOptions': choiceOptions.map((o) => o.toJson()).toList(),
        if (dataSource != null) 'dataSource': dataSource!.toJson(),
        if (validation != null) 'validation': validation!.toJson(),
        if (conditionalVisibility != null)
          'conditionalVisibility': conditionalVisibility!.toJson(),
      };
}

class RequestTypeCategory {
  final String id;
  final String key;
  final String nameAr;
  final String descriptionAr;
  final String iconKey;
  final List<RequestFieldDefinition> fields;
  final bool offlineEligible;

  const RequestTypeCategory({
    required this.id,
    required this.key,
    required this.nameAr,
    required this.descriptionAr,
    required this.iconKey,
    this.fields = const [],
    this.offlineEligible = false,
  });

  static const List<RequestTypeCategory> builtInCategories = [
    RequestTypeCategory(
      id: 'cat-leave',
      key: 'leave',
      nameAr: 'طلب إجازة',
      descriptionAr: 'إجازة سنوية، مرضية، طارئة أو بدون راتب',
      iconKey: 'beach_access',
      fields: [
        RequestFieldDefinition(
          key: 'leave_type',
          position: 1,
          kind: FieldKind.singleChoice,
          labelAr: 'نوع الإجازة',
          required: true,
          choiceOptions: [
            ChoiceOption(code: 'annual', labelAr: 'سنوية'),
            ChoiceOption(code: 'sick', labelAr: 'مرضية'),
            ChoiceOption(code: 'emergency', labelAr: 'طارئة'),
            ChoiceOption(code: 'unpaid', labelAr: 'بدون راتب'),
          ],
        ),
        RequestFieldDefinition(
          key: 'start_date',
          position: 2,
          kind: FieldKind.date,
          labelAr: 'تاريخ البداية',
          required: true,
        ),
        RequestFieldDefinition(
          key: 'end_date',
          position: 3,
          kind: FieldKind.date,
          labelAr: 'تاريخ النهاية',
          required: true,
        ),
        RequestFieldDefinition(
          key: 'reason',
          position: 4,
          kind: FieldKind.longText,
          labelAr: 'سبب الإجازة',
          required: false,
        ),
      ],
    ),
    RequestTypeCategory(
      id: 'cat-permission',
      key: 'permission',
      nameAr: 'طلب إذن خروج',
      descriptionAr: 'استئذان مؤقت خلال ساعات العمل الرسمية',
      iconKey: 'timer',
      fields: [
        RequestFieldDefinition(
          key: 'permission_date',
          position: 1,
          kind: FieldKind.date,
          labelAr: 'تاريخ الإذن',
          required: true,
        ),
        RequestFieldDefinition(
          key: 'minutes',
          position: 2,
          kind: FieldKind.integer,
          labelAr: 'المدة بالدقائق',
          required: true,
        ),
        RequestFieldDefinition(
          key: 'reason',
          position: 3,
          kind: FieldKind.shortText,
          labelAr: 'السبب',
          required: true,
        ),
      ],
    ),
    RequestTypeCategory(
      id: 'cat-correction',
      key: 'attendance_correction',
      nameAr: 'تصحيح بصمة / حضور',
      descriptionAr: 'تصحيح وقت تسجيل الحضور أو الانصراف',
      iconKey: 'fingerprint',
      fields: [
        RequestFieldDefinition(
          key: 'target_date',
          position: 1,
          kind: FieldKind.date,
          labelAr: 'تاريخ الحضور',
          required: true,
        ),
        RequestFieldDefinition(
          key: 'correction_type',
          position: 2,
          kind: FieldKind.singleChoice,
          labelAr: 'نوع البصمة',
          required: true,
          choiceOptions: [
            ChoiceOption(code: 'check_in', labelAr: 'تسجيل دخول'),
            ChoiceOption(code: 'check_out', labelAr: 'تسجيل انصراف'),
          ],
        ),
        RequestFieldDefinition(
          key: 'actual_time',
          position: 3,
          kind: FieldKind.time,
          labelAr: 'الوقت الفعلي',
          required: true,
        ),
        RequestFieldDefinition(
          key: 'reason',
          position: 4,
          kind: FieldKind.shortText,
          labelAr: 'سبب عدم التسجيل',
          required: true,
        ),
      ],
    ),
  ];
}

class DynamicApprovalStepEntity {
  final String id;
  final int position;
  final String state;
  final String assignedRole;
  final String? assignedDisplayName;
  final String? decision;
  final String? comment;
  final DateTime? decidedAt;

  const DynamicApprovalStepEntity({
    required this.id,
    required this.position,
    required this.state,
    required this.assignedRole,
    this.assignedDisplayName,
    this.decision,
    this.comment,
    this.decidedAt,
  });

  factory DynamicApprovalStepEntity.fromJson(Map<String, dynamic> json) {
    return DynamicApprovalStepEntity(
      id: json['id'] as String? ?? '',
      position: json['position'] as int? ?? 1,
      state: json['state'] as String? ?? 'waiting',
      assignedRole: json['assignedRole'] as String? ?? '',
      assignedDisplayName: json['assignedDisplayName'] as String?,
      decision: json['decision'] as String?,
      comment: json['comment'] as String?,
      decidedAt: json['decidedAt'] != null
          ? (DateTime.tryParse(json['decidedAt'] as String) ??
              (throw FormatException(
                  'Malformed decidedAt timestamp: ${json['decidedAt']}')))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'position': position,
        'state': state,
        'assignedRole': assignedRole,
        if (assignedDisplayName != null)
          'assignedDisplayName': assignedDisplayName,
        if (decision != null) 'decision': decision,
        if (comment != null) 'comment': comment,
        if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
      };
}

class DynamicRequestEntity {
  final String id;
  final String typeKey;
  final String typeNameAr;
  final String definitionVersionId;
  final String state;
  final int revision;
  final Map<String, dynamic> values;
  final List<DynamicApprovalStepEntity> timeline;
  final DateTime submittedAt;
  final DateTime? decidedAt;
  final DateTime? cancelledAt;
  final String? reasonCode;

  const DynamicRequestEntity({
    required this.id,
    required this.typeKey,
    required this.typeNameAr,
    required this.definitionVersionId,
    required this.state,
    required this.revision,
    required this.values,
    required this.timeline,
    required this.submittedAt,
    this.decidedAt,
    this.cancelledAt,
    this.reasonCode,
  });

  factory DynamicRequestEntity.fromJson(Map<String, dynamic> json) {
    final rawTimeline = json['timeline'] as List<dynamic>? ?? [];
    final timeline = rawTimeline
        .map((step) =>
            DynamicApprovalStepEntity.fromJson(step as Map<String, dynamic>))
        .toList();

    return DynamicRequestEntity(
      id: json['id'] as String? ?? '',
      typeKey: json['typeKey'] as String? ?? '',
      typeNameAr: json['typeNameAr'] as String? ?? '',
      definitionVersionId: json['definitionVersionId'] as String? ?? '',
      state: json['state'] as String? ?? 'submitted',
      revision: json['revision'] as int? ?? 1,
      values: json['values'] is Map
          ? Map<String, dynamic>.from(json['values'] as Map)
          : <String, dynamic>{},
      timeline: timeline,
      submittedAt: json['submittedAt'] != null
          ? (DateTime.tryParse(json['submittedAt'] as String) ??
              (throw FormatException(
                  'Malformed submittedAt timestamp: ${json['submittedAt']}')))
          : throw const FormatException(
              'Missing required submittedAt timestamp'),
      decidedAt: json['decidedAt'] != null
          ? (DateTime.tryParse(json['decidedAt'] as String) ??
              (throw FormatException(
                  'Malformed decidedAt timestamp: ${json['decidedAt']}')))
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? (DateTime.tryParse(json['cancelledAt'] as String) ??
              (throw FormatException(
                  'Malformed cancelledAt timestamp: ${json['cancelledAt']}')))
          : null,
      reasonCode: json['reasonCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'typeKey': typeKey,
        'typeNameAr': typeNameAr,
        'definitionVersionId': definitionVersionId,
        'state': state,
        'revision': revision,
        'values': values,
        'timeline': timeline.map((s) => s.toJson()).toList(),
        'submittedAt': submittedAt.toIso8601String(),
        if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
        if (reasonCode != null) 'reasonCode': reasonCode,
      };
}
