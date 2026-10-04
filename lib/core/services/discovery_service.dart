import 'dart:async';
import 'dart:io';
import '../../models/connection_state.dart';

class DiscoveredObsServer {
  final String ip;
  final int port;
  final String name;
  final StreamingSoftware software;

  const DiscoveredObsServer({
    required this.ip,
    required this.port,
    required this.name,
    this.software = StreamingSoftware.obsStudio,
  });
}

class DiscoveryService {
  /// Scans local network IP addresses and broadcast ports to auto-detect running instances
  /// of OBS Studio, Streamlabs, and vMix.
  static Future<List<DiscoveredObsServer>> scanLocalNetwork({
    StreamingSoftware? software,
    int? customPort,
    String? preferredHost,
    void Function(double progress, String status)? onProgress,
    void Function(DiscoveredObsServer server)? onDiscovered,
    bool Function()? isCancelled,
  }) async {
    final List<DiscoveredObsServer> discovered = [];
    final Set<String> seenServerKeys = {};

    // 1. Determine ports to probe based on target software and custom settings
    final ports = <int>{};
    if (customPort != null && customPort > 0 && customPort <= 65535) {
      ports.add(customPort);
    }
    if (software != null) {
      ports.add(software.defaultPort);
      if (software == StreamingSoftware.obsStudio || software == StreamingSoftware.streamlabs) {
        ports.add(4455);
        ports.add(4444);
      } else if (software == StreamingSoftware.vmix) {
        ports.add(8088);
      }
    } else {
      ports.addAll([4455, 8088, 4444]);
    }
    final portList = ports.toList();

    // 2. Build prioritized candidate IPs
    final candidates = <String>{};

    // User-entered preferred host / IP
    if (preferredHost != null && preferredHost.trim().isNotEmpty) {
      final clean = preferredHost
          .trim()
          .replaceAll(RegExp(r'^(https?|ws|wss)://'), '')
          .split(':')
          .first;
      if (clean.isNotEmpty) {
        candidates.add(clean);
      }
    }

    // Common loopback & emulator aliases
    candidates.addAll(['127.0.0.1', 'localhost', '10.0.2.2']);

    // Detect network interfaces
    final subnets = <String>{};
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
            subnets.add(subnet);
            // Add gateway and own device IP first
            candidates.add('$subnet.1');
            candidates.add(addr.address);

            final myHostPart = int.tryParse(parts[3]) ?? 100;
            // Immediate neighbors around device IP
            for (var i = myHostPart - 5; i <= myHostPart + 5; i++) {
              if (i >= 1 && i <= 254) {
                candidates.add('$subnet.$i');
              }
            }
          }
        }
      }
    } catch (_) {
      // Fallback
    }

    // If no subnet found from interfaces, fallback to standard home/studio private subnets
    if (subnets.isEmpty) {
      subnets.addAll(['192.168.1', '192.168.0', '10.0.0']);
      candidates.add('192.168.1.1');
      candidates.add('192.168.0.1');
    }

    // Expand subnet candidates in ordered priority:
    // Priority 1: .100 - .150 (standard DHCP lease range on most modern routers)
    for (final subnet in subnets) {
      for (var i = 100; i <= 150; i++) {
        candidates.add('$subnet.$i');
      }
    }

    // Priority 2: .2 - .50 (common static IP range)
    for (final subnet in subnets) {
      for (var i = 2; i <= 50; i++) {
        candidates.add('$subnet.$i');
      }
    }

    // Priority 3: .151 - .254
    for (final subnet in subnets) {
      for (var i = 151; i <= 254; i++) {
        candidates.add('$subnet.$i');
      }
    }

    // Priority 4: .51 - .99
    for (final subnet in subnets) {
      for (var i = 51; i <= 99; i++) {
        candidates.add('$subnet.$i');
      }
    }

    final candidateList = candidates.toList();
    final totalChecks = candidateList.length * portList.length;
    var checked = 0;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

    // Run probes concurrently in batches of 25 for fast and responsive scanning
    const batchSize = 25;
    for (var i = 0; i < candidateList.length; i += batchSize) {
      if (isCancelled?.call() == true) {
        return discovered;
      }

      final batch = candidateList.sublist(
        i,
        (i + batchSize < candidateList.length) ? i + batchSize : candidateList.length,
      );

      await Future.wait(batch.map((host) async {
        if (isCancelled?.call() == true) return;

        for (final port in portList) {
          if (isCancelled?.call() == true) return;

          Socket? socket;
          try {
            socket = await Socket.connect(
              host,
              port,
              timeout: const Duration(milliseconds: 250),
            );
            final key = '$host:$port';
            if (!seenServerKeys.contains(key)) {
              seenServerKeys.add(key);
              final resolvedSoftware = _resolveSoftware(port, software);
              final server = DiscoveredObsServer(
                ip: host,
                port: port,
                name: _resolveServerName(host, port, software),
                software: resolvedSoftware,
              );
              discovered.add(server);
              onDiscovered?.call(server);
            }
          } catch (_) {
            // Port unreachable or closed
          } finally {
            try {
              socket?.destroy();
            } catch (_) {}
          }

          checked++;
          final now = DateTime.now();
          if (now.difference(lastProgressAt).inMilliseconds >= 100 || checked == totalChecks) {
            lastProgressAt = now;
            onProgress?.call(
              totalChecks > 0 ? (checked / totalChecks).clamp(0.0, 1.0) : 1.0,
              'Scanning $host:$port...',
            );
          }
        }
      }));
    }

    return discovered;
  }

  static StreamingSoftware _resolveSoftware(int port, StreamingSoftware? currentSoftware) {
    if (port == 8088) return StreamingSoftware.vmix;
    if (port == 4455) {
      if (currentSoftware == StreamingSoftware.streamlabs) {
        return StreamingSoftware.streamlabs;
      }
      return StreamingSoftware.obsStudio;
    }
    if (port == 4444) return StreamingSoftware.obsStudio;
    return currentSoftware ?? StreamingSoftware.obsStudio;
  }

  static String _resolveServerName(String host, int port, StreamingSoftware? currentSoftware) {
    final sw = _resolveSoftware(port, currentSoftware);
    if (port == 4444) {
      return 'OBS Studio v4 ($host:$port)';
    }
    return '${sw.displayName} ($host:$port)';
  }
}
