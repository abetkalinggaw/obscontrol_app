import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/broadcast_service.dart';
import '../core/services/storage_service.dart';
import '../models/obs_audio_source.dart';
import 'obs_provider.dart';
import 'settings_provider.dart';

enum AudioMixerViewMode {
  vertical,
  horizontal,
}

class AudioViewModeNotifier extends Notifier<AudioMixerViewMode> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  AudioMixerViewMode build() {
    final storage = ref.watch(storageServiceProvider);
    final saved = storage.getAudioMixerViewMode();
    if (saved == 'horizontal') return AudioMixerViewMode.horizontal;
    return AudioMixerViewMode.vertical;
  }

  void setMode(AudioMixerViewMode mode) {
    if (state != mode) {
      state = mode;
      _storage.setAudioMixerViewMode(mode == AudioMixerViewMode.horizontal ? 'horizontal' : 'vertical');
    }
  }

  void toggle() {
    setMode(state == AudioMixerViewMode.vertical ? AudioMixerViewMode.horizontal : AudioMixerViewMode.vertical);
  }
}

final audioViewModeProvider = NotifierProvider<AudioViewModeNotifier, AudioMixerViewMode>(AudioViewModeNotifier.new);

class HiddenAudioChannelsNotifier extends Notifier<Set<String>> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  Set<String> build() {
    final storage = ref.watch(storageServiceProvider);
    return storage.getHiddenAudioChannels().toSet();
  }

  void toggleChannel(String channelName) {
    final updated = Set<String>.from(state);
    if (updated.contains(channelName)) {
      updated.remove(channelName);
    } else {
      updated.add(channelName);
    }
    state = updated;
    _storage.setHiddenAudioChannels(updated.toList());
  }

  void showAll() {
    state = {};
    _storage.setHiddenAudioChannels([]);
  }

  void hideAll(List<String> allChannelNames) {
    final all = allChannelNames.toSet();
    state = all;
    _storage.setHiddenAudioChannels(all.toList());
  }

  void setHiddenChannels(Set<String> hidden) {
    state = hidden;
    _storage.setHiddenAudioChannels(hidden.toList());
  }
}

final hiddenAudioChannelsProvider =
    NotifierProvider<HiddenAudioChannelsNotifier, Set<String>>(
        HiddenAudioChannelsNotifier.new);

class AudioState {
  final List<ObsAudioSource> sources;

  const AudioState({
    this.sources = const [],
  });

  AudioState copyWith({
    List<ObsAudioSource>? sources,
  }) {
    return AudioState(
      sources: sources ?? this.sources,
    );
  }
}

class AudioNotifier extends Notifier<AudioState> {
  BroadcastService get _service => ref.read(broadcastServiceProvider);

  @override
  AudioState build() {
    final service = ref.watch(broadcastServiceProvider);
    service.onAudioSourcesUpdated = (sources) {
      state = state.copyWith(sources: sources);
    };
    return const AudioState();
  }

  Future<void> setVolume(String name, double volumeMul) async {
    await _service.setInputVolume(name, volumeMul);
  }

  Future<void> toggleMute(String name) async {
    await _service.toggleInputMute(name);
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(AudioNotifier.new);

