class ObsStats {
  final double activeFps;
  final double cpuUsage;
  final double memoryUsage;
  final double averageFrameTimeMs;
  final int renderTotalFrames;
  final int renderSkippedFrames;
  final int outputTotalFrames;
  final int outputSkippedFrames;
  
  // Streaming state
  final bool isStreaming;
  final int streamTimecodeSeconds;
  final int kbitsPerSec;
  final int droppedFrames;
  final int totalStreamFrames;

  // Recording state
  final bool isRecording;
  final bool isRecordingPaused;
  final int recordTimecodeSeconds;

  // Replay Buffer state
  final bool isReplayBufferActive;

  // Studio Mode
  final bool studioModeEnabled;
  final String currentProgramScene;
  final String currentPreviewScene;

  const ObsStats({
    this.activeFps = 60.0,
    this.cpuUsage = 4.2,
    this.memoryUsage = 180.5,
    this.averageFrameTimeMs = 16.6,
    this.renderTotalFrames = 0,
    this.renderSkippedFrames = 0,
    this.outputTotalFrames = 0,
    this.outputSkippedFrames = 0,
    this.isStreaming = false,
    this.streamTimecodeSeconds = 0,
    this.kbitsPerSec = 6000,
    this.droppedFrames = 0,
    this.totalStreamFrames = 0,
    this.isRecording = false,
    this.isRecordingPaused = false,
    this.recordTimecodeSeconds = 0,
    this.isReplayBufferActive = false,
    this.studioModeEnabled = false,
    this.currentProgramScene = '',
    this.currentPreviewScene = '',
  });

  ObsStats copyWith({
    double? activeFps,
    double? cpuUsage,
    double? memoryUsage,
    double? averageFrameTimeMs,
    int? renderTotalFrames,
    int? renderSkippedFrames,
    int? outputTotalFrames,
    int? outputSkippedFrames,
    bool? isStreaming,
    int? streamTimecodeSeconds,
    int? kbitsPerSec,
    int? droppedFrames,
    int? totalStreamFrames,
    bool? isRecording,
    bool? isRecordingPaused,
    int? recordTimecodeSeconds,
    bool? isReplayBufferActive,
    bool? studioModeEnabled,
    String? currentProgramScene,
    String? currentPreviewScene,
  }) {
    return ObsStats(
      activeFps: activeFps ?? this.activeFps,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memoryUsage: memoryUsage ?? this.memoryUsage,
      averageFrameTimeMs: averageFrameTimeMs ?? this.averageFrameTimeMs,
      renderTotalFrames: renderTotalFrames ?? this.renderTotalFrames,
      renderSkippedFrames: renderSkippedFrames ?? this.renderSkippedFrames,
      outputTotalFrames: outputTotalFrames ?? this.outputTotalFrames,
      outputSkippedFrames: outputSkippedFrames ?? this.outputSkippedFrames,
      isStreaming: isStreaming ?? this.isStreaming,
      streamTimecodeSeconds: streamTimecodeSeconds ?? this.streamTimecodeSeconds,
      kbitsPerSec: kbitsPerSec ?? this.kbitsPerSec,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      totalStreamFrames: totalStreamFrames ?? this.totalStreamFrames,
      isRecording: isRecording ?? this.isRecording,
      isRecordingPaused: isRecordingPaused ?? this.isRecordingPaused,
      recordTimecodeSeconds: recordTimecodeSeconds ?? this.recordTimecodeSeconds,
      isReplayBufferActive: isReplayBufferActive ?? this.isReplayBufferActive,
      studioModeEnabled: studioModeEnabled ?? this.studioModeEnabled,
      currentProgramScene: currentProgramScene ?? this.currentProgramScene,
      currentPreviewScene: currentPreviewScene ?? this.currentPreviewScene,
    );
  }
}
