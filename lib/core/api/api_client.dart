import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final dynamic details;
  final Duration? retryAfter;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.details,
    this.retryAfter,
  });

  @override
  String toString() =>
      'ApiException($statusCode, code: $code, message: $message)';
}

class ApiClient {
  static const qaSandboxBuild = bool.fromEnvironment('ATTEND_QA_SANDBOX');
  final Dio _dio;
  final TokenStorage _tokenStorage;

  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: validateBaseUrl(baseUrl),
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            ) {
    if (qaSandboxBuild) {
      _dio.options.baseUrl = validateBaseUrl(baseUrl);
      _dio.options.followRedirects = false;
    }
    _setupInterceptors();
  }

  static String validateBaseUrl(String url,
      {bool isRelease = kReleaseMode, bool qaSandbox = qaSandboxBuild}) {
    if (qaSandbox) {
      final uri = Uri.tryParse(url);
      if (isRelease ||
          uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          !['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host) ||
          uri.userInfo.isNotEmpty) {
        throw ArgumentError('QA builds require a local sandbox API');
      }
    }
    if (isRelease) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') {
        throw ArgumentError(
          'Production release builds require HTTPS. Insecure URL rejected: $url',
        );
      }
      final host = uri.host.toLowerCase();
      if (host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '10.0.2.2' ||
          host.startsWith('192.168.') ||
          host.startsWith('10.') ||
          host.endsWith('.local')) {
        throw ArgumentError(
          'Production release builds prohibit local or emulator hosts: $host',
        );
      }
    }
    return url;
  }

  static Never _handleDioException(DioException e) {
    if (e.error is ApiException) throw e.error as ApiException;
    if (e.response != null) {
      final data = e.response?.data;
      String message = e.message ?? 'Unknown error';
      String? code;
      dynamic details;
      if (data is Map) {
        message =
            data['title'] as String? ?? data['message'] as String? ?? message;
        code = data['code'] as String?;
        details = data['parameters'] ?? data['details'];
      }
      throw ApiException(
        statusCode: e.response?.statusCode ?? 500,
        message: message,
        code: code,
        details: details,
        retryAfter: _retryAfter(e.response?.headers.value('retry-after')),
      );
    }
    throw e;
  }

  static Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }

  String get baseUrl => _dio.options.baseUrl;

  void updateBaseUrl(String newUrl) {
    if (kReleaseMode) {
      throw UnsupportedError('API base URL cannot be modified in release mode');
    }
    _dio.options.baseUrl = validateBaseUrl(newUrl);
  }

  Dio get dio => _dio;
  void Function()? onSessionExpired;

  /// Called while the authenticated token is still available, before the
  /// server logout endpoint invalidates it. Optional services use this to
  /// revoke device-bound state such as a push destination.
  Future<void> Function(AuthSessionEntity session)? onBeforeLogout;
  Future<void> Function(AuthSessionEntity session)? onSessionInvalidated;
  Future<AuthSessionEntity>? _refreshFuture;

  /// A single-flight refresh. Every request that failed with the same stale
  /// token joins this future; only its owner clears it after completion.
  Future<AuthSessionEntity> _refreshSessionSingleFlight() {
    final existing = _refreshFuture;
    if (existing != null) return existing;
    final created = refreshSession();
    _refreshFuture = created;
    created.then<void>(
      (_) {
        if (identical(_refreshFuture, created)) _refreshFuture = null;
      },
      onError: (_, __) {
        if (identical(_refreshFuture, created)) _refreshFuture = null;
      },
    );
    return created;
  }

  Future<void> _clearInvalidSession(AuthSessionEntity? session) async {
    if (session != null) await onSessionInvalidated?.call(session);
    await _tokenStorage.clearSession();
    onSessionExpired?.call();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (qaSandboxBuild) {
            try {
              validateBaseUrl(options.uri.toString());
              options.followRedirects = false;
            } on ArgumentError catch (error) {
              handler.reject(DioException(
                requestOptions: options,
                error: error,
              ));
              return;
            }
          }
          final path = options.path;
          final isUnauthenticatedAuthRoute = path.contains('/auth/login') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/password/reset');

          if (!isUnauthenticatedAuthRoute) {
            final session = await _tokenStorage.getSession();
            if (session != null && session.accessToken.isNotEmpty) {
              options.headers['Authorization'] =
                  'Bearer ${session.accessToken}';
            }
          }
          options.headers['Content-Type'] = 'application/json';
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final response = error.response;
          if (response != null) {
            final data = response.data;
            String message = error.message ?? 'Unknown error';
            String? code;
            dynamic details;

            if (data is Map) {
              message = data['title'] as String? ??
                  data['message'] as String? ??
                  message;
              code = data['code'] as String?;
              details = data['parameters'] ?? data['details'];
            }

            final statusCode = response.statusCode ?? 500;

            // Handle 401 Unauthorized token refresh
            final path = error.requestOptions.path;
            final isAuthRoute = path.contains('/auth/login') ||
                path.contains('/auth/refresh') ||
                path.contains('/auth/logout');

            final alreadyRetried =
                error.requestOptions.extra['authRetry'] == true;
            if (statusCode == 401 && !isAuthRoute && !alreadyRetried) {
              final session = await _tokenStorage.getSession();
              if (session != null &&
                  session.refreshToken != null &&
                  session.refreshToken!.isNotEmpty) {
                AuthSessionEntity? refreshed;
                try {
                  // A delayed old-token response can arrive after another
                  // request refreshed the session. Retry it with that session
                  // instead of rotating the refresh token again.
                  final failedAuthorization =
                      error.requestOptions.headers['Authorization'];
                  if (failedAuthorization != null &&
                      failedAuthorization != 'Bearer ${session.accessToken}') {
                    // Session was already updated in storage by another request
                    refreshed = session;
                  } else {
                    refreshed = await _refreshSessionSingleFlight();
                  }
                } on ApiException catch (e) {
                  // If the refresh token itself is expired, invalid or revoked (401),
                  // or forbidden, clear the session and redirect to login.
                  if (e.statusCode == 401 || e.statusCode == 403) {
                    await _clearInvalidSession(session);
                  }
                  // For other server errors (500, etc.), do NOT wipe the session
                } on DioException catch (e) {
                  final resp = e.response;
                  if (resp != null &&
                      (resp.statusCode == 401 || resp.statusCode == 403)) {
                    await _clearInvalidSession(session);
                  }
                  // Network errors or timeouts during refresh: do NOT clear session!
                } catch (_) {
                  // Unknown errors: do NOT clear session unless explicitly unauthenticated
                }

                if (refreshed != null) {
                  // Retry the original failed request with the new access token
                  try {
                    final retryOptions = error.requestOptions;
                    retryOptions.headers['Authorization'] =
                        'Bearer ${refreshed.accessToken}';
                    retryOptions.extra['authRetry'] = true;
                    final retryResponse = await _dio.fetch(retryOptions);
                    return handler.resolve(retryResponse);
                  } catch (retryError) {
                    if (retryError is DioException) {
                      return handler.next(retryError);
                    }
                    return handler.reject(
                      DioException(
                        requestOptions: error.requestOptions,
                        error: retryError,
                      ),
                    );
                  }
                }
              } else {
                await _clearInvalidSession(session);
              }
            }

            return handler.next(
              DioException(
                requestOptions: error.requestOptions,
                response: response,
                type: error.type,
                error: ApiException(
                  statusCode: statusCode,
                  message: message,
                  code: code,
                  details: details,
                  retryAfter:
                      _retryAfter(response.headers.value('retry-after')),
                ),
              ),
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Auth Operations matching OpenAPI 3.1 contract
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'tenantSlug': tenantSlug,
          'clientType': 'mobile',
          if (deviceInstallationId != null)
            'deviceInstallationId': deviceInstallationId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final membership = data['membership'] as Map<String, dynamic>;

      final session = AuthSessionEntity(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String?,
        tenantId: membership['tenantId'] as String,
        userId: user['id'] as String,
        role: UserRoleX.fromApi(membership['role'] as String? ?? 'employee'),
        email: user['email'] as String,
        displayName: user['displayName'] as String? ?? user['email'] as String,
      );

      await _tokenStorage.saveSession(session);
      await _tokenStorage.saveLastTenantSlug(tenantSlug);
      return session;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<AuthSessionEntity> refreshSession() async {
    try {
      final currentSession = await _tokenStorage.getSession();
      final refreshToken = currentSession?.refreshToken;

      final response = await _dio.post(
        '/auth/refresh',
        data: {
          if (refreshToken != null) 'refreshToken': refreshToken,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final membership = data['membership'] as Map<String, dynamic>;

      final session = AuthSessionEntity(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String? ?? refreshToken,
        tenantId: membership['tenantId'] as String,
        userId: user['id'] as String,
        role: UserRoleX.fromApi(membership['role'] as String? ?? 'employee'),
        email: user['email'] as String,
        displayName: user['displayName'] as String? ?? user['email'] as String,
      );

      await _tokenStorage.saveSession(session);
      return session;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<void> logout() async {
    final session = await _tokenStorage.getSession();
    try {
      if (session != null) await onBeforeLogout?.call(session);
      await _dio.post('/auth/logout');
    } catch (_) {
      // Ignore network errors or expired token rejection on logout
    } finally {
      await _clearInvalidSession(session);
    }
  }

  Future<void> requestPasswordReset({
    required String email,
    required String tenantSlug,
  }) async {
    try {
      await _dio.post(
        '/auth/password/reset/request',
        data: {
          'email': email,
          'tenantSlug': tenantSlug,
        },
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/auth/password/reset/confirm',
        data: {
          'resetToken': resetToken,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  // Attendance Operations (OpenAPI 0.2.0)
  Future<ShiftContextEntity> getCurrentAttendanceContext() async {
    try {
      final response = await _dio.get('/attendance/current');
      final data = response.data as Map<String, dynamic>;
      final branch = data['branch'] as Map<String, dynamic>;

      final state = data['state'] as String;
      final isCheckedIn = state == 'checked_in';

      final startsAtRaw = data['startsAt'] as String?;
      final endsAtRaw = data['endsAt'] as String?;
      final scheduledStart =
          startsAtRaw != null ? DateTime.tryParse(startsAtRaw) : null;
      final scheduledEnd =
          endsAtRaw != null ? DateTime.tryParse(endsAtRaw) : null;
      if (scheduledStart == null || scheduledEnd == null) {
        throw const ApiException(
          statusCode: 422,
          message: 'Malformed attendance timestamp received from server',
          code: 'MALFORMED_TIMESTAMP',
        );
      }

      return ShiftContextEntity(
        shiftInstanceId: data['shiftInstanceId'] as String,
        branchName: branch['name'] as String,
        branchTimezone: branch['timezone'] as String?,
        shiftName: 'الوردية الرسمية',
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        branchLocation: GeoPoint(
          latitude: _asDouble(branch['latitude'], 0.0),
          longitude: _asDouble(branch['longitude'], 0.0),
        ),
        allowedRadiusMeters: _asDouble(branch['radiusMeters'], 150.0),
        isCheckedIn: isCheckedIn,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<AttendanceEventEntity> submitAttendanceEvent({
    required String eventId,
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    required GeoPoint location,
    required DateTime capturedAt,
    AttendanceEvidenceDto? evidence,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/events',
        data: {
          'eventId': eventId,
          'shiftInstanceId': shiftInstanceId,
          'type': eventType.toApiValue(),
          'occurredAt': capturedAt.toUtc().toIso8601String(),
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'accuracyMeters': location.accuracyMeters ?? 10.0,
            'capturedAt': capturedAt.toUtc().toIso8601String(),
          },
          if (evidence != null) 'evidence': evidence.toJson(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      final resultStr = data['result'] as String? ?? 'accepted';

      return AttendanceEventEntity(
        id: eventId,
        eventType: eventType,
        capturedAt: capturedAt,
        location: location,
        shiftInstanceId: shiftInstanceId,
        status: AttendanceValidationStatusX.fromApiValue(resultStr),
        reasonCode: data['reasonCode'] as String?,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  /// Issues a short-lived registration challenge for the protected Android key.
  Future<IntegrityChallengeDto> createInstallationChallenge({
    required String platform,
    required String appIdentifier,
  }) async {
    try {
      final response = await _dio.post(
        '/device-installations/challenges',
        data: {
          'platform': platform,
          'appIdentifier': appIdentifier,
          // Bind the nonce to installation-key registration rather than an
          // attendance event. This is required by the production contract.
          'purpose': 'installation_registration',
        },
      );
      return IntegrityChallengeDto.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<InstallationRegistrationDto> registerDeviceInstallation(
    InstallationRegistrationRequestDto request,
  ) async {
    try {
      final response =
          await _dio.post('/device-installations', data: request.toJson());
      return InstallationRegistrationDto.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Fetches bounded operational configuration for the authenticated user.
  Future<Map<String, dynamic>> getMobileOperationalConfiguration() async {
    try {
      final response = await _dio.get('/mobile/configuration');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<IntegrityChallengeDto> createAttendanceIntegrityChallenge({
    required String eventId,
    required String installationId,
    required String contentDigest,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/integrity-challenges',
        data: {
          'eventId': eventId,
          'installationId': installationId,
          'contentDigest': contentDigest,
        },
      );
      return IntegrityChallengeDto.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // HR Sovereign Control Operations (Feature 015)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createManualAttendanceAction(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        '/attendance/manual-actions',
        data: payload,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> getDetailedReconciliationItems({
    String? state,
    String? cursor,
    int limit = 25,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (state != null && state.isNotEmpty) query['state'] = state;
      if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
      final response = await _dio.get(
        '/reconciliation/detailed-items',
        queryParameters: query,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> getOpenAdjustmentPayrollCycles() async {
    try {
      final response = await _dio.get(
        '/finance/administrative-adjustments/open-cycles',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> previewAdministrativeAdjustment(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        '/finance/administrative-adjustments/preview',
        data: payload,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> createAdministrativeAdjustment(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        '/finance/administrative-adjustments',
        data: payload,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> getEmployeeDirectory({
    String? search,
    int limit = 100,
    String lifecycleState = 'active',
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': limit,
        'lifecycleState': lifecycleState,
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      final response = await _dio.get(
        '/employees',
        queryParameters: query,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Request Operations (Feature 002: T020-T025, T034-T036)
  // ---------------------------------------------------------------------------

  Future<RequestDto> submitRequest(Map<String, dynamic> requestPayload) async {
    try {
      final response = await _dio.post(
        '/requests',
        data: requestPayload,
      );
      return RequestDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<RequestPageDto> getMyRequests({
    String? cursor,
    int? limit,
    String? type,
    String? state,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;
      if (type != null) queryParams['type'] = type;
      if (state != null) queryParams['state'] = state;

      final response = await _dio.get(
        '/requests',
        queryParameters: queryParams,
      );
      return RequestPageDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<RequestDto> getRequestDetail(String requestId) async {
    try {
      final response = await _dio.get('/requests/$requestId');
      return RequestDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<RequestDto> cancelRequest({
    required String requestId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/requests/$requestId/cancel',
        data: {
          'commandId': commandId,
          'expectedRevision': expectedRevision,
          'reason': reason,
        },
      );
      return RequestDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<List<LeaveBalanceDto>> getMyLeaveBalances() async {
    try {
      final response = await _dio.get('/leave/balance');
      final data = response.data;
      if (data is List) {
        return data
            .map((item) =>
                LeaveBalanceDto.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        return (data['items'] as List)
            .map((item) =>
                LeaveBalanceDto.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<RequestPageDto> getApprovalInbox({
    String? cursor,
    int? limit,
    String? status,
    String? employeeId,
    String? effectiveFrom,
    String? effectiveTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;
      if (status != null) queryParams['state'] = status;
      if (employeeId != null) queryParams['employeeId'] = employeeId;
      if (effectiveFrom != null) queryParams['effectiveFrom'] = effectiveFrom;
      if (effectiveTo != null) queryParams['effectiveTo'] = effectiveTo;

      final response = await _dio.get(
        '/approvals/inbox',
        queryParameters: queryParams,
      );
      return RequestPageDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<RequestDto> decideRequest({
    required String requestId,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(
        '/requests/$requestId/decisions',
        data: {
          'decisionId': decisionId,
          'expectedRevision': expectedRevision,
          'decision': decision,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      return RequestDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Attendance Shift History (OpenAPI 0.4.1: GET /attendance/shifts)
  // ---------------------------------------------------------------------------

  Future<EmployeeShiftPageDto> getMyShiftInstances({
    required String startDate,
    required String endDate,
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'startDate': startDate,
        'endDate': endDate,
      };
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _dio.get(
        '/attendance/shifts',
        queryParameters: queryParams,
      );
      return EmployeeShiftPageDto.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Dynamic Request Operations (Feature 004: US5)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createDynamicRequest(dynamic payload) async {
    try {
      final data = payload is CreateDynamicRequest
          ? payload.toJson()
          : (payload as Map<String, dynamic>);
      final response = await _dio.post(
        '/dynamic-requests',
        data: data,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMyDynamicRequests({
    String? cursor,
    int? limit,
    String? typeKey,
    String? state,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;
      if (typeKey != null) queryParams['typeKey'] = typeKey;
      if (state != null) queryParams['state'] = state;

      final response = await _dio.get(
        '/dynamic-requests',
        queryParameters: queryParams,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDynamicRequest(
      String dynamicRequestId) async {
    try {
      final response = await _dio.get('/dynamic-requests/$dynamicRequestId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelDynamicRequest({
    required String dynamicRequestId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/dynamic-requests/$dynamicRequestId/cancel',
        data: {
          'commandId': commandId,
          'expectedRevision': expectedRevision,
          'reason': reason,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> decideDynamicRequest({
    required String dynamicRequestId,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(
        '/dynamic-requests/$dynamicRequestId/decisions',
        data: {
          'decisionId': decisionId,
          'expectedRevision': expectedRevision,
          'decision': decision,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Profile & Dashboard Operations (OpenAPI 0.6.0 / 0.6.1)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _dio.get('/me');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> patchMe(Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/me', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _dio.get('/me/dashboard');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Request Catalog & Attachments (OpenAPI 0.6.1)
  // ---------------------------------------------------------------------------

  Future<RequestCatalogPage> listRequestCatalog({
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _dio.get(
        '/request-catalog',
        queryParameters: queryParams,
      );
      return RequestCatalogPage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<RequestAttachment> uploadRequestAttachment({
    required List<int> bytes,
    required String filename,
    String? mediaType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });
      final response = await _dio.post(
        '/request-attachments',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return RequestAttachment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<List<int>> downloadRequestAttachment(String attachmentId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/request-attachments/$attachmentId',
        options: Options(responseType: ResponseType.bytes),
      );
      return (response.data as List<dynamic>).cast<int>();
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Unified Activity (OpenAPI 0.6.1)
  // ---------------------------------------------------------------------------

  Future<RequestActivityPage> listMyRequestActivity({
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _dio.get(
        '/request-activity',
        queryParameters: queryParams,
      );
      return RequestActivityPage.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<ApprovalActivityPage> listMyApprovalActivity({
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _dio.get(
        '/approval-activity',
        queryParameters: queryParams,
      );
      return ApprovalActivityPage.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 005 Notifications & Reports (OpenAPI 0.7.0)
  // ---------------------------------------------------------------------------

  Future<NotificationPageDto> listNotifications({
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null && cursor.isNotEmpty) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _dio.get(
        '/notifications',
        queryParameters: queryParams,
      );
      return NotificationPageDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<UnreadNotificationCountDto> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      return UnreadNotificationCountDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<RecipientNotificationDto> getNotification(
    String notificationId,
  ) async {
    try {
      final response = await _dio.get('/notifications/$notificationId');
      return RecipientNotificationDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<RecipientNotificationDto> markNotificationRead(
    String notificationId,
  ) async {
    try {
      final response = await _dio.post(
        '/notifications/$notificationId/read',
      );
      return RecipientNotificationDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<UnreadNotificationCountDto> markAllNotificationsRead({
    required String commandId,
    DateTime? before,
  }) async {
    try {
      final payload = <String, dynamic>{
        'commandId': commandId,
        if (before != null) 'before': before.toUtc().toIso8601String(),
      };
      final response = await _dio.post(
        '/notifications/read-all',
        data: payload,
      );
      return UnreadNotificationCountDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 012: consent-first push registration. No endpoint receives a
  // notification body, provider diagnostic, or decrypted destination.
  // ---------------------------------------------------------------------------

  Future<NotificationDeviceDto> upsertNotificationDevice({
    required String installationId,
    required String token,
    required String locale,
  }) async {
    try {
      final response = await _dio.post(
        '/notification-devices',
        data: {
          'installationId': installationId,
          'platform': 'android',
          'provider': 'fcm',
          'token': token,
          'locale': locale,
        },
      );
      return NotificationDeviceDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<void> revokeNotificationDevice(String installationId) async {
    try {
      await _dio.delete('/notification-devices/$installationId');
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<List<NotificationPreferenceDto>> getNotificationPreferences() async {
    try {
      final response = await _dio.get('/me/notification-preferences');
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NotificationPreferenceDto.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<List<NotificationPreferenceDto>> replaceNotificationPreferences({
    required int expectedRevision,
    required List<NotificationPreferenceInputDto> items,
  }) async {
    try {
      final response = await _dio.put(
        '/me/notification-preferences',
        data: {
          'expectedRevision': expectedRevision,
          'items': items.map((item) => item.toJson()).toList(),
        },
      );
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NotificationPreferenceDto.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<WorkforceReportSummaryDto> getWorkforceSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get(
        '/reports/workforce/summary',
        queryParameters: {
          'from': _formatDate(from),
          'to': _formatDate(to),
        },
      );
      return WorkforceReportSummaryDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<ReportPageDto> getAttendanceLeaveReport({
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String? branchId,
    String? cursor,
    int? limit,
    String? requestType,
    String? requestState,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'startDate': _formatDate(from),
        'endDate': _formatDate(to),
      };
      if (employeeId != null && employeeId.isNotEmpty) {
        queryParams['employeeId'] = employeeId;
      }
      if (branchId != null && branchId.isNotEmpty) {
        queryParams['branchId'] = branchId;
      }
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }
      if (limit != null) {
        queryParams['limit'] = limit;
      }
      if (requestType != null && requestType.isNotEmpty) {
        queryParams['type'] = requestType;
      }
      if (requestState != null && requestState.isNotEmpty) {
        queryParams['state'] = requestState;
      }

      final response = await _dio.get(
        '/reports/attendance-leave',
        queryParameters: queryParams,
      );
      return ReportPageDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<ExportJobDto> createExport({
    required CreateExportRequestDto request,
  }) async {
    try {
      final response = await _dio.post(
        '/exports',
        data: request.toJson(),
      );
      return ExportJobDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<ExportJobDto> getExport(String exportId) async {
    try {
      final response = await _dio.get('/exports/$exportId');
      return ExportJobDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ── Feature 006: Self-service payslips (T032-T033) ──────────────────────

  /// Lists the authenticated employee's private payslips (cursor-paginated).
  /// May only call GET /finance/payslips. Never calculates or caches amounts.
  Future<PayslipPageDto> listMyPayslips({
    String? cursor,
    int limit = 25,
  }) async {
    try {
      final response = await _dio.get(
        '/finance/payslips',
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
        },
      );
      return PayslipPageDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Gets an authorized private payslip by ID.
  /// May only call GET /finance/payslips/{payslipId}.
  Future<PayslipDto> getPayslip(String payslipId) async {
    try {
      final response = await _dio.get('/finance/payslips/$payslipId');
      return PayslipDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ── Feature 006: Self-service advances (T041-T042) ──────────────────────

  /// Lists the authenticated employee's advances (cursor-paginated).
  /// Strictly calls GET /finance/advances. Never submits, approves, disburses,
  /// or calculates balances on the client.
  Future<AdvancePageDto> listMyAdvances({
    String? cursor,
    int limit = 25,
    String? state,
  }) async {
    try {
      final response = await _dio.get(
        '/finance/advances',
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
          if (state != null) 'state': state,
        },
      );
      return AdvancePageDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Previews advance eligibility and provisional installment schedule without side effects.
  Future<AdvanceEligibilityPreviewDto> previewAdvanceEligibility({
    required MoneyDto amount,
    required int installmentCount,
  }) async {
    try {
      final response = await _dio.post(
        '/finance/advances/eligibility-preview',
        data: {
          'amount': amount.toJson(),
          'installmentCount': installmentCount,
        },
      );
      return AdvanceEligibilityPreviewDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Submits an employee advance request.
  Future<AdvanceDto> submitAdvanceRequest(
    CreateAdvanceRequestDto request,
  ) async {
    try {
      final response = await _dio.post(
        '/finance/advances',
        data: request.toJson(),
      );
      return AdvanceDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ── Feature 011: Account Security & Profile (OpenAPI 0.9.0) ───────────────

  /// Changes the authenticated identity's password and revokes all other session families.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/auth/password/change',
        data: ChangePasswordRequestDto(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ).toJson(),
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Lists the current identity's active sessions in this tenant.
  Future<AccountSessionPageDto> listAccountSessions() async {
    try {
      final response = await _dio.get('/auth/sessions');
      return AccountSessionPageDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Revokes one session family owned by the current identity.
  Future<void> revokeAccountSession(String sessionId) async {
    try {
      await _dio.delete('/auth/sessions/$sessionId');
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Updates allowed profile fields and preferences (PATCH /me).
  Future<Map<String, dynamic>> updateMyProfile({
    required int expectedRevision,
    String? phone,
    String? secondaryEmail,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final response = await _dio.patch(
        '/me',
        data: UpdateMyProfileDto(
          expectedRevision: expectedRevision,
          phone: phone,
          secondaryEmail: secondaryEmail,
          preferences: preferences,
        ).toJson(),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ── Feature 011: Dynamic Request Selectors (OpenAPI 0.9.0) ─────────────────

  /// Searches authorized tenant options for one published request field.
  Future<RequestSelectorOptionPageDto> listRequestFieldOptions({
    required String definitionVersionId,
    required String fieldKey,
    String? search,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/request-catalog/$definitionVersionId/fields/$fieldKey/options',
        queryParameters: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          'limit': limit,
        },
      );
      return RequestSelectorOptionPageDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ── Feature 013: Company Quotas & Announcements ─────────────────

  /// Reads current employee quota balances (GET /me/quota-balances).
  Future<List<Map<String, dynamic>>> getMyQuotaBalances() async {
    try {
      final response = await _dio.get('/me/quota-balances');
      final list = response.data as List<dynamic>;
      return list
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Reads a company announcement for the authenticated recipient (GET /company-announcements/:id).
  Future<Map<String, dynamic>> readCompanyAnnouncement(
      String announcementId) async {
    try {
      final response = await _dio.get('/company-announcements/$announcementId');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // ── Feature 016: Dynamic HR Operations ────────────────────────────

  /// Lists HR operations visible to the actor (GET /hr-operations).
  Future<Map<String, dynamic>> listHrOperations({
    String? operationKind,
    String? state,
    String? employeeId,
    String? cursor,
    int limit = 25,
  }) async {
    try {
      final response = await _dio.get(
        '/hr-operations',
        queryParameters: {
          if (operationKind != null) 'operationKind': operationKind,
          if (state != null) 'state': state,
          if (employeeId != null) 'employeeId': employeeId,
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Reads one authorized operation and its safe timeline (GET /hr-operations/:operationId).
  Future<Map<String, dynamic>> getHrOperation(String operationId) async {
    try {
      final response = await _dio.get('/hr-operations/$operationId');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Revokes the unused future scope of an approved mission (POST /hr-operations/field-missions/:operationId/revoke).
  Future<Map<String, dynamic>> revokeFieldMission({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/hr-operations/field-missions/$operationId/revoke',
        data: {
          'commandId': commandId,
          'expectedRevision': expectedRevision,
          'reason': reason,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Records receipt acknowledgment for a disciplinary notice (POST /hr-operations/disciplinary/:operationId/acknowledgments).
  Future<Map<String, dynamic>> acknowledgeDisciplinaryNotice({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required int noticeRevision,
  }) async {
    try {
      final response = await _dio.post(
        '/hr-operations/disciplinary/$operationId/acknowledgments',
        data: {
          'commandId': commandId,
          'expectedRevision': expectedRevision,
          'noticeRevision': noticeRevision,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Submits an employee grievance (POST /hr-operations/disciplinary/:operationId/grievances).
  Future<Map<String, dynamic>> submitDisciplinaryGrievance({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String statement,
    List<String>? attachmentIds,
  }) async {
    try {
      final response = await _dio.post(
        '/hr-operations/disciplinary/$operationId/grievances',
        data: {
          'commandId': commandId,
          'expectedRevision': expectedRevision,
          'statement': statement,
          if (attachmentIds != null) 'attachmentIds': attachmentIds,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Previews a non-posting monetary consequence (POST /hr-operations/disciplinary/:operationId/consequence-preview).
  Future<Map<String, dynamic>> previewDisciplinaryConsequence({
    required String operationId,
    required String method,
    num? value,
  }) async {
    try {
      final response = await _dio.post(
        '/hr-operations/disciplinary/$operationId/consequence-preview',
        data: {
          'method': method,
          if (value != null) 'value': value,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Decides a proposed monetary consequence (POST /hr-operations/disciplinary/:operationId/consequence-decisions).
  Future<Map<String, dynamic>> decideDisciplinaryConsequence({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String decision,
    required String reason,
    String? payrollCycleId,
    required String method,
    num? value,
  }) async {
    try {
      final response = await _dio.post(
        '/hr-operations/disciplinary/$operationId/consequence-decisions',
        data: {
          'commandId': commandId,
          'expectedRevision': expectedRevision,
          'decision': decision,
          'reason': reason,
          if (payrollCycleId != null) 'payrollCycleId': payrollCycleId,
          'method': method,
          if (value != null) 'value': value,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Acts on a clearance item (PATCH /hr-operations/clearance/:caseId/items/:itemId).
  Future<Map<String, dynamic>> decideClearanceItem({
    required String caseId,
    required String itemId,
    required String commandId,
    required int expectedRevision,
    required String action,
    required String reason,
    String? assignedMembershipId,
    String? evidenceAttachmentId,
  }) async {
    try {
      final response = await _dio.patch(
        '/hr-operations/clearance/$caseId/items/$itemId',
        data: {
          'commandId': commandId,
          'expectedRevision': expectedRevision,
          'action': action,
          'reason': reason,
          if (assignedMembershipId != null)
            'assignedMembershipId': assignedMembershipId,
          if (evidenceAttachmentId != null)
            'evidenceAttachmentId': evidenceAttachmentId,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Finalizes clearance prospectively (POST /hr-operations/clearance/:caseId/finalize).
  Future<Map<String, dynamic>> finalizeClearance({
    required String caseId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/hr-operations/clearance/$caseId/finalize',
        data: {
          'commandId': commandId,
          'expectedRevision': expectedRevision,
          'reason': reason,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Fetches bounded attendance reminder feed (GET /attendance/reminder-feed).
  Future<Map<String, dynamic>> getAttendanceReminderFeed({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      // The server deliberately requires a bounded window.  Coordinators call
      // this method without dates during normal app start/resume, so always
      // send an explicit default window rather than issuing an invalid,
      // unbounded request that the API correctly rejects with HTTP 422.
      final now = DateTime.now().toUtc();
      final windowStart =
          (from ?? now.subtract(const Duration(days: 1))).toUtc();
      final windowEnd = (to ?? now.add(const Duration(days: 30))).toUtc();
      final query = <String, dynamic>{
        'from': windowStart.toIso8601String(),
        'until': windowEnd.toIso8601String(),
      };

      final response = await _dio.get(
        '/attendance/reminder-feed',
        queryParameters: query,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }
}

double _asDouble(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
