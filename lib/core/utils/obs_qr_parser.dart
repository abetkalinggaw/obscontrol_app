import 'dart:convert';

/// Structured connection data extracted from a scanned QR or barcode.
class ObsConnectionData {
  final String host;
  final int port;
  final String password;
  final String? name;
  final List<String> alternativeIps;
  final String rawSource;

  const ObsConnectionData({
    required this.host,
    this.port = 4455,
    this.password = '',
    this.name,
    this.alternativeIps = const [],
    this.rawSource = '',
  });

  @override
  String toString() => 'ObsConnectionData(host: $host, port: $port, password: ${password.isEmpty ? "none" : "***"}, name: $name)';
}

/// Robust parser for OBS Studio WebSocket barcodes and QR codes.
///
/// Supports:
/// 1. OBS Studio v5 official WebSocket QR format:
///    `{"server": "...", "port": 4455, "auth": "...", "ipList": [...]}`
/// 2. General JSON schemas with `host`, `address`, `ip`, `port`, `password`, `pw`, `auth`, `secret`, `name`
/// 3. URI schemes:
///    `obsws://[password@]host:port[/password]`, `obs://...`, `ws://...`, `wss://...`
/// 4. Delimited text:
///    `host:port[:password]` or `host:port` or plain IP `192.168.1.100`
class ObsQrParser {
  /// Parse raw barcode / QR string into [ObsConnectionData].
  /// Returns `null` if the content cannot be identified as an OBS connection target.
  static ObsConnectionData? parse(String? raw) {
    if (raw == null) return null;
    final content = raw.trim();
    if (content.isEmpty) return null;

    // 1. Try parsing JSON (official OBS Studio format & common variants)
    if (content.startsWith('{') && content.endsWith('}')) {
      final fromJson = _tryParseJson(content);
      if (fromJson != null) return fromJson;
    }

    // 2. Try parsing URI formats (obsws://, obs://, ws://, wss://, http://, etc.)
    if (content.contains('://')) {
      final fromUri = _tryParseUri(content);
      if (fromUri != null) return fromUri;
    }

    // 3. Try parsing delimiter-based text (e.g. host:port[:password])
    final fromDelimited = _tryParseDelimited(content);
    if (fromDelimited != null) return fromDelimited;

    return null;
  }

  static ObsConnectionData? _tryParseJson(String content) {
    try {
      final dynamic decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return null;

      // Extract host / server IP
      String? host = decoded['server']?.toString() ??
          decoded['host']?.toString() ??
          decoded['address']?.toString() ??
          decoded['ip']?.toString();

      // Extract alternative IPs if present
      final List<String> altIps = [];
      if (decoded['ipList'] is List) {
        for (final item in decoded['ipList']) {
          if (item != null && item.toString().isNotEmpty) {
            altIps.add(item.toString());
          }
        }
      }

      // If host is null but ipList is not empty, use first IP
      if ((host == null || host.isEmpty) && altIps.isNotEmpty) {
        host = altIps.first;
      }

      if (host == null || host.trim().isEmpty) return null;

      // Extract port
      int port = 4455;
      final rawPort = decoded['port'];
      if (rawPort is int) {
        port = rawPort;
      } else if (rawPort != null) {
        port = int.tryParse(rawPort.toString()) ?? 4455;
      }

      // Extract password / auth / secret
      final password = decoded['auth']?.toString() ??
          decoded['password']?.toString() ??
          decoded['pw']?.toString() ??
          decoded['secret']?.toString() ??
          '';

      // Extract name
      final name = decoded['name']?.toString() ??
          decoded['serverName']?.toString() ??
          'OBS Studio ($host)';

      return ObsConnectionData(
        host: host.trim(),
        port: port,
        password: password,
        name: name.trim(),
        alternativeIps: altIps,
        rawSource: content,
      );
    } catch (_) {
      return null;
    }
  }

  static ObsConnectionData? _tryParseUri(String content) {
    try {
      final uri = Uri.parse(content);
      if (uri.host.isEmpty) return null;

      final host = uri.host;
      final port = uri.port > 0 ? uri.port : 4455;

      // Password can be in userInfo (user:pass or just pass), query param, or path
      String password = '';
      if (uri.userInfo.isNotEmpty) {
        final parts = uri.userInfo.split(':');
        password = parts.length > 1 ? parts[1] : parts[0];
      } else if (uri.queryParameters.containsKey('auth')) {
        password = uri.queryParameters['auth'] ?? '';
      } else if (uri.queryParameters.containsKey('password')) {
        password = uri.queryParameters['password'] ?? '';
      } else if (uri.queryParameters.containsKey('pw')) {
        password = uri.queryParameters['pw'] ?? '';
      } else if (uri.path.isNotEmpty && uri.path != '/') {
        // e.g. obsws://host:4455/myPassword
        password = uri.path.replaceFirst('/', '');
      }

      final name = uri.queryParameters['name'] ?? 'OBS Studio ($host)';

      return ObsConnectionData(
        host: host,
        port: port,
        password: password,
        name: name,
        rawSource: content,
      );
    } catch (_) {
      return null;
    }
  }

  static ObsConnectionData? _tryParseDelimited(String content) {
    // Check for host:port:password or host:port
    final parts = content.split(':');
    if (parts.isEmpty) return null;

    final host = parts[0].trim();
    if (host.isEmpty) return null;

    // Validate if host looks like an IP, hostname, or localhost
    final isLikelyHost = host == 'localhost' ||
        RegExp(r'^[a-zA-Z0-9.\-_]+$').hasMatch(host);
    if (!isLikelyHost) return null;

    int port = 4455;
    String password = '';

    if (parts.length >= 2) {
      final parsedPort = int.tryParse(parts[1].trim());
      if (parsedPort != null && parsedPort > 0 && parsedPort <= 65535) {
        port = parsedPort;
        if (parts.length >= 3) {
          password = parts.sublist(2).join(':').trim();
        }
      } else {
        // Not a valid port; might be plain host with something else
        return null;
      }
    }

    return ObsConnectionData(
      host: host,
      port: port,
      password: password,
      name: 'OBS Studio ($host)',
      rawSource: content,
    );
  }
}
