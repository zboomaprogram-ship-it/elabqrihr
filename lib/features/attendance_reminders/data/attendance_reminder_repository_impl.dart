import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import '../domain/reminder_models.dart';
import '../domain/reminder_repository.dart';

class AttendanceReminderRepositoryImpl implements ReminderRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;

  static const String _storageKey = 'attendance_reminder_preferences_v1';

  AttendanceReminderRepositoryImpl({
    required ApiClient apiClient,
    required FlutterSecureStorage secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  @override
  Future<ReminderFeed> getReminderFeed({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _apiClient.getAttendanceReminderFeed(
      from: from,
      to: to,
    );
    return ReminderFeed.fromJson(response);
  }

  @override
  Future<ReminderPreferences> getPreferences() async {
    final raw = await _secureStorage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return const ReminderPreferences();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ReminderPreferences.fromJson(json);
    } catch (_) {
      return const ReminderPreferences();
    }
  }

  @override
  Future<void> savePreferences(ReminderPreferences preferences) async {
    final raw = jsonEncode(preferences.toJson());
    await _secureStorage.write(key: _storageKey, value: raw);
  }

  @override
  Future<void> clearPreferences() async {
    await _secureStorage.delete(key: _storageKey);
  }
}
