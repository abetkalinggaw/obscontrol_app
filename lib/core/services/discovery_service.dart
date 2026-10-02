import 'dart:async';
import 'dart:io';

class DiscoveredObsServer {
  final String ip;
  final int port;
  final String name;

  const DiscoveredObsServer({
    required this.ip,
    required this.port,
    required this.name,
  });
}

class DiscoveryService {
  /// Scans common local IP addresses and ports (4455, 4444) to auto-detect OBS WebSocket servers
  static Future<List<DiscoveredObsServer>> scanLocalNetwork({
    void Function(double progress, String status)? onProgress,
  }) async {
    final List<DiscoveredObsServer> discovered = [];

    // Probe loopback and common local IPs
    final candidates = <String>{
      '127.0.0.1',
      'localhost',
      '10.0.2.2', // Android emulator host alias
    };

    // Try to detect local network interface IPs
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            // Add router / gateway and top probable host IPs
            candidates.add('$subnet.1');
            candidates.add(addr.address);
            // Add a small sample range around current IP
            final myHostPart = int.tryParse(parts[3]) ?? 100;
            for (var i = 1; i <= 25; i++) {
              candidates.add('$subnet.$i');
            }
            for (var i = myHostPart - 5; i <= myHostPart + 5; i++) {
              if (i > 0 && i < 255) {
                candidates.add('$subnet.$i');
              }
            }
          }
        }
      }
    } catch (_) {
      // Fallback
    }

    final portList = [4455, 4444];
    final totalChecks = candidates.length * portList.length;
    var checked = 0;

    // Run probes concurrently in batches of 10
    final candidateList = candidates.toList();
    for (var i = 0; i < candidateList.length; i += 10) {
      final batch = candidateList.sublist(
        i,
        (i + 10 < candidateList.length) ? i + 10 : candidateList.length,
      );

      await Future.wait(batch.map((host) async {
        for (final port in portList) {
          try {
            final socket = await Socket.connect(
              host,
              port,
              timeout: const Duration(milliseconds: 300),
            );
            await socket.close();
            discovered.add(
              DiscoveredObsServer(
                ip: host,
                port: port,
                name: 'OBS Studio ($host:$port)',
              ),
            );
          } catch (_) {
            // Port closed or unreachable
          }
          checked++;
          onProgress?.call(
            checked / totalChecks,
            'Scanning $host:$port...',
          );
        }
      }));
    }

    return discovered;
  }
}
