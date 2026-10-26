enum OperationKind {
  fieldMission,
  disciplinaryCase,
  grievance,
  resignation,
  clearance;

  static OperationKind fromString(String value) {
    return switch (value) {
      'field_mission' => OperationKind.fieldMission,
      'disciplinary_case' => OperationKind.disciplinaryCase,
      'grievance' => OperationKind.grievance,
      'resignation' => OperationKind.resignation,
      'clearance' => OperationKind.clearance,
      _ => OperationKind.fieldMission,
    };
  }

  String toApiString() {
    return switch (this) {
      OperationKind.fieldMission => 'field_mission',
      OperationKind.disciplinaryCase => 'disciplinary_case',
      OperationKind.grievance => 'grievance',
      OperationKind.resignation => 'resignation',
      OperationKind.clearance => 'clearance',
    };
  }

  String get labelAr {
    return switch (this) {
      OperationKind.fieldMission => 'مأمورية عمل ميدانية',
      OperationKind.disciplinaryCase => 'إجراء جزائي أو إداري',
      OperationKind.grievance => 'تظلم إداري',
      OperationKind.resignation => 'طلب استقالة',
      OperationKind.clearance => 'إخلاء طرف وتسليم عهد',
    };
  }
}

enum MissionAuthorizationState {
  pending,
  active,
  expired,
  revoked,
  rejected,
  cancelled;

  static MissionAuthorizationState fromString(String value) {
    return switch (value) {
      'active' => MissionAuthorizationState.active,
      'expired' => MissionAuthorizationState.expired,
      'revoked' => MissionAuthorizationState.revoked,
      'rejected' => MissionAuthorizationState.rejected,
      'cancelled' => MissionAuthorizationState.cancelled,
      _ => MissionAuthorizationState.pending,
    };
  }

  String get labelAr {
    return switch (this) {
      MissionAuthorizationState.pending => 'قيد المراجعة',
      MissionAuthorizationState.active => 'معتمدة وسارية',
      MissionAuthorizationState.expired => 'منتهية الصلاحية',
      MissionAuthorizationState.revoked => 'ملغاة من الإدارة',
      MissionAuthorizationState.rejected => 'مرفوضة',
      MissionAuthorizationState.cancelled => 'ملغاة من الموظف',
    };
  }
}

