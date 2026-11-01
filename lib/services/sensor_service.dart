import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  static const double crashThreshold = 35.0; // m/s^2

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  bool _isListening = false;
  final _forceController = StreamController<double>.broadcast();

  bool get isListening => _isListening;
  Stream<double> get forceStream => _forceController.stream;

  // Callback to fire when an accident is detected
  void startListening({
    required Function(double magnitude, String crashType) onCrashDetected,
    Function(double magnitude)? onUpdate,
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
          _forceController.add(magnitude);

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

  String classifyCrash(double x, double y, double z, double magnitude) {
    double absX = x.abs();
    double absY = y.abs();
    double absZ = z.abs();

    String direction = "";
    if (absX > absY && absX > absZ) {
      direction = "Side Impact (Lateral)";
    } else if (absY > absX && absY > absZ) {
      direction = "Frontal/Rear Collision";
    } else {
      direction = "Rollover / Vertical Force";
    }

    String severity = (magnitude > 50.0) ? "High Severity" : "Moderate Severity";
    return "$severity $direction";
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
  }
}
