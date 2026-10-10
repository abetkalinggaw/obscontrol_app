import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/services/storage_service.dart';
import '../core/utils/haptics.dart';
import '../models/connection_state.dart';

class SettingsState {
  final List<ObsConnectionProfile> profiles;
  final List<ObsConnectionProfile> recentDevices;
  final String activeProfileId;
  final bool hapticsEnabled;
  final bool autoReconnect;
  final bool keepScreenOn;

  const SettingsState({
    required this.profiles,
    this.recentDevices = const [],
    required this.activeProfileId,
    required this.hapticsEnabled,
    required this.autoReconnect,
    required this.keepScreenOn,
  });

  ObsConnectionProfile get activeProfile {
    return profiles.firstWhere(
      (p) => p.id == activeProfileId,
      orElse: () => profiles.isNotEmpty
          ? profiles.first
          : ObsConnectionProfile(
              id: 'default',
              name: 'Main Studio PC',
              host: '192.168.1.100',
              port: 4455,
              password: '',
              lastUsed: DateTime.now(),
            ),
    );
  }

  SettingsState copyWith({
    List<ObsConnectionProfile>? profiles,
    List<ObsConnectionProfile>? recentDevices,
    String? activeProfileId,
    bool? hapticsEnabled,
    bool? autoReconnect,
    bool? keepScreenOn,
  }) {
    return SettingsState(
      profiles: profiles ?? this.profiles,
      recentDevices: recentDevices ?? this.recentDevices,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  SettingsState build() {
    final storage = ref.watch(storageServiceProvider);
    Haptics.enabled = storage.getHapticsEnabled();
    final keepScreenOn = storage.getKeepScreenOn();
    try {
      if (keepScreenOn) {
        WakelockPlus.enable().catchError((_) {});
      } else {
        WakelockPlus.disable().catchError((_) {});
      }
    } catch (_) {}
    return SettingsState(
      profiles: storage.loadProfiles(),
      recentDevices: storage.loadRecentDevices(),
      activeProfileId: storage.getActiveProfileId() ??
          (storage.loadProfiles().isNotEmpty ? storage.loadProfiles().first.id : 'default'),
      hapticsEnabled: storage.getHapticsEnabled(),
      autoReconnect: storage.getAutoReconnect(),
      keepScreenOn: keepScreenOn,
    );
  }

  Future<void> saveProfile(ObsConnectionProfile profile) async {
    final list = List<ObsConnectionProfile>.from(state.profiles);
    final idx = list.indexWhere((p) => p.id == profile.id);
    if (idx != -1) {
      list[idx] = profile;
    } else {
      list.add(profile);
    }
    await _storage.saveProfiles(list);
    state = state.copyWith(profiles: list);
  }

  Future<void> deleteProfile(String profileId) async {
    final list = state.profiles.where((p) => p.id != profileId).toList();
    if (list.isEmpty) {
      list.add(ObsConnectionProfile(
        id: 'default',
        name: 'Main Studio PC',
        host: '192.168.1.100',
        port: 4455,
        password: '',
        lastUsed: DateTime.now(),
      ));
    }
    await _storage.saveProfiles(list);
    final newActive = list.any((p) => p.id == state.activeProfileId)
        ? state.activeProfileId
        : list.first.id;
    state = state.copyWith(profiles: list, activeProfileId: newActive);
    await _storage.setActiveProfileId(newActive);
  }

  Future<void> setActiveProfile(String profileId) async {
    await _storage.setActiveProfileId(profileId);
    state = state.copyWith(activeProfileId: profileId);
  }

  Future<void> updateActiveProfileConnection({
    required String host,
    required int port,
    required String password,
    required StreamingSoftware software,
    String? name,
  }) async {
    final list = List<ObsConnectionProfile>.from(state.profiles);

    // Check if an existing profile matches this host, port, and software
    final matchIdx = list.indexWhere(
      (p) => p.host == host && p.port == port && p.software == software,
    );
    if (matchIdx != -1) {
      final existing = list[matchIdx];
      list[matchIdx] = existing.copyWith(
        password: password.isNotEmpty ? password : existing.password,
        lastUsed: DateTime.now(),
      );
      await _storage.saveProfiles(list);
      await _storage.setActiveProfileId(existing.id);
      state = state.copyWith(profiles: list, activeProfileId: existing.id);
      return;
    }

    final activeId = state.activeProfileId;
    final idx = list.indexWhere((p) => p.id == activeId);

    if (idx != -1) {
      final current = list[idx];
      list[idx] = current.copyWith(
        host: host,
        port: port,
        password: password,
        software: software,
        name: name ?? current.name,
        lastUsed: DateTime.now(),
      );
    } else {
      final newProfile = ObsConnectionProfile(
        id: activeId.isNotEmpty ? activeId : 'default',
        name: name ?? '${software.shortName} ($host)',
        host: host,
        port: port,
        password: password,
        software: software,
        lastUsed: DateTime.now(),
      );
      list.add(newProfile);
    }

    await _storage.saveProfiles(list);
    state = state.copyWith(profiles: list);
  }

  Future<void> addRecentDevice(ObsConnectionProfile device) async {
    final list = List<ObsConnectionProfile>.from(state.recentDevices);
    list.removeWhere((p) => p.host == device.host && p.port == device.port);
    list.insert(0, device);
    if (list.length > 10) {
      list.removeRange(10, list.length);
    }
    await _storage.saveRecentDevices(list);
    state = state.copyWith(recentDevices: list);
  }

  Future<void> removeRecentDevice(String id) async {
    final list = state.recentDevices.where((p) => p.id != id).toList();
    await _storage.saveRecentDevices(list);
    state = state.copyWith(recentDevices: list);
  }

  Future<void> clearRecentDevices() async {
    await _storage.saveRecentDevices([]);
    state = state.copyWith(recentDevices: []);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    Haptics.enabled = enabled;
    await _storage.setHapticsEnabled(enabled);
    state = state.copyWith(hapticsEnabled: enabled);
  }

  Future<void> setAutoReconnect(bool autoReconnect) async {
    await _storage.setAutoReconnect(autoReconnect);
    state = state.copyWith(autoReconnect: autoReconnect);
  }

  Future<void> setKeepScreenOn(bool keepOn) async {
    try {
      if (keepOn) {
        await WakelockPlus.enable().catchError((_) {});
      } else {
        await WakelockPlus.disable().catchError((_) {});
      }
    } catch (_) {}
    await _storage.setKeepScreenOn(keepOn);
    state = state.copyWith(keepScreenOn: keepOn);
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Initialize storageServiceProvider in main');
});

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
