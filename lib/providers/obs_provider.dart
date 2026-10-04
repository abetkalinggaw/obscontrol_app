import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/broadcast_service.dart';
import '../core/services/obs_websocket_service.dart';
import '../core/services/vmix_http_service.dart';
import '../models/connection_state.dart';
import '../models/obs_stats.dart';
import 'settings_provider.dart';

class ObsConnectionState {
  final ObsConnectionStatus status;
  final String? errorMessage;
  final ObsStats stats;
  final String currentHost;
  final int currentPort;
  final StreamingSoftware currentSoftware;

  const ObsConnectionState({
    this.status = ObsConnectionStatus.disconnected,
    this.errorMessage,
    this.stats = const ObsStats(),
    this.currentHost = '',
    this.currentPort = 4455,
    this.currentSoftware = StreamingSoftware.obsStudio,
  });

  ObsConnectionState copyWith({
    ObsConnectionStatus? status,
    String? errorMessage,
    ObsStats? stats,
    String? currentHost,
    int? currentPort,
    StreamingSoftware? currentSoftware,
  }) {
    return ObsConnectionState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      stats: stats ?? this.stats,
      currentHost: currentHost ?? this.currentHost,
      currentPort: currentPort ?? this.currentPort,
      currentSoftware: currentSoftware ?? this.currentSoftware,
    );
  }
}

class ObsNotifier extends Notifier<ObsConnectionState> {
  ObsWebSocketService get _obsService => ref.read(obsWebSocketServiceProvider);
  VmixHttpService get _vmixService => ref.read(vmixHttpServiceProvider);

  String _lastPassword = '';
  bool _userExplicitlyDisconnected = false;

  bool get userExplicitlyDisconnected => _userExplicitlyDisconnected;

  BroadcastService get activeService =>
      state.currentSoftware == StreamingSoftware.vmix ? _vmixService : _obsService;

  @override
  ObsConnectionState build() {
    final obsService = ref.watch(obsWebSocketServiceProvider);
    final vmixService = ref.watch(vmixHttpServiceProvider);
    final settings = ref.read(settingsProvider);

    obsService.autoReconnect = settings.autoReconnect;
    vmixService.autoReconnect = settings.autoReconnect;
    ref.listen(settingsProvider.select((s) => s.autoReconnect), (_, next) {
      obsService.autoReconnect = next;
      vmixService.autoReconnect = next;
    });

    obsService.onStatusChanged = (status, error) {
      if (state.currentSoftware != StreamingSoftware.vmix) {
        state = state.copyWith(status: status, errorMessage: error);
        if (status == ObsConnectionStatus.connected && state.currentHost.isNotEmpty) {
          ref.read(settingsProvider.notifier).updateActiveProfileConnection(
            host: state.currentHost,
            port: state.currentPort,
            password: _lastPassword,
            software: state.currentSoftware,
          );
        }
      }
    };
    obsService.onStatsUpdated = (stats) {
      if (state.currentSoftware != StreamingSoftware.vmix) {
        state = state.copyWith(stats: stats);
      }
    };

    vmixService.onStatusChanged = (status, error) {
      if (state.currentSoftware == StreamingSoftware.vmix) {
        state = state.copyWith(status: status, errorMessage: error);
        if (status == ObsConnectionStatus.connected && state.currentHost.isNotEmpty) {
          ref.read(settingsProvider.notifier).updateActiveProfileConnection(
            host: state.currentHost,
            port: state.currentPort,
            password: _lastPassword,
            software: StreamingSoftware.vmix,
          );
        }
      }
    };
    vmixService.onStatsUpdated = (stats) {
      if (state.currentSoftware == StreamingSoftware.vmix) {
        state = state.copyWith(stats: stats);
      }
    };

    return const ObsConnectionState();
  }

  Future<void> connectCurrentProfile() async {
    final settings = ref.read(settingsProvider);
    final profile = settings.activeProfile;
    await connect(
      host: profile.host,
      port: profile.port,
      password: profile.password,
      name: profile.name,
      software: profile.software,
    );
  }

  Future<void> connect({
    required String host,
    required int port,
    required String password,
    String? name,
    StreamingSoftware software = StreamingSoftware.obsStudio,
  }) async {
    _userExplicitlyDisconnected = false;
    _lastPassword = password;
    disconnect();
    _userExplicitlyDisconnected = false; // Reset after disconnect() sets it to true

    final autoReconnect = ref.read(settingsProvider).autoReconnect;
    _obsService.autoReconnect = autoReconnect;
    _vmixService.autoReconnect = autoReconnect;

    state = state.copyWith(
      currentHost: host,
      currentPort: port,
      currentSoftware: software,
      status: ObsConnectionStatus.connecting,
    );

    ref.read(settingsProvider.notifier).addRecentDevice(
      ObsConnectionProfile(
        id: 'recent_${host}_$port',
        name: name ?? (host == '127.0.0.1' || host == 'localhost' ? 'Local Studio' : '${software.shortName} ($host)'),
        host: host,
        port: port,
        password: password,
        software: software,
        lastUsed: DateTime.now(),
      ),
    );

    if (software == StreamingSoftware.vmix) {
      await _vmixService.connect(
        host: host,
        port: port,
        password: password,
      );
    } else {
      await _obsService.connect(
        host: host,
        port: port,
        password: password,
      );
    }
  }

  void disconnect() {
    _userExplicitlyDisconnected = true;
    _obsService.disconnect();
    _vmixService.disconnect();
    state = state.copyWith(status: ObsConnectionStatus.disconnected);
  }

  /// Testing helper to set mock state without demo timers
  void setMockState({
    ObsConnectionStatus? status,
    ObsStats? stats,
    String? currentHost,
    int? currentPort,
    StreamingSoftware? software,
  }) {
    state = state.copyWith(
      status: status,
      stats: stats,
      currentHost: currentHost,
      currentPort: currentPort,
      currentSoftware: software,
    );
  }

  Future<void> toggleStream() async {
    await activeService.toggleStream();
  }

  Future<void> toggleRecord() async {
    await activeService.toggleRecord();
  }

  Future<void> saveReplayBuffer() async {
    await activeService.saveReplayBuffer();
  }

  Future<void> toggleStudioMode() async {
    await activeService.toggleStudioMode();
  }
}

final obsWebSocketServiceProvider = Provider<ObsWebSocketService>((ref) {
  final service = ObsWebSocketService();
  ref.onDispose(() => service.disconnect(notify: false));
  return service;
});

final vmixHttpServiceProvider = Provider<VmixHttpService>((ref) {
  final service = VmixHttpService();
  ref.onDispose(() => service.disconnect(notify: false));
  return service;
});

final broadcastServiceProvider = Provider<BroadcastService>((ref) {
  final obsState = ref.watch(obsProvider);
  if (obsState.currentSoftware == StreamingSoftware.vmix) {
    return ref.watch(vmixHttpServiceProvider);
  }
  return ref.watch(obsWebSocketServiceProvider);
});

final obsProvider = NotifierProvider<ObsNotifier, ObsConnectionState>(ObsNotifier.new);
