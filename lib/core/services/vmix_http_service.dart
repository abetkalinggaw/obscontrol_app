import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../models/connection_state.dart';
import '../../models/obs_audio_source.dart';
import '../../models/obs_scene.dart';
import '../../models/obs_stats.dart';
import 'broadcast_service.dart';

/// vMix Web Controller HTTP API Service.
/// Communicates with vMix on port 8088 via `http://<host>:8088/api/`
class VmixHttpService implements BroadcastService {
  HttpClient? _httpClient;
  Timer? _pollTimer;

  ObsConnectionStatus _status = ObsConnectionStatus.disconnected;
  @override
  ObsConnectionStatus get status => _status;

  String? _host;
  int? _port;
  String? _password;
  bool _userExplicitlyDisconnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  int _consecutivePollErrors = 0;
  bool autoReconnect = true;

  String? get lastHost => _host;
  int? get lastPort => _port;
  String? get lastPassword => _password;
  bool get userExplicitlyDisconnected => _userExplicitlyDisconnected;

  // Cached state
  ObsStats _currentStats = const ObsStats();
  List<ObsScene> _currentScenes = [];
  List<ObsAudioSource> _currentAudioSources = [];
  String _activeProgram = '';
  String _activePreview = '';

  // Callbacks
  @override
  StatusCallback? onStatusChanged;
  @override
  StatsCallback? onStatsUpdated;
  @override
  ScenesCallback? onScenesUpdated;
  @override
  AudioSourcesCallback? onAudioSourcesUpdated;
  @override
  ThumbnailsCallback? onThumbnailsUpdated;

  void _updateStatus(ObsConnectionStatus status, {String? error}) {
    _status = status;
    onStatusChanged?.call(status, error);
  }

  @visibleForTesting
  void parseVmixXmlForTesting(String xml) => _parseVmixXml(xml);

