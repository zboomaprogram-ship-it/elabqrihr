// ignore_for_file: constant_identifier_names
// Generated contract types matching specs/005-workforce-operations/contracts/openapi.yaml (OpenAPI 0.7.0)
// Covers Feature 001 Foundation, Feature 002 Requests, Feature 003 Pilot Readiness, Feature 004 Product Experience, and Feature 005 Workforce Operations.

enum EmployeeStatus {
  invited,
  active,
  inactive,
}

class EmployeeDto {
  final String id;
  final String employeeNumber;
  final String displayName;
  final String email;
  final String branchId;
  final String shiftPolicyId;
  final EmployeeStatus status;
  final String invitationToken;
  final DateTime invitationExpiresAt;

  const EmployeeDto({
    required this.id,
    required this.employeeNumber,
    required this.displayName,
    required this.email,
    required this.branchId,
    required this.shiftPolicyId,
    required this.status,
    required this.invitationToken,
    required this.invitationExpiresAt,
  });

  factory EmployeeDto.fromJson(Map<String, dynamic> json) {
    return EmployeeDto(
      id: json['id'] as String,
      employeeNumber: json['employeeNumber'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      branchId: json['branchId'] as String,
      shiftPolicyId: json['shiftPolicyId'] as String,
      status: EmployeeStatus.values.byName(json['status'] as String),
      invitationToken: json['invitationToken'] as String,
      invitationExpiresAt:
          DateTime.parse(json['invitationExpiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeNumber': employeeNumber,
        'displayName': displayName,
        'email': email,
        'branchId': branchId,
        'shiftPolicyId': shiftPolicyId,
        'status': status.name,
        'invitationToken': invitationToken,
        'invitationExpiresAt': invitationExpiresAt.toIso8601String(),
      };
}

class BranchDto {
  final String id;
  final String name;
  final String timezone;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const BranchDto({
    required this.id,
    required this.name,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory BranchDto.fromJson(Map<String, dynamic> json) {
    return BranchDto(
      id: json['id'] as String,
      name: json['name'] as String,
      timezone: json['timezone'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: json['radiusMeters'] as int,
    );
  }
}

class ShiftPolicyDto {
  final String id;
  final String name;
  final int version;
  final String status;
  final String localStartTime;
  final String localEndTime;

  const ShiftPolicyDto({
    required this.id,
    required this.name,
    required this.version,
    required this.status,
    required this.localStartTime,
    required this.localEndTime,
  });

  factory ShiftPolicyDto.fromJson(Map<String, dynamic> json) {
    return ShiftPolicyDto(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as int,
      status: json['status'] as String,
      localStartTime: json['localStartTime'] as String,
      localEndTime: json['localEndTime'] as String,
    );
  }
}

// -----------------------------------------------------------------------------
// OpenAPI 0.4.0 Feature 002: Requests, Approvals & Leave DTOs (T022)
// -----------------------------------------------------------------------------

class ApprovalStepDto {
  final String id;
  final int position;
  final String reviewerRole;
  final String? reviewerName;
  final String state; // waiting | pending | approved | rejected | cancelled
  final DateTime? decidedAt;
  final String? comment;

  const ApprovalStepDto({
    required this.id,
    required this.position,
    required this.reviewerRole,
    this.reviewerName,
    required this.state,
    this.decidedAt,
    this.comment,
  });

  factory ApprovalStepDto.fromJson(Map<String, dynamic> json) {
    return ApprovalStepDto(
      id: json['id'] as String,
      position: json['position'] as int,
      reviewerRole: json['reviewerRole'] as String,
      reviewerName: json['reviewerName'] as String?,
      state: json['state'] as String,
      decidedAt: json['decidedAt'] != null
          ? DateTime.parse(json['decidedAt'] as String)
          : null,
      comment: json['comment'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'position': position,
        'reviewerRole': reviewerRole,
        if (reviewerName != null) 'reviewerName': reviewerName,
        'state': state,
        if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
        if (comment != null) 'comment': comment,
      };
}

class RequestDto {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String type; // leave | permission | attendance_correction
  final String
      state; // submitted | pending_approval | approved | rejected | cancelled | processing_failed
  final int revision;
  final int requestedMinutes;
  final DateTime submittedAt;
  final DateTime? decidedAt;
  final DateTime? cancelledAt;
  final String? reasonCode;
  final Map<String, dynamic> details;
  final List<ApprovalStepDto> steps;

  const RequestDto({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.type,
    required this.state,
    required this.revision,
    required this.requestedMinutes,
    required this.submittedAt,
    this.decidedAt,
    this.cancelledAt,
    this.reasonCode,
    required this.details,
    required this.steps,
  });

  factory RequestDto.fromJson(Map<String, dynamic> json) {
    return RequestDto(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      employeeName: json['employeeName'] as String?,
      type: json['type'] as String,
      state: json['state'] as String,
      revision: json['revision'] as int,
      requestedMinutes: json['requestedMinutes'] as int? ?? 0,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      decidedAt: json['decidedAt'] != null
          ? DateTime.parse(json['decidedAt'] as String)
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'] as String)
          : null,
      reasonCode: json['reasonCode'] as String?,
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => ApprovalStepDto.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        if (employeeName != null) 'employeeName': employeeName,
        'type': type,
        'state': state,
        'revision': revision,
        'requestedMinutes': requestedMinutes,
        'submittedAt': submittedAt.toIso8601String(),
        if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
        if (reasonCode != null) 'reasonCode': reasonCode,
        'details': details,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}

class RequestPageDto {
  final List<RequestDto> items;
  final String? nextCursor;

  const RequestPageDto({
    required this.items,
    this.nextCursor,
  });

  factory RequestPageDto.fromJson(Map<String, dynamic> json) {
    return RequestPageDto(
      items: (json['items'] as List<dynamic>)
          .map((item) => RequestDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class LeaveBalanceDto {
  final String employeeId;
  final String categoryId;
  final String categoryName;
  final String periodStart;
  final String periodEnd;
  final int balanceMinutes;

  const LeaveBalanceDto({
    required this.employeeId,
    required this.categoryId,
    required this.categoryName,
    required this.periodStart,
    required this.periodEnd,
    required this.balanceMinutes,
  });

  factory LeaveBalanceDto.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceDto(
      employeeId: json['employeeId'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      periodStart: json['periodStart'] as String,
      periodEnd: json['periodEnd'] as String,
      balanceMinutes: json['balanceMinutes'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
        'balanceMinutes': balanceMinutes,
      };
}

class EmployeeShiftSummaryDto {
  final String shiftInstanceId;
  final String businessDate;
  final DateTime startsAt;
  final DateTime endsAt;
  final String branchName;
  final String state;

  const EmployeeShiftSummaryDto({
    required this.shiftInstanceId,
    required this.businessDate,
    required this.startsAt,
    required this.endsAt,
    required this.branchName,
    required this.state,
  });

  factory EmployeeShiftSummaryDto.fromJson(Map<String, dynamic> json) {
    return EmployeeShiftSummaryDto(
      shiftInstanceId: json['shiftInstanceId'] as String,
      businessDate: json['businessDate'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      branchName: json['branchName'] as String,
      state: json['state'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'shiftInstanceId': shiftInstanceId,
        'businessDate': businessDate,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'branchName': branchName,
        'state': state,
      };
}

class EmployeeShiftPageDto {
  final List<EmployeeShiftSummaryDto> items;
  final String? nextCursor;

  const EmployeeShiftPageDto({
    required this.items,
    this.nextCursor,
  });

  factory EmployeeShiftPageDto.fromJson(Map<String, dynamic> json) {
    return EmployeeShiftPageDto(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => EmployeeShiftSummaryDto.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
      };
}

// =========================================================================
// OpenAPI 0.6.1 Additions: Catalog, Dynamic Requests, Attachments, Activity
// =========================================================================

enum RequestKind {
  built_in,
  dynamic,
}

enum RequestFieldKind {
  short_text,
  long_text,
  integer,
  decimal,
  date,
  time,
  date_time,
  single_choice,
  multiple_choice,
  boolean,
  employee_reference,
  attachment,
}

class FieldChoice {
  final String code;
  final String labelAr;
  final String? secondaryLabel;

  const FieldChoice({
    required this.code,
    required this.labelAr,
    this.secondaryLabel,
  });

  factory FieldChoice.fromJson(Map<String, dynamic> json) {
    return FieldChoice(
      code: json['code'] as String,
      labelAr: json['labelAr'] as String,
      secondaryLabel: json['secondaryLabel'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'labelAr': labelAr,
        if (secondaryLabel != null) 'secondaryLabel': secondaryLabel,
      };
}

class RequestFieldDefinitionInput {
  final String key;
  final int position;
  final RequestFieldKind kind;
  final String labelAr;
  final String? secondaryLabel;
  final String? helpText;
  final bool required;
  final String sensitivity;
  final int? minLength;
  final int? maxLength;
  final double? minimum;
  final double? maximum;
  final int? maxItems;
  final List<FieldChoice>? choices;
  final RequestFieldDataSourceDto? dataSource;
  final FieldValidationRuleDto? validation;
  final ConditionalVisibilityRuleDto? conditionalVisibility;

  const RequestFieldDefinitionInput({
    required this.key,
    required this.position,
    required this.kind,
    required this.labelAr,
    this.secondaryLabel,
    this.helpText,
    required this.required,
    this.sensitivity = 'standard',
    this.minLength,
    this.maxLength,
    this.minimum,
    this.maximum,
    this.maxItems,
    this.choices,
    this.dataSource,
    this.validation,
    this.conditionalVisibility,
  });

  factory RequestFieldDefinitionInput.fromJson(Map<String, dynamic> json) {
    return RequestFieldDefinitionInput(
      key: json['key'] as String,
      position: json['position'] as int? ?? 1,
      kind: RequestFieldKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => RequestFieldKind.short_text,
      ),
      labelAr: json['labelAr'] as String? ?? '',
      secondaryLabel: json['secondaryLabel'] as String?,
      helpText: json['helpText'] as String?,
      required: json['required'] as bool? ?? false,
      sensitivity: json['sensitivity'] as String? ?? 'standard',
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
      minimum: (json['minimum'] as num?)?.toDouble(),
      maximum: (json['maximum'] as num?)?.toDouble(),
      maxItems: json['maxItems'] as int?,
      choices: (json['choices'] as List<dynamic>?)
          ?.map((c) => FieldChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
      dataSource: json['dataSource'] != null
          ? RequestFieldDataSourceDto.fromJson(
              json['dataSource'] as Map<String, dynamic>)
          : null,
      validation: json['validation'] != null
          ? FieldValidationRuleDto.fromJson(
              json['validation'] as Map<String, dynamic>)
          : null,
      conditionalVisibility: json['conditionalVisibility'] != null
          ? ConditionalVisibilityRuleDto.fromJson(
              json['conditionalVisibility'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'position': position,
        'kind': kind.name,
        'labelAr': labelAr,
        if (secondaryLabel != null) 'secondaryLabel': secondaryLabel,
        if (helpText != null) 'helpText': helpText,
        'required': required,
        'sensitivity': sensitivity,
        if (minLength != null) 'minLength': minLength,
        if (maxLength != null) 'maxLength': maxLength,
        if (minimum != null) 'minimum': minimum,
        if (maximum != null) 'maximum': maximum,
        if (maxItems != null) 'maxItems': maxItems,
        if (choices != null)
          'choices': choices!.map((c) => c.toJson()).toList(),
        if (dataSource != null) 'dataSource': dataSource!.toJson(),
        if (validation != null) 'validation': validation!.toJson(),
        if (conditionalVisibility != null)
          'conditionalVisibility': conditionalVisibility!.toJson(),
      };
}

class RequestCatalogItem {
  final RequestKind kind;
  final String typeKey;
  final String? definitionVersionId;
  final String nameAr;
  final String? secondaryName;
  final String? description;

  /// Tenant-owned category returned by the server; never derived from text.
  final String categoryKey;
  final String? iconKey;
  final bool offlineEligible;
  final List<RequestFieldDefinitionInput> fields;

  const RequestCatalogItem({
    required this.kind,
    required this.typeKey,
    this.definitionVersionId,
    required this.nameAr,
    this.secondaryName,
    this.description,
    required this.categoryKey,
    this.iconKey,
    required this.offlineEligible,
    this.fields = const [],
  });

  factory RequestCatalogItem.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String? ?? 'dynamic';
    return RequestCatalogItem(
      kind: RequestKind.values.firstWhere(
        (k) => k.name == rawKind,
        orElse: () => RequestKind.dynamic,
      ),
      typeKey: json['typeKey'] as String,
      definitionVersionId: json['definitionVersionId'] as String?,
      nameAr: json['nameAr'] as String? ?? '',
      secondaryName: json['secondaryName'] as String?,
      description: json['description'] as String?,
      categoryKey: json['categoryKey'] as String? ?? 'general',
      iconKey: json['iconKey'] as String?,
      offlineEligible: json['offlineEligible'] as bool? ?? false,
      fields: (json['fields'] as List<dynamic>?)
              ?.map((f) => RequestFieldDefinitionInput.fromJson(
                  f as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'typeKey': typeKey,
        if (definitionVersionId != null)
          'definitionVersionId': definitionVersionId,
        'nameAr': nameAr,
        if (secondaryName != null) 'secondaryName': secondaryName,
        if (description != null) 'description': description,
        'categoryKey': categoryKey,
        if (iconKey != null) 'iconKey': iconKey,
        'offlineEligible': offlineEligible,
        'fields': fields.map((f) => f.toJson()).toList(),
      };
}

class RequestCatalogPage {
  final List<RequestCatalogItem> items;
  final String? nextCursor;

  const RequestCatalogPage({
    required this.items,
    this.nextCursor,
  });

  factory RequestCatalogPage.fromJson(Map<String, dynamic> json) {
    return RequestCatalogPage(
      items: (json['items'] as List<dynamic>?)
              ?.map(
                  (i) => RequestCatalogItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
      };
}

class RequestAttachment {
  final String id;
  final String displayName;
  final String mediaType;
  final int sizeBytes;
  final String state;
  final DateTime expiresAt;

  const RequestAttachment({
    required this.id,
    required this.displayName,
    required this.mediaType,
    required this.sizeBytes,
    required this.state,
    required this.expiresAt,
  });

  factory RequestAttachment.fromJson(Map<String, dynamic> json) {
    return RequestAttachment(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      mediaType: json['mediaType'] as String,
      sizeBytes: json['sizeBytes'] as int,
      state: json['state'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'mediaType': mediaType,
        'sizeBytes': sizeBytes,
        'state': state,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };
}

/// Dynamic request submission matching OpenAPI 0.6.1 `CreateDynamicRequest`.
/// Strictly contains NO `typeKey` property as required by OpenAPI 0.6.1.
class CreateDynamicRequest {
  final String requestId;
  final String commandId;
  final String definitionVersionId;
  final DateTime capturedAt;
  final Map<String, dynamic> values;

  const CreateDynamicRequest({
    required this.requestId,
    required this.commandId,
    required this.definitionVersionId,
    required this.capturedAt,
    required this.values,
  });

  factory CreateDynamicRequest.fromJson(Map<String, dynamic> json) {
    return CreateDynamicRequest(
      requestId: json['requestId'] as String,
      commandId: json['commandId'] as String,
      definitionVersionId: json['definitionVersionId'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      values: Map<String, dynamic>.from(json['values'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'commandId': commandId,
        'definitionVersionId': definitionVersionId,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'values': values,
      };
}

class RequestActivitySummary {
  final RequestKind kind;
  final String id;
  final String typeKey;
  final String typeNameAr;
  final String state;
  final int revision;
  final String? currentStageLabel;
  final DateTime submittedAt;
  final DateTime? updatedAt;

  const RequestActivitySummary({
    required this.kind,
    required this.id,
    required this.typeKey,
    required this.typeNameAr,
    required this.state,
    required this.revision,
    this.currentStageLabel,
    required this.submittedAt,
    this.updatedAt,
  });

  factory RequestActivitySummary.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String? ?? 'built_in';
    return RequestActivitySummary(
      kind: RequestKind.values.firstWhere(
        (k) => k.name == rawKind,
        orElse: () => RequestKind.built_in,
      ),
      id: json['id'] as String,
      typeKey: json['typeKey'] as String,
      typeNameAr: json['typeNameAr'] as String,
      state: json['state'] as String,
      revision: json['revision'] as int? ?? 1,
      currentStageLabel: json['currentStageLabel'] as String?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'id': id,
        'typeKey': typeKey,
        'typeNameAr': typeNameAr,
        'state': state,
        'revision': revision,
        if (currentStageLabel != null) 'currentStageLabel': currentStageLabel,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };
}

class RequestActivityPage {
  final List<RequestActivitySummary> items;
  final String? nextCursor;

  const RequestActivityPage({
    required this.items,
    this.nextCursor,
  });

  factory RequestActivityPage.fromJson(Map<String, dynamic> json) {
    return RequestActivityPage(
      items: (json['items'] as List<dynamic>?)
              ?.map((i) =>
                  RequestActivitySummary.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
      };
}

class ApprovalActivitySummary {
  final RequestKind kind;
  final String requestId;
  final String typeNameAr;
  final String requesterDisplayName;
  final String state;
  final String? stageLabel;
  final int expectedRevision;
  final DateTime submittedAt;

  const ApprovalActivitySummary({
    required this.kind,
    required this.requestId,
    required this.typeNameAr,
    required this.requesterDisplayName,
    required this.state,
    this.stageLabel,
    required this.expectedRevision,
    required this.submittedAt,
  });

  factory ApprovalActivitySummary.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String? ?? 'built_in';
    return ApprovalActivitySummary(
      kind: RequestKind.values.firstWhere(
        (k) => k.name == rawKind,
        orElse: () => RequestKind.built_in,
      ),
      requestId: json['requestId'] as String,
      typeNameAr: json['typeNameAr'] as String,
      requesterDisplayName: json['requesterDisplayName'] as String,
      state: json['state'] as String,
      stageLabel: json['stageLabel'] as String?,
      expectedRevision: json['expectedRevision'] as int? ?? 1,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'requestId': requestId,
        'typeNameAr': typeNameAr,
        'requesterDisplayName': requesterDisplayName,
        'state': state,
        if (stageLabel != null) 'stageLabel': stageLabel,
        'expectedRevision': expectedRevision,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
      };
}

class ApprovalActivityPage {
  final List<ApprovalActivitySummary> items;
  final String? nextCursor;

  const ApprovalActivityPage({
    required this.items,
    this.nextCursor,
  });

  factory ApprovalActivityPage.fromJson(Map<String, dynamic> json) {
    return ApprovalActivityPage(
      items: (json['items'] as List<dynamic>?)
              ?.map((i) =>
                  ApprovalActivitySummary.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
      };
}

// =============================================================================
// Feature 005 Workforce Operations (OpenAPI 0.7.0)
// =============================================================================

enum NotificationDestinationKindDto {
  attendance,
  request,
  approval,
  employee,
  report,
  announcement,
  finalSettlement,
}

enum NotificationReadStateDto {
  unread,
  read,
}

class RecipientNotificationDto {
  final String id;
  final String kind;
  final String titleKey;
  final String bodyKey;
  final NotificationDestinationKindDto destinationKind;
  final String destinationId;
  final NotificationReadStateDto readState;
  final DateTime? readAt;
  final DateTime createdAt;

  const RecipientNotificationDto({
    required this.id,
    required this.kind,
    required this.titleKey,
    required this.bodyKey,
    required this.destinationKind,
    required this.destinationId,
    required this.readState,
    this.readAt,
    required this.createdAt,
  });

  factory RecipientNotificationDto.fromJson(Map<String, dynamic> json) {
    return RecipientNotificationDto(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? 'general',
      titleKey: json['titleKey'] as String? ?? '',
      bodyKey: json['bodyKey'] as String? ?? '',
      destinationKind: NotificationDestinationKindDto.values.firstWhere(
        (k) =>
            k.name.toLowerCase() ==
            (json['destinationKind'] as String?)
                ?.replaceAll('_', '')
                .toLowerCase(),
        orElse: () => NotificationDestinationKindDto.request,
      ),
      destinationId: json['destinationId'] as String? ?? '',
      readState: NotificationReadStateDto.values.firstWhere(
        (s) => s.name == (json['readState'] as String?),
        orElse: () => NotificationReadStateDto.unread,
      ),
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'titleKey': titleKey,
        'bodyKey': bodyKey,
        'destinationKind': destinationKind.name,
        'destinationId': destinationId,
        'readState': readState.name,
        if (readAt != null) 'readAt': readAt!.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

class NotificationPageDto {
  final List<RecipientNotificationDto> items;
  final String? nextCursor;

  const NotificationPageDto({
    required this.items,
    this.nextCursor,
  });

  factory NotificationPageDto.fromJson(Map<String, dynamic> json) {
    return NotificationPageDto(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  RecipientNotificationDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
      };
}

class UnreadNotificationCountDto {
  final int count;

  const UnreadNotificationCountDto({required this.count});

  factory UnreadNotificationCountDto.fromJson(Map<String, dynamic> json) {
    return UnreadNotificationCountDto(
      count: json['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'count': count};
}

class MarkAllNotificationsReadRequestDto {
  final String commandId;
  final DateTime? before;

  const MarkAllNotificationsReadRequestDto({
    required this.commandId,
    this.before,
  });

  factory MarkAllNotificationsReadRequestDto.fromJson(
      Map<String, dynamic> json) {
    return MarkAllNotificationsReadRequestDto(
      commandId: json['commandId'] as String,
      before: json['before'] != null
          ? DateTime.tryParse(json['before'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'commandId': commandId,
        if (before != null) 'before': before!.toUtc().toIso8601String(),
      };
}

class WorkforceReportSummaryDto {
  final String from;
  final String to;
  final int activeEmployees;
  final int suspendedEmployees;
  final int archivedEmployees;
  final int activeLocations;
  final int unassignedEmployees;
  final DateTime generatedAt;

  const WorkforceReportSummaryDto({
    required this.from,
    required this.to,
    required this.activeEmployees,
    required this.suspendedEmployees,
    required this.archivedEmployees,
    required this.activeLocations,
    required this.unassignedEmployees,
    required this.generatedAt,
  });

  int get totalEmployees =>
      activeEmployees + suspendedEmployees + archivedEmployees;

  factory WorkforceReportSummaryDto.fromJson(Map<String, dynamic> json) {
    return WorkforceReportSummaryDto(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      activeEmployees: json['activeEmployees'] as int? ?? 0,
      suspendedEmployees: json['suspendedEmployees'] as int? ?? 0,
      archivedEmployees: json['archivedEmployees'] as int? ?? 0,
      activeLocations: json['activeLocations'] as int? ?? 0,
      unassignedEmployees: json['unassignedEmployees'] as int? ?? 0,
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'activeEmployees': activeEmployees,
        'suspendedEmployees': suspendedEmployees,
        'archivedEmployees': archivedEmployees,
        'activeLocations': activeLocations,
        'unassignedEmployees': unassignedEmployees,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
      };
}

class ReportTotalsDto {
  final int employees;
  final int attendanceExceptions;
  final int leaveMinutes;
  final int requests;

  const ReportTotalsDto({
    required this.employees,
    required this.attendanceExceptions,
    required this.leaveMinutes,
    required this.requests,
  });

  factory ReportTotalsDto.fromJson(Map<String, dynamic> json) {
    return ReportTotalsDto(
      employees: json['employees'] as int? ?? 0,
      attendanceExceptions: json['attendanceExceptions'] as int? ?? 0,
      leaveMinutes: json['leaveMinutes'] as int? ?? 0,
      requests: json['requests'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'employees': employees,
        'attendanceExceptions': attendanceExceptions,
        'leaveMinutes': leaveMinutes,
        'requests': requests,
      };
}

class ReportItemDto {
  final String employeeId;
  final String employeeName;
  final String businessDate;
  final String attendanceState;
  final int leaveMinutes;
  final String? requestState;

  const ReportItemDto({
    required this.employeeId,
    required this.employeeName,
    required this.businessDate,
    required this.attendanceState,
    required this.leaveMinutes,
    this.requestState,
  });

  factory ReportItemDto.fromJson(Map<String, dynamic> json) {
    return ReportItemDto(
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      businessDate: json['businessDate'] as String? ?? '',
      attendanceState: json['attendanceState'] as String? ?? '',
      leaveMinutes: json['leaveMinutes'] as int? ?? 0,
      requestState: json['requestState'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'businessDate': businessDate,
        'attendanceState': attendanceState,
        'leaveMinutes': leaveMinutes,
        if (requestState != null) 'requestState': requestState,
      };
}

class ReportPageDto {
  final ReportTotalsDto totals;
  final List<ReportItemDto> items;
  final String? nextCursor;

  const ReportPageDto({
    required this.totals,
    required this.items,
    this.nextCursor,
  });

  factory ReportPageDto.fromJson(Map<String, dynamic> json) {
    return ReportPageDto(
      totals: ReportTotalsDto.fromJson(
        json['totals'] as Map<String, dynamic>? ?? {},
      ),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ReportItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'totals': totals.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
      };
}

class ReportFilterDto {
  final String startDate;
  final String endDate;
  final String? employeeId;
  final String? branchId;
  final String? requestType;
  final String? requestState;

  const ReportFilterDto({
    required this.startDate,
    required this.endDate,
    this.employeeId,
    this.branchId,
    this.requestType,
    this.requestState,
  });

  factory ReportFilterDto.fromJson(Map<String, dynamic> json) {
    return ReportFilterDto(
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      employeeId: json['employeeId'] as String?,
      branchId: json['branchId'] as String?,
      requestType: json['requestType'] as String?,
      requestState: json['requestState'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        'endDate': endDate,
        if (employeeId != null) 'employeeId': employeeId,
        if (branchId != null) 'branchId': branchId,
        if (requestType != null) 'requestType': requestType,
        if (requestState != null) 'requestState': requestState,
      };
}

class CreateExportRequestDto {
  final String commandId;
  final String reportType;
  final String format;
  final ReportFilterDto filter;

  const CreateExportRequestDto({
    required this.commandId,
    this.reportType = 'attendance_leave',
    this.format = 'csv',
    required this.filter,
  });

  factory CreateExportRequestDto.fromJson(Map<String, dynamic> json) {
    return CreateExportRequestDto(
      commandId: json['commandId'] as String? ?? '',
      reportType: json['reportType'] as String? ?? 'attendance_leave',
      format: json['format'] as String? ?? 'csv',
      filter: ReportFilterDto.fromJson(
        json['filter'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'commandId': commandId,
        'reportType': reportType,
        'format': format,
        'filter': filter.toJson(),
      };
}

class ExportJobDto {
  final String id;
  final String reportType;
  final String format;
  final String state;
  final int? rowCount;
  final String? checksum;
  final String? reasonCode;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const ExportJobDto({
    required this.id,
    this.reportType = 'attendance_leave',
    this.format = 'csv',
    required this.state,
    this.rowCount,
    this.checksum,
    this.reasonCode,
    required this.createdAt,
    this.expiresAt,
  });

  factory ExportJobDto.fromJson(Map<String, dynamic> json) {
    return ExportJobDto(
      id: json['id'] as String? ?? '',
      reportType: json['reportType'] as String? ?? 'attendance_leave',
      format: json['format'] as String? ?? 'csv',
      state:
          json['state'] as String? ?? (json['status'] as String? ?? 'queued'),
      rowCount: json['rowCount'] as int?,
      checksum: json['checksum'] as String?,
      reasonCode: json['reasonCode'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reportType': reportType,
        'format': format,
        'state': state,
        if (rowCount != null) 'rowCount': rowCount,
        if (checksum != null) 'checksum': checksum,
        if (reasonCode != null) 'reasonCode': reasonCode,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (expiresAt != null)
          'expiresAt': expiresAt!.toUtc().toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Feature 006 — Payroll & Finance (OpenAPI 0.8.0)
// Only self-service payslip types (T032-T033). Advance, adjustment, and
// report types are intentionally absent until BLOCKED contracts are released.
// ---------------------------------------------------------------------------

/// Money value object. Amounts are server-formatted strings (e.g. "1234.56").
/// Never parse, round, or calculate on the client — render as provided.
class MoneyDto {
  final String currency;
  final String amount;

  const MoneyDto({required this.currency, required this.amount});

  factory MoneyDto.fromJson(Map<String, dynamic> json) => MoneyDto(
        currency: json['currency'] as String,
        amount: json['amount'] as String,
      );

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'amount': amount,
      };
}

enum PayrollLineKind {
  earning,
  deduction,
  adjustment,
  installment,
  rounding;

  static PayrollLineKind fromString(String v) => switch (v) {
        'earning' => PayrollLineKind.earning,
        'deduction' => PayrollLineKind.deduction,
        'adjustment' => PayrollLineKind.adjustment,
        'installment' => PayrollLineKind.installment,
        'rounding' => PayrollLineKind.rounding,
        _ => PayrollLineKind.earning,
      };
}

class PayrollLineDto {
  final String id;
  final PayrollLineKind kind;
  final String code;
  final MoneyDto amount;
  final String sourceType;
  final String sourceId;

  const PayrollLineDto({
    required this.id,
    required this.kind,
    required this.code,
    required this.amount,
    required this.sourceType,
    required this.sourceId,
  });

  factory PayrollLineDto.fromJson(Map<String, dynamic> json) => PayrollLineDto(
        id: json['id'] as String,
        kind: PayrollLineKind.fromString(json['kind'] as String),
        code: json['code'] as String,
        amount: MoneyDto.fromJson(json['amount'] as Map<String, dynamic>),
        sourceType: json['sourceType'] as String,
        sourceId: json['sourceId'] as String,
      );
}

enum PayslipDocumentState {
  queued,
  ready,
  failed,
  expired;

  static PayslipDocumentState fromString(String v) => switch (v) {
        'ready' => PayslipDocumentState.ready,
        'failed' => PayslipDocumentState.failed,
        'expired' => PayslipDocumentState.expired,
        _ => PayslipDocumentState.queued,
      };
}

class PayslipSummaryDto {
  final String id;
  final String cycleKey;
  final MoneyDto gross;
  final MoneyDto deductions;
  final MoneyDto net;
  final DateTime issuedAt;
  final PayslipDocumentState documentState;

  const PayslipSummaryDto({
    required this.id,
    required this.cycleKey,
    required this.gross,
    required this.deductions,
    required this.net,
    required this.issuedAt,
    required this.documentState,
  });

  factory PayslipSummaryDto.fromJson(Map<String, dynamic> json) =>
      PayslipSummaryDto(
        id: json['id'] as String,
        cycleKey: json['cycleKey'] as String,
        gross: MoneyDto.fromJson(json['gross'] as Map<String, dynamic>),
        deductions:
            MoneyDto.fromJson(json['deductions'] as Map<String, dynamic>),
        net: MoneyDto.fromJson(json['net'] as Map<String, dynamic>),
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        documentState:
            PayslipDocumentState.fromString(json['documentState'] as String),
      );
}

class PayslipDto extends PayslipSummaryDto {
  final String employeeId;
  final String periodStart;
  final String periodEnd;
  final List<PayrollLineDto> lines;
  final String? downloadUrl;
  final DateTime? downloadExpiresAt;

  const PayslipDto({
    required super.id,
    required super.cycleKey,
    required super.gross,
    required super.deductions,
    required super.net,
    required super.issuedAt,
    required super.documentState,
    required this.employeeId,
    required this.periodStart,
    required this.periodEnd,
    required this.lines,
    this.downloadUrl,
    this.downloadExpiresAt,
  });

  factory PayslipDto.fromJson(Map<String, dynamic> json) => PayslipDto(
        id: json['id'] as String,
        cycleKey: json['cycleKey'] as String,
        gross: MoneyDto.fromJson(json['gross'] as Map<String, dynamic>),
        deductions:
            MoneyDto.fromJson(json['deductions'] as Map<String, dynamic>),
        net: MoneyDto.fromJson(json['net'] as Map<String, dynamic>),
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        documentState:
            PayslipDocumentState.fromString(json['documentState'] as String),
        employeeId: json['employeeId'] as String,
        periodStart: json['periodStart'] as String,
        periodEnd: json['periodEnd'] as String,
        lines: (json['lines'] as List<dynamic>)
            .map((e) => PayrollLineDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        downloadUrl: json['downloadUrl'] as String?,
        downloadExpiresAt: json['downloadExpiresAt'] != null
            ? DateTime.tryParse(json['downloadExpiresAt'] as String)
            : null,
      );
}

class PayslipPageDto {
  final List<PayslipSummaryDto> items;
  final String? nextCursor;

  const PayslipPageDto({required this.items, this.nextCursor});

  factory PayslipPageDto.fromJson(Map<String, dynamic> json) => PayslipPageDto(
        items: (json['items'] as List<dynamic>)
            .map((e) => PayslipSummaryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );
}

// ── Feature 006: Self-service advances (T041-T042) ─────────────────────────

enum AdvanceState {
  submitted,
  pendingApproval,
  approved,
  rejected,
  disbursed,
  collecting,
  settled,
  cancelled,
  reversed;

  static AdvanceState fromString(String v) => switch (v) {
        'submitted' => AdvanceState.submitted,
        'pending_approval' => AdvanceState.pendingApproval,
        'approved' => AdvanceState.approved,
        'rejected' => AdvanceState.rejected,
        'disbursed' => AdvanceState.disbursed,
        'collecting' => AdvanceState.collecting,
        'settled' => AdvanceState.settled,
        'cancelled' => AdvanceState.cancelled,
        'reversed' => AdvanceState.reversed,
        _ => AdvanceState.submitted,
      };

  String toServerString() => switch (this) {
        AdvanceState.submitted => 'submitted',
        AdvanceState.pendingApproval => 'pending_approval',
        AdvanceState.approved => 'approved',
        AdvanceState.rejected => 'rejected',
        AdvanceState.disbursed => 'disbursed',
        AdvanceState.collecting => 'collecting',
        AdvanceState.settled => 'settled',
        AdvanceState.cancelled => 'cancelled',
        AdvanceState.reversed => 'reversed',
      };
}

class AdvanceDto {
  final String id;
  final String employeeId;
  final MoneyDto principal;
  final MoneyDto postedAmount;
  final MoneyDto remainingBalance;
  final AdvanceState state;
  final String approvalStage;
  final Map<String, dynamic> approvalRoute;
  final bool hrReviewed;
  final bool financeReviewed;
  final List<AdvanceScheduleItemDto> installmentSchedule;
  final int revision;

  const AdvanceDto({
    required this.id,
    required this.employeeId,
    required this.principal,
    required this.postedAmount,
    required this.remainingBalance,
    required this.state,
    this.approvalStage = 'hr_review',
    this.approvalRoute = const {},
    this.hrReviewed = false,
    this.financeReviewed = false,
    this.installmentSchedule = const [],
    required this.revision,
  });

  factory AdvanceDto.fromJson(Map<String, dynamic> json) => AdvanceDto(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String,
        principal: MoneyDto.fromJson(json['principal'] as Map<String, dynamic>),
        postedAmount:
            MoneyDto.fromJson(json['postedAmount'] as Map<String, dynamic>),
        remainingBalance:
            MoneyDto.fromJson(json['remainingBalance'] as Map<String, dynamic>),
        state: AdvanceState.fromString(json['state'] as String),
        approvalStage: json['approvalStage'] as String? ?? 'hr_review',
        approvalRoute:
            (json['approvalRoute'] as Map<String, dynamic>?) ?? const {},
        hrReviewed: (json['reviewHistory']
                as Map<String, dynamic>?)?['hrReviewed'] as bool? ??
            false,
        financeReviewed: (json['reviewHistory']
                as Map<String, dynamic>?)?['financeReviewed'] as bool? ??
            false,
        installmentSchedule: (json['installmentSchedule'] as List<dynamic>?)
                ?.map((entry) => AdvanceScheduleItemDto.fromJson(
                    entry as Map<String, dynamic>))
                .toList() ??
            const [],
        revision: json['revision'] as int,
      );
}

class AdvancePageDto {
  final List<AdvanceDto> items;
  final String? nextCursor;

  const AdvancePageDto({required this.items, this.nextCursor});

  factory AdvancePageDto.fromJson(Map<String, dynamic> json) => AdvancePageDto(
        items: (json['items'] as List<dynamic>)
            .map((e) => AdvanceDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );
}

class AdvanceScheduleItemDto {
  final int sequence;
  final String dueDate;
  final MoneyDto amount;

  const AdvanceScheduleItemDto({
    required this.sequence,
    required this.dueDate,
    required this.amount,
  });

  factory AdvanceScheduleItemDto.fromJson(Map<String, dynamic> json) =>
      AdvanceScheduleItemDto(
        sequence: json['sequence'] as int,
        dueDate: json['dueDate'] as String,
        amount: MoneyDto.fromJson(json['amount'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'sequence': sequence,
        'dueDate': dueDate,
        'amount': amount.toJson(),
      };
}

class AdvanceEligibilityPreviewDto {
  final String evaluationId;
  final String policyVersionId;
  final bool eligible;
  final List<String> reasonCodes;
  final DateTime expiresAt;
  final List<AdvanceScheduleItemDto> provisionalSchedule;

  const AdvanceEligibilityPreviewDto({
    required this.evaluationId,
    required this.policyVersionId,
    required this.eligible,
    required this.reasonCodes,
    required this.expiresAt,
    required this.provisionalSchedule,
  });

  factory AdvanceEligibilityPreviewDto.fromJson(Map<String, dynamic> json) =>
      AdvanceEligibilityPreviewDto(
        evaluationId: json['evaluationId'] as String,
        policyVersionId: json['policyVersionId'] as String,
        eligible: json['eligible'] as bool,
        reasonCodes: (json['reasonCodes'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        provisionalSchedule: (json['provisionalSchedule'] as List<dynamic>?)
                ?.map((e) =>
                    AdvanceScheduleItemDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class CreateAdvanceRequestDto {
  final String commandId;
  final MoneyDto principal;
  final MoneyDto installmentAmount;
  final String reason;
  final List<String>? attachmentIds;
  final String? eligibilityEvaluationId;
  final int? installmentCount;

  const CreateAdvanceRequestDto({
    required this.commandId,
    required this.principal,
    required this.installmentAmount,
    required this.reason,
    this.attachmentIds,
    this.eligibilityEvaluationId,
    this.installmentCount,
  });

  Map<String, dynamic> toJson() => {
        'commandId': commandId,
        'principal': principal.toJson(),
        'installmentAmount': installmentAmount.toJson(),
        'reason': reason,
        if (attachmentIds != null) 'attachmentIds': attachmentIds,
        if (eligibilityEvaluationId != null)
          'eligibilityEvaluationId': eligibilityEvaluationId,
        if (installmentCount != null) 'installmentCount': installmentCount,
      };
}

// ── Feature 011: Account Security, Sessions, and Dynamic Selectors (OpenAPI 0.9.0) ──

class AccountSessionDto {
  final String id;
  final String clientType;
  final String? deviceInstallationId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool current;

  const AccountSessionDto({
    required this.id,
    required this.clientType,
    this.deviceInstallationId,
    required this.createdAt,
    required this.expiresAt,
    required this.current,
  });

  factory AccountSessionDto.fromJson(Map<String, dynamic> json) =>
      AccountSessionDto(
        id: json['id'] as String,
        clientType: json['clientType'] as String? ?? 'mobile',
        deviceInstallationId: json['deviceInstallationId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        current: json['current'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientType': clientType,
        if (deviceInstallationId != null)
          'deviceInstallationId': deviceInstallationId,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'current': current,
      };
}

class AccountSessionPageDto {
  final List<AccountSessionDto> items;

  const AccountSessionPageDto({required this.items});

  factory AccountSessionPageDto.fromJson(Map<String, dynamic> json) =>
      AccountSessionPageDto(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => AccountSessionDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ChangePasswordRequestDto {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequestDto({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      };
}

class UpdateMyProfileDto {
  final int expectedRevision;
  final String? phone;
  final String? secondaryEmail;
  final Map<String, dynamic>? preferences;

  const UpdateMyProfileDto({
    required this.expectedRevision,
    this.phone,
    this.secondaryEmail,
    this.preferences,
  });

  Map<String, dynamic> toJson() => {
        'expectedRevision': expectedRevision,
        if (phone != null) 'phone': phone,
        if (secondaryEmail != null) 'secondaryEmail': secondaryEmail,
        if (preferences != null) 'preferences': preferences,
      };
}

class RequestSelectorOptionDto {
  final String value;
  final String labelAr;
  final String? secondaryLabel;

  const RequestSelectorOptionDto({
    required this.value,
    required this.labelAr,
    this.secondaryLabel,
  });

  factory RequestSelectorOptionDto.fromJson(Map<String, dynamic> json) =>
      RequestSelectorOptionDto(
        value: json['value'] as String,
        labelAr: json['labelAr'] as String,
        secondaryLabel: json['secondaryLabel'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'value': value,
        'labelAr': labelAr,
        if (secondaryLabel != null) 'secondaryLabel': secondaryLabel,
      };
}

class RequestSelectorOptionPageDto {
  final List<RequestSelectorOptionDto> items;

  const RequestSelectorOptionPageDto({required this.items});

  factory RequestSelectorOptionPageDto.fromJson(Map<String, dynamic> json) =>
      RequestSelectorOptionPageDto(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) =>
                RequestSelectorOptionDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

enum RequestFieldSourceType {
  employees,
  branches,
  departments,
  workLocations;

  static RequestFieldSourceType fromString(String v) => switch (v) {
        'employees' => RequestFieldSourceType.employees,
        'branches' => RequestFieldSourceType.branches,
        'departments' => RequestFieldSourceType.departments,
        'work_locations' => RequestFieldSourceType.workLocations,
        _ => RequestFieldSourceType.employees,
      };

  String toServerString() => switch (this) {
        RequestFieldSourceType.employees => 'employees',
        RequestFieldSourceType.branches => 'branches',
        RequestFieldSourceType.departments => 'departments',
        RequestFieldSourceType.workLocations => 'work_locations',
      };
}

class RequestFieldDataSourceDto {
  final RequestFieldSourceType source;
  final bool searchEnabled;

  const RequestFieldDataSourceDto({
    required this.source,
    this.searchEnabled = true,
  });

  factory RequestFieldDataSourceDto.fromJson(Map<String, dynamic> json) =>
      RequestFieldDataSourceDto(
        source: RequestFieldSourceType.fromString(json['source'] as String),
        searchEnabled: json['searchEnabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'source': source.toServerString(),
        'searchEnabled': searchEnabled,
      };
}

class FieldValidationRuleDto {
  final num? min;
  final num? max;
  final int? minLength;
  final int? maxLength;
  final String? pattern;

  const FieldValidationRuleDto({
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
    this.pattern,
  });

  factory FieldValidationRuleDto.fromJson(Map<String, dynamic> json) =>
      FieldValidationRuleDto(
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

class ConditionalVisibilityRuleDto {
  final String dependsOnFieldKey;
  final String operator;
  final dynamic value;
  final List<dynamic>? values;

  const ConditionalVisibilityRuleDto({
    required this.dependsOnFieldKey,
    required this.operator,
    this.value,
    this.values,
  });

  factory ConditionalVisibilityRuleDto.fromJson(Map<String, dynamic> json) =>
      ConditionalVisibilityRuleDto(
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
}

// -----------------------------------------------------------------------------
// OpenAPI 0.10.0 Feature 012: protected installation and notification DTOs.
// Kept free of platform APIs so presentation can depend on the contract safely.
// -----------------------------------------------------------------------------

class IntegrityChallengeDto {
  final String challengeId;
  final String nonce;
  final DateTime expiresAt;

  const IntegrityChallengeDto({
    required this.challengeId,
    required this.nonce,
    required this.expiresAt,
  });

  factory IntegrityChallengeDto.fromJson(Map<String, dynamic> json) =>
      IntegrityChallengeDto(
        challengeId: json['challengeId'] as String,
        nonce: json['nonce'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class InstallationRegistrationRequestDto {
  final String challengeId;
  final String platform;
  final String appIdentifier;
  final String appVersion;
  final int buildNumber;
  final String publicKeySpki;
  final String publicKeyThumbprint;
  final String integrityToken;

  const InstallationRegistrationRequestDto({
    required this.challengeId,
    required this.platform,
    required this.appIdentifier,
    required this.appVersion,
    required this.buildNumber,
    required this.publicKeySpki,
    required this.publicKeyThumbprint,
    required this.integrityToken,
  });

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'platform': platform,
        'appIdentifier': appIdentifier,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'publicKeySpki': publicKeySpki,
        'publicKeyThumbprint': publicKeyThumbprint,
        'keyAlgorithm': 'ES256',
        'integrityToken': integrityToken,
      };
}

class InstallationRegistrationDto {
  final String installationId;
  final String platform;
  final String status;
  final String? reasonCode;
  final DateTime registeredAt;
  final int revision;

  const InstallationRegistrationDto({
    required this.installationId,
    required this.platform,
    required this.status,
    this.reasonCode,
    required this.registeredAt,
    required this.revision,
  });

  factory InstallationRegistrationDto.fromJson(Map<String, dynamic> json) =>
      InstallationRegistrationDto(
        installationId: json['installationId'] as String,
        platform: json['platform'] as String,
        status: json['status'] as String,
        reasonCode: json['reasonCode'] as String?,
        registeredAt: DateTime.parse(json['registeredAt'] as String),
        revision: json['revision'] as int,
      );
}

class AttendanceEvidenceDto {
  final String contentDigest;
  final String installationId;
  final String challengeId;
  final String signature;
  final String integrityToken;

  const AttendanceEvidenceDto({
    required this.contentDigest,
    required this.installationId,
    required this.challengeId,
    required this.signature,
    required this.integrityToken,
  });

  Map<String, dynamic> toJson() => {
        'canonicalVersion': 1,
        'contentDigest': contentDigest,
        'installationId': installationId,
        'challengeId': challengeId,
        'signature': signature,
        'signatureAlgorithm': 'ES256',
        'integrityToken': integrityToken,
      };
}

class NotificationPreferenceDto {
  final String category;
  final bool pushEnabled;
  final int revision;

  const NotificationPreferenceDto({
    required this.category,
    required this.pushEnabled,
    required this.revision,
  });

  factory NotificationPreferenceDto.fromJson(Map<String, dynamic> json) =>
      NotificationPreferenceDto(
        category: json['category'] as String,
        pushEnabled: json['pushEnabled'] as bool,
        revision: json['revision'] as int,
      );
}

/// Feature 012: safe push registration response. It deliberately excludes the
/// FCM destination and all provider diagnostics.
class NotificationDeviceDto {
  final String id;
  final String installationId;
  final String provider;
  final String state;
  final DateTime lastSeenAt;

  const NotificationDeviceDto({
    required this.id,
    required this.installationId,
    required this.provider,
    required this.state,
    required this.lastSeenAt,
  });

  factory NotificationDeviceDto.fromJson(Map<String, dynamic> json) =>
      NotificationDeviceDto(
        id: json['id'] as String,
        installationId: json['installationId'] as String,
        provider: json['provider'] as String,
        state: json['state'] as String,
        lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
      );
}

class NotificationPreferenceInputDto {
  final String category;
  final bool pushEnabled;

  const NotificationPreferenceInputDto({
    required this.category,
    required this.pushEnabled,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'pushEnabled': pushEnabled,
      };
}
