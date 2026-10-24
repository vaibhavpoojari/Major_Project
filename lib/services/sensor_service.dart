import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class SensorVectorReading {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  const SensorVectorReading({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });
}

class SensorService {
  static const double crashThreshold = 35.0; // m/s^2

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  bool _isListening = false;
  final _forceController = StreamController<double>.broadcast();
  final _vectorController = StreamController<SensorVectorReading>.broadcast();

  bool get isListening => _isListening;
  Stream<double> get forceStream => _forceController.stream;
  Stream<SensorVectorReading> get vectorStream => _vectorController.stream;

  // Callback to fire when an accident is detected
  void startListening({
    required Function(double magnitude, String crashType) onCrashDetected,
    Function(double magnitude)? onUpdate,
    Function(double x, double y, double z, double magnitude)? onVectorUpdate,
  }) {
    if (_isListening) return;
    _isListening = true;

    try {
      _subscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          // Calculate 3D vector force magnitude: sqrt(x^2 + y^2 + z^2)
          final double magnitude = sqrt(
            pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2),
          );

          if (onUpdate != null) {
            onUpdate(magnitude);
          }
          if (onVectorUpdate != null) {
            onVectorUpdate(event.x, event.y, event.z, magnitude);
          }

          final reading = SensorVectorReading(
            x: event.x,
            y: event.y,
            z: event.z,
            magnitude: magnitude,
            timestamp: DateTime.now(),
          );

          _forceController.add(magnitude);
          _vectorController.add(reading);

          if (magnitude >= crashThreshold) {
            final String crashType = classifyCrash(event.x, event.y, event.z, magnitude);
            onCrashDetected(magnitude, crashType);
          }
        },
        onError: (error) {
          // Accelerometer stream error handling
        },
        cancelOnError: false,
      );
    } catch (_) {
      // Exception starting sensor listener
    }
  }

  /// Classifies crash force using objective X/Y/Z axis directional terminology.
  /// Smartphone sensors capture device-frame coordinate vectors (ax, ay, az).
  /// Unsupported vehicle-level claims (such as rollover or vehicle side-collision)
  /// are removed in favor of factual primary vector orientation.
  String classifyCrash(double x, double y, double z, double magnitude) {
    double absX = x.abs();
    double absY = y.abs();
    double absZ = z.abs();

    String dominantAxis;
    if (absX >= absY && absX >= absZ) {
      dominantAxis = "Primary X-Axis Vector (${x >= 0 ? '+X Lateral' : '-X Lateral'})";
    } else if (absY >= absX && absY >= absZ) {
      dominantAxis = "Primary Y-Axis Vector (${y >= 0 ? '+Y Longitudinal' : '-Y Longitudinal'})";
    } else {
      dominantAxis = "Primary Z-Axis Vector (${z >= 0 ? '+Z Normal' : '-Z Normal'})";
    }

    String severity = (magnitude >= 50.0) ? "High Severity" : "Moderate Severity";
    return "$severity Vector Impact [$dominantAxis]";
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
  }

  static bool isAccident(double magnitude) => magnitude >= crashThreshold;

  // Simulation method for manual presentation triggers
  void simulateCrash(String crashType, Function(double magnitude, String crashType) onCrashDetected) {
    onCrashDetected(crashThreshold, crashType);
  }

  void dispose() {
    stopListening();
    _forceController.close();
    _vectorController.close();
  }
}
