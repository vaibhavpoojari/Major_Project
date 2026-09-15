import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

void startPlatformBuzzer() {
  try {
    FlutterRingtonePlayer().playAlarm(
      looping: true,
      volume: 1.0,
      asAlarm: true,
    );
  } catch (e) {
    print("BuzzerServiceMobile: Failed to play mobile ringtone: $e");
  }
}

void stopPlatformBuzzer() {
  try {
    FlutterRingtonePlayer().stop();
  } catch (e) {
    print("BuzzerServiceMobile: Failed to stop mobile ringtone: $e");
  }
}
