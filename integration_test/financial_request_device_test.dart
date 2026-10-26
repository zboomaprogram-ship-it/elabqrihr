// ignore_for_file: avoid_print
// Device acceptance test for Feature 006 financial request screens (T050-T051, T063).
// Run with: flutter test integration_test/financial_request_device_test.dart -d 10JE1B00ZB000E8
// Screenshots saved to /sdcard/Download/f006_payslip/ on device.
// Pull: adb -s 10JE1B00ZB000E8 pull /sdcard/Download/f006_payslip/ test-results/screenshots/

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integration_test/integration_test.dart';

import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/attachment_picker_service.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/financial_request_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/screens/financial_request_screen.dart';

const publishedExpenseDefinition = RequestTypeCategory(
  id: 'ver-fin-expense-1',
  key: 'financial_expense_claim',
  nameAr: 'طلب استرداد مصروفات عمل',
  descriptionAr:
      'طلب استرداد مصاريف السفر والمهام الرسمية المعتمدة وفق سياسة البدلات',
  iconKey: 'receipt_long',
  offlineEligible: false,
  fields: [
    RequestFieldDefinition(
      key: 'title',
      position: 1,
      kind: FieldKind.shortText,
      labelAr: 'بيان المصروف المالي',
      required: true,
    ),
    RequestFieldDefinition(
      key: 'amount',
      position: 2,
      kind: FieldKind.decimal,
      labelAr: 'المبلغ المطلوب (SDG)',
      required: true,
    ),
    RequestFieldDefinition(
      key: 'expense_date',
      position: 3,
      kind: FieldKind.date,
      labelAr: 'تاريخ الفاتورة أو الصرف',
      required: true,
    ),
    RequestFieldDefinition(
      key: 'receipt_attachment',
      position: 4,
      kind: FieldKind.attachment,
      labelAr: 'المستند الخاص المرفق',
      required: true,
    ),
    RequestFieldDefinition(
      key: 'notes',
      position: 5,
      kind: FieldKind.longText,
      labelAr: 'ملاحظات وتفاصيل إضافية',
      required: false,
    ),
  ],
);

const publishedBonusDefinition = RequestTypeCategory(
  id: 'ver-fin-bonus-1',
  key: 'financial_bonus_request',
  nameAr: 'طلب مكافأة أداء استثنائي',
  descriptionAr: 'طلب صرف مكافأة إنجاز مشروع أو مهمة طارئة معتمدة',
  iconKey: 'card_giftcard',
  offlineEligible: false,
  fields: [
    RequestFieldDefinition(
      key: 'project_name',
      position: 1,
      kind: FieldKind.shortText,
      labelAr: 'اسم المشروع أو المهمة',
      required: true,
    ),
    RequestFieldDefinition(
      key: 'amount',
      position: 2,
      kind: FieldKind.decimal,
      labelAr: 'المبلغ المقترح (SDG)',
      required: true,
    ),
  ],
);

class _DeviceFinancialRepo extends Fake implements DynamicRequestRepository {
  final List<RequestTypeCategory> categories;
  final bool shouldDeny;

  _DeviceFinancialRepo({this.categories = const [], this.shouldDeny = false});

  @override
  Future<List<RequestTypeCategory>> getFinancialRequestCategories() async {
    if (shouldDeny) {
      throw const AuthFailure('غير مصرح لك بالوصول إلى الطلبات المالية');
    }
    return categories;
  }

  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = false,
    String? typeNameAr,
  }) async {
    return DynamicRequestEntity(
      id: 'req-fin-live-888',
      typeKey: typeKey,
      typeNameAr: 'طلب استرداد مصروفات عمل',
      definitionVersionId: definitionVersionId,
      state: 'submitted',
      revision: 1,
      values: values,
      timeline: const [],
      submittedAt: DateTime.now().toUtc(),
    );
  }
}

class _DeviceAttachmentPicker extends Fake implements AttachmentPickerService {
  @override
  Future<PickedFileResult?> pickFile() async {
    return PickedFileResult(
      bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      filename: 'official_receipt_doc.pdf',
      mediaType: 'application/pdf',
    );
  }
}

