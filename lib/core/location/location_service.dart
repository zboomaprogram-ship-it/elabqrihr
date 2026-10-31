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

    // Reuse only a recent, sufficiently accurate system fix.
    Position? cachedPosition;
    try {
      // The platform plugin does not expose a timeLimit for its cached lookup.
      // Bound it so a stalled Android location provider cannot leave the
      // attendance refresh waiting indefinitely before fresh-fix fallbacks run.
      cachedPosition = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 2),
      );
      if (cachedPosition != null &&
          _isFresh(cachedPosition) &&
          cachedPosition.isMocked) {
        throw const MockLocationDetectedException();
      }
      if (cachedPosition != null &&
          _isFresh(cachedPosition) &&
          cachedPosition.accuracy <= 65) {
        return _toGeoPoint(cachedPosition);
      }
    } catch (e) {
      if (e is MockLocationDetectedException) rethrow;
    }

    // Request a current fix before trying lower accuracy.
    Position? position;
    try {
      final freshPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (freshPos.isMocked) throw const MockLocationDetectedException();
      if (_isFresh(freshPos)) position = freshPos;
    } catch (e) {
      if (e is MockLocationDetectedException) rethrow;
    }

    // Medium accuracy may succeed where the high-accuracy request cannot.
    if (position == null) {
      try {
        final mediumPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        if (mediumPos.isMocked) throw const MockLocationDetectedException();
        if (_isFresh(mediumPos)) position = mediumPos;
      } catch (e) {
        if (e is MockLocationDetectedException) rethrow;
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
      timestamp: position.timestamp.toUtc(),
      isMocked: position.isMocked,
    );
  }

  bool _isFresh(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return age >= Duration.zero && age <= const Duration(seconds: 20);
  }
}
