import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/services/vmix_http_service.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:obscontrol_app/models/obs_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VmixHttpService Unit Tests', () {
    test('initial status is disconnected with default stats', () {
      final service = VmixHttpService();
      expect(service.status, ObsConnectionStatus.disconnected);
      expect(service.userExplicitlyDisconnected, isFalse);
    });

    test('disconnect updates status and stops timers', () {
      final service = VmixHttpService();
      var notifiedStatus = ObsConnectionStatus.connected;
      service.onStatusChanged = (status, error) {
        notifiedStatus = status;
      };

      service.disconnect(notify: true);
      expect(service.status, ObsConnectionStatus.disconnected);
      expect(service.userExplicitlyDisconnected, isTrue);
      expect(notifiedStatus, ObsConnectionStatus.disconnected);
    });

    test('XML parsing extracts streaming, recording, inputs and audio levels correctly', () {
      const sampleVmixXml = '''
<vmix>
  <version>26.0.0.45</version>
  <edition>HD</edition>
  <preset>Default.vmix</preset>
  <inputs>
    <input key="abc1" number="1" type="Camera" title="Cam 1 Main" state="Running" position="0" duration="0" loop="False" muted="False" volume="100" meterF1="0.65" meterF2="0.68">Cam 1 Main</input>
    <input key="abc2" number="2" type="Video" title="Video Clip" state="Paused" position="5000" duration="15000" loop="False" muted="True" volume="80" meterF1="0.0" meterF2="0.0">Video Clip</input>
    <input key="abc3" number="3" type="Audio" title="Mic Aux" state="Running" position="0" duration="0" loop="False" muted="False" volume="90" meterF1="0.45" meterF2="0.42">Mic Aux</input>
  </inputs>
  <active>1</active>
  <preview>2</preview>
  <recording>True</recording>
  <streaming>True</streaming>
</vmix>
''';

      final service = VmixHttpService();
      ObsStats? receivedStats;
      int scenesCount = 0;
      int audioSourcesCount = 0;
      String? activePgm;
      String? activePrv;

      service.onStatsUpdated = (stats) {
        receivedStats = stats;
      };
      service.onScenesUpdated = (scenes, pgm, prv) {
        scenesCount = scenes.length;
        activePgm = pgm;
        activePrv = prv;
      };
      service.onAudioSourcesUpdated = (audios) {
        audioSourcesCount = audios.length;
      };

      // Directly trigger testable XML parsing
      service.parseVmixXmlForTesting(sampleVmixXml);

      // Verify parsed broadcast status
      expect(receivedStats, isNotNull);
      expect(receivedStats!.isStreaming, isTrue);
      expect(receivedStats!.isRecording, isTrue);
      expect(activePgm, 'Cam 1 Main');
      expect(activePrv, 'Video Clip');
      expect(scenesCount, 3);
      expect(audioSourcesCount, 3);
    });

    test('reports error status when cannot reach vMix host', () async {
      final service = VmixHttpService();
      service.autoReconnect = false;

      // Connect to unused port
      await service.connect(
        host: '127.0.0.1',
        port: 59998,
      );

      expect(service.status, ObsConnectionStatus.error);
      service.disconnect(notify: false);
    });
  });
}
