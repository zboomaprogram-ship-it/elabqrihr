import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/mobile_controls/data/mobile_controls_cache_impl.dart';
import 'package:attend_mobile/features/mobile_controls/data/mobile_controls_repository_impl.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_repository.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/mobile_controls_cubit.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/mobile_controls_state.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/widgets/mobile_controls_views.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class FakeTokenStorage extends TokenStorage {
  final AuthSessionEntity? session;
  FakeTokenStorage(this.session);

  @override
  Future<AuthSessionEntity?> getSession() async => session;
}

class FakeMobileControlsCache implements MobileControlsCachePort {
  final Map<String, String> _store = {};

  @override
  Future<MobileOperationalConfiguration?> getCached({
    required String tenantId,
    required String userId,
  }) async {
    final raw = _store['$tenantId:$userId'];
    if (raw == null) return null;
    try {
      final config = MobileOperationalConfiguration.fromMap(
          jsonDecode(raw) as Map<String, dynamic>);
      if (config.isExpired()) return null;
      return config;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save({
    required String tenantId,
    required String userId,
    required MobileOperationalConfiguration config,
  }) async {
    _store['$tenantId:$userId'] = jsonEncode(config.toMap());
  }

  @override
  Future<void> clear({
    required String tenantId,
    required String userId,
  }) async {
    _store.remove('$tenantId:$userId');
  }
}

void main() {
  final testSession = AuthSessionEntity(
    accessToken: 'test-token',
    tenantId: 'tenant-100',
    userId: 'user-200',
    role: UserRole.employee,
    email: 'test@example.com',
    displayName: 'Test User',
  );

  group('Feature 019: Mobile Controls Domain & Restrictive Defaults', () {
    test('defaultRestrictive creates safe non-executing configuration', () {
      final config = MobileOperationalConfiguration.defaultRestrictive();
      expect(config.version, equals('1'));
      expect(config.isExpired(), isFalse);
      expect(config.isActionAllowed(MobileControlKey.requestsSubmit), isTrue);
      expect(config.isActionAllowed(MobileControlKey.attendanceSubmit), isTrue);
      expect(config.buildPolicy.minimumBuild, equals(1));
      expect(config.buildPolicy.recommendedBuild, equals(19));
      expect(
          config.destinations, contains(MobileAllowedDestination.attendance));
    });

    test('parses contract JSON correctly with maintenance/restricted states',
        () {
      final map = {
        'version': '2',
        'issuedAt': DateTime.now().toUtc().toIso8601String(),
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
        'controls': {
          'requests.submit': {
            'controlKey': 'requests.submit',
            'state': 'maintenance',
            'outcomeCode': 'MOBILE_ACTION_RESTRICTED',
            'messageAr': 'صيانة مؤقتة لخدمة الطلبات',
            'revision': 1,
          },
          'attendance.submit': {
            'controlKey': 'attendance.submit',
            'state': 'normal',
            'outcomeCode': 'MOBILE_ACTION_ALLOWED',
            'revision': 0,
          },
        },
        'buildPolicy': {'minimumBuild': 18, 'recommendedBuild': 20},
        'messages': [],
        'destinations': ['notification_center', 'attendance'],
        'dynamicContent': {
          'requestCatalogVersion': 'catalog-${'a' * 64}',
        },
      };

      final config = MobileOperationalConfiguration.fromMap(map);
      expect(config.version, equals('2'));
      expect(config.isActionAllowed(MobileControlKey.requestsSubmit), isFalse);
      expect(config.isActionAllowed(MobileControlKey.attendanceSubmit), isTrue);

      final reqControl = config.getControl(MobileControlKey.requestsSubmit);
      expect(reqControl?.state, equals(MobileControlState.maintenance));
      expect(reqControl?.messageAr, equals('صيانة مؤقتة لخدمة الطلبات'));
      expect(config.buildPolicy.isUpdateRequired(17), isTrue);
      expect(config.buildPolicy.isUpdateRequired(19), isFalse);
      expect(config.buildPolicy.isUpdateRecommended(19), isTrue);
      expect(config.destinations,
          contains(MobileAllowedDestination.notificationCenter));
      expect(config.destinations,
          isNot(contains(MobileAllowedDestination.requestHistory)));
      expect(
        config.dynamicContent?.requestCatalogVersion,
        equals('catalog-${'a' * 64}'),
      );
    });

    test(
        'ignores malformed dynamic content instead of accepting remote instructions',
        () {
      final config = MobileOperationalConfiguration.fromMap({
        'version': '2',
        'issuedAt': DateTime.now().toUtc().toIso8601String(),
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
        'controls': {},
        'buildPolicy': {'minimumBuild': 18, 'recommendedBuild': 19},
        'messages': [],
        'destinations': ['attendance', 'untrusted_destination'],
        'dynamicContent': {'requestCatalogVersion': 'navigate:/admin'},
      });

      expect(config.dynamicContent, isNull);
      expect(
          config.destinations, contains(MobileAllowedDestination.attendance));
      expect(config.destinations, isNot(contains('untrusted_destination')));
    });
  });

  group('Feature 019: Cache & Identity Isolation', () {
    test(
        'strictly isolates cached configurations across tenant and user identities',
        () async {
      final cache = FakeMobileControlsCache();
      final configUser1 = MobileOperationalConfiguration.defaultRestrictive();
      await cache.save(
        tenantId: 'tenant-A',
        userId: 'user-1',
        config: configUser1,
      );

      final user1Read =
          await cache.getCached(tenantId: 'tenant-A', userId: 'user-1');
      expect(user1Read, isNotNull);

      final user2Read =
          await cache.getCached(tenantId: 'tenant-A', userId: 'user-2');
      expect(user2Read, isNull,
          reason: 'Cross-user cache read must return null');

      final tenantBRead =
          await cache.getCached(tenantId: 'tenant-B', userId: 'user-1');
      expect(tenantBRead, isNull,
          reason: 'Cross-tenant cache read must return null');
    });

    test('discards expired cache automatically', () async {
      final cache = FakeMobileControlsCache();
      final expiredConfig = MobileOperationalConfiguration(
        version: '1',
        issuedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
        controls: {},
        buildPolicy:
            const MobileBuildPolicy(minimumBuild: 1, recommendedBuild: 1),
        messages: const [],
        destinations: const {},
      );

      await cache.save(
        tenantId: 'tenant-A',
        userId: 'user-1',
        config: expiredConfig,
      );

      final read =
          await cache.getCached(tenantId: 'tenant-A', userId: 'user-1');
      expect(read, isNull, reason: 'Expired cache must be discarded');
    });

    test(
        'MobileControlsCacheImpl delegates writes and reads to FlutterSecureStorage',
        () async {
      final mockStorage = MockFlutterSecureStorage();
      final cacheImpl = MobileControlsCacheImpl(mockStorage);
      final config = MobileOperationalConfiguration.defaultRestrictive();

      when(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => jsonEncode(config.toMap()));
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await cacheImpl.save(
        tenantId: 'tenant-1',
        userId: 'user-1',
        config: config,
      );
      verify(() => mockStorage.write(
            key: 'attend_mobile_controls_tenant-1_user-1',
            value: any(named: 'value'),
          )).called(1);

      final read = await cacheImpl.getCached(
        tenantId: 'tenant-1',
        userId: 'user-1',
      );
      expect(read, isNotNull);
      expect(read?.version, equals('1'));

      await cacheImpl.clear(
        tenantId: 'tenant-1',
        userId: 'user-1',
      );
      verify(() => mockStorage.delete(
            key: 'attend_mobile_controls_tenant-1_user-1',
          )).called(1);
    });
  });

  group('Feature 019: Repository Refresh & Fallback', () {
    late MockApiClient mockApiClient;
    late FakeTokenStorage tokenStorage;
    late FakeMobileControlsCache cache;
    late MobileControlsRepositoryImpl repository;

    setUp(() {
      mockApiClient = MockApiClient();
      tokenStorage = FakeTokenStorage(testSession);
      cache = FakeMobileControlsCache();
      repository = MobileControlsRepositoryImpl(
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
        cache: cache,
      );
    });

    test('fetches from API, updates cache, and returns fresh configuration',
        () async {
      when(() => mockApiClient.getMobileOperationalConfiguration()).thenAnswer(
        (_) async => {
          'version': '3',
          'issuedAt': DateTime.now().toUtc().toIso8601String(),
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 15))
              .toIso8601String(),
          'controls': {
            'attendance.submit': {
              'controlKey': 'attendance.submit',
              'state': 'restricted',
              'outcomeCode': 'MOBILE_ACTION_RESTRICTED',
              'messageAr': 'تسجيل الحضور متوقف مؤقتاً',
              'revision': 2,
            },
          },
          'buildPolicy': {'minimumBuild': 1, 'recommendedBuild': 19},
          'messages': [],
          'destinations': ['attendance'],
        },
      );

      final result = await repository.getConfiguration(forceRefresh: true);
      expect(result.version, equals('3'));
      expect(
          result.isActionAllowed(MobileControlKey.attendanceSubmit), isFalse);

      final cached = await cache.getCached(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(cached?.version, equals('3'));
    });

    test(
        'safely falls back to cache or default on network error without crashing',
        () async {
      when(() => mockApiClient.getMobileOperationalConfiguration())
          .thenThrow(Exception('Network timeout'));

      final result = await repository.getConfiguration(forceRefresh: true);
      expect(result, isNotNull);
      expect(result.version, equals('1'));
    });
  });

  group('Feature 019: MobileControlsCubit & Action Guards', () {
    late MockApiClient mockApiClient;
    late FakeTokenStorage tokenStorage;
    late FakeMobileControlsCache cache;
    late MobileControlsRepositoryImpl repository;

    setUp(() {
      mockApiClient = MockApiClient();
      tokenStorage = FakeTokenStorage(testSession);
      cache = FakeMobileControlsCache();
      repository = MobileControlsRepositoryImpl(
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
        cache: cache,
      );
    });

    test('evaluates ActionAllowed when control is normal', () async {
      final cubit = MobileControlsCubit(
        repository: repository,
        currentBuildNumber: 19,
      );

      final decision = cubit.evaluateAction(MobileControlKey.requestsSubmit);
      expect(decision.isPermitted, isTrue);
      expect(decision, isA<ActionAllowed>());
    });

    test('evaluates ActionMaintenance with safe Arabic message', () async {
      final maintenanceConfig = MobileOperationalConfiguration(
        version: '5',
        issuedAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
        controls: {
          MobileControlKey.attendanceSubmit: const MobileControlEntry(
            controlKey: MobileControlKey.attendanceSubmit,
            state: MobileControlState.maintenance,
            outcomeCode: 'MOBILE_ACTION_RESTRICTED',
            messageAr: 'نظام الحضور قيد الصيانة المجدولة',
          ),
        },
        buildPolicy:
            const MobileBuildPolicy(minimumBuild: 1, recommendedBuild: 19),
        messages: const [],
        destinations: MobileAllowedDestination.values.toSet(),
      );

      final customRepo = MobileControlsRepositoryImpl(
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
        cache: cache,
        initialConfiguration: maintenanceConfig,
      );

      final cubit = MobileControlsCubit(
        repository: customRepo,
        currentBuildNumber: 19,
      );
      await cubit.loadConfiguration();

      final decision = cubit.evaluateAction(MobileControlKey.attendanceSubmit);
      expect(decision.isPermitted, isFalse);
      expect(decision, isA<ActionMaintenance>());
      final maintenance = decision as ActionMaintenance;
      expect(maintenance.messageAr, equals('نظام الحضور قيد الصيانة المجدولة'));
    });

    test('evaluates UpdateRequired when currentBuild is below minimumBuild',
        () async {
      final updateReqConfig = MobileOperationalConfiguration(
        version: '5',
        issuedAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
        controls: const {},
        buildPolicy:
            const MobileBuildPolicy(minimumBuild: 20, recommendedBuild: 22),
        messages: const [],
        destinations: MobileAllowedDestination.values.toSet(),
      );

      final customRepo = MobileControlsRepositoryImpl(
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
        cache: cache,
        initialConfiguration: updateReqConfig,
      );

      // currentBuildNumber is 19, which is < 20 (update required)
      final cubit = MobileControlsCubit(
        repository: customRepo,
        currentBuildNumber: 19,
      );
      await cubit.loadConfiguration();

      expect(cubit.state.isUpdateRequired, isTrue);
      final decision = cubit.evaluateAction(MobileControlKey.requestsSubmit);
      expect(decision.isPermitted, isFalse);
      expect(decision, isA<UpdateRequired>());
    });

    test('validates destination allow-list correctly', () async {
      final destConfig = MobileOperationalConfiguration(
        version: '6',
        issuedAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
        controls: const {},
        buildPolicy:
            const MobileBuildPolicy(minimumBuild: 1, recommendedBuild: 19),
        messages: const [],
        destinations: {MobileAllowedDestination.notificationCenter},
      );

      final customRepo = MobileControlsRepositoryImpl(
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
        cache: cache,
        initialConfiguration: destConfig,
      );

      final cubit = MobileControlsCubit(
        repository: customRepo,
        currentBuildNumber: 19,
      );
      await cubit.loadConfiguration();

      expect(
        cubit.isDestinationAllowed(MobileAllowedDestination.notificationCenter),
        isTrue,
      );
      expect(
        cubit.isDestinationAllowed(MobileAllowedDestination.attendance),
        isFalse,
      );
    });
  });

  group('Feature 019: Arabic Accessible Widgets', () {
    testWidgets('MobileControlRestrictedBanner renders Arabic text in RTL',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileControlRestrictedBanner(
              messageAr: 'إرسال الطلبات متوقف مؤقتاً للصيانة',
              isMaintenance: true,
            ),
          ),
        ),
      );

      expect(find.text('إرسال الطلبات متوقف مؤقتاً للصيانة'), findsOneWidget);
      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
    });

    testWidgets('MobileUpdateRequiredScreen renders update guidance',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MobileUpdateRequiredScreen(
            minimumBuild: 20,
            currentBuild: 19,
          ),
        ),
      );

      expect(find.text('تحديث مطلوب للمتابعة'), findsOneWidget);
      expect(find.byIcon(Icons.system_update_rounded), findsOneWidget);
    });
  });
}
