import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';

class _NoSessionStorage extends TokenStorage {
  @override
  Future<AuthSessionEntity?> getSession() async => null;

  @override
  Future<void> saveSession(AuthSessionEntity session) async {}

  @override
  Future<void> clearSession() async {}
}

ApiClient _requestClient(void Function(Map<String, dynamic>) inspect) {
  final dio = Dio(BaseOptions(baseUrl: 'http://contract.test'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final body = Map<String, dynamic>.from(options.data as Map);
    inspect(body);
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 201,
      data: {
        'id': body['requestId'],
        'employeeId': '397e59eb-cf12-4217-bf48-316886e8ea34',
        'type': body['type'],
        'state': 'pending_approval',
        'revision': 1,
        'requestedMinutes': 60,
        'submittedAt': '2026-09-21T08:00:00.000Z',
        'details': body,
        'steps': <Object>[],
      },
    ));
  }));
  return ApiClient(
    baseUrl: 'http://contract.test',
    tokenStorage: _NoSessionStorage(),
    dio: dio,
  );
}

void main() {
  group('Request Serialization & Contract Types (T021/T022)', () {
    test('ApiClient sends exact OpenAPI 0.4.1 payloads for all request types',
        () async {
      final payloads = [
        {
          'requestId': 'b87d3a2e-8480-4961-8ff8-98e82023a100',
          'type': 'leave',
          'categoryId': '00000000-0000-0000-0000-000000000001',
          'startDate': '2026-09-22',
          'endDate': '2026-09-23',
          'reason': 'طلب إجازة اعتيادية',
        },
        {
          'requestId': 'c98e4b3f-9591-5072-9aa9-09f93134b211',
          'type': 'permission',
          'shiftInstanceId': '8c52084c-cb14-41d9-813a-773cefb180a0',
          'categoryCode': 'personal',
          'startsAt': '2026-09-22T09:00:00.000Z',
          'endsAt': '2026-09-22T11:00:00.000Z',
          'reason': 'إذن شخصي لمراجعة دائرة حكومية',
        },
        {
          'requestId': 'd09f5c4a-0602-6183-abb0-10a04245c322',
          'type': 'attendance_correction',
          'shiftInstanceId': '8c52084c-cb14-41d9-813a-773cefb180a0',
          'correctionKind': 'add_check_in',
          'proposedAt': '2026-09-22T08:30:00.000Z',
          'reason': 'نسيان البصمة عند الدخول',
        },
      ];

      for (final expected in payloads) {
        final client = _requestClient((actual) {
          expect(actual, expected);
          expect(actual.containsKey('requestedMinutes'), isFalse);
        });
        final result = await client.submitRequest(expected);
        expect(result.type, expected['type']);
      }
    });
    test(
        'CreateLeaveRequest canonical contract payload forbids requestedMinutes',
        () {
      final payload = <String, dynamic>{
        'requestId': 'b87d3a2e-8480-4961-8ff8-98e82023a100',
        'type': 'leave',
        'categoryId': '00000000-0000-0000-0000-000000000001',
        'startDate': '2026-09-22',
        'endDate': '2026-09-23',
        'reason': 'طلب إجازة اعتيادية',
      };

      const allowedKeys = {
        'requestId',
        'type',
        'categoryId',
        'startDate',
        'endDate',
        'partialStartTime',
        'partialEndTime',
        'reason',
      };

      for (final key in payload.keys) {
        expect(allowedKeys.contains(key), isTrue,
            reason:
                'Key $key is not permitted by OpenAPI 0.4.0 CreateLeaveRequest');
      }
      expect(payload.containsKey('requestedMinutes'), isFalse);
    });

    test(
        'CreatePermissionRequest canonical contract payload forbids requestedMinutes',
        () {
      final payload = <String, dynamic>{
        'requestId': 'c98e4b3f-9591-5072-9aa9-09f93134b211',
        'type': 'permission',
        'shiftInstanceId': 'shift-inst-001',
        'categoryCode': 'personal',
        'startsAt': '2026-09-22T09:00:00.000Z',
        'endsAt': '2026-09-22T11:00:00.000Z',
        'reason': 'إذن شخصي لمراجعة دائرة حكومية',
      };

      const allowedKeys = {
        'requestId',
        'type',
        'shiftInstanceId',
        'categoryCode',
        'startsAt',
        'endsAt',
        'reason',
      };

      for (final key in payload.keys) {
        expect(allowedKeys.contains(key), isTrue,
            reason:
                'Key $key is not permitted by OpenAPI 0.4.0 CreatePermissionRequest');
      }
      expect(payload.containsKey('requestedMinutes'), isFalse);
    });

    test(
        'CreateCorrectionRequest canonical contract payload conforms to schema',
        () {
      final payload = <String, dynamic>{
        'requestId': 'd09f5c4a-0602-6183-abb0-10a04245c322',
        'type': 'attendance_correction',
        'shiftInstanceId': 'shift-inst-002',
        'sourceEventId': 'event-001',
        'correctionKind': 'add_check_in',
        'proposedAt': '2026-09-22T08:30:00.000Z',
        'reason': 'نسيان البصمة عند الدخول',
      };

      const allowedKeys = {
        'requestId',
        'type',
        'shiftInstanceId',
        'sourceEventId',
        'correctionKind',
        'proposedAt',
        'reason',
      };

      for (final key in payload.keys) {
        expect(allowedKeys.contains(key), isTrue,
            reason:
                'Key $key is not permitted by OpenAPI 0.4.0 CreateCorrectionRequest');
      }
      expect(payload.containsKey('requestedMinutes'), isFalse);
    });

    test('RequestDto round-trip serialization matches OpenAPI 0.4.0 schema',
        () {
      final json = {
        'id': 'b87d3a2e-8480-4961-8ff8-98e82023a100',
        'employeeId': '397e59eb-cf12-4217-bf48-316886e8ea34',
        'employeeName': 'أحمد إبراهيم',
        'type': 'leave',
        'state': 'pending_approval',
        'revision': 2,
        'requestedMinutes': 480,
        'submittedAt': '2026-09-21T08:00:00.000Z',
        'decidedAt': null,
        'cancelledAt': null,
        'reasonCode': null,
        'details': {
          'categoryId': '00000000-0000-0000-0000-000000000001',
          'startDate': '2026-09-22',
          'endDate': '2026-09-22',
          'reason': 'إجازة سنوية لظرف عائلي',
        },
        'steps': [
          {
            'id': 'step-1',
            'position': 1,
            'reviewerRole': 'manager',
            'reviewerName': 'محمد المدير',
            'state': 'pending',
            'decidedAt': null,
            'comment': null,
          }
        ],
      };

      final dto = RequestDto.fromJson(json);

      expect(dto.id, 'b87d3a2e-8480-4961-8ff8-98e82023a100');
      expect(dto.employeeName, 'أحمد إبراهيم');
      expect(dto.type, 'leave');
      expect(dto.state, 'pending_approval');
      expect(dto.revision, 2);
      expect(dto.requestedMinutes, 480);
      expect(dto.steps.length, 1);
      expect(dto.steps.first.reviewerRole, 'manager');

      final serialized = dto.toJson();
      expect(serialized['id'], dto.id);
      expect(serialized['revision'], 2);
      expect(serialized['type'], 'leave');
    });

    test('LeaveBalanceDto parses ledger balance correctly', () {
      final json = {
        'employeeId': 'emp-123',
        'categoryId': 'cat-annual',
        'categoryName': 'إجازة سنوية',
        'periodStart': '2026-01-01',
        'periodEnd': '2026-12-31',
        'balanceMinutes': 9600,
      };

      final dto = LeaveBalanceDto.fromJson(json);
      expect(dto.employeeId, 'emp-123');
      expect(dto.categoryName, 'إجازة سنوية');
      expect(dto.balanceMinutes, 9600);
      expect(dto.balanceMinutes / 480, 20.0); // 20 days
    });

    test(
        'Domain RequestType and RequestState map accurately to contract strings',
        () {
      expect(RequestType.leave.toApiValue(), 'leave');
      expect(RequestType.permission.toApiValue(), 'permission');
      expect(RequestType.attendanceCorrection.toApiValue(),
          'attendance_correction');

      expect(RequestState.submitted.toApiValue(), 'submitted');
      expect(RequestState.pendingApproval.toApiValue(), 'pending_approval');
      expect(RequestState.approved.toApiValue(), 'approved');
      expect(RequestState.rejected.toApiValue(), 'rejected');
      expect(RequestState.cancelled.toApiValue(), 'cancelled');
      expect(RequestState.pendingSync.toApiValue(), 'pending_sync');
      expect(RequestState.conflict.toApiValue(), 'conflict');
    });
  });
}
