import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/connection_state.dart';

/// Modal dialog providing step-by-step connection guides for OBS Studio,
/// Streamlabs, and vMix, along with local network troubleshooting.
class ConnectionGuideDialog extends StatefulWidget {
  final StreamingSoftware? initialSoftware;

  const ConnectionGuideDialog({super.key, this.initialSoftware});

  static Future<void> show(
    BuildContext context, {
    StreamingSoftware? initialSoftware,
  }) {
    Haptics.selection();
    return showDialog(
      context: context,
      builder: (ctx) => ConnectionGuideDialog(initialSoftware: initialSoftware),
    );
  }

  @override
  State<ConnectionGuideDialog> createState() => _ConnectionGuideDialogState();
}

class _ConnectionGuideDialogState extends State<ConnectionGuideDialog> {
  late int _selectedTab; // 0: OBS, 1: SLOBS, 2: vMix, 3: Network Tips

  @override
  void initState() {
    super.initState();
    if (widget.initialSoftware == StreamingSoftware.streamlabs) {
      _selectedTab = 1;
    } else if (widget.initialSoftware == StreamingSoftware.vmix) {
      _selectedTab = 2;
    } else {
      _selectedTab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.surfaceBorderBold, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'HOW TO CONNECT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.surfaceBorder,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, 'OBS Studio'),
                    _buildTabButton(1, 'Streamlabs'),
                    _buildTabButton(2, 'vMix'),
                    _buildTabButton(3, 'Network'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildCurrentTabContent(),
              ),
            ),

            // Bottom Action
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.surfaceBorder, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'GOT IT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Haptics.selection();
          setState(() => _selectedTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentCyan.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: isSelected
                ? Border.all(color: AppColors.accentCyan, width: 1.2)
                : Border.all(color: Colors.transparent, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected
                  ? AppColors.accentCyan
                  : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildObsGuide();
      case 1:
        return _buildStreamlabsGuide();
      case 2:
        return _buildVmixGuide();
      case 3:
      default:
        return _buildNetworkGuide();
    }
  }

  Widget _buildObsGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(
          icon: Icons.info_outline_rounded,
          color: AppColors.accentCyan,
          title: 'Built-in WebSocket v5',
          description: 'OBS Studio v28.0 and above includes WebSocket server support natively without installing any 3rd-party plugins.',
        ),
        const SizedBox(height: 14),
        _buildStep(
          stepNumber: '1',
          title: 'Open OBS Studio on your PC or Mac',
          detail: 'Make sure your computer and mobile device are connected to the same Wi-Fi network.',
        ),
        _buildStep(
          stepNumber: '2',
          title: 'Navigate to WebSocket Server Settings',
          detail: 'In the top menu bar, click on:',
          pillHighlight: 'Tools  >  WebSocket Server Settings',
        ),
        _buildStep(
          stepNumber: '3',
          title: 'Enable the WebSocket Server',
          detail: 'Check the box labeled "Enable WebSocket server". Default Server Port is 4455.',
          pillHighlight: 'Server Port: 4455',
        ),
        _buildStep(
          stepNumber: '4',
          title: 'Authentication & QR Code',
          detail: 'If "Enable Authentication" is checked, note or generate your Server Password. Click "Show Connect Info" to view the QR code on your PC monitor.',
        ),
        _buildStep(
          stepNumber: '5',
          title: 'Connect Instantly',
          detail: 'In this app, tap "Scan OBS WebSocket QR Code" to connect automatically in 1 second, or type your computer\'s IP address and tap CONNECT.',
        ),
      ],
    );
  }

  Widget _buildStreamlabsGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(
          icon: Icons.live_tv_rounded,
          color: const Color(0xFF31F7B6),
          title: 'Streamlabs Remote Access',
          description: 'Streamlabs utilizes the WebSocket v5 protocol for remote controller interaction.',
        ),
        const SizedBox(height: 14),
        _buildStep(
          stepNumber: '1',
          title: 'Launch Streamlabs',
          detail: 'Ensure Streamlabs is running on your streaming computer.',
        ),
        _buildStep(
          stepNumber: '2',
          title: 'Open Remote Settings',
          detail: 'Click the Settings gear icon in the bottom-left corner, then go to:',
          pillHighlight: 'Settings  >  Remote Control / API',
        ),
        _buildStep(
          stepNumber: '3',
          title: 'Verify WebSocket Port & Token',
          detail: 'Confirm WebSocket is enabled on port 4455. If a password or API token is generated, copy it.',
          pillHighlight: 'Default Port: 4455',
        ),
        _buildStep(
          stepNumber: '4',
          title: 'Connect From Mobile',
          detail: 'Select the "Streamlabs" tab in this app, enter your PC\'s local IP address and password, then tap CONNECT.',
        ),
      ],
    );
  }

  Widget _buildVmixGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(
          icon: Icons.videocam_rounded,
          color: AppColors.accentOrange,
          title: 'vMix Web Controller (REST/XML API)',
          description: 'vMix provides built-in HTTP Web Controller and API access directly on Windows.',
        ),
        const SizedBox(height: 14),
        _buildStep(
          stepNumber: '1',
          title: 'Open vMix on your Windows PC',
          detail: 'Ensure your project is loaded with your camera inputs and scenes.',
        ),
        _buildStep(
          stepNumber: '2',
          title: 'Access Web Controller Settings',
          detail: 'In the top-right toolbar of vMix, click on:',
          pillHighlight: 'Settings  >  Web Controller',
        ),
        _buildStep(
          stepNumber: '3',
          title: 'Enable Web Controller',
          detail: 'Check the "Enabled" box. Notice the default port number 8088 and the displayed local URL (e.g. http://192.168.1.xxx:8088).',
          pillHighlight: 'Default Port: 8088',
        ),
        _buildStep(
          stepNumber: '4',
          title: 'Authentication (Optional)',
          detail: 'Leave username/password empty for fast local control, or configure authentication if desired.',
        ),
        _buildStep(
          stepNumber: '5',
          title: 'Connect From Mobile',
          detail: 'In this app, select the "vMix" tab, enter your vMix PC\'s local IP address, and tap CONNECT.',
        ),
      ],
    );
  }

  Widget _buildNetworkGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(
          icon: Icons.wifi_rounded,
          color: AppColors.connectedGreen,
          title: 'Local Network Requirements',
          description: 'Your mobile device and PC must be on the same local network subnet (same Wi-Fi router).',
        ),
        const SizedBox(height: 14),
        _buildStep(
          stepNumber: '1',
          title: 'Find your PC\'s Local IP Address',
          detail: 'On Windows:\n• Press Win + R, type "cmd", and hit Enter.\n• Type "ipconfig" and look for "IPv4 Address" (e.g. 192.168.1.150).\n\nOn macOS:\n• Open System Settings > Wi-Fi > Details, or run "ipconfig getifaddr en0" in Terminal.',
          pillHighlight: 'e.g. 192.168.1.xxx',
        ),
        _buildStep(
          stepNumber: '2',
          title: 'Avoid "Guest" Wi-Fi Networks',
          detail: 'Guest networks often enable "Client Isolation", which blocks communication between devices. Always use your primary private Wi-Fi network.',
        ),
        _buildStep(
          stepNumber: '3',
          title: 'Check Windows Defender Firewall',
          detail: 'If the app fails to connect, ensure OBS or vMix has permission to accept incoming connections on Private networks, or temporarily allow TCP port 4455 / 8088.',
        ),
        _buildStep(
          stepNumber: '4',
          title: 'Use Auto-Discovery (Scan LAN)',
          detail: 'In Quick Connect, tap "Scan LAN" to let the app automatically search your subnet for running OBS instances.',
        ),
      ],
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String stepNumber,
    required String title,
    required String detail,
    String? pillHighlight,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: AppColors.surfaceBorderBold,
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.accentCyan,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (pillHighlight != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: AppColors.surfaceBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      pillHighlight,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.previewAmber,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
