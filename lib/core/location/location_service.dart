import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

abstract class LocationService {
  Future<GeoPoint> getCurrentLocation();
}

class MockLocationDetectedException implements Exception {
  const MockLocationDetectedException();

  @override
  String toString() => 'MockLocationDetected';
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<GeoPoint> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException(
          'Location permissions are denied',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException(
        'Location permissions are permanently denied',
      );
    }

    if (!kIsWeb) {
      try {
        final accuracyStatus = await Geolocator.getLocationAccuracy();
        if (accuracyStatus == LocationAccuracyStatus.reduced) {
          throw const PermissionDeniedException(
            'الموقع التقريبي مفعّل. افتح إعدادات التطبيق وفعّل الموقع الدقيق (Precise location) حتى يمكن التحقق من نطاق الفرع.',
          );
        }
      } catch (error) {
        if (error is PermissionDeniedException) rethrow;
      }
    }

    // 1. Inspect cached position from OS
    Position? cachedPosition;
    try {
      cachedPosition = await Geolocator.getLastKnownPosition();
      if (cachedPosition != null && cachedPosition.isMocked) {
        throw const MockLocationDetectedException();
      }
    } catch (e) {
      if (e is MockLocationDetectedException) rethrow;
    }

    // 2. Multi-tier acquisition with graceful fallbacks
    Position? position;

    // Tier A: Fast high-accuracy fix (bounded to 8 seconds to prevent long UI lock)
    try {
      final highAccPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (highAccPos.isMocked) throw const MockLocationDetectedException();
      if (_isFresh(highAccPos)) {
        position = highAccPos;
      }
    } catch (e) {
      if (e is MockLocationDetectedException) rethrow;
    }

    // Tier B: Native Android LocationManager fallback
    // Critical on Android vendors (e.g. Vivo/Xiaomi/Samsung) where Google Fused Provider stalls indoors
    if (position == null && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final nativePos = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.best,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 8),
          ),
        );
        if (nativePos.isMocked) throw const MockLocationDetectedException();
        if (_isFresh(nativePos, maxAgeMinutes: 2)) {
          position = nativePos;
        }
      } catch (e) {
        if (e is MockLocationDetectedException) rethrow;
      }
    }

    // Tier C: Safe cached position fallback if recent (< 3 min, accuracy <= 50m)
    if (position == null && cachedPosition != null) {
      if (_isFresh(cachedPosition, maxAgeMinutes: 3) && cachedPosition.accuracy <= 50) {
        position = cachedPosition;
      }
    }

    // Tier D: Medium accuracy fallback (WiFi/Cell network assisted)
    if (position == null) {
      try {
        final mediumPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
        if (mediumPos.isMocked) throw const MockLocationDetectedException();
        if (_isFresh(mediumPos, maxAgeMinutes: 2)) {
          position = mediumPos;
        }
      } catch (e) {
        if (e is MockLocationDetectedException) rethrow;
      }
    }

    // Tier E: Last resort cached position if captured within 10 minutes
    if (position == null && cachedPosition != null) {
      if (_isFresh(cachedPosition, maxAgeMinutes: 10)) {
        position = cachedPosition;
      }
    }

    if (position == null) {
      throw TimeoutException(
        'استغرق تحديد موقعك وقتاً أطول من المتوقع. تأكد من تشغيل GPS وصلاحيات الموقع ثم أعد المحاولة.',
      );
    }

    return GeoPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: DateTime.now().toUtc(),
      isMocked: position.isMocked,
    );
  }

  bool _isFresh(Position position, {int maxAgeMinutes = 1}) {
    final age = DateTime.now().difference(position.timestamp).abs();
    return age <= Duration(minutes: maxAgeMinutes);
  }
}
