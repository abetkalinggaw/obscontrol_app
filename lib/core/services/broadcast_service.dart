import '../../models/connection_state.dart';
import '../../models/obs_audio_source.dart';
import '../../models/obs_scene.dart';
import '../../models/obs_stats.dart';

typedef StatusCallback = void Function(
  ObsConnectionStatus status,
  String? error,
);
typedef StatsCallback = void Function(ObsStats stats);
typedef ScenesCallback = void Function(
  List<ObsScene> scenes,
  String activeProgram,
  String activePreview,
);
typedef AudioSourcesCallback = void Function(List<ObsAudioSource> sources);
typedef ThumbnailsCallback = void Function(List<ObsScene> scenes);

/// Common interface for streaming broadcast controllers (OBS Studio, Streamlabs, vMix).
abstract class BroadcastService {
  ObsConnectionStatus get status;

  StatusCallback? get onStatusChanged;
  set onStatusChanged(StatusCallback? callback);

  StatsCallback? get onStatsUpdated;
  set onStatsUpdated(StatsCallback? callback);

  ScenesCallback? get onScenesUpdated;
  set onScenesUpdated(ScenesCallback? callback);

  AudioSourcesCallback? get onAudioSourcesUpdated;
  set onAudioSourcesUpdated(AudioSourcesCallback? callback);

  ThumbnailsCallback? get onThumbnailsUpdated;
  set onThumbnailsUpdated(ThumbnailsCallback? callback);

  Future<void> connect({
    required String host,
    required int port,
    required String password,
  });

  void disconnect({bool notify = true});

  Future<void> setCurrentProgramScene(String sceneName);
  Future<void> setCurrentPreviewScene(String sceneName);
  Future<void> triggerStudioTransition([String transitionName = 'Cut']);
  Future<void> setTransitionDuration(int durationMs);
  Future<void> setTBarPosition(double position, {bool release = true});
  Future<void> toggleStudioMode();
  Future<void> setInputVolume(String inputName, double volumeMul);
  Future<void> toggleInputMute(String inputName);
  Future<void> toggleStream();
  Future<void> toggleRecord();
  Future<void> saveReplayBuffer();
  Future<void> openMultiviewProjector();
}
