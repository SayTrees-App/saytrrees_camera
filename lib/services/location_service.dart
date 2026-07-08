import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../providers/app_state_provider.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;

  Future<void> startForegroundTracking(AppStateProvider provider) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      provider.setLocationError('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        provider.setLocationError('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      provider.setLocationError(
          'Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    // Location settings for high accuracy
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, 
    );

    // Try fetching immediate position first
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      provider.updateLocation(position.latitude, position.longitude, altitude: position.altitude);
    } catch (e) {
      print('Initial location fetch failed: $e');
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings).listen((Position? position) {
      if (position != null) {
        provider.updateLocation(position.latitude, position.longitude, altitude: position.altitude);
      }
    });
  }

  void stopForegroundTracking() {
    _positionStreamSubscription?.cancel();
  }
}
