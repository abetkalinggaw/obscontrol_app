import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/connection_state.dart';
import '../../models/obs_audio_source.dart';
import '../../models/obs_scene.dart';
import '../../models/obs_stats.dart';
import 'broadcast_service.dart';

class ObsWebSocketService implements BroadcastService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _statsTimer;
  Timer? _previewLoopTimer;
  Timer? _connectionTimeoutTimer;

  bool _isFetchingPreviews = false;
  bool _pendingImmediatePreview = false;
  int _backgroundSceneOffset = 0;
  
  ObsConnectionStatus _status = ObsConnectionStatus.disconnected;
  @override
  ObsConnectionStatus get status => _status;

  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _requestIdCounter = 0;

  // Listeners
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

  // Cached state
  ObsStats _currentStats = const ObsStats();
  List<ObsScene> _currentScenes = [];
  List<ObsAudioSource> _currentAudioSources = [];

  // Fallback / Auto-reconnect
  String? _lastHost;
  int? _lastPort;
  String? _lastPassword;
  bool _userExplicitlyDisconnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool autoReconnect = true;

  String? get lastHost => _lastHost;
  int? get lastPort => _lastPort;
  String? get lastPassword => _lastPassword;
  bool get userExplicitlyDisconnected => _userExplicitlyDisconnected;

  // -------------------------------------------------------------
  // Connect to Real OBS Studio / Streamlabs (v5)
  // -------------------------------------------------------------
  @override
  Future<void> connect({
    required String host,
    required int port,
    required String password,
  }) async {
    _userExplicitlyDisconnected = false;
    _reconnectTimer?.cancel();
    _disconnectInternal();
    _lastHost = host;
    _lastPort = port;
    _lastPassword = password;

    _updateStatus(ObsConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://$host:$port');
      _channel = WebSocketChannel.connect(uri);

      // Listen to raw messages
      _subscription = _channel!.stream.listen(
        (data) => _handleIncomingMessage(data, password),
        onError: (err) {
          debugPrint('OBS WebSocket error: $err');
          _updateStatus(ObsConnectionStatus.error, error: 'Connection failed: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('OBS WebSocket connection closed');
          if (_status != ObsConnectionStatus.disconnected) {
            _updateStatus(ObsConnectionStatus.disconnected);
          }
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      // Timeout if no Hello received within 6 seconds
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = Timer(const Duration(seconds: 6), () {
        if (_status == ObsConnectionStatus.connecting) {
          _updateStatus(ObsConnectionStatus.error, error: 'Connection timed out. Check IP and port.');
          _disconnectInternal();
          _scheduleReconnect();
        }
      });
    } catch (e) {
      _updateStatus(ObsConnectionStatus.error, error: e.toString());
      _scheduleReconnect();
    }
  }

  void _handleIncomingMessage(dynamic raw, String password) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final op = json['op'] as int?;
      final d = json['d'] as Map<String, dynamic>? ?? {};

      switch (op) {
        case 0: // Hello
          _handleHello(d, password);
          break;
        case 2: // Identified
          _handleIdentified(d);
          break;
        case 5: // Event
          _handleEvent(d);
          break;
        case 7: // RequestResponse
          _handleRequestResponse(d);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Error parsing OBS message: $e');
    }
  }

  void _handleHello(Map<String, dynamic> data, String password) {
    final auth = data['authentication'] as Map<String, dynamic>?;
    String? authString;

    if (auth != null) {
      final challenge = auth['challenge'] as String;
      final salt = auth['salt'] as String;

      // OBS v5 auth formula:
      // secret = base64(sha256(password + salt))
      // auth = base64(sha256(secret + challenge))
      final secretBytes = sha256.convert(utf8.encode(password + salt)).bytes;
      final secretBase64 = base64Encode(secretBytes);
      final authBytes = sha256.convert(utf8.encode(secretBase64 + challenge)).bytes;
      authString = base64Encode(authBytes);
    }

    // Send Opcode 1: Identify
    // Event subscriptions: 2047 (All events) | (1 << 16) (InputVolumeMeters)
    final identifyData = <String, dynamic>{
      'rpcVersion': 1,
      'eventSubscriptions': 2047 | (1 << 16),
    };
    if (authString != null) {
      identifyData['authentication'] = authString;
    }

    final identifyMsg = {
      'op': 1,
      'd': identifyData,
    };

    _sendRaw(identifyMsg);
  }

  void _handleIdentified(Map<String, dynamic> data) async {
    _connectionTimeoutTimer?.cancel();
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _updateStatus(ObsConnectionStatus.connected);

    // Initial State Fetch
    await _fetchInitialState();

    // Start periodic telemetry poll (stats & duration)
    _startStatsPolling();

    // Start thumbnail polling for scene previews
    _startThumbnailPolling();
  }

  void _handleEvent(Map<String, dynamic> data) {
    final eventType = data['eventType'] as String? ?? '';
    final eventData = data['eventData'] as Map<String, dynamic>? ?? {};

    switch (eventType) {
      case 'CurrentProgramSceneChanged':
        final sceneName = eventData['sceneName'] as String? ?? '';
        _currentStats = _currentStats.copyWith(currentProgramScene: sceneName);
        _markScenesActive(program: sceneName);
        onStatsUpdated?.call(_currentStats);
        _fetchRealtimeMultiviewPreviews(immediate: true);
        _fetchAudioInputs();
        break;

      case 'CurrentPreviewSceneChanged':
        final sceneName = eventData['sceneName'] as String? ?? '';
        _currentStats = _currentStats.copyWith(currentPreviewScene: sceneName);
        _markScenesActive(preview: sceneName);
        onStatsUpdated?.call(_currentStats);
        _fetchRealtimeMultiviewPreviews(immediate: true);
        if (_currentStats.studioModeEnabled) {
          _fetchAudioInputs();
        }
        break;

      case 'SceneTransitionStarted':
        _fetchRealtimeMultiviewPreviews(immediate: true);
        break;

      case 'SceneTransitionEnded':
        _fetchRealtimeMultiviewPreviews(immediate: true);
        _fetchAudioInputs();
        break;

      case 'StreamStateChanged':
        final active = eventData['outputActive'] as bool? ?? false;
        _currentStats = _currentStats.copyWith(
          isStreaming: active,
          streamTimecodeSeconds: active ? _currentStats.streamTimecodeSeconds : 0,
        );
        onStatsUpdated?.call(_currentStats);
        break;

      case 'RecordStateChanged':
        final active = eventData['outputActive'] as bool? ?? false;
        final paused = eventData['outputPaused'] as bool? ?? false;
        _currentStats = _currentStats.copyWith(
          isRecording: active,
          isRecordingPaused: paused,
          recordTimecodeSeconds: active ? _currentStats.recordTimecodeSeconds : 0,
        );
        onStatsUpdated?.call(_currentStats);
        break;

      case 'ReplayBufferStateChanged':
        final active = eventData['outputActive'] as bool? ?? false;
        _currentStats = _currentStats.copyWith(isReplayBufferActive: active);
        onStatsUpdated?.call(_currentStats);
        break;

      case 'StudioModeStateChanged':
        final enabled = eventData['studioModeEnabled'] as bool? ?? false;
        _currentStats = _currentStats.copyWith(studioModeEnabled: enabled);
        if (enabled) {
          _fetchCurrentPreviewScene();
        }
        onStatsUpdated?.call(_currentStats);
        _fetchRealtimeMultiviewPreviews(immediate: true);
        break;

      case 'InputVolumeChanged':
        final inputName = eventData['inputName'] as String? ?? '';
        final volMul = (eventData['inputVolumeMul'] as num?)?.toDouble() ?? 1.0;
        final volDb = (eventData['inputVolumeDb'] as num?)?.toDouble() ?? 0.0;
        _updateAudioSource(inputName, volumeMul: volMul, volumeDb: volDb);
        break;

      case 'InputMuteStateChanged':
        final inputName = eventData['inputName'] as String? ?? '';
        final muted = eventData['inputMuted'] as bool? ?? false;
        _updateAudioSource(inputName, muted: muted);
        break;

      case 'InputVolumeMeters':
        final inputs = eventData['inputs'] as List? ?? [];
        for (final item in inputs) {
          if (item is Map) {
            final name = item['inputName'] as String? ?? '';
            final levels = item['inputLevelsMul'] as List? ?? [];
            if (levels.isNotEmpty) {
              // OBS WebSocket v5: inputLevelsMul[ch] = [magnitude, peak, input_peak]
              // Use index 1 (peak) — matches what OBS Studio VU meter displays.
              // Convert linear multiplier → dB → 0-1 fraction (same -60..0 dB range as scale).
              final left = _mulToDisplayFrac(
                (levels[0] is List && (levels[0] as List).length > 1)
                    ? ((levels[0] as List)[1] as num).toDouble()
                    : (levels[0] is List && (levels[0] as List).isNotEmpty)
                        ? ((levels[0] as List)[0] as num).toDouble()
                        : 0.0,
              );
              final right = (levels.length > 1 && levels[1] is List && (levels[1] as List).isNotEmpty)
                  ? _mulToDisplayFrac(
                      ((levels[1] as List).length > 1)
                          ? ((levels[1] as List)[1] as num).toDouble()
                          : ((levels[1] as List)[0] as num).toDouble(),
                    )
                  : left;
              _updateAudioSource(name, leftLevel: left, rightLevel: right);
            }
          }
        }
        break;

      case 'SceneListChanged':
        _fetchScenes().then((_) => _fetchRealtimeMultiviewPreviews(immediate: true));
        break;

      case 'InputCreated':
      case 'InputRemoved':
      case 'InputNameChanged':
      case 'SceneItemCreated':
      case 'SceneItemRemoved':
      case 'SceneItemEnableStateChanged':
        _fetchAudioInputs();
        break;
    }
  }

  void _handleRequestResponse(Map<String, dynamic> data) {
    final requestId = data['requestId'] as String?;
    if (requestId != null && _pendingRequests.containsKey(requestId)) {
      final completer = _pendingRequests.remove(requestId);
      completer?.complete(data);
    }
  }

  Future<Map<String, dynamic>> sendRequest(String requestType, [Map<String, dynamic>? requestData]) {
    final completer = Completer<Map<String, dynamic>>();
    final reqId = 'req_${++_requestIdCounter}';
    _pendingRequests[reqId] = completer;

    final reqPayload = <String, dynamic>{
      'requestType': requestType,
      'requestId': reqId,
    };
    if (requestData != null) {
      reqPayload['requestData'] = requestData;
    }

    final msg = {
      'op': 6,
      'd': reqPayload,
    };

    _sendRaw(msg);

    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        _pendingRequests.remove(reqId);
        return {'requestStatus': {'result': false, 'comment': 'Timed out'}};
      },
    );
  }

  void _sendRaw(Map<String, dynamic> json) {
    try {
      _channel?.sink.add(jsonEncode(json));
    } catch (e) {
      debugPrint('Error sending OBS packet: $e');
    }
  }

  // -------------------------------------------------------------
  // Data Fetching
  // -------------------------------------------------------------
  Future<void> _fetchInitialState() async {
    await Future.wait([
      _fetchScenes(),
      _fetchAudioInputs(),
      _fetchStats(),
      _fetchStreamAndRecordStatus(),
      _fetchStudioMode(),
    ]);
  }

  Future<void> _fetchStudioMode() async {
    try {
      final resp = await sendRequest('GetStudioModeEnabled');
      final d = resp['responseData'] as Map<String, dynamic>?;
      if (d != null) {
        final enabled = d['studioModeEnabled'] as bool? ?? false;
        _currentStats = _currentStats.copyWith(studioModeEnabled: enabled);
        if (enabled) {
          await _fetchCurrentPreviewScene();
        }
        onStatsUpdated?.call(_currentStats);
      }
    } catch (e) {
      debugPrint('Error fetching studio mode: $e');
    }
  }

  Future<void> _fetchCurrentPreviewScene() async {
    try {
      final resp = await sendRequest('GetCurrentPreviewScene');
      final d = resp['responseData'] as Map<String, dynamic>?;
      if (d != null) {
        final previewName = d['currentPreviewSceneName'] as String? ?? '';
        if (previewName.isNotEmpty) {
          _currentStats = _currentStats.copyWith(currentPreviewScene: previewName);
          _markScenesActive(preview: previewName);
          onStatsUpdated?.call(_currentStats);
        }
      }
    } catch (e) {
      debugPrint('Error fetching current preview scene: $e');
    }
  }

  Future<void> _fetchScenes() async {
    final resp = await sendRequest('GetSceneList');
    final d = resp['responseData'] as Map<String, dynamic>?;
    if (d != null) {
      final currentProg = d['currentProgramSceneName'] as String? ?? '';
      final currentPrev = d['currentPreviewSceneName'] as String? ?? currentProg;
      final rawScenes = d['scenes'] as List? ?? [];

      _currentScenes = rawScenes.map((s) {
        final name = s['sceneName'] as String;
        final idx = s['sceneIndex'] as int? ?? 0;
        return ObsScene(
          name: name,
          sceneIndex: idx,
          isProgram: name == currentProg,
          isPreview: name == currentPrev,
        );
      }).toList();

      _currentStats = _currentStats.copyWith(
        currentProgramScene: currentProg,
        currentPreviewScene: currentPrev,
      );

      onScenesUpdated?.call(_currentScenes, currentProg, currentPrev);
      onStatsUpdated?.call(_currentStats);
    }
  }

  Future<void> _fetchAudioInputs() async {
    try {
      // 1. Query Special / Global Inputs from OBS (Desktop Audio 1-2, Mic/Aux 1-4)
      final specialResp = await sendRequest('GetSpecialInputs');
      final specialData = specialResp['responseData'] as Map<String, dynamic>? ?? {};
      final specialInputNames = <String>[];
      for (final key in ['desktop1', 'desktop2', 'mic1', 'mic2', 'mic3', 'mic4']) {
        final val = specialData[key] as String?;
        if (val != null && val.isNotEmpty && !specialInputNames.contains(val)) {
          specialInputNames.add(val);
        }
      }

      // 2. Query scene items for active Program scene (and Preview if in Studio Mode)
      final activeSceneAudioNames = <String>{};
      final activeScenesToQuery = <String>{};
      if (_currentStats.currentProgramScene.isNotEmpty) {
        activeScenesToQuery.add(_currentStats.currentProgramScene);
      }
      if (_currentStats.studioModeEnabled && _currentStats.currentPreviewScene.isNotEmpty) {
        activeScenesToQuery.add(_currentStats.currentPreviewScene);
      }

      for (final sceneName in activeScenesToQuery) {
        try {
          final itemsResp = await sendRequest('GetSceneItemList', {'sceneName': sceneName});
          final items = (itemsResp['responseData']?['sceneItems'] as List?) ?? [];
          for (final item in items) {
            if (item is Map) {
              final sName = item['sourceName'] as String?;
              if (sName != null && sName.isNotEmpty) {
                activeSceneAudioNames.add(sName);
              }
            }
          }
        } catch (_) {}
      }

      // 3. Query all inputs from OBS
      final resp = await sendRequest('GetInputList');
      final d = resp['responseData'] as Map<String, dynamic>?;
      if (d == null) return;

      final rawInputs = d['inputs'] as List? ?? [];
      final Map<String, Map<String, dynamic>> rawInputMap = {};
      for (final inp in rawInputs) {
        if (inp is Map) {
          final name = inp['inputName'] as String?;
          if (name != null) {
            rawInputMap[name] = Map<String, dynamic>.from(inp);
          }
        }
      }

      // 4. Candidate names that belong to the OBS Audio Mixer:
      // Global Audio Devices + Sources in current active Program / Preview scene(s)
      final Set<String> candidateNames = {};
      if (specialInputNames.isNotEmpty || activeSceneAudioNames.isNotEmpty) {
        candidateNames.addAll(specialInputNames);
        candidateNames.addAll(activeSceneAudioNames);
      } else {
        candidateNames.addAll(rawInputMap.keys);
      }

      // 5. Query volume and mute ONLY for candidates that actually exist in rawInputs
      final List<ObsAudioSource> verifiedSources = [];

      await Future.wait(candidateNames.map((name) async {
        final inpInfo = rawInputMap[name];
        if (inpInfo == null) return;
        final kind = (inpInfo['inputKind'] as String?) ?? '';

        try {
          final volResp = await sendRequest('GetInputVolume', {'inputName': name});
          final volData = volResp['responseData'] as Map<String, dynamic>?;

          // CRITICAL: If volData is null or inputVolumeMul is null, OBS says this source has NO audio!
          // Filter it out so non-audio sources (images, text, color, non-audio video) never appear in the mixer.
          if (volData == null || volData['inputVolumeMul'] == null) {
            return;
          }

          final volMul = (volData['inputVolumeMul'] as num?)?.toDouble() ?? 1.0;
          final volDb = (volData['inputVolumeDb'] as num?)?.toDouble() ?? 0.0;

          final muteResp = await sendRequest('GetInputMute', {'inputName': name});
          final muteData = muteResp['responseData'] as Map<String, dynamic>?;
          final isMuted = muteData?['inputMuted'] as bool? ?? false;

          // Preserve existing live VU meter levels if already cached
          final existing = _currentAudioSources.firstWhere(
            (s) => s.name == name,
            orElse: () => ObsAudioSource(name: name),
          );

          verifiedSources.add(
            ObsAudioSource(
              name: name,
              inputKind: kind,
              volumeMul: volMul,
              volumeDb: volDb,
              muted: isMuted,
              leftLevel: existing.leftLevel,
              rightLevel: existing.rightLevel,
              peakHold: existing.peakHold,
            ),
          );
        } catch (_) {}
      }));

      // 6. Sort channels identically to OBS Studio Audio Mixer:
      // Special/Global audio devices first (in specialInputNames order),
      // then active scene audio sources.
      verifiedSources.sort((a, b) {
        final aSpecialIdx = specialInputNames.indexOf(a.name);
        final bSpecialIdx = specialInputNames.indexOf(b.name);

        if (aSpecialIdx != -1 && bSpecialIdx != -1) {
          return aSpecialIdx.compareTo(bSpecialIdx);
        }
        if (aSpecialIdx != -1) return -1;
        if (bSpecialIdx != -1) return 1;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _currentAudioSources = verifiedSources;
      onAudioSourcesUpdated?.call(_currentAudioSources);
    } catch (e) {
      debugPrint('Error fetching audio inputs: $e');
    }
  }

  Future<void> _fetchStats() async {
    final resp = await sendRequest('GetStats');
    final d = resp['responseData'] as Map<String, dynamic>?;
    if (d != null) {
      _currentStats = _currentStats.copyWith(
        activeFps: (d['activeFps'] as num?)?.toDouble() ?? 60.0,
        cpuUsage: (d['cpuUsage'] as num?)?.toDouble() ?? 0.0,
        memoryUsage: (d['memoryUsage'] as num?)?.toDouble() ?? 0.0,
        averageFrameTimeMs: (d['averageFrameTime'] as num?)?.toDouble() ?? 16.6,
        renderSkippedFrames: (d['renderSkippedFrames'] as num?)?.toInt() ?? 0,
        renderTotalFrames: (d['renderTotalFrames'] as num?)?.toInt() ?? 0,
        outputSkippedFrames: (d['outputSkippedFrames'] as num?)?.toInt() ?? 0,
        outputTotalFrames: (d['outputTotalFrames'] as num?)?.toInt() ?? 0,
      );
      onStatsUpdated?.call(_currentStats);
    }
  }

  Future<void> _fetchStreamAndRecordStatus() async {
    final streamResp = await sendRequest('GetStreamStatus');
    final sd = streamResp['responseData'] as Map<String, dynamic>?;
    if (sd != null) {
      final isStreaming = sd['outputActive'] as bool? ?? false;
      final timecode = (sd['outputDuration'] as num?)?.toInt() ?? 0;
      final kbits = (sd['outputKbitsPerSec'] as num?)?.toInt() ?? 6000;
      final dropped = (sd['outputSkippedFrames'] as num?)?.toInt() ?? 0;
      final total = (sd['outputTotalFrames'] as num?)?.toInt() ?? 1;

      _currentStats = _currentStats.copyWith(
        isStreaming: isStreaming,
        streamTimecodeSeconds: timecode ~/ 1000,
        kbitsPerSec: kbits,
        droppedFrames: dropped,
        totalStreamFrames: total,
      );
    }

    final recordResp = await sendRequest('GetRecordStatus');
    final rd = recordResp['responseData'] as Map<String, dynamic>?;
    if (rd != null) {
      final isRecording = rd['outputActive'] as bool? ?? false;
      final isPaused = rd['outputPaused'] as bool? ?? false;
      final timecode = (rd['outputDuration'] as num?)?.toInt() ?? 0;

      _currentStats = _currentStats.copyWith(
        isRecording: isRecording,
        isRecordingPaused: isPaused,
        recordTimecodeSeconds: timecode ~/ 1000,
      );
    }

    onStatsUpdated?.call(_currentStats);
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == ObsConnectionStatus.connected) {
        _fetchStats();
        _fetchStreamAndRecordStatus();
      }
    });
  }

  /// Starts adaptive high-cadence real-time preview streaming across ALL visible
  /// multiview scenes and active program/preview monitors simultaneously.
  void _startThumbnailPolling() {
    _previewLoopTimer?.cancel();
    _fetchRealtimeMultiviewPreviews(immediate: true);
  }

  /// Schedules the next real-time multiview preview capture.
  /// Uses an adaptive non-overlapping backpressure loop (~100ms gap) to guarantee
  /// fluid ~6-8 fps live preview across all multiview scenes with zero request pileup.
  void _scheduleNextPreviewFrame([int delayMs = 100]) {
    _previewLoopTimer?.cancel();
    if (_status != ObsConnectionStatus.connected) return;

    _previewLoopTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_status == ObsConnectionStatus.connected) {
        _fetchRealtimeMultiviewPreviews();
      }
    });
  }

  /// Fetches real-time screenshots for ALL multiview scenes (all visible scenes in grid
  /// plus Program and Preview) concurrently using Future.wait.
  Future<void> _fetchRealtimeMultiviewPreviews({bool immediate = false}) async {
    if (_status != ObsConnectionStatus.connected || _currentScenes.isEmpty) {
      return;
    }

    if (_isFetchingPreviews) {
      if (immediate) {
        _pendingImmediatePreview = true;
      }
      return;
    }

    _isFetchingPreviews = true;
    _previewLoopTimer?.cancel();

    try {
      final targets = <String>{};
      final program = _currentStats.currentProgramScene;
      final preview = _currentStats.currentPreviewScene;

      // 1. Always prioritize active Program & Preview scenes
      if (program.isNotEmpty) targets.add(program);
      if (_currentStats.studioModeEnabled && preview.isNotEmpty) targets.add(preview);

      // 2. Add all scenes displayed in the multiview wall (up to 8 scenes)
      for (final s in _currentScenes) {
        targets.add(s.name);
        if (targets.length >= 8) break;
      }

      // 3. If there are additional scenes beyond 8, include them in round-robin batches (up to 12 total targets)
      if (_currentScenes.length > 8) {
        final extraScenes = _currentScenes.skip(8).toList();
        if (extraScenes.isNotEmpty) {
          for (var i = 0; i < 4 && i < extraScenes.length; i++) {
            final idx = (_backgroundSceneOffset + i) % extraScenes.length;
            targets.add(extraScenes[idx].name);
          }
          _backgroundSceneOffset = (_backgroundSceneOffset + 4) % extraScenes.length;
        }
      }

      if (targets.isEmpty) return;

      final updatedMap = <String, String>{};
      bool anyUpdated = false;

      // Parallel batch screenshot fetch with optimized dimensions (280x158, quality 38)
      // for instant transmission, low latency, and fluid multi-tile live rendering.
      await Future.wait(targets.map((sceneName) async {
        try {
          final resp = await sendRequest('GetSourceScreenshot', {
            'sourceName': sceneName,
            'imageFormat': 'jpeg',
            'imageWidth': 280,
            'imageHeight': 158,
            'imageCompressionQuality': 38,
          });
          final d = resp['responseData'] as Map<String, dynamic>?;
          final imageData = d?['imageData'] as String?;
          if (imageData != null && imageData.isNotEmpty) {
            final base64Data = imageData.contains(',')
                ? imageData.split(',').last
                : imageData;
            updatedMap[sceneName] = base64Data;
            anyUpdated = true;
          }
        } catch (_) {}
      }));

      if (anyUpdated && _currentScenes.isNotEmpty) {
        _currentScenes = _currentScenes.map((s) {
          if (updatedMap.containsKey(s.name)) {
            return s.copyWith(thumbnailBase64: updatedMap[s.name]);
          }
          return s;
        }).toList();
        onThumbnailsUpdated?.call(List.from(_currentScenes));
      }
    } finally {
      _isFetchingPreviews = false;

      if (_status == ObsConnectionStatus.connected) {
        if (_pendingImmediatePreview) {
          _pendingImmediatePreview = false;
          _scheduleNextPreviewFrame(0);
        } else {
          _scheduleNextPreviewFrame(100);
        }
      }
    }
  }

  void _markScenesActive({String? program, String? preview}) {
    _currentScenes = _currentScenes.map((s) {
      return s.copyWith(
        isProgram: program != null ? s.name == program : s.isProgram,
        isPreview: preview != null ? s.name == preview : s.isPreview,
      );
    }).toList();
    onScenesUpdated?.call(
      _currentScenes,
      program ?? _currentStats.currentProgramScene,
      preview ?? _currentStats.currentPreviewScene,
    );
  }

  /// Converts an OBS linear volume multiplier (0.0–1.0+) to a 0.0–1.0 display
  /// fraction using the same dB scale OBS Studio uses in its audio mixer:
  ///   -60 dB (or silence) → 0.0 (bottom of meter)
  ///    0 dB               → 1.0 (top of meter)
  /// Uses a linear-in-dB mapping, which matches OBS's VU meter tick placement.
  double _mulToDisplayFrac(double mul) {
    if (mul <= 0.0) return 0.0;
    const double minDb = -60.0;
    const double maxDb = 0.0;
    final db = 20.0 * math.log(mul) / math.ln10; // 20 * log10(mul)
    final clamped = db.clamp(minDb, maxDb);
    return (clamped - minDb) / (maxDb - minDb);
  }

  void _updateAudioSource(
    String name, {
    double? volumeMul,
    double? volumeDb,
    bool? muted,
    double? leftLevel,
    double? rightLevel,
  }) {
    final idx = _currentAudioSources.indexWhere((s) => s.name == name);
    if (idx != -1) {
      final s = _currentAudioSources[idx];
      final newLeft = leftLevel ?? s.leftLevel;
      final newRight = rightLevel ?? s.rightLevel;
      final peak = math.max(newLeft, newRight);
      final newPeakHold = peak > s.peakHold ? peak : math.max(0.0, s.peakHold - 0.05);

      _currentAudioSources[idx] = s.copyWith(
        volumeMul: volumeMul ?? s.volumeMul,
        volumeDb: volumeDb ?? s.volumeDb,
        muted: muted ?? s.muted,
        leftLevel: newLeft,
        rightLevel: newRight,
        peakHold: newPeakHold,
      );
      onAudioSourcesUpdated?.call(List.from(_currentAudioSources));
    }
  }

  // -------------------------------------------------------------
  // Public OBS Operations
  // -------------------------------------------------------------
  @override
  Future<void> setCurrentProgramScene(String sceneName) async {
    await sendRequest('SetCurrentProgramScene', {'sceneName': sceneName});
    _fetchRealtimeMultiviewPreviews(immediate: true);
  }

  @override
  Future<void> setCurrentPreviewScene(String sceneName) async {
    await sendRequest('SetCurrentPreviewScene', {'sceneName': sceneName});
    _fetchRealtimeMultiviewPreviews(immediate: true);
  }

  @override
  Future<void> triggerStudioTransition([String transitionName = 'Cut']) async {
    try {
      if (transitionName.isNotEmpty) {
        await sendRequest('SetCurrentSceneTransition', {'transitionName': transitionName});
      }
    } catch (_) {}
    await sendRequest('TriggerStudioModeTransition');
    _fetchRealtimeMultiviewPreviews(immediate: true);
  }

  @override
  Future<void> setTransitionDuration(int durationMs) async {
    if (_status != ObsConnectionStatus.connected) return;
    try {
      await sendRequest('SetCurrentSceneTransitionDuration', {
        'transitionDuration': durationMs,
      });
    } catch (e) {
      debugPrint('Error setting transition duration: $e');
    }
  }

  @override
  Future<void> setTBarPosition(double position, {bool release = true}) async {
    if (_status != ObsConnectionStatus.connected) return;
    try {
      final clamped = position.clamp(0.0, 1.0);
      await sendRequest('SetTBarPosition', {
        'position': clamped,
        'release': release,
      });
      if (release && clamped >= 0.95) {
        // Guarantee OBS completes the Studio Mode transition and swaps preview/program
        await sendRequest('TriggerStudioModeTransition');
        _fetchRealtimeMultiviewPreviews(immediate: true);
      }
    } catch (e) {
      debugPrint('Error setting T-Bar position: $e');
    }
  }

  @override
  Future<void> toggleStudioMode() async {
    final nextState = !_currentStats.studioModeEnabled;
    await sendRequest('SetStudioModeEnabled', {'studioModeEnabled': nextState});
  }

  @override
  Future<void> setInputVolume(String inputName, double volumeMul) async {
    await sendRequest('SetInputVolume', {
      'inputName': inputName,
      'inputVolumeMul': volumeMul,
    });
  }

  @override
  Future<void> toggleInputMute(String inputName) async {
    await sendRequest('ToggleInputMute', {'inputName': inputName});
  }

  @override
  Future<void> toggleStream() async {
    await sendRequest('ToggleStream');
  }

  @override
  Future<void> toggleRecord() async {
    await sendRequest('ToggleRecord');
  }

  @override
  Future<void> saveReplayBuffer() async {
    await sendRequest('SaveReplayBuffer');
  }

  @override
  Future<void> openMultiviewProjector() async {
    // Disabled to prevent projector windows from spamming or piling up on the host OBS machine.
  }

  // -------------------------------------------------------------
  // Cleanup & Disconnect
  // -------------------------------------------------------------
  @override
  void disconnect({bool notify = true}) {
    _userExplicitlyDisconnected = true;
    _reconnectTimer?.cancel();
    _disconnectInternal();
    if (notify) {
      _updateStatus(ObsConnectionStatus.disconnected);
    }
  }

  void _scheduleReconnect() {
    if (_userExplicitlyDisconnected) return;
    if (!autoReconnect) return;
    if (_lastHost == null || _lastPort == null) return;
    if (_status == ObsConnectionStatus.connected) return;

    _reconnectTimer?.cancel();
    // Exponential backoff: 2s, 4s, 8s, 10s max
    final delay = math.min(10, 2 * (1 << math.min(_reconnectAttempts, 2)));
    _reconnectAttempts++;
    debugPrint('OBS WebSocket auto-reconnect scheduled in $delay s (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (!_userExplicitlyDisconnected &&
          _status != ObsConnectionStatus.connected &&
          _status != ObsConnectionStatus.connecting) {
        connect(
          host: _lastHost!,
          port: _lastPort!,
          password: _lastPassword ?? '',
        );
      }
    });
  }

  void _disconnectInternal() {
    _connectionTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _statsTimer?.cancel();
    _previewLoopTimer?.cancel();
    _isFetchingPreviews = false;
    _pendingImmediatePreview = false;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _pendingRequests.clear();
  }

  void _updateStatus(ObsConnectionStatus status, {String? error}) {
    _status = status;
    onStatusChanged?.call(status, error);
  }
}