class _DeviceApiClient extends Fake implements ApiClient {
  @override
  Future<RequestAttachment> uploadRequestAttachment({
    required List<int> bytes,
    required String filename,
    String? mediaType,
  }) async {
    return RequestAttachment(
      id: 'att-auth-live-555',
      displayName: filename,
      mediaType: mediaType ?? 'application/pdf',
      sizeBytes: 15420,
      state: 'uploaded',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
  }
}

const _outDir = '/sdcard/Download/f006_payslip';

Future<void> _save(
  IntegrationTestWidgetsFlutterBinding b,
  WidgetTester tester,
  String name,
) async {
  await b.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  final bytes = await b.takeScreenshot(name);
  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  await File('$_outDir/$name').writeAsBytes(bytes);
  print('[SCREENSHOT] $name — ${bytes.length} bytes');
}

Widget _wrap(Widget screen, {ApiClient? apiClient}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: apiClient != null
          ? RepositoryProvider<ApiClient>.value(
              value: apiClient,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: screen,
              ),
            )
          : Directionality(
              textDirection: TextDirection.rtl,
              child: screen,
            ),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F006 Vivo V2254: financial request catalog — loaded 100%',
      (tester) async {
    final repo = _DeviceFinancialRepo(
      categories: [publishedExpenseDefinition, publishedBonusDefinition],
    );
    final cubit = FinancialRequestCubit(repository: repo);
    await tester.pumpWidget(_wrap(FinancialRequestScreen(cubit: cubit)));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_financial_catalog_100.png');
  });

  testWidgets('F006 Vivo V2254: financial request catalog — loaded 200%',
      (tester) async {
    final repo = _DeviceFinancialRepo(
      categories: [publishedExpenseDefinition, publishedBonusDefinition],
    );
    final cubit = FinancialRequestCubit(repository: repo);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _wrap(FinancialRequestScreen(cubit: cubit)),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_financial_catalog_200.png');
  });

  testWidgets('F006 Vivo V2254: financial request catalog — empty state',
      (tester) async {
    final repo = _DeviceFinancialRepo(categories: const []);
    final cubit = FinancialRequestCubit(repository: repo);
    await tester.pumpWidget(_wrap(FinancialRequestScreen(cubit: cubit)));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_financial_catalog_empty.png');
  });

  testWidgets('F006 Vivo V2254: financial request catalog — denied state',
      (tester) async {
    final repo = _DeviceFinancialRepo(shouldDeny: true);
    final cubit = FinancialRequestCubit(repository: repo);
    await tester.pumpWidget(_wrap(FinancialRequestScreen(cubit: cubit)));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(
        binding, tester, 'vivo_v2254_f006_financial_catalog_denied.png');
  });

  testWidgets(
      'F006 Vivo V2254: financial request form — loaded with attachment 100%',
      (tester) async {
    final repo = _DeviceFinancialRepo(categories: [publishedExpenseDefinition]);
    final cubit = FinancialRequestCubit(repository: repo);
    final picker = _DeviceAttachmentPicker();
    final client = _DeviceApiClient();

    await tester.pumpWidget(_wrap(
      FinancialRequestScreen(
        cubit: cubit,
        attachmentPicker: picker,
        initialCategory: publishedExpenseDefinition,
      ),
      apiClient: client,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.enterText(
      find.byKey(const Key('dynamic_field_title')),
      'تذاكر سفر وتكاليف إقامة مؤتمر تقني',
    );
    await tester.enterText(
      find.byKey(const Key('dynamic_field_amount')),
      '6800.00',
    );
    await tester
        .tap(find.byKey(const Key('dynamic_field_receipt_attachment_btn')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await _save(binding, tester, 'vivo_v2254_f006_financial_form_100.png');
  });

  testWidgets('F006 Vivo V2254: financial request form — 200% text scale',
      (tester) async {
    final repo = _DeviceFinancialRepo(categories: [publishedExpenseDefinition]);
    final cubit = FinancialRequestCubit(repository: repo);
    final picker = _DeviceAttachmentPicker();
    final client = _DeviceApiClient();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _wrap(
          FinancialRequestScreen(
            cubit: cubit,
            attachmentPicker: picker,
            initialCategory: publishedExpenseDefinition,
          ),
          apiClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await _save(binding, tester, 'vivo_v2254_f006_financial_form_200.png');
  });

  testWidgets(
      'F006 Vivo V2254: financial request form — submitted confirmation',
      (tester) async {
    final repo = _DeviceFinancialRepo(categories: [publishedExpenseDefinition]);
    final cubit = FinancialRequestCubit(repository: repo);
    final picker = _DeviceAttachmentPicker();
    final client = _DeviceApiClient();

    await tester.pumpWidget(_wrap(
      FinancialRequestScreen(
        cubit: cubit,
        attachmentPicker: picker,
        initialCategory: publishedExpenseDefinition,
      ),
      apiClient: client,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.enterText(
      find.byKey(const Key('dynamic_field_title')),
      'تذاكر سفر وتكاليف إقامة مؤتمر تقني',
    );
    await tester.enterText(
      find.byKey(const Key('dynamic_field_amount')),
      '6800.00',
    );
    await tester
        .tap(find.byKey(const Key('dynamic_field_receipt_attachment_btn')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester
        .ensureVisible(find.byKey(const Key('dynamic_form_submit_button')));
    await tester.tap(find.byKey(const Key('dynamic_form_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await _save(
        binding, tester, 'vivo_v2254_f006_financial_form_submitted.png');
  });
}
