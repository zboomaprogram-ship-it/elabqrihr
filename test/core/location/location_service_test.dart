import 'dart:async';

import 'package:attend_mobile/core/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class FakeGeo extends GeolocatorPlatform {
  Position? cached;
  Position? current;
  Completer<Position?>? cachedCompleter;
  int requests = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    final pending = cachedCompleter;
    return pending == null ? Future.value(cached) : pending.future;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    requests++;
    if (current == null) throw TimeoutException('no fix');
    return current!;
  }
}

Position point(DateTime time) => Position(
      latitude: 30,
      longitude: 31,
      timestamp: time,
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform previous;
  late FakeGeo fake;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    fake = FakeGeo();
    GeolocatorPlatform.instance = fake;
  });
  tearDown(() {
    GeolocatorPlatform.instance = previous;
  });

  test('preserves the actual timestamp for a recent cached fix', () async {
    final timestamp =
        DateTime.now().toUtc().subtract(const Duration(seconds: 5));
    fake.cached = point(timestamp);
    final result = await GeolocatorLocationService().getCurrentLocation();
    expect(result.timestamp, timestamp);
    expect(fake.requests, 0);
  });

  test('does not use an old cached fix after fresh requests fail', () async {
    fake.cached =
        point(DateTime.now().toUtc().subtract(const Duration(minutes: 15)));
    await expectLater(GeolocatorLocationService().getCurrentLocation(),
        throwsA(isA<TimeoutException>()));
    expect(fake.requests, 2);
  });

  test('does not wait forever for a stalled last-known location request',
      () async {
    fake.cachedCompleter = Completer<Position?>();
    var completed = false;
    Object? failure;
    final lookup = GeolocatorLocationService().getCurrentLocation().then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error) {
        failure = error;
        completed = true;
      },
    );

    await Future<void>.delayed(const Duration(seconds: 3));

    expect(completed, isTrue,
        reason:
            'A stalled native location call must not leave refresh pending');
    expect(failure, isA<TimeoutException>());
    expect(fake.requests, 2);
    await lookup;
  });
}
