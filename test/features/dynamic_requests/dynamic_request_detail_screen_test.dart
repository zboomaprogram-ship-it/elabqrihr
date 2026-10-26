import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_detail_screen.dart';

class _DynamicRepository extends Mock implements DynamicRequestRepository {}

void main() {
  testWidgets(
      'dynamic history opens its dynamic detail instead of legacy request detail',
      (tester) async {
    final repository = _DynamicRepository();
    when(() => repository.getDynamicRequest('dynamic-request-1')).thenAnswer(
      (_) async => DynamicRequestEntity(
        id: 'dynamic-request-1',
        typeKey: 'expense_claim',
        typeNameAr: 'طلب مصروف',
        definitionVersionId: 'definition-1',
        state: 'pending_approval',
        revision: 3,
        values: const {'amount': 125},
        timeline: const [],
        submittedAt: DateTime.utc(2026, 9, 30, 8),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<DynamicRequestRepository>.value(
          value: repository,
          child: const RequestDetailScreen(
            requestId: 'dynamic-request-1',
            isDynamic: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('طلب مصروف'), findsOneWidget);
    expect(find.text('بيانات الطلب'), findsOneWidget);
    expect(find.text('مسار الموافقة'), findsOneWidget);
    verify(() => repository.getDynamicRequest('dynamic-request-1')).called(1);
  });
}
