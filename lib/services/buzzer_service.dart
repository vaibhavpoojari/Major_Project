import 'buzzer_service_stub.dart'
    if (dart.library.js) 'buzzer_service_web.dart'
    if (dart.library.io) 'buzzer_service_mobile.dart';

class BuzzerService {
  static final BuzzerService _instance = BuzzerService._internal();
  factory BuzzerService() => _instance;
  BuzzerService._internal();

  bool _isBuzzerActive = false;

  void startBuzzer() {
    if (_isBuzzerActive) return;
    _isBuzzerActive = true;
    print("BuzzerService: Starting alarm buzzer...");
    startPlatformBuzzer();
  }

  void stopBuzzer() {
    if (!_isBuzzerActive) return;
    _isBuzzerActive = false;
    print("BuzzerService: Stopping alarm buzzer...");
    stopPlatformBuzzer();
  }
}
