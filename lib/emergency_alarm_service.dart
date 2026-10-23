import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Owns the single in-app emergency audio player.
///
/// Looping is allowed only while an emergency ringing UI is visibly active.
/// Background attention is provided by Android notifications and backend
/// reminders, never by a long-running Dart player.
class EmergencyAlarmService {
  EmergencyAlarmService._();

  static final AudioPlayer _player = AudioPlayer();
  static final ValueNotifier<String?> currentEmergencyId =
      ValueNotifier<String?>(null);
  static bool _starting = false;

  static bool get isPlaying => currentEmergencyId.value != null;

  static Future<void> startAlarm(String emergencyId) async {
    if (emergencyId.isEmpty || currentEmergencyId.value == emergencyId) return;
    if (_starting) return;
    _starting = true;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        AssetSource('audio/esugid_emergency_alert.mp3'),
        volume: 1,
        mode: PlayerMode.mediaPlayer,
      );
      currentEmergencyId.value = emergencyId;
      debugPrint('[EMERGENCY] Visible alarm started id=$emergencyId');
    } catch (error) {
      currentEmergencyId.value = null;
      debugPrint('[EMERGENCY] Visible alarm could not start: $error');
    } finally {
      _starting = false;
    }
  }

  static Future<void> stopAlarm({String? emergencyId}) async {
    if (emergencyId != null &&
        currentEmergencyId.value != null &&
        currentEmergencyId.value != emergencyId) {
      return;
    }
    if (currentEmergencyId.value != null) {
      currentEmergencyId.value = null;
      try {
        await _player.stop();
      } catch (_) {}
    }
    debugPrint('[EMERGENCY] Visible alarm stopped id=${emergencyId ?? 'any'}');
  }
}
