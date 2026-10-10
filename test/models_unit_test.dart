import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/models/macro_action.dart';
import 'package:obscontrol_app/models/obs_scene.dart';
import 'package:obscontrol_app/models/obs_stats.dart';
import 'package:obscontrol_app/models/obs_audio_source.dart';

void main() {
  group('MacroAction Unit Tests', () {
    test('instantiates with default values and fields', () {
      const action = MacroAction(
        id: 'macro-1',
        title: 'GO LIVE',
        subtitle: 'Start stream',
        iconName: 'play',
        colorValue: 0xFF00FF00,
        type: MacroType.toggleStream,
        target: '',
      );

      expect(action.id, 'macro-1');
      expect(action.title, 'GO LIVE');
      expect(action.subtitle, 'Start stream');
      expect(action.iconName, 'play');
      expect(action.colorValue, 0xFF00FF00);
      expect(action.type, MacroType.toggleStream);
      expect(action.target, '');
    });

    test('copyWith updates specified fields only', () {
      const original = MacroAction(
        id: 'm1',
        title: 'Scene A',
        subtitle: 'Main',
        iconName: 'videocam',
        colorValue: 0xFF123456,
        type: MacroType.switchScene,
        target: 'Scene 1',
      );

      final modified = original.copyWith(
        title: 'Scene B',
        target: 'Scene 2',
        colorValue: 0xFF654321,
      );

      expect(modified.id, 'm1');
      expect(modified.title, 'Scene B');
      expect(modified.subtitle, 'Main');
      expect(modified.iconName, 'videocam');
      expect(modified.colorValue, 0xFF654321);
      expect(modified.type, MacroType.switchScene);
      expect(modified.target, 'Scene 2');
    });

    test('serializes and deserializes all MacroType enum variants', () {
      for (final type in MacroType.values) {
        final action = MacroAction(
          id: 'test_${type.name}',
          title: 'Title_${type.name}',
          subtitle: 'Test',
          iconName: 'icon',
          colorValue: 0xFFFFFFFF,
          type: type,
          target: 'Target_${type.name}',
        );

        final json = action.toJson();
        final restored = MacroAction.fromJson(json);

        expect(restored.id, action.id);
        expect(restored.title, action.title);
        expect(restored.type, type);
        expect(restored.target, action.target);
      }
    });

    test(
      'fromJson falls back gracefully when fields are missing or unknown',
      () {
        final json = <String, dynamic>{
          'id': 'fallback-id',
          'title': 'Fallback',
        };

        final restored = MacroAction.fromJson(json);
        expect(restored.id, 'fallback-id');
        expect(restored.title, 'Fallback');
        expect(restored.subtitle, '');
        expect(restored.iconName, 'bolt');
        expect(restored.colorValue, 0xFF1E1E1E);
        expect(restored.type, MacroType.switchScene);
        expect(restored.target, '');
      },
    );
  });

  group('ObsStats Unit Tests', () {
    test('default constructor sets sensible defaults', () {
      const stats = ObsStats();
      expect(stats.activeFps, 60.0);
      expect(stats.cpuUsage, 4.2);
      expect(stats.memoryUsage, 180.5);
      expect(stats.averageFrameTimeMs, 16.6);
      expect(stats.renderSkippedFrames, 0);
      expect(stats.renderTotalFrames, 0);
      expect(stats.outputSkippedFrames, 0);
      expect(stats.outputTotalFrames, 0);
      expect(stats.isStreaming, isFalse);
      expect(stats.isRecording, isFalse);
      expect(stats.isReplayBufferActive, isFalse);
      expect(stats.streamTimecodeSeconds, 0);
      expect(stats.recordTimecodeSeconds, 0);
      expect(stats.currentProgramScene, '');
      expect(stats.currentPreviewScene, '');
      expect(stats.studioModeEnabled, isFalse);
    });

    test('copyWith updates stats correctly', () {
      const stats = ObsStats();
      final updated = stats.copyWith(
        activeFps: 30.0,
        cpuUsage: 15.4,
        isStreaming: true,
        isRecording: true,
        streamTimecodeSeconds: 120,
        currentProgramScene: 'Live Cam',
        studioModeEnabled: true,
      );

      expect(updated.activeFps, 30.0);
      expect(updated.cpuUsage, 15.4);
      expect(updated.isStreaming, isTrue);
      expect(updated.isRecording, isTrue);
      expect(updated.streamTimecodeSeconds, 120);
      expect(updated.currentProgramScene, 'Live Cam');
      expect(updated.studioModeEnabled, isTrue);
      expect(updated.isReplayBufferActive, isFalse); // unchanged
    });
  });

  group('ObsAudioSource Unit Tests', () {
    test('default values and properties check', () {
      const source = ObsAudioSource(name: 'Desktop Audio');
      expect(source.name, 'Desktop Audio');
      expect(source.inputKind, 'wasapi_input_capture');
      expect(source.volumeMul, 1.0);
      expect(source.volumeDb, 0.0);
      expect(source.muted, isFalse);
      expect(source.leftLevel, 0.0);
      expect(source.rightLevel, 0.0);
      expect(source.peakHold, 0.0);
    });

    test('copyWith updates levels, mute and peakHold', () {
      const source = ObsAudioSource(name: 'Mic');
      final updated = source.copyWith(
        volumeMul: 0.5,
        volumeDb: -6.0,
        muted: true,
        leftLevel: 0.75,
        rightLevel: 0.80,
        peakHold: 0.85,
      );

      expect(updated.name, 'Mic');
      expect(updated.volumeMul, 0.5);
      expect(updated.volumeDb, -6.0);
      expect(updated.muted, isTrue);
      expect(updated.leftLevel, 0.75);
      expect(updated.rightLevel, 0.80);
      expect(updated.peakHold, 0.85);
    });
  });

  group('ObsScene and ObsSceneItem Unit Tests', () {
    test('ObsSceneItem properties and defaults', () {
      const item = ObsSceneItem(
        sceneItemId: 101,
        sourceName: 'Webcam C920',
        sourceType: 'dshow_input',
        sceneItemEnabled: true,
      );

      expect(item.sceneItemId, 101);
      expect(item.sourceName, 'Webcam C920');
      expect(item.sourceType, 'dshow_input');
      expect(item.sceneItemEnabled, isTrue);
    });

    test('ObsSceneItem copyWith and fromJson', () {
      const item = ObsSceneItem(
        sceneItemId: 1,
        sourceName: 'Camera',
        sourceType: 'video',
        sceneItemEnabled: true,
      );
      final copied = item.copyWith(sceneItemEnabled: false);
      expect(copied.sceneItemEnabled, isFalse);
      expect(copied.sourceName, 'Camera');

      final fromJsonItem = ObsSceneItem.fromJson(const {
        'sceneItemId': 99,
        'sourceName': 'Display Capture',
        'sourceType': 'monitor_capture',
        'sceneItemEnabled': true,
      });
      expect(fromJsonItem.sceneItemId, 99);
      expect(fromJsonItem.sourceName, 'Display Capture');
    });

    test('ObsScene equality and item list handling', () {
      const scene1 = ObsScene(
        name: 'Scene 1',
        sceneIndex: 0,
        isProgram: true,
        isPreview: false,
        items: [
          ObsSceneItem(
            sceneItemId: 1,
            sourceName: 'Camera',
            sourceType: 'video',
            sceneItemEnabled: true,
          ),
        ],
      );

      expect(scene1.name, 'Scene 1');
      expect(scene1.sceneIndex, 0);
      expect(scene1.isProgram, isTrue);
      expect(scene1.isPreview, isFalse);
      expect(scene1.items.length, 1);
      expect(scene1.items.first.sourceName, 'Camera');
    });
  });
}