class FieldMissionDestination {
  final String label;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const FieldMissionDestination({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory FieldMissionDestination.fromJson(Map<String, dynamic> json) {
    return FieldMissionDestination(
      label: json['label'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radiusMeters'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      };
}

class FieldMissionDetail {
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final String? purpose;
  final FieldMissionDestination destination;
  final MissionAuthorizationState authorizationState;

  const FieldMissionDetail({
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    this.purpose,
    required this.destination,
    required this.authorizationState,
  });

  factory FieldMissionDetail.fromJson(Map<String, dynamic> json) {
    return FieldMissionDetail(
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      timezone: json['timezone'] as String? ?? 'UTC',
      purpose: json['purpose'] as String?,
      destination: FieldMissionDestination.fromJson(
          json['destination'] as Map<String, dynamic>? ?? {}),
      authorizationState: MissionAuthorizationState.fromString(
          json['authorizationState'] as String? ?? 'pending'),
    );
  }

  Map<String, dynamic> toJson() => {
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'timezone': timezone,
        if (purpose != null) 'purpose': purpose,
        'destination': destination.toJson(),
        'authorizationState': authorizationState.name,
      };
}

class TimelineItem {
  final String id;
  final String kind;
  final DateTime occurredAt;
  final String labelAr;
  final String? actorLabel;

  const TimelineItem({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.labelAr,
    this.actorLabel,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    return TimelineItem(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      occurredAt: DateTime.parse(
          json['occurredAt'] as String? ?? DateTime.now().toIso8601String()),
      labelAr: json['labelAr'] as String? ?? '',
      actorLabel: json['actorLabel'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'occurredAt': occurredAt.toIso8601String(),
        'labelAr': labelAr,
        if (actorLabel != null) 'actorLabel': actorLabel,
      };
}

class HrOperationSummary {
  final String id;
  final OperationKind operationKind;
  final String employeeId;
  final String? employeeName;
  final String state;
  final int revision;
  final DateTime submittedAt;
  final String? nextActionLabelAr;

  const HrOperationSummary({
    required this.id,
    required this.operationKind,
    required this.employeeId,
    this.employeeName,
    required this.state,
    required this.revision,
    required this.submittedAt,
    this.nextActionLabelAr,
  });

  factory HrOperationSummary.fromJson(Map<String, dynamic> json) {
    return HrOperationSummary(
      id: json['id'] as String? ?? '',
      operationKind: OperationKind.fromString(
          json['operationKind'] as String? ?? 'field_mission'),
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String?,
      state: json['state'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      submittedAt: DateTime.parse(
          json['submittedAt'] as String? ?? DateTime.now().toIso8601String()),
      nextActionLabelAr: json['nextActionLabelAr'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'operationKind': operationKind.toApiString(),
        'employeeId': employeeId,
        if (employeeName != null) 'employeeName': employeeName,
        'state': state,
        'revision': revision,
        'submittedAt': submittedAt.toIso8601String(),
        if (nextActionLabelAr != null) 'nextActionLabelAr': nextActionLabelAr,
      };
}

class HrOperationDetail {
  final String id;
  final OperationKind operationKind;
  final String employeeId;
  final String? employeeName;
  final String state;
  final int revision;
  final DateTime submittedAt;
  final String? nextActionLabelAr;
  final FieldMissionDetail? fieldMission;
  final DisciplinaryDetail? disciplinary;
  final ResignationDetail? resignation;
  final ClearanceCase? clearance;
  final List<TimelineItem> timeline;
  final List<String> permissions;

  const HrOperationDetail({
    required this.id,
    required this.operationKind,
    required this.employeeId,
    this.employeeName,
    required this.state,
    required this.revision,
    required this.submittedAt,
    this.nextActionLabelAr,
    this.fieldMission,
    this.disciplinary,
    this.resignation,
    this.clearance,
    this.timeline = const [],
    this.permissions = const [],
  });

  bool get canRevoke => permissions.contains('revoke_mission');
  bool get canAcknowledge => permissions.contains('acknowledge_notice');
  bool get canGrievance => permissions.contains('submit_grievance');
  bool get canDecideConsequence => permissions.contains('decide_consequence');
  bool get canDecideClearance => permissions.contains('decide_clearance_item');
  bool get canFinalizeClearance => permissions.contains('finalize_clearance');

  factory HrOperationDetail.fromJson(Map<String, dynamic> json) {
    final timelineList = (json['timeline'] as List<dynamic>? ?? [])
        .map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final permissionsList = (json['permissions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return HrOperationDetail(
      id: json['id'] as String? ?? '',
      operationKind: OperationKind.fromString(
          json['operationKind'] as String? ?? 'field_mission'),
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String?,
      state: json['state'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      submittedAt: DateTime.parse(
          json['submittedAt'] as String? ?? DateTime.now().toIso8601String()),
      nextActionLabelAr: json['nextActionLabelAr'] as String?,
      fieldMission: json['fieldMission'] != null
          ? FieldMissionDetail.fromJson(
              json['fieldMission'] as Map<String, dynamic>)
          : null,
      disciplinary: json['disciplinary'] != null
          ? DisciplinaryDetail.fromJson(
              json['disciplinary'] as Map<String, dynamic>)
          : null,
      resignation: json['resignation'] != null
          ? ResignationDetail.fromJson(
              json['resignation'] as Map<String, dynamic>)
          : null,
      clearance: json['clearance'] != null
          ? ClearanceCase.fromJson(
              json['clearance'] as Map<String, dynamic>)
          : null,
      timeline: timelineList,
      permissions: permissionsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'operationKind': operationKind.toApiString(),
        'employeeId': employeeId,
        if (employeeName != null) 'employeeName': employeeName,
        'state': state,
        'revision': revision,
        'submittedAt': submittedAt.toIso8601String(),
        if (nextActionLabelAr != null) 'nextActionLabelAr': nextActionLabelAr,
        if (fieldMission != null) 'fieldMission': fieldMission!.toJson(),
        if (disciplinary != null) 'disciplinary': disciplinary!.toJson(),
        if (resignation != null) 'resignation': resignation!.toJson(),
        if (clearance != null) 'clearance': clearance!.toJson(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'permissions': permissions,
      };
}

class Acknowledgment {
  final String id;
  final int noticeRevision;
  final DateTime acknowledgedAt;
  final String meaning;

  const Acknowledgment({
    required this.id,
    required this.noticeRevision,
    required this.acknowledgedAt,
    this.meaning = 'receipt_only',
  });

  factory Acknowledgment.fromJson(Map<String, dynamic> json) {
    return Acknowledgment(
      id: json['id'] as String? ?? '',
      noticeRevision: (json['noticeRevision'] as num?)?.toInt() ?? 1,
      acknowledgedAt: DateTime.parse(json['acknowledgedAt'] as String? ??
          DateTime.now().toIso8601String()),
      meaning: json['meaning'] as String? ?? 'receipt_only',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'noticeRevision': noticeRevision,
        'acknowledgedAt': acknowledgedAt.toIso8601String(),
        'meaning': meaning,
      };
}

class Grievance {
  final String id;
  final String state;
  final DateTime submittedAt;
  final String deadlineState;
  final String? statement;

  const Grievance({
    required this.id,
    required this.state,
    required this.submittedAt,
    required this.deadlineState,
    this.statement,
  });

  factory Grievance.fromJson(Map<String, dynamic> json) {
    return Grievance(
      id: json['id'] as String? ?? '',
      state: json['state'] as String? ?? 'submitted',
      submittedAt: DateTime.parse(json['submittedAt'] as String? ??
          DateTime.now().toIso8601String()),
      deadlineState: json['deadlineState'] as String? ?? 'on_time',
      statement: json['statement'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'state': state,
        'submittedAt': submittedAt.toIso8601String(),
        'deadlineState': deadlineState,
        if (statement != null) 'statement': statement,
      };
}

class DisciplinaryDetail {
  final String? policyTitle;
  final DateTime? incidentAt;
  final int noticeRevision;
  final String acknowledgmentState;
  final DateTime? grievanceDueAt;
  final List<Grievance> grievances;
  final String consequenceState;

  const DisciplinaryDetail({
    this.policyTitle,
    this.incidentAt,
    required this.noticeRevision,
    required this.acknowledgmentState,
    this.grievanceDueAt,
    this.grievances = const [],
    required this.consequenceState,
  });

  bool get isAcknowledged => acknowledgmentState == 'acknowledged';

  factory DisciplinaryDetail.fromJson(Map<String, dynamic> json) {
    final grievancesList = (json['grievances'] as List<dynamic>? ?? [])
        .map((g) => Grievance.fromJson(g as Map<String, dynamic>))
        .toList();

    return DisciplinaryDetail(
      policyTitle: json['policyTitle'] as String?,
      incidentAt: json['incidentAt'] != null
          ? DateTime.parse(json['incidentAt'] as String)
          : null,
      noticeRevision: (json['noticeRevision'] as num?)?.toInt() ?? 1,
      acknowledgmentState:
          json['acknowledgmentState'] as String? ?? 'not_acknowledged',
      grievanceDueAt: json['grievanceDueAt'] != null
          ? DateTime.parse(json['grievanceDueAt'] as String)
          : null,
      grievances: grievancesList,
      consequenceState: json['consequenceState'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() => {
        if (policyTitle != null) 'policyTitle': policyTitle,
        if (incidentAt != null) 'incidentAt': incidentAt!.toIso8601String(),
        'noticeRevision': noticeRevision,
        'acknowledgmentState': acknowledgmentState,
        if (grievanceDueAt != null)
          'grievanceDueAt': grievanceDueAt!.toIso8601String(),
        'grievances': grievances.map((g) => g.toJson()).toList(),
        'consequenceState': consequenceState,
      };
}

class ConsequencePreview {
  final String postingState;
  final String method;
  final int amountMinor;
  final String currency;
  final String? explanationAr;

  const ConsequencePreview({
    this.postingState = 'not_posted',
    required this.method,
    required this.amountMinor,
    required this.currency,
    this.explanationAr,
  });

  factory ConsequencePreview.fromJson(Map<String, dynamic> json) {
    return ConsequencePreview(
      postingState: json['postingState'] as String? ?? 'not_posted',
      method: json['method'] as String? ?? 'fixed',
      amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'EGP',
      explanationAr: json['explanationAr'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'postingState': postingState,
        'method': method,
        'amountMinor': amountMinor,
        'currency': currency,
        if (explanationAr != null) 'explanationAr': explanationAr,
      };
}

class ConsequenceDecision {
  final String id;
  final String state;
  final int amountMinor;
  final String currency;
  final String? financialAdjustmentId;
  final DateTime decidedAt;

  const ConsequenceDecision({
    required this.id,
    required this.state,
    required this.amountMinor,
    required this.currency,
    this.financialAdjustmentId,
    required this.decidedAt,
  });

  factory ConsequenceDecision.fromJson(Map<String, dynamic> json) {
    return ConsequenceDecision(
      id: json['id'] as String? ?? '',
      state: json['state'] as String? ?? 'approved',
      amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'EGP',
      financialAdjustmentId: json['financialAdjustmentId'] as String?,
      decidedAt: DateTime.parse(json['decidedAt'] as String? ??
          DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'state': state,
        'amountMinor': amountMinor,
        'currency': currency,
        if (financialAdjustmentId != null)
          'financialAdjustmentId': financialAdjustmentId,
        'decidedAt': decidedAt.toIso8601String(),
      };
}

class ResignationDetail {
  final DateTime requestedLastWorkingDate;
  final DateTime? approvedLastWorkingDate;
  final int noticeDays;
  final String state;

  const ResignationDetail({
    required this.requestedLastWorkingDate,
    this.approvedLastWorkingDate,
    required this.noticeDays,
    required this.state,
  });

  factory ResignationDetail.fromJson(Map<String, dynamic> json) {
    return ResignationDetail(
      requestedLastWorkingDate: DateTime.parse(
          json['requestedLastWorkingDate'] as String),
      approvedLastWorkingDate: json['approvedLastWorkingDate'] != null
          ? DateTime.parse(json['approvedLastWorkingDate'] as String)
          : null,
      noticeDays: (json['noticeDays'] as num?)?.toInt() ?? 30,
      state: json['state'] as String? ?? 'submitted',
    );
  }

  Map<String, dynamic> toJson() => {
        'requestedLastWorkingDate':
            requestedLastWorkingDate.toIso8601String(),
        if (approvedLastWorkingDate != null)
          'approvedLastWorkingDate':
              approvedLastWorkingDate!.toIso8601String(),
        'noticeDays': noticeDays,
        'state': state,
      };
}

class ClearanceItem {
  final String id;
  final String titleAr;
  final bool mandatory;
  final bool evidenceRequired;
  final String state;
  final int revision;
  final String? assigneeLabel;
  final DateTime? dueAt;

  const ClearanceItem({
    required this.id,
    required this.titleAr,
    required this.mandatory,
    required this.evidenceRequired,
    required this.state,
    required this.revision,
    this.assigneeLabel,
    this.dueAt,
  });

  bool get isCompleted => state == 'completed' || state == 'waived';
  bool get isPendingOrBlocked => state == 'pending' || state == 'blocked';

  factory ClearanceItem.fromJson(Map<String, dynamic> json) {
    return ClearanceItem(
      id: json['id'] as String? ?? '',
      titleAr: json['titleAr'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      evidenceRequired: json['evidenceRequired'] as bool? ?? false,
      state: json['state'] as String? ?? 'pending',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      assigneeLabel: json['assigneeLabel'] as String?,
      dueAt: json['dueAt'] != null
          ? DateTime.parse(json['dueAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'mandatory': mandatory,
        'evidenceRequired': evidenceRequired,
        'state': state,
        'revision': revision,
        if (assigneeLabel != null) 'assigneeLabel': assigneeLabel,
        if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
      };
}

class ClearanceCase {
  final String id;
  final String employeeId;
  final String state;
  final int revision;
  final DateTime? targetLastWorkingDate;
  final List<ClearanceItem> items;
  final Map<String, String> handoffs;

  const ClearanceCase({
    required this.id,
    required this.employeeId,
    required this.state,
    required this.revision,
    this.targetLastWorkingDate,
    required this.items,
    this.handoffs = const {},
  });

  bool get isReadyOrCompleted => state == 'ready' || state == 'completed';

  int get completedCount => items.where((i) => i.isCompleted).length;
  int get mandatoryOutstandingCount =>
      items.where((i) => i.mandatory && !i.isCompleted).length;

  factory ClearanceCase.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((i) => ClearanceItem.fromJson(i as Map<String, dynamic>))
        .toList();
    final rawHandoffs = json['handoffs'] as Map<String, dynamic>? ?? {};
    final handoffsMap = rawHandoffs.map((k, v) => MapEntry(k, v.toString()));

    return ClearanceCase(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      state: json['state'] as String? ?? 'not_started',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      targetLastWorkingDate: json['targetLastWorkingDate'] != null
          ? DateTime.parse(json['targetLastWorkingDate'] as String)
          : null,
      items: itemsList,
      handoffs: handoffsMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'state': state,
        'revision': revision,
        if (targetLastWorkingDate != null)
          'targetLastWorkingDate':
              targetLastWorkingDate!.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'handoffs': handoffs,
      };
}