  @override
  Future<void> connect({
    required String host,
    required int port,
    String? password,
    HttpClient? httpClient,
  }) async {
    _userExplicitlyDisconnected = false;
    _reconnectTimer?.cancel();
    disconnect(notify: false);
    _host = host;
    _port = port;
    _password = password;
    _updateStatus(ObsConnectionStatus.connecting);

    _httpClient = httpClient ?? (HttpClient()..connectionTimeout = const Duration(seconds: 5));

    try {
      final success = await _fetchStatus();
      if (success) {
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _updateStatus(ObsConnectionStatus.connected);
        _startPolling();
      } else {
        _updateStatus(
          ObsConnectionStatus.error,
          error: 'Failed to communicate with vMix Web Controller at $host:$port',
        );
        _scheduleReconnect();
      }
    } catch (e) {
      _updateStatus(
        ObsConnectionStatus.error,
        error: 'Cannot reach vMix on $host:$port. Ensure Web Controller is enabled in vMix settings.',
      );
      _scheduleReconnect();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _consecutivePollErrors = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 600), (_) async {
      final success = await _fetchStatus();
      if (!success) {
        _consecutivePollErrors++;
        if (_consecutivePollErrors >= 3 && _status == ObsConnectionStatus.connected) {
          _updateStatus(ObsConnectionStatus.disconnected, error: 'Lost connection to vMix Web Controller');
          _pollTimer?.cancel();
          _scheduleReconnect();
        }
      } else {
        _consecutivePollErrors = 0;
      }
    });
  }

  Future<bool> _fetchStatus() async {
    if (_host == null || _port == null || _httpClient == null) return false;

    try {
      final uri = Uri.parse('http://$_host:$_port/api/');
      final request = await _httpClient!.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final xmlBody = await response.transform(utf8.decoder).join();
        _parseVmixXml(xmlBody);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('vMix poll error: $e');
      return false;
    }
  }

  void _parseVmixXml(String xml) {
    // 1. Extract active and preview input numbers
    final activeMatch = RegExp(r'<active>(\d+)<\/active>', caseSensitive: false).firstMatch(xml);
    final previewMatch = RegExp(r'<preview>(\d+)<\/preview>', caseSensitive: false).firstMatch(xml);
    final activeNum = activeMatch?.group(1) ?? '1';
    final previewNum = previewMatch?.group(1) ?? '2';

    // 2. Extract streaming & recording flags
    final streamingMatch = RegExp(r'<streaming>(True|False)<\/streaming>', caseSensitive: false).firstMatch(xml);
    final recordingMatch = RegExp(r'<recording>(True|False)<\/recording>', caseSensitive: false).firstMatch(xml);
    final isStreaming = streamingMatch?.group(1)?.toLowerCase() == 'true';
    final isRecording = recordingMatch?.group(1)?.toLowerCase() == 'true';

    // 3. Extract inputs
    final inputMatches = RegExp(r'<input\s+([^>]+)>(.*?)<\/input>|<input\s+([^>]+)\/>', caseSensitive: false)
        .allMatches(xml);

    final List<ObsScene> newScenes = [];
    final List<ObsAudioSource> newAudio = [];
    String programTitle = '';
    String previewTitle = '';

    int idx = 0;
    for (final match in inputMatches) {
      final attrs = match.group(1) ?? match.group(3) ?? '';
      final body = match.group(2) ?? '';

      final number = _extractAttr(attrs, 'number') ?? '${idx + 1}';
      final title = _extractAttr(attrs, 'title') ?? (body.isNotEmpty ? body : 'Input $number');
      final type = _extractAttr(attrs, 'type') ?? 'Input';
      final isProg = number == activeNum;
      final isPrev = number == previewNum;

      if (isProg) programTitle = title;
      if (isPrev) previewTitle = title;

      newScenes.add(
        ObsScene(
          name: title,
          sceneIndex: int.tryParse(number) ?? idx,
          isProgram: isProg,
          isPreview: isPrev,
          items: [
            ObsSceneItem(
              sceneItemId: int.tryParse(number) ?? idx,
              sourceName: title,
              sourceType: type,
              sceneItemEnabled: true,
            ),
          ],
        ),
      );

      // Check for audio capabilities
      final mutedAttr = _extractAttr(attrs, 'muted');
      final volAttr = _extractAttr(attrs, 'volume');
      final m1Attr = _extractAttr(attrs, 'meterF1');
      final m2Attr = _extractAttr(attrs, 'meterF2');

      if (volAttr != null || m1Attr != null || type.toLowerCase().contains('audio') || type.toLowerCase().contains('camera')) {
        final volVal = double.tryParse(volAttr ?? '100') ?? 100.0;
        final volMul = (volVal / 100.0).clamp(0.0, 1.0);
        final isMuted = mutedAttr?.toLowerCase() == 'true';
        final m1 = (double.tryParse(m1Attr ?? '0.0') ?? 0.0).clamp(0.0, 1.0);
        final m2 = (double.tryParse(m2Attr ?? '0.0') ?? 0.0).clamp(0.0, 1.0);
        final db = volMul > 0 ? (20 * math.log(volMul) / math.ln10).clamp(-60.0, 0.0) : -60.0;

        newAudio.add(
          ObsAudioSource(
            name: title,
            inputKind: type,
            volumeMul: volMul,
            volumeDb: db,
            muted: isMuted,
            leftLevel: m1,
            rightLevel: m2,
            peakHold: math.max(m1, m2),
          ),
        );
      }

      idx++;
    }

    _activeProgram = programTitle.isNotEmpty ? programTitle : 'Input $activeNum';
    _activePreview = previewTitle.isNotEmpty ? previewTitle : 'Input $previewNum';
    _currentScenes = newScenes;
    _currentAudioSources = newAudio;

    _currentStats = _currentStats.copyWith(
      isStreaming: isStreaming,
      isRecording: isRecording,
      currentProgramScene: _activeProgram,
      currentPreviewScene: _activePreview,
      studioModeEnabled: true,
      activeFps: 30.0,
    );

    onStatsUpdated?.call(_currentStats);
    onScenesUpdated?.call(_currentScenes, _activeProgram, _activePreview);
    onAudioSourcesUpdated?.call(_currentAudioSources);
  }

  String? _extractAttr(String attrs, String name) {
    final m = RegExp('$name="([^"]*)"', caseSensitive: false).firstMatch(attrs);
    return m?.group(1);
  }

  Future<void> _sendFunction(String function, [Map<String, String>? params]) async {
    if (_host == null || _port == null || _httpClient == null) return;

    try {
      final queryParams = <String, String>{'Function': function};
      if (params != null) {
        queryParams.addAll(params);
      }
      final uri = Uri.http('$_host:$_port', '/api/', queryParams);
      final request = await _httpClient!.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 3));
      await response.drain();

      // Refresh immediately after action
      _fetchStatus();
    } catch (e) {
      debugPrint('vMix sendFunction error ($function): $e');
    }
  }

  @override
  Future<void> setCurrentProgramScene(String sceneName) async {
    final inputId = _findInputId(sceneName);
    await _sendFunction('CutDirect', {'Input': inputId});
  }

  @override
  Future<void> setCurrentPreviewScene(String sceneName) async {
    final inputId = _findInputId(sceneName);
    await _sendFunction('PreviewInput', {'Input': inputId});
  }

  int _transitionDurationMs = 300;

  @override
  Future<void> triggerStudioTransition([String transitionName = 'Cut']) async {
    if (transitionName.toLowerCase() == 'fade') {
      await _sendFunction('Fade', {'Duration': '$_transitionDurationMs'});
    } else if (transitionName.toLowerCase() == 'cut') {
      await _sendFunction('Cut');
    } else {
      await _sendFunction('Transition1');
    }
  }

  @override
  Future<void> setTransitionDuration(int durationMs) async {
    _transitionDurationMs = durationMs;
  }

  @override
  Future<void> setTBarPosition(double position, {bool release = true}) async {
    final faderVal = (position.clamp(0.0, 1.0) * 255).round();
    await _sendFunction('SetFader', {'Value': faderVal.toString()});
    if (release && position >= 0.95) {
      await _sendFunction('Transition', {});
    }
  }

  @override
  Future<void> toggleStudioMode() async {
    // vMix is naturally two-bus (Preview & Output)
  }

  @override
  Future<void> setInputVolume(String inputName, double volumeMul) async {
    final inputId = _findInputId(inputName);
    final val100 = (volumeMul * 100).round().clamp(0, 100);
    await _sendFunction('SetVolume', {'Input': inputId, 'Value': val100.toString()});
  }

  @override
  Future<void> toggleInputMute(String inputName) async {
    final inputId = _findInputId(inputName);
    await _sendFunction('Audio', {'Input': inputId});
  }

  @override
  Future<void> toggleStream() async {
    await _sendFunction('StartStopStreaming');
  }

  @override
  Future<void> toggleRecord() async {
    await _sendFunction('StartStopRecording');
  }

  @override
  Future<void> saveReplayBuffer() async {
    await _sendFunction('ReplayMarkInOut');
  }

  @override
  Future<void> openMultiviewProjector() async {
    // vMix renders inputs continuously by default; no projector required.
  }

  String _findInputId(String sceneName) {
    for (final s in _currentScenes) {
      if (s.name == sceneName) {
        return s.sceneIndex.toString();
      }
    }
    return sceneName;
  }

  @override
  void disconnect({bool notify = true}) {
    _userExplicitlyDisconnected = true;
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _pollTimer = null;
    _httpClient?.close(force: true);
    _httpClient = null;

    _currentScenes = [];
    _currentAudioSources = [];
    _currentStats = const ObsStats();

    if (notify) {
      _updateStatus(ObsConnectionStatus.disconnected);
    } else {
      _status = ObsConnectionStatus.disconnected;
    }
  }

  void _scheduleReconnect() {
    if (_userExplicitlyDisconnected) return;
    if (!autoReconnect) return;
    if (_host == null || _port == null) return;
    if (_status == ObsConnectionStatus.connected) return;

    _reconnectTimer?.cancel();
    final delay = math.min(10, 2 * (1 << math.min(_reconnectAttempts, 2)));
    _reconnectAttempts++;
    debugPrint('vMix auto-reconnect scheduled in $delay s (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (!_userExplicitlyDisconnected &&
          _status != ObsConnectionStatus.connected &&
          _status != ObsConnectionStatus.connecting) {
        connect(
          host: _host!,
          port: _port!,
          password: _password,
        );
      }
    });
  }
}
