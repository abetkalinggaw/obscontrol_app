enum MacroType {
  switchScene,
  toggleMute,
  toggleStream,
  toggleRecord,
  saveReplay,
  studioTransition,
  toggleSourceVisibility,
  screenshot,
}

class MacroAction {
  final String id;
  final String title;
  final String subtitle;
  final String iconName; // e.g. "mic", "videocam", "play", "refresh", "camera", "bolt"
  final int colorValue; // e.g. 0xFFFF3B30
  final MacroType type;
  final String target; // scene name or input name or transition name

  const MacroAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.colorValue,
    required this.type,
    required this.target,
  });

  MacroAction copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? iconName,
    int? colorValue,
    MacroType? type,
    String? target,
  }) {
    return MacroAction(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      target: target ?? this.target,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'iconName': iconName,
    'colorValue': colorValue,
    'type': type.name,
    'target': target,
  };

  factory MacroAction.fromJson(Map<String, dynamic> json) {
    return MacroAction(
      id: json['id'] as String? ?? 'macro_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Button',
      subtitle: json['subtitle'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'bolt',
      colorValue: json['colorValue'] as int? ?? 0xFF1E1E1E,
      type: MacroType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MacroType.switchScene,
      ),
      target: json['target'] as String? ?? '',
    );
  }
}
