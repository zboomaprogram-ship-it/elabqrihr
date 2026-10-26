import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/attachment_picker_service.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/dynamic_request_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/dynamic_form_builder.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_catalog_screen.dart';

void main() {
  group('Dynamic Request Form & Catalog Tests (T028, T030, T031, US5)', () {
    test('in-flight dynamic submission ignores repeated submit commands',
        () async {
      final pending = Completer<void>();
      final repo = _FakeDynamicRequestRepo(submissionWait: pending.future);
      final cubit = DynamicRequestCubit(repository: repo);
      addTearDown(cubit.close);
      final first = cubit.submitRequest(
          typeKey: 'equipment_request',
          definitionVersionId: 'equipment-v1',
          values: {},
          offlineEligible: true);
      final second = cubit.submitRequest(
          typeKey: 'equipment_request',
          definitionVersionId: 'equipment-v1',
          values: {},
          offlineEligible: true);
      final calls = repo.submitCalls;
      pending.complete();
      await Future.wait([first, second]);
      expect(calls, 1);
    });

    testWidgets(
        'offline dynamic submission shows queued feedback without server success',
        (tester) async {
      final repo = _FakeDynamicRequestRepo(
          submitState: 'pending_sync',
          categoriesToReturn: [
            const RequestTypeCategory(
                id: 'equipment-v1',
                key: 'equipment_request',
                nameAr: 'طلب معدات العمل',
                descriptionAr: '',
                iconKey: 'inventory',
                fields: [],
                offlineEligible: true),
          ]);
      final cubit = DynamicRequestCubit(repository: repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: RequestCatalogScreen(cubit: cubit))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('طلب معدات العمل'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('تم حفظ طلبك على الجهاز'), findsOneWidget);
      expect(
          find.text(
              'بانتظار المزامنة عند عودة الاتصال. لم يصل الطلب إلى الشركة بعد.'),
          findsOneWidget);
      expect(find.text('تم إرسال طلب معدات العمل بنجاح'), findsNothing);
      expect(find.text('تم توثيق طلبك بنجاح في النظام'), findsNothing);
    });

    testWidgets('RequestCatalogScreen renders all request categories',
        (tester) async {
      RequestTypeCategory? selected;
      final fakeRepo = _FakeDynamicRequestRepo(
        categoriesToReturn: RequestTypeCategory.builtInCategories,
      );
      final cubit = DynamicRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestCatalogScreen(
              cubit: cubit,
              onCategorySelected: (cat) => selected = cat,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('طلب إجازة'), findsOneWidget);
      expect(find.text('طلب إذن خروج'), findsOneWidget);
      expect(find.text('تصحيح بصمة / حضور'), findsOneWidget);
      expect(find.text('طلب عهدة أو أجهزة'), findsNothing);
      expect(find.text('طلب عمل عن بُعد'), findsNothing);

      await tester.tap(find.text('طلب إجازة'));
      expect(selected?.key, equals('leave'));
    });

    testWidgets(
        'loads the catalog only after the authenticated request screen opens',
        (tester) async {
      final fakeRepo = _FakeDynamicRequestRepo(
        categoriesToReturn: RequestTypeCategory.builtInCategories,
      );
      final cubit = DynamicRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RequestCatalogScreen(cubit: cubit))),
      );
      await tester.pumpAndSettle();

      expect(find.text('طلب إجازة'), findsOneWidget);
    });

    testWidgets(
        'T062: RequestCatalogScreen renders DynamicRequestError on failure and does not convert to built-in success',
        (tester) async {
      final fakeRepo = _FakeDynamicRequestRepo(
        shouldFailCatalog: true,
      );
      final cubit = DynamicRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestCatalogScreen(
              cubit: cubit,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Proves failure is NOT converted to built-in success: built-ins are NOT displayed
      expect(find.text('طلب إجازة'), findsNothing);
      expect(find.text('تصحيح بصمة / حضور'), findsNothing);

      // Proves DynamicRequestError with retry CTA is rendered
      expect(find.text('فشل تحميل تصنيفات الطلبات من الخادم'), findsOneWidget);
      expect(find.byKey(const Key('catalog_retry_button')), findsOneWidget);

      // Tap retry with successful repo
      fakeRepo.shouldFailCatalog = false;
      fakeRepo.categoriesToReturn = RequestTypeCategory.builtInCategories;
      await tester.tap(find.byKey(const Key('catalog_retry_button')));
      await tester.pumpAndSettle();

      // Now catalog is displayed
      expect(find.text('طلب إجازة'), findsOneWidget);
    });

    testWidgets(
        'DynamicFormBuilder generates validated inputs and validates required fields',
        (tester) async {
      Map<String, dynamic>? submittedValues;

      const testFields = [
        RequestFieldDefinition(
          key: 'title',
          position: 1,
          kind: FieldKind.shortText,
          labelAr: 'عنوان الطلب',
          required: true,
        ),
        RequestFieldDefinition(
          key: 'amount',
          position: 2,
          kind: FieldKind.integer,
          labelAr: 'المبلغ',
          required: false,
        ),
        RequestFieldDefinition(
          key: 'is_urgent',
          position: 3,
          kind: FieldKind.boolean,
          labelAr: 'طلب عاجل',
          required: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                fields: testFields,
                onSubmit: (val) => submittedValues = val,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('عنوان الطلب'), findsOneWidget);
      expect(find.text('المبلغ'), findsOneWidget);
      expect(find.text('طلب عاجل'), findsOneWidget);

      // Attempt submit with required field empty
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('هذا الحقل مطلوب'), findsOneWidget);
      expect(submittedValues, isNull);

      // Fill in required field
      await tester.enterText(
        find.byKey(const Key('dynamic_field_title')),
        'طلب بدل مواصلات',
      );
      await tester.enterText(
        find.byKey(const Key('dynamic_field_amount')),
        '250',
      );

      // Submit again
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();

      expect(submittedValues, isNotNull);
      expect(submittedValues!['title'], equals('طلب بدل مواصلات'));
      expect(submittedValues!['amount'], equals(250));
    });

    testWidgets(
        'employee references use an authorized dropdown, never a free-text identifier',
        (tester) async {
      Map<String, dynamic>? submittedValues;
      const fields = [
        RequestFieldDefinition(
          key: 'delegate_employee',
          position: 1,
          kind: FieldKind.employeeReference,
          labelAr: 'الموظف البديل',
          required: true,
          choiceOptions: [
            ChoiceOption(code: 'employee-1', labelAr: 'أحمد علي'),
          ],
        ),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicFormBuilder(
            fields: fields,
            onSubmit: (values) => submittedValues = values,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNothing);
      await tester
          .tap(find.byKey(const Key('dynamic_field_delegate_employee')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أحمد علي').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();
      expect(submittedValues, equals({'delegate_employee': 'employee-1'}));
    });

    testWidgets(
        'T061: Attachment picker cancellation returns no file and causes no error',
        (tester) async {
      final mockPicker = _MockAttachmentPickerService();
      mockPicker.resultToReturn = null; // Simulated user cancellation
      final fakeApi = _FakeApiClient();

      const testFields = [
        RequestFieldDefinition(
          key: 'doc',
          position: 1,
          kind: FieldKind.attachment,
          labelAr: 'المرفق',
          required: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicFormBuilder(
              fields: testFields,
              attachmentPicker: mockPicker,
              apiClient: fakeApi,
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('إرفاق ملف خاص'), findsOneWidget);

      await tester.tap(find.text('إرفاق ملف خاص'));
      await tester.pumpAndSettle();

      // No error message and no attachment loaded
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('المرفق'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsNothing);
    });

    testWidgets('T061: Missing native support renders Arabic unavailable state',
        (tester) async {
      final mockPicker = _MockAttachmentPickerService();
      mockPicker.exceptionToThrow = const AttachmentPickerUnavailableException(
          'خدمة اختيار الملفات غير متوفرة على هذا الجهاز');
      final fakeApi = _FakeApiClient();

      const testFields = [
        RequestFieldDefinition(
          key: 'doc',
          position: 1,
          kind: FieldKind.attachment,
          labelAr: 'المرفق',
          required: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicFormBuilder(
              fields: testFields,
              attachmentPicker: mockPicker,
              apiClient: fakeApi,
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('إرفاق ملف خاص'));
      await tester.pumpAndSettle();

      expect(find.text('خدمة اختيار الملفات غير متوفرة على هذا الجهاز'),
          findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsNothing);
    });

    testWidgets(
        'T061: Successful file pick uploads via API and submits only authorized attachment ID',
        (tester) async {
      final mockPicker = _MockAttachmentPickerService();
      mockPicker.resultToReturn = const PickedFileResult(
        bytes: [1, 2, 3, 4],
        filename: 'report.pdf',
        mediaType: 'application/pdf',
      );
      final fakeApi = _FakeApiClient();
      fakeApi.attachmentToReturn = RequestAttachment(
        id: 'att-auth-999',
        displayName: 'report.pdf',
        mediaType: 'application/pdf',
        sizeBytes: 1024,
        state: 'ready',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      Map<String, dynamic>? submittedValues;
      const testFields = [
        RequestFieldDefinition(
          key: 'doc',
          position: 1,
          kind: FieldKind.attachment,
          labelAr: 'المرفق',
          required: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                fields: testFields,
                attachmentPicker: mockPicker,
                apiClient: fakeApi,
                onSubmit: (val) => submittedValues = val,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('إرفاق ملف خاص'));
      await tester.pumpAndSettle();

      // Proves attachment is uploaded and rendered
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);

      // Submit form
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();

      // Proves ONLY the authorized ID is submitted, not simulated maps
      expect(submittedValues, isNotNull);
      expect(submittedValues!['doc'], equals('att-auth-999'));
    });

    testWidgets(
        'T065: Rejected dynamic submission (422 validation failure) never shows success motion and shows error snackbar',
        (tester) async {
      final fakeRepo = _FakeDynamicRequestRepo(
        categoriesToReturn: [
          const RequestTypeCategory(
            id: 'dyn-def-001',
            key: 'custody',
            nameAr: 'طلب عهدة',
            descriptionAr: 'عهدة أجهزة ومعدات',
            iconKey: 'devices',
            fields: [
              RequestFieldDefinition(
                key: 'title',
                position: 1,
                kind: FieldKind.shortText,
                labelAr: 'عنوان العهدة',
                required: true,
              ),
            ],
          ),
        ],
        submitException: const ApiException(
          statusCode: 422,
          code: 'VALIDATION_FAILED',
          message: 'البيانات المدخلة غير صحيحة أو غير مكتملة.',
        ),
      );
      final cubit = DynamicRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestCatalogScreen(cubit: cubit),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open dynamic request form modal
      await tester.tap(find.text('طلب عهدة'));
      await tester.pumpAndSettle();

      // Enter field text
      await tester.enterText(
          find.byKey(const Key('dynamic_field_title')), 'جهاز حاسب آلي');
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();

      // PROVES negative transition: Success motion and title are NEVER displayed
      expect(find.text('تم إرسال طلب عهدة بنجاح'), findsNothing);
      expect(find.text('تم توثيق طلبك بنجاح في النظام'), findsNothing);

      // PROVES error snackbar is rendered with mapped Arabic failure message
      expect(find.text('البيانات المدخلة غير صحيحة أو غير مكتملة.'),
          findsOneWidget);
    });

    testWidgets(
        'T065: Network-failed dynamic submission (SocketException) never shows success motion and shows network error snackbar',
        (tester) async {
      final fakeRepo = _FakeDynamicRequestRepo(
        categoriesToReturn: [
          const RequestTypeCategory(
            id: 'dyn-def-002',
            key: 'remote_work',
            nameAr: 'طلب عمل عن بعد',
            descriptionAr: 'عمل عن بعد لظرف طارئ',
            iconKey: 'home_work',
            fields: [
              RequestFieldDefinition(
                key: 'reason',
                position: 1,
                kind: FieldKind.shortText,
                labelAr: 'السبب',
                required: true,
              ),
            ],
          ),
        ],
        submitException: const SocketException('Connection refused'),
      );
      final cubit = DynamicRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestCatalogScreen(cubit: cubit),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open dynamic request form modal
      await tester.tap(find.text('طلب عمل عن بعد'));
      await tester.pumpAndSettle();

      // Enter field text
      await tester.enterText(
          find.byKey(const Key('dynamic_field_reason')), 'ظرف طارئ');
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();

      // PROVES negative transition: Success motion is NEVER displayed
      expect(find.text('تم إرسال طلب عمل عن بعد بنجاح'), findsNothing);
      expect(find.text('تم توثيق طلبك بنجاح في النظام'), findsNothing);

      // PROVES network error snackbar is displayed
      expect(
        find.text(
            'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت أو إعدادات الشبكة.'),
        findsOneWidget,
      );
    });
  });
}

class _MockAttachmentPickerService implements AttachmentPickerService {
  PickedFileResult? resultToReturn;
  Exception? exceptionToThrow;

  @override
  Future<PickedFileResult?> pickFile() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return resultToReturn;
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  RequestAttachment? attachmentToReturn;
  Exception? exceptionToThrow;

  @override
  Future<RequestAttachment> uploadRequestAttachment({
    required List<int> bytes,
    required String filename,
    String? mediaType,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return attachmentToReturn ??
        RequestAttachment(
          id: 'att-mock-123',
          displayName: filename,
          mediaType: mediaType ?? 'application/pdf',
          sizeBytes: bytes.length,
          state: 'uploaded',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        );
  }
}

class _FakeDynamicRequestRepo extends Fake implements DynamicRequestRepository {
  List<RequestTypeCategory> categoriesToReturn;
  bool shouldFailCatalog;
  Exception? submitException;
  String submitState;
  Future<void>? submissionWait;
  int submitCalls = 0;

  _FakeDynamicRequestRepo({
    this.categoriesToReturn = const [],
    this.shouldFailCatalog = false,
    this.submitException,
    this.submitState = 'submitted',
    this.submissionWait,
  });

  @override
  Future<List<RequestTypeCategory>> getRequestCategories() async {
    if (shouldFailCatalog) {
      throw const ServerFailure('فشل تحميل تصنيفات الطلبات من الخادم');
    }
    return categoriesToReturn;
  }

  @override
  Future<void> synchronizeOutbox() async {}

  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = false,
    String? typeNameAr,
  }) async {
    submitCalls++;
    await submissionWait;
    if (submitException != null) {
      throw submitException!;
    }
    return DynamicRequestEntity(
      id: 'dyn-req-test',
      typeKey: typeKey,
      typeNameAr: 'طلب مخصص',
      definitionVersionId: definitionVersionId,
      state: submitState,
      revision: 1,
      values: values,
      timeline: const [],
      submittedAt: DateTime.now().toUtc(),
    );
  }
}
