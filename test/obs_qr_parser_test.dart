import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/utils/obs_qr_parser.dart';

void main() {
  group('ObsQrParser Tests', () {
    test('Parses official OBS Studio v5 WebSocket JSON QR code', () {
      const qrData = '''
      {
        "server": "192.168.1.120",
        "port": 4455,
        "auth": "obs_super_secret_pw",
        "ipList": ["192.168.1.120", "127.0.0.1"]
      }
      ''';

      final result = ObsQrParser.parse(qrData);
      expect(result, isNotNull);
      expect(result!.host, '192.168.1.120');
      expect(result.port, 4455);
      expect(result.password, 'obs_super_secret_pw');
      expect(result.alternativeIps, ['192.168.1.120', '127.0.0.1']);
    });

    test('Parses JSON with alternative field names (address, pw, name)', () {
      const qrData = '{"address":"studio.local","port":"4444","pw":"myPass","name":"Main Rig"}';
      final result = ObsQrParser.parse(qrData);
      expect(result, isNotNull);
      expect(result!.host, 'studio.local');
      expect(result.port, 4444);
      expect(result.password, 'myPass');
      expect(result.name, 'Main Rig');
    });

    test('Parses obsws:// URI schema with password in query', () {
      const qrData = 'obsws://192.168.1.50:4455?auth=stagePass&name=Stage%20OBS';
      final result = ObsQrParser.parse(qrData);
      expect(result, isNotNull);
      expect(result!.host, '192.168.1.50');
      expect(result.port, 4455);
      expect(result.password, 'stagePass');
      expect(result.name, 'Stage OBS');
    });

    test('Parses ws:// URI schema with password in userInfo', () {
      const qrData = 'ws://admin:secret123@10.0.0.15:4455';
      final result = ObsQrParser.parse(qrData);
      expect(result, isNotNull);
      expect(result!.host, '10.0.0.15');
      expect(result.port, 4455);
      expect(result.password, 'secret123');
    });

    test('Parses plain host:port:password string', () {
      const qrData = '192.168.1.99:4455:strongPassword';
      final result = ObsQrParser.parse(qrData);
      expect(result, isNotNull);
      expect(result!.host, '192.168.1.99');
      expect(result.port, 4455);
      expect(result.password, 'strongPassword');
    });

    test('Parses plain host:port without password', () {
      const qrData = '192.168.1.100:4455';
      final result = ObsQrParser.parse(qrData);
      expect(result, isNotNull);
      expect(result!.host, '192.168.1.100');
      expect(result.port, 4455);
      expect(result.password, '');
    });

    test('Returns null for invalid or empty strings', () {
      expect(ObsQrParser.parse(''), isNull);
      expect(ObsQrParser.parse(null), isNull);
      expect(ObsQrParser.parse('just a random sentence with no host or port'), isNull);
      expect(ObsQrParser.parse('http://'), isNull);
    });
  });
}
