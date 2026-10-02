class ObsAudioSource {
  final String name;
  final String inputKind;
  final double volumeMul; // Linear 0.0 - 1.0
  final double volumeDb;  // dB value (e.g. -6.0)
  final bool muted;
  final double leftLevel;  // 0.0 - 1.0 peak
  final double rightLevel; // 0.0 - 1.0 peak
  final double peakHold;   // Peak indicator

  const ObsAudioSource({
    required this.name,
    this.inputKind = 'wasapi_input_capture',
    this.volumeMul = 1.0,
    this.volumeDb = 0.0,
    this.muted = false,
    this.leftLevel = 0.0,
    this.rightLevel = 0.0,
    this.peakHold = 0.0,
  });

  ObsAudioSource copyWith({
    String? name,
    String? inputKind,
    double? volumeMul,
    double? volumeDb,
    bool? muted,
    double? leftLevel,
    double? rightLevel,
    double? peakHold,
  }) {
    return ObsAudioSource(
      name: name ?? this.name,
      inputKind: inputKind ?? this.inputKind,
      volumeMul: volumeMul ?? this.volumeMul,
      volumeDb: volumeDb ?? this.volumeDb,
      muted: muted ?? this.muted,
      leftLevel: leftLevel ?? this.leftLevel,
      rightLevel: rightLevel ?? this.rightLevel,
      peakHold: peakHold ?? this.peakHold,
    );
  }
}
