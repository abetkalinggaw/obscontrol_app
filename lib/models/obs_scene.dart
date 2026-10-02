class ObsSceneItem {
  final int sceneItemId;
  final String sourceName;
  final String sourceType;
  final bool sceneItemEnabled;

  const ObsSceneItem({
    required this.sceneItemId,
    required this.sourceName,
    required this.sourceType,
    required this.sceneItemEnabled,
  });

  ObsSceneItem copyWith({
    int? sceneItemId,
    String? sourceName,
    String? sourceType,
    bool? sceneItemEnabled,
  }) {
    return ObsSceneItem(
      sceneItemId: sceneItemId ?? this.sceneItemId,
      sourceName: sourceName ?? this.sourceName,
      sourceType: sourceType ?? this.sourceType,
      sceneItemEnabled: sceneItemEnabled ?? this.sceneItemEnabled,
    );
  }

  factory ObsSceneItem.fromJson(Map<String, dynamic> json) {
    return ObsSceneItem(
      sceneItemId: json['sceneItemId'] as int? ?? 0,
      sourceName: json['sourceName'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'input',
      sceneItemEnabled: json['sceneItemEnabled'] as bool? ?? true,
    );
  }
}

class ObsScene {
  final String name;
  final int sceneIndex;
  final bool isProgram;
  final bool isPreview;
  final List<ObsSceneItem> items;
  final String? thumbnailBase64;

  const ObsScene({
    required this.name,
    required this.sceneIndex,
    this.isProgram = false,
    this.isPreview = false,
    this.items = const [],
    this.thumbnailBase64,
  });

  ObsScene copyWith({
    String? name,
    int? sceneIndex,
    bool? isProgram,
    bool? isPreview,
    List<ObsSceneItem>? items,
    String? thumbnailBase64,
  }) {
    return ObsScene(
      name: name ?? this.name,
      sceneIndex: sceneIndex ?? this.sceneIndex,
      isProgram: isProgram ?? this.isProgram,
      isPreview: isPreview ?? this.isPreview,
      items: items ?? this.items,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
    );
  }
}
