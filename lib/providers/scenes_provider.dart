import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/broadcast_service.dart';
import '../core/services/storage_service.dart';
import '../models/obs_scene.dart';
import 'obs_provider.dart';
import 'settings_provider.dart';

class ScenesState {
  final List<ObsScene> scenes;
  final String activeProgramScene;
  final String activePreviewScene;
  final List<String> customSceneOrder;
  final bool isLocked;
  final String? selectedSceneName;

  const ScenesState({
    this.scenes = const [],
    this.activeProgramScene = '',
    this.activePreviewScene = '',
    this.customSceneOrder = const [],
    this.isLocked = false,
    this.selectedSceneName,
  });

  ScenesState copyWith({
    List<ObsScene>? scenes,
    String? activeProgramScene,
    String? activePreviewScene,
    List<String>? customSceneOrder,
    bool? isLocked,
    String? selectedSceneName,
    bool clearSelectedScene = false,
  }) {
    return ScenesState(
      scenes: scenes ?? this.scenes,
      activeProgramScene: activeProgramScene ?? this.activeProgramScene,
      activePreviewScene: activePreviewScene ?? this.activePreviewScene,
      customSceneOrder: customSceneOrder ?? this.customSceneOrder,
      isLocked: isLocked ?? this.isLocked,
      selectedSceneName: clearSelectedScene ? null : (selectedSceneName ?? this.selectedSceneName),
    );
  }
}

class ScenesNotifier extends Notifier<ScenesState> {
  BroadcastService get _service => ref.read(broadcastServiceProvider);

  StorageService? get _storage {
    try {
      return ref.read(storageServiceProvider);
    } catch (_) {
      return null;
    }
  }

  List<ObsScene> _applyOrder(List<ObsScene> rawScenes, List<String> order) {
    if (order.isEmpty) return rawScenes;
    final map = {for (final s in rawScenes) s.name: s};
    final ordered = <ObsScene>[];
    for (final name in order) {
      if (map.containsKey(name)) {
        ordered.add(map.remove(name)!);
      }
    }
    ordered.addAll(map.values);
    return ordered;
  }

  @override
  ScenesState build() {
    final service = ref.watch(broadcastServiceProvider);
    final storage = _storage;
    final initialOrder = storage?.getSceneOrder() ?? const <String>[];
    final initialLocked = storage?.getMultiviewLocked() ?? false;

    service.onScenesUpdated = (scenes, program, preview) {
      final currentOrder = state.customSceneOrder.isNotEmpty ? state.customSceneOrder : initialOrder;
      final ordered = _applyOrder(scenes, currentOrder);
      state = state.copyWith(
        scenes: ordered,
        activeProgramScene: program,
        activePreviewScene: preview,
      );
    };

    service.onThumbnailsUpdated = (scenes) {
      final currentOrder = state.customSceneOrder.isNotEmpty ? state.customSceneOrder : initialOrder;
      final ordered = _applyOrder(scenes, currentOrder);
      state = state.copyWith(scenes: ordered);
    };

    return ScenesState(
      customSceneOrder: initialOrder,
      isLocked: initialLocked,
    );
  }

  void reorderScenes(int oldIndex, int newIndex) {
    if (state.isLocked) return;
    if (oldIndex < 0 || oldIndex >= state.scenes.length) return;
    if (newIndex < 0 || newIndex >= state.scenes.length) return;
    if (oldIndex == newIndex) return;

    final updated = List<ObsScene>.from(state.scenes);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    final newOrder = updated.map((s) => s.name).toList();

    state = state.copyWith(
      scenes: updated,
      customSceneOrder: newOrder,
    );
    _storage?.setSceneOrder(newOrder);
  }

  void toggleMultiviewLock() {
    final next = !state.isLocked;
    state = state.copyWith(isLocked: next);
    _storage?.setMultiviewLocked(next);
  }

  void selectSceneForArrangement(String sceneName) {
    if (state.isLocked) return;
    if (state.selectedSceneName == sceneName) {
      state = state.copyWith(clearSelectedScene: true);
    } else {
      state = state.copyWith(selectedSceneName: sceneName);
    }
  }

  void swapSelectedSceneWith(int targetIndex) {
    if (state.isLocked) return;
    final selected = state.selectedSceneName;
    if (selected == null) return;
    final sourceIndex = state.scenes.indexWhere((s) => s.name == selected);
    if (sourceIndex != -1 && sourceIndex != targetIndex) {
      reorderScenes(sourceIndex, targetIndex);
    }
    state = state.copyWith(clearSelectedScene: true);
  }

  Future<void> selectProgramScene(String sceneName) async {
    await _service.setCurrentProgramScene(sceneName);
  }

  Future<void> selectPreviewScene(String sceneName) async {
    await _service.setCurrentPreviewScene(sceneName);
  }

  Future<void> triggerTransition([String transitionName = '']) async {
    await _service.triggerStudioTransition(transitionName);
  }

  Future<void> setTransitionDuration(int durationMs) async {
    await ref.read(transitionDurationProvider.notifier).setDuration(durationMs);
  }

  Future<void> setTBarPosition(double position, {bool release = true}) async {
    await _service.setTBarPosition(position, release: release);
  }

  Future<void> openMultiviewProjector() async {
    await _service.openMultiviewProjector();
  }
}

final scenesProvider = NotifierProvider<ScenesNotifier, ScenesState>(ScenesNotifier.new);

class TransitionDurationNotifier extends Notifier<int> {
  StorageService? get _storage {
    try {
      return ref.read(storageServiceProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  int build() {
    return _storage?.getTransitionDuration() ?? 300;
  }

  Future<void> setDuration(int durationMs) async {
    state = durationMs;
    await _storage?.setTransitionDuration(durationMs);
    try {
      final service = ref.read(broadcastServiceProvider);
      await service.setTransitionDuration(durationMs);
    } catch (_) {}
  }
}

final transitionDurationProvider =
    NotifierProvider<TransitionDurationNotifier, int>(TransitionDurationNotifier.new);

class GridCountNotifier extends Notifier<int> {
  @override
  int build() => 8;

  void setCount(int count) {
    if (count == 4 || count == 8) {
      state = count;
    }
  }
}

final gridCountProvider = NotifierProvider<GridCountNotifier, int>(GridCountNotifier.new);

