import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/attachment_picker_service.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/financial_request_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/screens/financial_request_screen.dart';

class _FakeAttachmentPicker extends Fake implements AttachmentPickerService {
  PickedFileResult? resultToReturn;
  bool shouldThrow = false;

  @override
  Future<PickedFileResult?> pickFile() async {
    if (shouldThrow) {
      throw const AttachmentPickerException('فشل اختيار الملف');
    }
    return resultToReturn ??
        PickedFileResult(
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          filename: 'invoice_receipt.pdf',
          mediaType: 'application/pdf',
        );
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  RequestAttachment? attachmentToReturn;
  bool shouldThrow = false;

  @override
  Future<RequestAttachment> uploadRequestAttachment({
    required List<int> bytes,
    required String filename,
    String? mediaType,
  }) async {
    if (shouldThrow) {
      throw const NetworkFailure('فشل رفع الملف إلى الخادم');
    }
    return attachmentToReturn ??
        RequestAttachment(
          id: 'att-auth-sec-777',
          displayName: filename,
          mediaType: mediaType ?? 'application/pdf',
          sizeBytes: bytes.length,
          state: 'uploaded',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        );
  }
}

class _FakeFinancialDynamicRepo extends Fake
    implements DynamicRequestRepository {
  List<RequestTypeCategory> financialCategoriesToReturn;
  bool shouldFailCatalog;
  bool shouldDenyCatalog;
  bool shouldFailSubmission;
  bool shouldDenySubmission;
  Map<String, dynamic>? lastSubmittedValues;
  String? lastSubmittedTypeKey;
  int catalogCallCount = 0;
  int submitCallCount = 0;

  _FakeFinancialDynamicRepo({
    this.financialCategoriesToReturn = const [],
    this.shouldFailCatalog = false,
    this.shouldDenyCatalog = false,
    this.shouldFailSubmission = false,
    this.shouldDenySubmission = false,
  });

  @override
  Future<List<RequestTypeCategory>> getFinancialRequestCategories() async {
    catalogCallCount++;
    if (shouldDenyCatalog) {
      throw const AuthFailure('غير مصرح لك بالوصول إلى الطلبات المالية');
    }
    if (shouldFailCatalog) {
      throw const NetworkFailure('تعذر الاتصال بالخادم لتحميل الطلبات');
    }
    return financialCategoriesToReturn;
  }

  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = false,
    String? typeNameAr,
  }) async {
    submitCallCount++;
    lastSubmittedTypeKey = typeKey;
    lastSubmittedValues = values;

    if (shouldDenySubmission) {
      throw const AuthFailure('غير مصرح لك بإرسال هذا الطلب المالي');
    }
    if (shouldFailSubmission) {
      throw const NetworkFailure('فشل الاتصال أثناء إرسال الطلب المالي');
    }

    return DynamicRequestEntity(
      id: 'fin-req-success-101',
      typeKey: typeKey,
      typeNameAr: 'طلب صرف مستحقات مالية',
      definitionVersionId: definitionVersionId,
      state: 'submitted',
      revision: 1,
      values: values,
      timeline: const [],
      submittedAt: DateTime.now().toUtc(),
    );
  }
}

