import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/transition_mix_provider.dart';
import 'scene_preview_box.dart';

/// PROGRAM monitor that renders transitions like OBS: while the T-Bar is
/// dragged (or a FADE runs) the incoming Preview scene cross-fades over the
/// outgoing Program scene.
///
/// The outgoing/incoming images are snapshotted when a transition begins, so
/// OBS updating Program mid-transition doesn't make the monitor jump.
class ProgramMonitor extends ConsumerStatefulWidget {
  final String programScene;
  final String? programThumbnail;
  final String previewScene;
  final String? previewThumbnail;
  final double aspectRatio;
  final bool showTallyBanner;

  const ProgramMonitor({
    super.key,
    required this.programScene,
    required this.programThumbnail,
    required this.previewScene,
    required this.previewThumbnail,
    this.aspectRatio = 16 / 9,
    this.showTallyBanner = true,
  });

  @override
  ConsumerState<ProgramMonitor> createState() => _ProgramMonitorState();
}

class _ProgramMonitorState extends ConsumerState<ProgramMonitor> {
  int? _capturedGen;
  String _fromName = '';
  String? _fromThumb;
  String _toName = '';
  String? _toThumb;

  // Decoding base64 every frame of a fade is expensive; cache bytes.
  String? _toThumbKey;
  Widget? _toImage;

  void _capture(int gen) {
    _capturedGen = gen;
    _fromName = widget.programScene;
    _fromThumb = widget.programThumbnail;
    _toName = widget.previewScene;
    _toThumb = widget.previewThumbnail;
  }

  Widget? _incomingImage() {
    final thumb = _toThumb;
    if (thumb == null || thumb.isEmpty) return null;
    if (_toThumbKey != thumb) {
      _toThumbKey = thumb;
      _toImage = Image.memory(
        base64Decode(thumb),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return _toImage;
  }

  @override
  Widget build(BuildContext context) {
    final mix = ref.watch(transitionMixProvider);

    if (!mix.active) {
      _capturedGen = null;
      return ScenePreviewBox(
        sceneName: widget.programScene.isNotEmpty ? widget.programScene : 'No Program',
        isProgram: true,
        thumbnailBase64: widget.programThumbnail,
        aspectRatio: widget.aspectRatio,
        showTallyBanner: widget.showTallyBanner,
      );
    }

    if (_capturedGen != mix.generation) _capture(mix.generation);

    final incoming = _incomingImage();
    final p = mix.progress.clamp(0.0, 1.0);
    final name = p >= 0.5 ? _toName : _fromName;

    return ScenePreviewBox(
      sceneName: name.isNotEmpty ? name : 'No Program',
      isProgram: true,
      thumbnailBase64: _fromThumb,
      aspectRatio: widget.aspectRatio,
      showTallyBanner: widget.showTallyBanner,
      overlay: Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: p,
            child: incoming ?? const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
  }
}
