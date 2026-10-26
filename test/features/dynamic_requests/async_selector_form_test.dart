import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/dynamic_form_builder.dart';

class _FakeAsyncSelectorRepo implements DynamicRequestRepository {
  List<RequestSelectorOption> mockOptions = [];
  String? lastSearchQuery;

  @override
  Future<List<RequestSelectorOption>> getFieldOptions({
    required String definitionVersionId,
    required String fieldKey,
    String? search,
  }) async {
    lastSearchQuery = search;
    if (search != null && search.isNotEmpty) {
      return mockOptions
          .where((o) =>
              o.label.toLowerCase().contains(search.toLowerCase()) ||
              (o.subtitle?.toLowerCase().contains(search.toLowerCase()) ??
                  false))
          .toList();
    }
    return mockOptions;
  }

  @override
  Future<List<RequestTypeCategory>> getRequestCategories() async => const [];

  @override
  Future<List<RequestTypeCategory>> getFinancialRequestCategories() async =>
      const [];

  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = true,
    String? typeNameAr,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<DynamicRequestEntity>> getMyDynamicRequests({
    String? typeKey,
    String? state,
  }) async =>
      const [];

  @override
  Future<DynamicRequestEntity> getDynamicRequest(String id) =>
      throw UnimplementedError();

  @override
  Future<DynamicRequestEntity> cancelDynamicRequest({
    required String id,
    required int expectedRevision,
    required String reason,
  }) =>
      throw UnimplementedError();

  @override
  Future<DynamicRequestEntity> decideDynamicRequest({
    required String id,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> synchronizeOutbox() async {}

  @override
  Future<List<ApprovalActivitySummary>> getApprovalActivity({
    String? cursor,
    int? limit,
  }) async =>
      const [];

  @override
  Future<List<RequestActivitySummary>> getRequestActivity({
    String? cursor,
    int? limit,
  }) async =>
      const [];
}

void main() {
  testWidgets('async searchable selector loads options and allows selection',
      (tester) async {
    final repo = _FakeAsyncSelectorRepo();
    repo.mockOptions = [
      const RequestSelectorOption(
        value: 'emp-101',
        label: 'خالد عبدالله',
        subtitle: 'مهندس برمجيات • الرياض',
      ),
      const RequestSelectorOption(
        value: 'emp-102',
        label: 'سارة محمد',
        subtitle: 'أخصائية موارد بشرية • جدة',
      ),
    ];

    Map<String, dynamic>? submittedValues;

    final fields = [
      const RequestFieldDefinition(
        key: 'assigned_employee',
        position: 1,
        kind: FieldKind.employeeReference,
        labelAr: 'الموظف المعني',
        required: true,
        dataSource: RequestFieldDataSource(source: 'employees'),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormBuilder(
              fields: fields,
              definitionVersionId: 'ver-test-1',
              dynamicRequestRepository: repo,
              onSubmit: (val) => submittedValues = val,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap selector
    await tester.tap(find.byKey(const Key('dynamic_field_assigned_employee')));
    await tester.pumpAndSettle();

    // Bottom sheet opens with options
    expect(find.text('خالد عبدالله'), findsOneWidget);
    expect(find.text('سارة محمد'), findsOneWidget);

    // Search filter
    await tester.enterText(
        find.byKey(const Key('selector_search_input')), 'سارة');
    await tester.pumpAndSettle();

    expect(find.text('سارة محمد'), findsOneWidget);
    expect(find.text('خالد عبدالله'), findsNothing);

    // Tap option
    await tester.tap(find.text('سارة محمد'));
    await tester.pumpAndSettle();

    // Field now displays selected label
    expect(find.text('سارة محمد'), findsOneWidget);

    // Submit form
    await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
    await tester.pumpAndSettle();

    expect(submittedValues, equals({'assigned_employee': 'emp-102'}));
  });

  testWidgets('enforces client validation rules (min, max, length, pattern)',
      (tester) async {
    final fields = [
      const RequestFieldDefinition(
        key: 'national_id',
        position: 1,
        kind: FieldKind.shortText,
        labelAr: 'رقم الهوية',
        required: true,
        validation: FieldValidationRule(
          minLength: 10,
          maxLength: 10,
          pattern: r'^[0-9]+$',
        ),
      ),
      const RequestFieldDefinition(
        key: 'item_count',
        position: 2,
        kind: FieldKind.integer,
        labelAr: 'العدد المطلوب',
        required: true,
        validation: FieldValidationRule(min: 1, max: 50),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormBuilder(
              fields: fields,
              onSubmit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter invalid text for national_id (< 10 chars, non-digit)
    await tester.enterText(
        find.byKey(const Key('dynamic_field_national_id')), 'ABC12');
    await tester.enterText(
        find.byKey(const Key('dynamic_field_item_count')), '100');

    await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('يجب ألا يقل النص عن 10 أحرف'), findsOneWidget);
    expect(find.text('القيمة يجب ألا تتجاوز 50'), findsOneWidget);
  });

  testWidgets('enforces conditional visibility based on parent field value',
      (tester) async {
    final fields = [
      const RequestFieldDefinition(
        key: 'requires_device',
        position: 1,
        kind: FieldKind.boolean,
        labelAr: 'هل يتطلب جهازاً إضافياً؟',
      ),
      const RequestFieldDefinition(
        key: 'device_specs',
        position: 2,
        kind: FieldKind.shortText,
        labelAr: 'مواصفات الجهاز المطلوب',
        required: true,
        conditionalVisibility: ConditionalVisibilityRule(
          dependsOnFieldKey: 'requires_device',
          operator: 'equals',
          value: true,
        ),
      ),
    ];

    Map<String, dynamic>? submittedValues;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormBuilder(
              fields: fields,
              onSubmit: (val) => submittedValues = val,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially requires_device is false, so device_specs is hidden
    expect(find.text('مواصفات الجهاز المطلوب'), findsNothing);

    // Submitting succeeds without required device_specs failing
    await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
    await tester.pumpAndSettle();
    expect(submittedValues, equals({'requires_device': false}));

    // Toggle switch to true
    await tester.tap(find.byKey(const Key('dynamic_field_requires_device')));
    await tester.pumpAndSettle();

    // Now device_specs is visible!
    expect(find.text('مواصفات الجهاز المطلوب'), findsOneWidget);
  });
}
