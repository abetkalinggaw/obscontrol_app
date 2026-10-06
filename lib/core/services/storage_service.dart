import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/connection_state.dart';
import '../../models/macro_action.dart';

class StorageService {
  static const _keyProfiles = 'obs_saved_profiles';
  static const _keyRecentDevices = 'obs_recent_devices';
  static const _keyActiveProfile = 'obs_active_profile_id';
  static const _keyMacros = 'obs_custom_macros';
  static const _keyHaptics = 'obs_haptics_enabled';
  static const _keyAutoReconnect = 'obs_auto_reconnect';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Connection Profiles
  List<ObsConnectionProfile> loadProfiles() {
    final raw = _prefs.getStringList(_keyProfiles);
    if (raw == null || raw.isEmpty) {
      return [
        ObsConnectionProfile(
          id: 'default',
          name: 'Main Studio PC',
          host: '192.168.1.100',
          port: 4455,
          password: '',
          autoConnect: false,
          lastUsed: DateTime.now(),
        ),
      ];
    }
    return raw
        .map((str) => ObsConnectionProfile.fromJson(jsonDecode(str)))
        .toList();
  }

  Future<void> saveProfiles(List<ObsConnectionProfile> profiles) async {
    final raw = profiles.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_keyProfiles, raw);
  }

  // Recent Devices
  List<ObsConnectionProfile> loadRecentDevices() {
    final raw = _prefs.getStringList(_keyRecentDevices);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    return raw
        .map((str) => ObsConnectionProfile.fromJson(jsonDecode(str)))
        .toList();
  }

  Future<void> saveRecentDevices(List<ObsConnectionProfile> devices) async {
    final raw = devices.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_keyRecentDevices, raw);
  }

  String? getActiveProfileId() {
    return _prefs.getString(_keyActiveProfile);
  }

  Future<void> setActiveProfileId(String id) async {
    await _prefs.setString(_keyActiveProfile, id);
  }

  // Macro Deck Actions
  List<MacroAction> loadMacros() {
    final raw = _prefs.getString(_keyMacros);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        return list.map((item) => MacroAction.fromJson(item)).toList();
      } catch (_) {}
    }
    // Default 3x4 (12 tiles) macro deck
    return [
      const MacroAction(
        id: 'm1',
        title: 'BRB + MUTE',
        subtitle: 'Break Scene',
        iconName: 'pause',
        colorValue: 0xFFFF9500,
        type: MacroType.switchScene,
        target: 'BRB / Intermission',
      ),
      const MacroAction(
        id: 'm2',
        title: 'MIC MUTE',
        subtitle: 'Toggle Mic',
        iconName: 'mic_off',
        colorValue: 0xFFFF3B30,
        type: MacroType.toggleMute,
        target: 'Mic/Aux',
      ),
      const MacroAction(
        id: 'm3',
        title: 'DESKTOP MUTE',
        subtitle: 'All Audio',
        iconName: 'volume_off',
        colorValue: 0xFF5856D6,
        type: MacroType.toggleMute,
        target: 'Desktop Audio',
      ),
      const MacroAction(
        id: 'm4',
        title: 'CUT TRANS',
        subtitle: 'Studio Cut',
        iconName: 'cut',
        colorValue: 0xFF34C759,
        type: MacroType.studioTransition,
        target: 'Cut',
      ),
      const MacroAction(
        id: 'm5',
        title: 'GAMEPLAY',
        subtitle: 'Main Scene',
        iconName: 'videogame_asset',
        colorValue: 0xFF007AFF,
        type: MacroType.switchScene,
        target: 'Gameplay 4K',
      ),
      const MacroAction(
        id: 'm6',
        title: 'FULL CAM',
        subtitle: 'Face Cam',
        iconName: 'videocam',
        colorValue: 0xFFAF52DE,
        type: MacroType.switchScene,
        target: 'Camera Main',
      ),
      const MacroAction(
        id: 'm7',
        title: 'FADE (300ms)',
        subtitle: 'Smooth Fade',
        iconName: 'auto_awesome',
        colorValue: 0xFFFFCC00,
        type: MacroType.studioTransition,
        target: 'Fade',
      ),
      const MacroAction(
        id: 'm8',
        title: 'REPLAY CLIP',
        subtitle: 'Save Buffer',
        iconName: 'history',
        colorValue: 0xFFFF2D55,
        type: MacroType.saveReplay,
        target: '',
      ),
      const MacroAction(
        id: 'm9',
        title: 'SCREEN SHARE',
        subtitle: 'Desktop Display',
        iconName: 'screen_share',
        colorValue: 0xFF5AC8FA,
        type: MacroType.switchScene,
        target: 'Screen Share',
      ),
      const MacroAction(
        id: 'm10',
        title: 'BGM MUTE',
        subtitle: 'Spotify / Music',
        iconName: 'music_off',
        colorValue: 0xFF32D74B,
        type: MacroType.toggleMute,
        target: 'Spotify BGM',
      ),
      const MacroAction(
        id: 'm11',
        title: 'START REC',
        subtitle: 'Local Record',
        iconName: 'fiber_manual_record',
        colorValue: 0xFFFF3B30,
        type: MacroType.toggleRecord,
        target: '',
      ),
      const MacroAction(
        id: 'm12',
        title: 'OUTRO SCENE',
        subtitle: 'Stream Ending',
        iconName: 'flag',
        colorValue: 0xFF8E8E93,
        type: MacroType.switchScene,
        target: 'Ending Credits',
      ),
    ];
  }

  Future<void> saveMacros(List<MacroAction> macros) async {
    final raw = jsonEncode(macros.map((m) => m.toJson()).toList());
    await _prefs.setString(_keyMacros, raw);
  }

  // App settings
  bool getHapticsEnabled() => _prefs.getBool(_keyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool enabled) => _prefs.setBool(_keyHaptics, enabled);

  static const _keyKeepScreenOn = 'obs_keep_screen_on';
  bool getKeepScreenOn() => _prefs.getBool(_keyKeepScreenOn) ?? true;
  Future<void> setKeepScreenOn(bool keepOn) => _prefs.setBool(_keyKeepScreenOn, keepOn);

  bool getAutoReconnect() => _prefs.getBool(_keyAutoReconnect) ?? true;
  Future<void> setAutoReconnect(bool autoReconnect) => _prefs.setBool(_keyAutoReconnect, autoReconnect);

  static const _keyAudioMixerViewMode = 'obs_audio_mixer_view_mode';
  String getAudioMixerViewMode() => _prefs.getString(_keyAudioMixerViewMode) ?? 'vertical';
  Future<void> setAudioMixerViewMode(String mode) => _prefs.setString(_keyAudioMixerViewMode, mode);

  static const _keyHiddenAudioChannels = 'obs_hidden_audio_channels';
  List<String> getHiddenAudioChannels() => _prefs.getStringList(_keyHiddenAudioChannels) ?? [];
  Future<void> setHiddenAudioChannels(List<String> hiddenChannels) => _prefs.setStringList(_keyHiddenAudioChannels, hiddenChannels);

  static const _keySceneOrder = 'obs_multiview_scene_order';
  List<String> getSceneOrder() => _prefs.getStringList(_keySceneOrder) ?? [];
  Future<void> setSceneOrder(List<String> order) => _prefs.setStringList(_keySceneOrder, order);

  static const _keyMultiviewLocked = 'obs_multiview_locked';
  bool getMultiviewLocked() => _prefs.getBool(_keyMultiviewLocked) ?? false;
  Future<void> setMultiviewLocked(bool locked) => _prefs.setBool(_keyMultiviewLocked, locked);

  static const _keyTransitionDuration = 'obs_transition_duration';
  int getTransitionDuration() => _prefs.getInt(_keyTransitionDuration) ?? 300;
  Future<void> setTransitionDuration(int ms) => _prefs.setInt(_keyTransitionDuration, ms);

  static const _keyMonitoredAudioChannel = 'obs_monitored_audio_channel';
  String? getMonitoredAudioChannel() => _prefs.getString(_keyMonitoredAudioChannel);
  Future<void> setMonitoredAudioChannel(String channelName) => _prefs.setString(_keyMonitoredAudioChannel, channelName);
}

