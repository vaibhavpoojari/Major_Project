import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionStatusResult {
  final bool isLocationGranted;
  final bool isLocationDeniedForever;
  final bool isNotificationGranted;
  final bool isSmsGranted;

  PermissionStatusResult({
    required this.isLocationGranted,
    required this.isLocationDeniedForever,
    required this.isNotificationGranted,
    required this.isSmsGranted,
  });
}

class PermissionService {
  static const MethodChannel _permissionsChannel = MethodChannel(
    'com.example.accident_guard_system/permissions',
  );
  static const MethodChannel _smsChannel = MethodChannel(
    'com.example.accident_guard_system/sms',
  );

  /// Requests all necessary runtime permissions on first app launch
  static Future<PermissionStatusResult> requestInitialPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final bool alreadyPrompted = prefs.getBool('has_requested_initial_permissions') ?? false;

    // 1. Location Permission
    LocationPermission locationPermission = await Geolocator.checkPermission();
    if (!alreadyPrompted && locationPermission == LocationPermission.denied) {
      try {
        locationPermission = await Geolocator.requestPermission();
      } catch (e) {
        print("PermissionService: Location request error: $e");
      }
    }

    final bool isLocationGranted = (locationPermission == LocationPermission.always ||
        locationPermission == LocationPermission.whileInUse);
    final bool isLocationDeniedForever = (locationPermission == LocationPermission.deniedForever);

    // 2. Notification Permission (Android 13+ POST_NOTIFICATIONS)
    bool isNotificationGranted = true;
    try {
      if (!alreadyPrompted) {
        isNotificationGranted = await _permissionsChannel.invokeMethod<bool>('requestNotificationPermission') ?? true;
      } else {
        isNotificationGranted = await _permissionsChannel.invokeMethod<bool>('checkNotificationPermission') ?? true;
      }
    } catch (e) {
      print("PermissionService: Notification permission check error: $e");
    }

    // 3. SMS Permission
    bool isSmsGranted = false;
    try {
      if (!alreadyPrompted) {
        isSmsGranted = await _smsChannel.invokeMethod<bool>('requestSmsPermission') ?? false;
      }
    } catch (e) {
      print("PermissionService: SMS permission check error: $e");
    }

    await prefs.setBool('has_requested_initial_permissions', true);

    return PermissionStatusResult(
      isLocationGranted: isLocationGranted,
      isLocationDeniedForever: isLocationDeniedForever,
      isNotificationGranted: isNotificationGranted,
      isSmsGranted: isSmsGranted,
    );
  }

  /// Check current Location permission without repeatedly triggering popups
  static Future<LocationPermission> checkLocationPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      print("PermissionService: Error checking location permission: $e");
      return LocationPermission.denied;
    }
  }

  /// Handles Location permission flow with user guidance
  static Future<bool> ensureLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      return true;
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showPermissionDeniedForeverDialog(context);
      }
      return false;
    }

    if (permission == LocationPermission.denied) {
      try {
        permission = await Geolocator.requestPermission();
      } catch (e) {
        print("PermissionService: Error requesting location permission: $e");
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        return true;
      } else if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          _showPermissionDeniedForeverDialog(context);
        }
        return false;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ GPS location access is required for nearest-hospital detection."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }
    }

    return false;
  }

  /// Opens Android App Settings
  static Future<void> openAppSettings() async {
    try {
      final bool opened = await Geolocator.openAppSettings();
      if (!opened) {
        await _permissionsChannel.invokeMethod('openAppSettings');
      }
    } catch (_) {
      try {
        await _permissionsChannel.invokeMethod('openAppSettings');
      } catch (e) {
        print("PermissionService: Could not open settings: $e");
      }
    }
  }

  static void _showPermissionDeniedForeverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text("Location Access Required"),
          ],
        ),
        content: const Text(
          "GPS Location permission is permanently denied.\n\n"
          "Accident Guard needs location access to pinpoint accidents and automatically find real nearest hospitals.\n\n"
          "Please open App Settings and allow Location permission.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Not Now"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text("Open App Settings"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
