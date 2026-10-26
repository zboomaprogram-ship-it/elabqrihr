import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/dynamic_requests/data/dynamic_request_repository_impl.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';

class InMemoryTokenStorage extends TokenStorage {
  AuthSessionEntity? _session;

  InMemoryTokenStorage([this._session]);

  @override
  Future<void> saveSession(AuthSessionEntity session) async =>
      _session = session;

  @override
  Future<AuthSessionEntity?> getSession() async => _session;

  @override
  Future<void> clearSession() async => _session = null;
}

void main() {
  group('Dynamic Request Contract & Repository Tests (T060 - OpenAPI 0.6.1)',
      () {
    late Dio dio;
    late ApiClient apiClient;
    late AppDriftDatabase database;
    late InMemoryTokenStorage tokenStorage;
    late DynamicRequestRepositoryImpl repository;

    const testSession = AuthSessionEntity(
      accessToken: 'jwt-test',
      tenantId: 'tenant-test-1',
      userId: 'user-emp-1',
      role: UserRole.employee,
      email: 'emp@test.local',
      displayName: 'أحمد محمود',
    );

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test'));
      tokenStorage = InMemoryTokenStorage(testSession);
      apiClient = ApiClient(
          baseUrl: 'http://test', dio: dio, tokenStorage: tokenStorage);
      database = AppDriftDatabase(NativeDatabase.memory());
      tokenStorage = InMemoryTokenStorage(testSession);
      repository = DynamicRequestRepositoryImpl(
        apiClient: apiClient,
        database: database,
        tokenStorage: tokenStorage,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('GET /request-catalog deserializes all 12 approved field kinds',
        () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/request-catalog') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'items': [
                      {
                        'typeKey': 'leave',
                        'nameAr': 'إجازة وفق سياسة الشركة',
                        'kind': 'built_in',
                        'categoryKey': 'leave',
                        'offlineEligible': true,
                      },
                      {
                        'typeKey': 'equipment_provisioning',
                        'nameAr': 'طلب توفير أجهزة ومعدات',
                        'description': 'طلب استلام أجهزة ومعدات حاسوبية',
                        'iconKey': 'laptop',
                        'kind': 'dynamic',
                        'categoryKey': 'financial',
                        'definitionVersionId': 'ver-eq-100',
                        'fields': [
                          {
                            'key': 'f_short_text',
                            'position': 1,
                            'kind': 'short_text',
                            'labelAr': 'عنوان الطلب',
                            'required': true,
                          },
                          {
                            'key': 'f_long_text',
                            'position': 2,
                            'kind': 'long_text',
                            'labelAr': 'المواصفات المطلوبة',
                            'required': false,
                          },
                          {
                            'key': 'f_integer',
                            'position': 3,
                            'kind': 'integer',
                            'labelAr': 'العدد المطلوب',
                            'required': true,
                          },
                          {
                            'key': 'f_decimal',
                            'position': 4,
                            'kind': 'decimal',
                            'labelAr': 'الميزانية التقديرية',
                            'required': false,
                          },
                          {
                            'key': 'f_date',
                            'position': 5,
                            'kind': 'date',
                            'labelAr': 'تاريخ الحاجة',
                            'required': true,
                          },
                          {
                            'key': 'f_time',
                            'position': 6,
                            'kind': 'time',
                            'labelAr': 'وقت الاستلام',
                            'required': false,
                          },
                          {
                            'key': 'f_date_time',
                            'position': 7,
                            'kind': 'date_time',
                            'labelAr': 'الموعد النهائي',
                            'required': false,
                          },
                          {
                            'key': 'f_single_choice',
                            'position': 8,
                            'kind': 'single_choice',
                            'labelAr': 'نوع الجهاز',
                            'required': true,
                            'choices': [
                              {'code': 'laptop', 'labelAr': 'حاسوب محمول'},
                              {'code': 'monitor', 'labelAr': 'شاشة إضافية'},
                            ],
                          },
                          {
                            'key': 'f_multiple_choice',
                            'position': 9,
                            'kind': 'multiple_choice',
                            'labelAr': 'الملحقات المطلوبة',
                            'required': false,
                            'choices': [
                              {'code': 'mouse', 'labelAr': 'فأرة لاسلكية'},
                              {'code': 'keyboard', 'labelAr': 'لوحة مفاتيح'},
                            ],
                          },
                          {
                            'key': 'f_boolean',
                            'position': 10,
                            'kind': 'boolean',
                            'labelAr': 'عاجل جداً',
                            'required': false,
                          },
                          {
                            'key': 'f_attachment',
                            'position': 11,
                            'kind': 'attachment',
                            'labelAr': 'عروض الأسعار المرفقة',
                            'required': false,
                          },
                          {
                            'key': 'f_employee_reference',
                            'position': 12,
                            'kind': 'employee_reference',
                            'labelAr': 'المستفيد المباشر',
                            'required': false,
                          },
                        ],
                      }
                    ],
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final categories = await repository.getRequestCategories();

      // The server controls both template and dynamic categories.
      expect(categories.length, equals(2));
      expect(categories.first.nameAr, equals('إجازة وفق سياسة الشركة'));

      final dynamicCat =
          categories.firstWhere((c) => c.key == 'equipment_provisioning');
      expect(dynamicCat.nameAr, equals('طلب توفير أجهزة ومعدات'));
      expect(dynamicCat.id, equals('ver-eq-100'));
      expect(dynamicCat.fields.length, equals(12));

      // Verify each of the 12 field kinds
      expect(dynamicCat.fields[0].kind, equals(FieldKind.shortText));
      expect(dynamicCat.fields[1].kind, equals(FieldKind.longText));
      expect(dynamicCat.fields[2].kind, equals(FieldKind.integer));
      expect(dynamicCat.fields[3].kind, equals(FieldKind.decimal));
      expect(dynamicCat.fields[4].kind, equals(FieldKind.date));
      expect(dynamicCat.fields[5].kind, equals(FieldKind.time));
      expect(dynamicCat.fields[6].kind, equals(FieldKind.dateTime));
      expect(dynamicCat.fields[7].kind, equals(FieldKind.singleChoice));
      expect(dynamicCat.fields[7].choiceOptions.length, equals(2));
      expect(dynamicCat.fields[8].kind, equals(FieldKind.multipleChoice));
      expect(dynamicCat.fields[9].kind, equals(FieldKind.boolean));
      expect(dynamicCat.fields[10].kind, equals(FieldKind.attachment));
      expect(dynamicCat.fields[11].kind, equals(FieldKind.employeeReference));
    });

    test(
        'POST /dynamic-requests strict dynamic submission asserts NO typeKey in serialized payload',
        () async {
      Map<String, dynamic>? interceptedBody;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/dynamic-requests' &&
                options.method == 'POST') {
              interceptedBody = options.data is String
                  ? jsonDecode(options.data as String) as Map<String, dynamic>
                  : options.data as Map<String, dynamic>;

              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': interceptedBody!['requestId'],
                    'typeKey': 'equipment_provisioning',
                    'typeNameAr': 'طلب توفير أجهزة ومعدات',
                    'definitionVersionId':
                        interceptedBody!['definitionVersionId'],
                    'state': 'submitted',
                    'revision': 1,
                    'values': interceptedBody!['values'],
                    'timeline': [],
                    'submittedAt': '2026-09-23T10:00:00.000Z',
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final result = await repository.submitDynamicRequest(
        typeKey: 'equipment_provisioning',
        definitionVersionId: 'ver-eq-100',
        values: {
          'f_short_text': 'طلب شاشة 27 بوصة',
          'f_integer': 2,
          'f_attachment': 'att-priv-999',
        },
      );

      expect(interceptedBody, isNotNull);
      // STRICT OpenAPI 0.6.1 assertion: NO typeKey in POST /dynamic-requests
      expect(interceptedBody!.containsKey('typeKey'), isFalse,
          reason:
              'OpenAPI 0.6.1 CreateDynamicRequest must never contain typeKey');
      expect(interceptedBody!['requestId'], isNotEmpty);
      expect(interceptedBody!['commandId'], isNotEmpty);
      expect(interceptedBody!['definitionVersionId'], equals('ver-eq-100'));
      expect(interceptedBody!['capturedAt'], isNotEmpty);
      expect(
          interceptedBody!['values']['f_attachment'], equals('att-priv-999'));

      expect(result.id, equals(interceptedBody!['requestId']));
      expect(result.state, equals('submitted'));
    });

    test('POST & GET /request-attachments private upload and download contract',
        () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/request-attachments' &&
                options.method == 'POST') {
              expect(options.data, isA<FormData>());
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': 'att-uuid-888',
                    'displayName': 'medical_report.pdf',
                    'sizeBytes': 2048,
                    'mediaType': 'application/pdf',
                    'state': 'uploaded',
                    'expiresAt': '2026-09-24T10:00:00.000Z',
                  },
                ),
              );
            }

            if (options.path == '/request-attachments/att-uuid-888' &&
                options.method == 'GET') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [10, 20, 30, 40, 50],
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final uploaded = await apiClient.uploadRequestAttachment(
        bytes: [10, 20, 30, 40, 50],
        filename: 'medical_report.pdf',
        mediaType: 'application/pdf',
      );

      expect(uploaded.id, equals('att-uuid-888'));
      expect(uploaded.displayName, equals('medical_report.pdf'));
      expect(uploaded.sizeBytes, equals(2048));
      expect(uploaded.mediaType, equals('application/pdf'));
      expect(uploaded.state, equals('uploaded'));

      final downloadedBytes =
          await apiClient.downloadRequestAttachment('att-uuid-888');
      expect(downloadedBytes, equals([10, 20, 30, 40, 50]));
    });

    test('GET /request-activity and GET /approval-activity contract', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/request-activity') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'items': [
                      {
                        'kind': 'dynamic',
                        'id': 'req-dyn-001',
                        'typeKey': 'equipment_provisioning',
                        'typeNameAr': 'طلب توفير أجهزة',
                        'state': 'submitted',
                        'revision': 1,
                        'currentStageLabel': 'قيد مراجعة المدير المباشر',
                        'submittedAt': '2026-09-23T09:30:00.000Z',
                      }
                    ],
                  },
                ),
              );
            }
            if (options.path == '/approval-activity') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'items': [
                      {
                        'kind': 'dynamic',
                        'requestId': 'req-dyn-001',
                        'typeNameAr': 'طلب توفير أجهزة',
                        'requesterDisplayName': 'أحمد محمود',
                        'state': 'pending',
                        'stageLabel': 'قيد مراجعة المدير المباشر',
                        'expectedRevision': 1,
                        'submittedAt': '2026-09-23T10:15:00.000Z',
                      }
                    ],
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final reqActivity = await apiClient.listMyRequestActivity();
      expect(reqActivity.items.length, equals(1));
      expect(reqActivity.items.first.id, equals('req-dyn-001'));
      expect(reqActivity.items.first.state, equals('submitted'));
      expect(reqActivity.items.first.typeKey, equals('equipment_provisioning'));

      final appActivity = await apiClient.listMyApprovalActivity();
      expect(appActivity.items.length, equals(1));
      expect(appActivity.items.first.requestId, equals('req-dyn-001'));
      expect(appActivity.items.first.state, equals('pending'));
      expect(appActivity.items.first.expectedRevision, equals(1));
    });

    test(
        'HTTP error status codes (400, 404, 409, 413, 415, 422) map accurately to ApiException',
        () async {
      final statuses = [400, 404, 409, 413, 415, 422];

      for (final code in statuses) {
        final client = ApiClient(
          baseUrl: 'http://test',
          dio: Dio(BaseOptions(baseUrl: 'http://test')),
          tokenStorage: tokenStorage,
        );

        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: code,
                    data: {
                      'message': 'Error for HTTP $code',
                      'code': 'ERR_$code',
                    },
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            },
          ),
        );

        expect(
          () => client.listRequestCatalog(),
          throwsA(predicate((e) =>
              e is ApiException &&
              e.statusCode == code &&
              e.code == 'ERR_$code')),
          reason: 'Failed to properly map HTTP $code to ApiException',
        );
      }
    });

    test(
        'DynamicRequestEntity.fromJson strictly rejects missing or malformed server timestamps',
        () {
      final validJson = {
        'id': 'req-1',
        'typeKey': 'equipment',
        'typeNameAr': 'أجهزة',
        'definitionVersionId': 'v1',
        'state': 'submitted',
        'revision': 1,
        'values': {},
        'timeline': [],
      };

      // 1. Missing submittedAt throws FormatException
      expect(
        () => DynamicRequestEntity.fromJson(validJson),
        throwsA(isA<FormatException>()),
      );

      // 2. Malformed submittedAt throws FormatException
      expect(
        () => DynamicRequestEntity.fromJson({
          ...validJson,
          'submittedAt': 'not-a-valid-date-iso',
        }),
        throwsA(isA<FormatException>()),
      );

      // 3. Malformed decidedAt throws FormatException
      expect(
        () => DynamicRequestEntity.fromJson({
          ...validJson,
          'submittedAt': '2026-09-23T10:00:00.000Z',
          'decidedAt': 'invalid-decided-at',
        }),
        throwsA(isA<FormatException>()),
      );

      // 4. Malformed cancelledAt throws FormatException
      expect(
        () => DynamicRequestEntity.fromJson({
          ...validJson,
          'submittedAt': '2026-09-23T10:00:00.000Z',
          'cancelledAt': 'invalid-cancelled-at',
        }),
        throwsA(isA<FormatException>()),
      );

      // 5. Valid timestamps parse correctly without exception
      final parsed = DynamicRequestEntity.fromJson({
        ...validJson,
        'submittedAt': '2026-09-23T10:00:00.000Z',
        'decidedAt': '2026-09-23T11:00:00.000Z',
      });
      expect(parsed.submittedAt.year, equals(2026));
      expect(parsed.decidedAt?.year, equals(2026));
    });
  });
}
