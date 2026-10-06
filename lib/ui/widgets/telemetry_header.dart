import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../models/connection_state.dart';
import '../../models/obs_stats.dart';

/// Flat Precision Telemetry & Status Header.
///
/// Features clean solid dark panels, crisp hairline borders,
/// high-contrast status cues, and clear monospaced telemetry data.
class TelemetryHeader extends StatelessWidget {
  final ObsConnectionStatus connectionStatus;
  final ObsStats stats;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onOpenSettings;
  final VoidCallback onToggleStream;
  final VoidCallback onToggleRecord;
  final VoidCallback? onSaveReplay;
  final bool isCollapsed;

  const TelemetryHeader({
    super.key,
    required this.connectionStatus,
    required this.stats,
    required this.onToggleCollapse,
    this.onOpenSettings,
    required this.onToggleStream,
    required this.onToggleRecord,
    this.onSaveReplay,
    this.isCollapsed = false,
  });

  Color _getStatusColor() {
    switch (connectionStatus) {
      case ObsConnectionStatus.connected:
        return AppColors.connectedGreen;
      case ObsConnectionStatus.connecting:
        return AppColors.previewAmber;
      case ObsConnectionStatus.error:
        return AppColors.liveRed;
      case ObsConnectionStatus.disconnected:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText() {
    switch (connectionStatus) {
      case ObsConnectionStatus.connected:
        return 'CONNECTED';
      case ObsConnectionStatus.connecting:
        return 'CONNECTING';
      case ObsConnectionStatus.error:
        return 'ERROR';
      case ObsConnectionStatus.disconnected:
        return 'OFFLINE';
    }
  }

  Widget _buildStatusIndicator(Color statusColor) {
    return IconButton(
      onPressed: onOpenSettings,
      tooltip: 'Status: ${_getStatusText()}',
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.50),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryBox(bool isLive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.liveRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              Formatters.formatDuration(stats.streamTimecodeSeconds),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.liveRed,
              ),
            ),
          ] else ...[
            Text(
              'STANDBY',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              '|',
              style: TextStyle(color: AppColors.surfaceBorderBold, fontSize: 11),
            ),
          ),
          Text(
            '${Formatters.formatFps(stats.activeFps)} FPS',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (stats.cpuUsage > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7),
              child: Text(
                '|',
                style: TextStyle(color: AppColors.surfaceBorderBold, fontSize: 11),
              ),
            ),
            Text(
              'CPU ${stats.cpuUsage.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamButton(bool isLive) {
    return Semantics(
      button: true,
      label: isLive ? 'Stop live stream' : 'Start live stream',
      child: InkWell(
        onTap: () {
          Haptics.medium();
          onToggleStream();
        },
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          decoration: BoxDecoration(
            color: isLive ? AppColors.liveRed : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isLive ? AppColors.liveRed : AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                size: 16,
                color: isLive ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isLive ? 'STREAMING' : 'START STREAM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isLive ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton(bool isRecording) {
    return Semantics(
      button: true,
      label: isRecording ? 'Stop recording' : 'Start recording',
      child: InkWell(
        onTap: () {
          Haptics.medium();
          onToggleRecord();
        },
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          decoration: BoxDecoration(
            color: isRecording ? AppColors.liveRed : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isRecording ? AppColors.liveRed : AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isRecording ? AppColors.textPrimary : AppColors.liveRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isRecording
                      ? Formatters.formatDuration(stats.recordTimecodeSeconds)
                      : 'RECORD',
                  style: TextStyle(
                    fontFamily: isRecording ? 'monospace' : null,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isRecording ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton() {
    return IconButton(
      onPressed: () {
        Haptics.selection();
        onToggleCollapse();
      },
      tooltip: isCollapsed
          ? 'Show Broadcast Controls'
          : 'Hide Broadcast Controls',
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: 1.0,
          ),
        ),
        child: Center(
          child: AnimatedRotation(
            turns: isCollapsed ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isLive = stats.isStreaming;
    final isRecording = stats.isRecording;

    return RepaintBoundary(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            bottom: BorderSide(
              color: AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Bar: Status dot | Center Telemetry | Collapse Chevron
                SizedBox(
                  height: 38,
                  child: Row(
                    children: [
                      _buildStatusIndicator(statusColor),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildTelemetryBox(isLive),
                            ),
                          ),
                        ),
                      ),
                      _buildCollapseButton(),
                    ],
                  ),
                ),

                // Collapsible Bottom Action Row (Stream, Record)
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  firstCurve: Curves.easeOut,
                  secondCurve: Curves.easeIn,
                  crossFadeState: isCollapsed
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStreamButton(isLive),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRecordButton(isRecording),
                        ),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox(width: double.infinity, height: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
