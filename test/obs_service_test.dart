import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/utils/formatters.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:obscontrol_app/models/macro_action.dart';
import 'package:obscontrol_app/models/obs_scene.dart';

void main() {
  group('Formatters Tests', () {
    test('Format duration seconds to HH:mm:ss', () {
      expect(Formatters.formatDuration(0), '00:00');
      expect(Formatters.formatDuration(75), '01:15');
      expect(Formatters.formatDuration(3661), '01:01:01');
    });

    test('Format FPS', () {
      expect(Formatters.formatFps(60.0), '60.0');
      expect(Formatters.formatFps(59.94), '59.9');
    });

    test('Volume multiplier to dB and back', () {
      final db = Formatters.volumeMultiplierToDb(1.0);
      expect(db.abs() < 0.001, isTrue); // 0 dB
      expect(Formatters.formatDb(0.0), '+0.0 dB');
      expect(Formatters.formatDb(-6.2), '-6.2 dB');
      expect(Formatters.formatDb(-70.0), '-∞ dB');
    });

    test('Format dropped frames', () {
      expect(Formatters.formatDroppedFrames(0, 1000), '0 (0.0%)');
      expect(Formatters.formatDroppedFrames(50, 1000), '50 (5.0%)');
    });

    test('Format relative time', () {
      final now = DateTime.now();
      expect(Formatters.formatRelativeTime(now), 'Just now');
      expect(
        Formatters.formatRelativeTime(now.subtract(const Duration(minutes: 5))),
        '5 mins ago',
      );
      expect(
        Formatters.formatRelativeTime(now.subtract(const Duration(hours: 3))),
        '3 hours ago',
      );
      expect(
        Formatters.formatRelativeTime(now.subtract(const Duration(days: 2))),
        '2 days ago',
      );
    });
  });

  group('Multi-Software & Connection Profile Tests', () {
    test('StreamingSoftware properties and defaults', () {
      expect(StreamingSoftware.obsStudio.displayName, 'OBS Studio');
      expect(StreamingSoftware.obsStudio.defaultPort, 4455);
      expect(StreamingSoftware.streamlabs.displayName, 'Streamlabs');
      expect(StreamingSoftware.streamlabs.defaultPort, 4455);
      expect(StreamingSoftware.vmix.displayName, 'vMix');
      expect(StreamingSoftware.vmix.defaultPort, 8088);
    });

    test('ObsConnectionProfile JSON serialization with software', () {
      final now = DateTime.now();
      final profile = ObsConnectionProfile(
        id: 'test_vmix',
        name: 'vMix Primary',
        host: '192.168.1.120',
        port: 8088,
        password: '',
        software: StreamingSoftware.vmix,
        lastUsed: now,
      );

      final json = profile.toJson();
      final restored = ObsConnectionProfile.fromJson(json);

      expect(restored.id, 'test_vmix');
      expect(restored.name, 'vMix Primary');
      expect(restored.host, '192.168.1.120');
      expect(restored.port, 8088);
      expect(restored.software, StreamingSoftware.vmix);
    });
  });

  group('Macro Action Model Tests', () {
    test('JSON serialization & deserialization', () {
      const original = MacroAction(
        id: 'test_macro',
        title: 'MUTE ALL',
        subtitle: 'Emergency',
        iconName: 'mic_off',
        colorValue: 0xFFFF3B30,
        type: MacroType.toggleMute,
        target: 'Mic/Aux',
      );

      final json = original.toJson();
      final restored = MacroAction.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.subtitle, original.subtitle);
      expect(restored.type, original.type);
      expect(restored.target, original.target);
    });
  });

  group('ObsScene & Multiview Preview Tests', () {
    test('ObsScene copyWith preserves and updates thumbnailBase64', () {
      const scene1 = ObsScene(name: 'Camera 1', sceneIndex: 0);
      expect(scene1.thumbnailBase64, isNull);

      final updated = scene1.copyWith(thumbnailBase64: 'fakeBase64String');
      expect(updated.thumbnailBase64, 'fakeBase64String');
      expect(updated.name, 'Camera 1');

      final cleared = updated.copyWith(thumbnailBase64: null);
      // copyWith defaults to this.thumbnailBase64 if not explicitly replaced
      expect(cleared.thumbnailBase64, 'fakeBase64String');

      final replaced = updated.copyWith(thumbnailBase64: 'newBase64');
      expect(replaced.thumbnailBase64, 'newBase64');
    });
  });
}
