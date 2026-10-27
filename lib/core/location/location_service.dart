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

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
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

    // 1. Check cached position from OS first (instant, zero binder lock)
    Position? cachedPosition;
    try {
      cachedPosition = await Geolocator.getLastKnownPosition();
      if (cachedPosition != null && cachedPosition.isMocked) {
        throw const MockLocationDetectedException();
      }
      // If we have a fresh cached position (within 3 minutes and <= 65m accuracy), use it immediately!
      if (cachedPosition != null &&
          _isFresh(cachedPosition, maxAgeMinutes: 3) &&
          cachedPosition.accuracy <= 65) {
        return _toGeoPoint(cachedPosition);
      }
    } catch (e) {
      if (e is MockLocationDetectedException) rethrow;
    }

    // 2. Request a fresh position fix with a tight 5-second timeout via FusedLocationProvider
    Position? position;
    try {
      final freshPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (freshPos.isMocked) throw const MockLocationDetectedException();
      position = freshPos;
    } catch (e) {
      if (e is MockLocationDetectedException) rethrow;
    }

    // 3. Fallback: If fresh position timed out or failed (indoors/no satellites),
    // safely reuse the cached position if available within 15 minutes
    if (position == null && cachedPosition != null) {
      if (_isFresh(cachedPosition, maxAgeMinutes: 15)) {
        position = cachedPosition;
      }
    }

    // 4. Fallback 2: Fast medium accuracy (Cell/WiFi) with 4-second timeout
    if (position == null) {
      try {
        final mediumPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        if (mediumPos.isMocked) throw const MockLocationDetectedException();
        position = mediumPos;
      } catch (e) {
        if (e is MockLocationDetectedException) rethrow;
      }
    }

    // 5. Fallback 3: Any last known position up to 30 minutes
    if (position == null && cachedPosition != null) {
      if (_isFresh(cachedPosition, maxAgeMinutes: 30)) {
        position = cachedPosition;
      }
    }

    if (position == null) {
      throw TimeoutException(
        'استغرق تحديد موقعك وقتاً أطول من المتوقع. تأكد من تشغيل GPS وصلاحيات الموقع ثم أعد المحاولة.',
      );
    }

    return _toGeoPoint(position);
  }

  GeoPoint _toGeoPoint(Position position) {
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
