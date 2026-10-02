enum ObsConnectionStatus { disconnected, connecting, connected, error }

enum StreamingSoftware { obsStudio, streamlabs, vmix }

extension StreamingSoftwareExtension on StreamingSoftware {
  String get displayName {
    switch (this) {
      case StreamingSoftware.obsStudio:
        return 'OBS Studio';
      case StreamingSoftware.streamlabs:
        return 'Streamlabs';
      case StreamingSoftware.vmix:
        return 'vMix';
    }
  }

  String get shortName {
    switch (this) {
      case StreamingSoftware.obsStudio:
        return 'OBS';
      case StreamingSoftware.streamlabs:
        return 'SLOBS';
      case StreamingSoftware.vmix:
        return 'VMIX';
    }
  }

  int get defaultPort {
    switch (this) {
      case StreamingSoftware.obsStudio:
      case StreamingSoftware.streamlabs:
        return 4455;
      case StreamingSoftware.vmix:
        return 8088;
    }
  }

  String get protocolLabel {
    switch (this) {
      case StreamingSoftware.obsStudio:
        return 'WebSocket v5';
      case StreamingSoftware.streamlabs:
        return 'SLOBS WebSocket';
      case StreamingSoftware.vmix:
        return 'vMix Web API';
    }
  }

  String get setupHint {
    switch (this) {
      case StreamingSoftware.obsStudio:
        return 'Tools > WebSocket Server Settings (Port 4455)';
      case StreamingSoftware.streamlabs:
        return 'Settings > Remote Control / WebSocket (Port 4455)';
      case StreamingSoftware.vmix:
        return 'Settings > Web Controller (Port 8088)';
    }
  }
}

class ObsConnectionProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String password;
  final StreamingSoftware software;
  final bool autoConnect;
  final DateTime lastUsed;

  const ObsConnectionProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.password,
    this.software = StreamingSoftware.obsStudio,
    this.autoConnect = false,
    required this.lastUsed,
  });

  ObsConnectionProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? password,
    StreamingSoftware? software,
    bool? autoConnect,
    DateTime? lastUsed,
  }) {
    return ObsConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      password: password ?? this.password,
      software: software ?? this.software,
      autoConnect: autoConnect ?? this.autoConnect,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'password': password,
    'software': software.name,
    'autoConnect': autoConnect,
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory ObsConnectionProfile.fromJson(Map<String, dynamic> json) {
    StreamingSoftware resolvedSoftware = StreamingSoftware.obsStudio;
    final softStr = json['software'] as String?;
    if (softStr != null) {
      for (final s in StreamingSoftware.values) {
        if (s.name == softStr) {
          resolvedSoftware = s;
          break;
        }
      }
    }

    return ObsConnectionProfile(
      id: json['id'] as String? ?? 'default',
      name: json['name'] as String? ?? 'Main Studio',
      host: json['host'] as String? ?? '192.168.1.100',
      port: json['port'] as int? ?? (resolvedSoftware.defaultPort),
      password: json['password'] as String? ?? '',
      software: resolvedSoftware,
      autoConnect: json['autoConnect'] as bool? ?? false,
      lastUsed: json['lastUsed'] != null
          ? DateTime.tryParse(json['lastUsed'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