void main() {
  const publishedExpenseDefinition = RequestTypeCategory(
    id: 'ver-fin-expense-1',
    key: 'financial_expense_claim',
    nameAr: 'طلب استرداد مصروفات',
    descriptionAr: 'استرداد مصاريف السفر والمهام الرسمية المعتمدة',
    iconKey: 'receipt_long',
    offlineEligible: false,
    fields: [
      RequestFieldDefinition(
        key: 'title',
        position: 1,
        kind: FieldKind.shortText,
        labelAr: 'بيان المصروف',
        required: true,
      ),
      RequestFieldDefinition(
        key: 'amount',
        position: 2,
        kind: FieldKind.decimal,
        labelAr: 'المبلغ المطلوب',
        required: true,
      ),
      RequestFieldDefinition(
        key: 'receipt',
        position: 3,
        kind: FieldKind.attachment,
        labelAr: 'إيصال الصرف',
        required: true,
      ),
    ],
  );

  group('Feature 006 - Financial Dynamic Requests (T050-T051)', () {
    testWidgets(
        '1. Catalog loading: renders company-published financial request definitions',
        (tester) async {
      final fakeRepo = _FakeFinancialDynamicRepo(
        financialCategoriesToReturn: [publishedExpenseDefinition],
      );
      final cubit = FinancialRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: FinancialRequestScreen(cubit: cubit),
        ),
      );

      // Loading state
      expect(find.byType(RequestListSkeleton), findsOneWidget);

      await tester.pumpAndSettle();

      // Successfully loaded catalog from server
      expect(find.text('طلب استرداد مصروفات'), findsOneWidget);
      expect(find.text('استرداد مصاريف السفر والمهام الرسمية المعتمدة'),
          findsOneWidget);
      expect(fakeRepo.catalogCallCount, equals(1));
    });

    testWidgets(
        '2. Catalog empty: proves no hardcoded client financial types exist',
        (tester) async {
      final fakeRepo = _FakeFinancialDynamicRepo(
        financialCategoriesToReturn: const [],
      );
      final cubit = FinancialRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: FinancialRequestScreen(cubit: cubit),
        ),
      );

      await tester.pumpAndSettle();

      // When company has published no definitions, client does NOT fabricate any
      expect(find.text('لا توجد طلبات مالية معتمدة'), findsOneWidget);
      expect(find.text('لم تقم الشركة بنشر نماذج طلبات مالية متاحة لك حالياً.'),
          findsOneWidget);
      expect(find.text('طلب إجازة'), findsNothing);
      expect(find.text('طلب سلفة'), findsNothing);
    });

    testWidgets(
        '3. Denied state: 403 Forbidden displays explicit authorization error',
        (tester) async {
      final fakeRepo = _FakeFinancialDynamicRepo(
        shouldDenyCatalog: true,
      );
      final cubit = FinancialRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: FinancialRequestScreen(cubit: cubit),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('غير مصرح بالوصول'), findsOneWidget);
      expect(
          find.text('غير مصرح لك بالوصول إلى الطلبات المالية'), findsOneWidget);
    });

    testWidgets(
        '4. Error state & Retry: network failure shows retry button and retries',
        (tester) async {
      final fakeRepo = _FakeFinancialDynamicRepo(
        shouldFailCatalog: true,
      );
      final cubit = FinancialRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: FinancialRequestScreen(cubit: cubit),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تعذر تحميل الطلبات المالية'), findsOneWidget);
      expect(find.byKey(const Key('financial_request_retry_button')),
          findsOneWidget);

      // Fix failure and tap retry
      fakeRepo.shouldFailCatalog = false;
      fakeRepo.financialCategoriesToReturn = [publishedExpenseDefinition];

      await tester.tap(find.byKey(const Key('financial_request_retry_button')));
      await tester.pumpAndSettle();

      expect(find.text('طلب استرداد مصروفات'), findsOneWidget);
      expect(fakeRepo.catalogCallCount, equals(2));
    });

    testWidgets('5. Form navigation, private attachment handling & submission',
        (tester) async {
      final fakeRepo = _FakeFinancialDynamicRepo(
        financialCategoriesToReturn: [publishedExpenseDefinition],
      );
      final fakePicker = _FakeAttachmentPicker();
      final fakeClient = _FakeApiClient();
      final cubit = FinancialRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<ApiClient>.value(
            value: fakeClient,
            child: FinancialRequestScreen(
              cubit: cubit,
              attachmentPicker: fakePicker,
              initialCategory: publishedExpenseDefinition,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Form header and server governance disclaimer
      expect(find.text('طلب استرداد مصروفات'), findsWidgets);
      expect(
        find.textContaining(
            'الطلبات المالية تخضع للتدقيق والاعتماد المالي المباشر'),
        findsOneWidget,
      );

      // Enter text fields
      await tester.enterText(
        find.byKey(const Key('dynamic_field_title')),
        'تذاكر سفر مهمة عمل رسمية',
      );
      await tester.enterText(
        find.byKey(const Key('dynamic_field_amount')),
        '4500.50',
      );

      // Upload private attachment
      await tester.tap(find.byKey(const Key('dynamic_field_receipt_btn')));
      await tester.pumpAndSettle();

      // Proves attachment uploaded and displayed with safe display name
      expect(find.text('invoice_receipt.pdf'), findsOneWidget);

      // Submit form
      await tester
          .ensureVisible(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();

      // Proves success screen rendered
      expect(find.text('تم إرسال الطلب المالي بنجاح'), findsOneWidget);
      expect(find.text('الطلب رقم: fin-req-success-101'), findsOneWidget);

      // Verifies attachment privacy: ONLY authorized ID is sent to the server!
      // No raw bytes, local filepaths, or unauthenticated tokens are in values
      expect(fakeRepo.lastSubmittedValues?['title'],
          equals('تذاكر سفر مهمة عمل رسمية'));
      expect(fakeRepo.lastSubmittedValues?['amount'], equals(4500.50));
      expect(
          fakeRepo.lastSubmittedValues?['receipt'], equals('att-auth-sec-777'));
      expect(fakeRepo.lastSubmittedTypeKey, equals('financial_expense_claim'));
    });

    testWidgets(
        '6. Submission error & retry: preserves values and retries online',
        (tester) async {
      final fakeRepo = _FakeFinancialDynamicRepo(
        financialCategoriesToReturn: [publishedExpenseDefinition],
        shouldFailSubmission: true,
      );
      final fakePicker = _FakeAttachmentPicker();
      final fakeClient = _FakeApiClient();
      final cubit = FinancialRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<ApiClient>.value(
            value: fakeClient,
            child: FinancialRequestScreen(
              cubit: cubit,
              attachmentPicker: fakePicker,
              initialCategory: publishedExpenseDefinition,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('dynamic_field_title')),
        'شراء قرطاسية ومستلزمات مكتبية',
      );
      await tester.enterText(
        find.byKey(const Key('dynamic_field_amount')),
        '850.00',
      );

      await tester.tap(find.byKey(const Key('dynamic_field_receipt_btn')));
      await tester.pumpAndSettle();

      // Submit and fail
      await tester
          .ensureVisible(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('فشل الاتصال أثناء إرسال الطلب المالي'), findsOneWidget);
      expect(
          find.byKey(const Key('financial_form_retry_button')), findsOneWidget);

      // Fix failure and retry
      fakeRepo.shouldFailSubmission = false;
      await tester
          .ensureVisible(find.byKey(const Key('financial_form_retry_button')));
      await tester.tap(find.byKey(const Key('financial_form_retry_button')));
      await tester.pumpAndSettle();

      expect(find.text('تم إرسال الطلب المالي بنجاح'), findsOneWidget);
      expect(fakeRepo.submitCallCount, equals(2));
    });

    testWidgets(
        '7. Submission denied: 403 authorization error renders explicit denied state',
        (tester) async {
      final fakeRepo = _FakeFinancialDynamicRepo(
        financialCategoriesToReturn: [publishedExpenseDefinition],
        shouldDenySubmission: true,
      );
      final fakePicker = _FakeAttachmentPicker();
      final fakeClient = _FakeApiClient();
      final cubit = FinancialRequestCubit(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<ApiClient>.value(
            value: fakeClient,
            child: FinancialRequestScreen(
              cubit: cubit,
              attachmentPicker: fakePicker,
              initialCategory: publishedExpenseDefinition,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('dynamic_field_title')),
        'طلب سلفة خاصة',
      );
      await tester.enterText(
        find.byKey(const Key('dynamic_field_amount')),
        '1000.00',
      );

      await tester.tap(find.byKey(const Key('dynamic_field_receipt_btn')));
      await tester.pumpAndSettle();

      await tester
          .ensureVisible(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('غير مصرح بالوصول'), findsOneWidget);
      expect(find.text('غير مصرح لك بإرسال هذا الطلب المالي'), findsOneWidget);
    });

    testWidgets('8. 200% text scale: renders without RenderFlex overflow',
        (tester) async {
      final fakeRepo = _FakeFinancialDynamicRepo(
        financialCategoriesToReturn: [publishedExpenseDefinition],
      );
      final fakePicker = _FakeAttachmentPicker();
      final cubit = FinancialRequestCubit(repository: fakeRepo);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: FinancialRequestScreen(
              cubit: cubit,
              attachmentPicker: fakePicker,
              initialCategory: publishedExpenseDefinition,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Zero RenderFlex errors at 2.0x scale
      expect(tester.takeException(), isNull);
      expect(find.text('طلب استرداد مصروفات'), findsWidgets);
    });
  });
}
