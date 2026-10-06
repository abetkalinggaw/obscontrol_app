import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../models/connection_state.dart';
import '../../providers/obs_provider.dart';
import '../../providers/settings_provider.dart';
import '../dialogs/quick_connect_sheet.dart';
import '../dialogs/connection_guide_dialog.dart';
import '../widgets/floating_bars_insets.dart';
import 'barcode_scanner_screen.dart';

/// Bauhaus Architectural Connection & Preferences Screen with Accordion Profiles & Recent Devices.
class ConnectionSettingsScreen extends ConsumerStatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  ConsumerState<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends ConsumerState<ConnectionSettingsScreen> {
  bool _isSavedProfilesExpanded = true;
  bool _isRecentDevicesExpanded = true;

  // Dialog to Add a New Profile (supports optional pre-fill, e.g. from Recent Devices)
  void _showAddProfileDialog({
    String? initialName,
    String? initialHost,
    int? initialPort,
    String? initialPassword,
    StreamingSoftware? initialSoftware,
  }) {
    Haptics.selection();
    StreamingSoftware selectedSoftware = initialSoftware ?? StreamingSoftware.obsStudio;
    final nameCtrl = TextEditingController(text: initialName ?? '');
    final hostCtrl = TextEditingController(text: initialHost ?? '');
    final portCtrl = TextEditingController(
      text: initialPort != null ? initialPort.toString() : '',
    );
    final passCtrl = TextEditingController(text: initialPassword ?? '');
    bool obscurePass = true;
    bool setAsActive = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.surfaceBorderActive, width: 1.0),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Expanded(
                child: Text(
                  'ADD CONNECTION PROFILE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, size: 20, color: AppColors.accentCyan),
                tooltip: 'How to Connect',
                onPressed: () => ConnectionGuideDialog.show(
                  context,
                  initialSoftware: selectedSoftware,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Software Selector Segment
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                  ),
                  child: Row(
                    children: StreamingSoftware.values.map((sw) {
                      final isSelected = selectedSoftware == sw;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Haptics.selection();
                            setDialogState(() {
                              final prevDefault = selectedSoftware.defaultPort;
                              final currentPort = int.tryParse(portCtrl.text.trim());
                              selectedSoftware = sw;
                              if (portCtrl.text.isEmpty || currentPort == prevDefault) {
                                portCtrl.clear();
                              }
                            });
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
                              sw.displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (selectedSoftware != StreamingSoftware.vmix)
                  InkWell(
                    onTap: () async {
                      Haptics.selection();
                      final scanned = await BarcodeScannerScreen.open(context, autoConnect: false);
                      if (scanned != null) {
                        setDialogState(() {
                          if (scanned.name != null && scanned.name!.isNotEmpty) {
                            nameCtrl.text = scanned.name!;
                          }
                          hostCtrl.text = scanned.host;
                          portCtrl.text = scanned.port.toString();
                          passCtrl.text = scanned.password;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.accentCyan),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'AUTO-FILL FROM OBS QR',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: AppColors.accentCyan,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _buildDialogTextField(
                  controller: nameCtrl,
                  label: 'PROFILE NAME',
                  hint: 'Studio Secondary',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 65,
                      child: _buildDialogTextField(
                        controller: hostCtrl,
                        label: 'HOST IP / DOMAIN',
                        hint: '192.168.1.100',
                        icon: Icons.computer_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 35,
                      child: _buildDialogTextField(
                        controller: portCtrl,
                        label: 'PORT',
                        hint: selectedSoftware.defaultPort.toString(),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: passCtrl,
                  label: selectedSoftware == StreamingSoftware.vmix
                      ? 'PASSWORD (OPTIONAL)'
                      : 'PASSWORD (OPTIONAL)',
                  hint: selectedSoftware == StreamingSoftware.vmix
                      ? 'vMix API password'
                      : 'WebSocket v5 password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setDialogState(() => setAsActive = !setAsActive),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: setAsActive,
                            activeColor: AppColors.accentCyan,
                            onChanged: (val) => setDialogState(() => setAsActive = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Set as Active Profile',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final rawHost = hostCtrl.text.trim();
                final host = rawHost.isNotEmpty ? rawHost : '192.168.1.100';
                final port = int.tryParse(portCtrl.text.trim()) ?? selectedSoftware.defaultPort;

                Haptics.medium();
                final newId = 'profile_${DateTime.now().millisecondsSinceEpoch}';
                final rawName = nameCtrl.text.trim();
                final name = rawName.isNotEmpty
                    ? rawName
                    : (initialName ?? '${selectedSoftware.displayName} ($host)');
                final newProfile = ObsConnectionProfile(
                  id: newId,
                  name: name,
                  host: host,
                  port: port,
                  password: passCtrl.text,
                  software: selectedSoftware,
                  lastUsed: DateTime.now(),
                );

                ref.read(settingsProvider.notifier).saveProfile(newProfile);
                if (setAsActive) {
                  ref.read(settingsProvider.notifier).setActiveProfile(newId);
                }

                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
              ),
              child: const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog to Edit an Existing Profile
  void _showEditProfileDialog(ObsConnectionProfile profile) {
    Haptics.selection();
    StreamingSoftware selectedSoftware = profile.software;
    final nameCtrl = TextEditingController(text: profile.name);
    final hostCtrl = TextEditingController(text: profile.host);
    final portCtrl = TextEditingController(text: profile.port.toString());
    final passCtrl = TextEditingController(text: profile.password);
    bool obscurePass = true;
    final isActive = profile.id == ref.read(settingsProvider).activeProfileId;
    bool setAsActive = isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.surfaceBorderActive, width: 1.0),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: AppColors.previewAmber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Expanded(
                child: Text(
                  'EDIT CONNECTION PROFILE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Software Selector Segment
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                  ),
                  child: Row(
                    children: StreamingSoftware.values.map((sw) {
                      final isSelected = selectedSoftware == sw;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Haptics.selection();
                            setDialogState(() {
                              final prevDefault = selectedSoftware.defaultPort;
                              final currentPort = int.tryParse(portCtrl.text.trim());
                              selectedSoftware = sw;
                              if (currentPort == null || currentPort == prevDefault) {
                                portCtrl.text = sw.defaultPort.toString();
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.previewAmber.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                              border: isSelected
                                  ? Border.all(color: AppColors.previewAmber, width: 1.2)
                                  : Border.all(color: Colors.transparent, width: 1.2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              sw.displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                color: isSelected ? AppColors.previewAmber : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                _buildDialogTextField(
                  controller: nameCtrl,
                  label: 'PROFILE NAME',
                  hint: 'Profile Name',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 65,
                      child: _buildDialogTextField(
                        controller: hostCtrl,
                        label: 'HOST IP / DOMAIN',
                        hint: '192.168.1.100',
                        icon: Icons.computer_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 35,
                      child: _buildDialogTextField(
                        controller: portCtrl,
                        label: 'PORT',
                        hint: selectedSoftware.defaultPort.toString(),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: passCtrl,
                  label: selectedSoftware == StreamingSoftware.vmix
                      ? 'PASSWORD (OPTIONAL)'
                      : 'PASSWORD',
                  hint: selectedSoftware == StreamingSoftware.vmix
                      ? 'vMix API password'
                      : 'Password (leave blank if none)',
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                  ),
                ),
                const SizedBox(height: 10),
                if (!isActive)
                  InkWell(
                    onTap: () => setDialogState(() => setAsActive = !setAsActive),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: setAsActive,
                              activeColor: AppColors.previewAmber,
                              onChanged: (val) => setDialogState(() => setAsActive = val ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Set as Active Profile',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final host = hostCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? selectedSoftware.defaultPort;
                if (host.isEmpty) return;

                Haptics.medium();
                final updated = profile.copyWith(
                  name: nameCtrl.text.trim().isEmpty ? profile.name : nameCtrl.text.trim(),
                  host: host,
                  port: port,
                  password: passCtrl.text,
                  software: selectedSoftware,
                );

                ref.read(settingsProvider.notifier).saveProfile(updated);
                if (setAsActive) {
                  ref.read(settingsProvider.notifier).setActiveProfile(profile.id);
                }

                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.previewAmber,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
              ),
              child: const Text('UPDATE PROFILE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog to Confirm Profile Deletion
  void _showDeleteProfileDialog(ObsConnectionProfile profile) {
    Haptics.heavy();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.liveRed, width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.liveRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Expanded(
              child: Text(
                'DELETE PROFILE',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  fontSize: 13.5,
                  color: AppColors.liveRed,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete profile "${profile.name.toUpperCase()}" (${profile.host}:${profile.port})?',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Haptics.medium();
              ref.read(settingsProvider.notifier).deleteProfile(profile.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.liveRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Dialog to Confirm Clearing Recent Devices
  void _showClearRecentsDialog() {
    Haptics.selection();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.surfaceBorderBold, width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: const Text(
          'CLEAR RECENT DEVICES',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            fontSize: 13.5,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to clear all recently connected devices history?',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Haptics.medium();
              ref.read(settingsProvider.notifier).clearRecentDevices();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.liveRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
            child: const Text('CLEAR ALL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            isDense: true,
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            prefixIcon: icon != null ? Icon(icon, size: 18, color: AppColors.textSecondary) : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.0),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = FloatingBarsInsets.of(context);
    final obsState = ref.watch(obsProvider);
    final settingsState = ref.watch(settingsProvider);
    final isConnected = obsState.status == ObsConnectionStatus.connected;

    return ListView(
      padding: EdgeInsets.fromLTRB(14, insets.topInset + 6, 14, insets.bottomInset + 16),
      children: [
        // Connection Status Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isConnected
                  ? AppColors.connectedGreen
                  : AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.connectedGreen.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isConnected ? AppColors.connectedGreen : AppColors.surfaceBorder,
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  isConnected ? Icons.check_circle_outline_rounded : Icons.link_off_rounded,
                  color: isConnected ? AppColors.connectedGreen : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? 'CONNECTED TO ${obsState.currentSoftware.displayName.toUpperCase()}'
                          : 'DISCONNECTED',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected
                          ? '${obsState.currentHost.isNotEmpty ? obsState.currentHost : '127.0.0.1'}:${obsState.currentPort} • ${obsState.currentSoftware.protocolLabel}'
                          : 'Tap below to connect or select a saved profile',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isConnected)
                TextButton(
                  onPressed: () {
                    Haptics.medium();
                    ref.read(obsProvider.notifier).disconnect();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.liveRed.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                      side: const BorderSide(color: AppColors.liveRed, width: 1.0),
                    ),
                  ),
                  child: const Text(
                    'DISCONNECT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.liveRed,
                      letterSpacing: 0.6,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => QuickConnectSheet.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.connectedGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  child: const Text(
                    'CONNECT',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Bauhaus Quick Action: Scan OBS QR Code
        InkWell(
          onTap: () => BarcodeScannerScreen.open(context, autoConnect: true),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.5), width: 1.0),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded, size: 17, color: AppColors.accentCyan),
                SizedBox(width: 8),
                Text(
                  'SCAN OBS WEBSOCKET QR CODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentCyan,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Bauhaus Quick Action: Connection Setup Guide
        InkWell(
          onTap: () => ConnectionGuideDialog.show(context),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 15, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'HOW TO CONNECT? SETUP GUIDE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // ==========================================
        // 1. ACCORDION: SAVED CONNECTION PROFILES
        // ==========================================
        _buildAccordionHeader(
          title: 'SAVED CONNECTION PROFILES',
          icon: Icons.dns_rounded,
          count: settingsState.profiles.length,
          isExpanded: _isSavedProfilesExpanded,
          onTap: () {
            Haptics.selection();
            setState(() => _isSavedProfilesExpanded = !_isSavedProfilesExpanded);
          },
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _isSavedProfilesExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    ...settingsState.profiles.map((profile) {
                      final isActive = profile.id == settingsState.activeProfileId;
                      final isCurrentLive = isConnected && isActive;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                            side: BorderSide(
                              color: isActive ? AppColors.accentCyan : AppColors.surfaceBorder,
                              width: 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(5),
                            onTap: () {
                              Haptics.medium();
                              ref.read(settingsProvider.notifier).setActiveProfile(profile.id);
                              ref.read(obsProvider.notifier).connect(
                                host: profile.host,
                                port: profile.port,
                                password: profile.password,
                                name: profile.name,
                                software: profile.software,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.accentCyan.withValues(alpha: 0.15)
                                          : AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isActive ? AppColors.accentCyan : AppColors.surfaceBorder,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.desktop_windows_rounded,
                                      color: isActive ? AppColors.accentCyan : AppColors.textSecondary,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                profile.name.toUpperCase(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textPrimary,
                                                  fontSize: 13,
                                                  letterSpacing: 0.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isActive) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: isCurrentLive ? AppColors.connectedGreen : AppColors.accentCyan,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (isCurrentLive) ...[
                                                      Container(
                                                        width: 5,
                                                        height: 5,
                                                        margin: const EdgeInsets.only(right: 3),
                                                        decoration: const BoxDecoration(
                                                          color: Colors.white,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    ],
                                                    const Text(
                                                      'ACTIVE',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.surface,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceElevated,
                                                borderRadius: BorderRadius.circular(2),
                                                border: Border.all(color: AppColors.surfaceBorderBold, width: 1),
                                              ),
                                              child: Text(
                                                profile.software.shortName,
                                                style: const TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.accentCyan,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                '${profile.host}:${profile.port}',
                                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isCurrentLive)
                                        ElevatedButton(
                                          onPressed: () {
                                            Haptics.medium();
                                            ref.read(settingsProvider.notifier).setActiveProfile(profile.id);
                                            ref.read(obsProvider.notifier).connect(
                                              host: profile.host,
                                              port: profile.port,
                                              password: profile.password,
                                              name: profile.name,
                                              software: profile.software,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.connectedGreen,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: const Size(0, 28),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                          ),
                                          child: const Text(
                                            'CONNECT',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                      IconButton(
                                        tooltip: 'Edit Profile',
                                        icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.textSecondary),
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _showEditProfileDialog(profile),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Profile',
                                        icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.textMuted),
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _showDeleteProfileDialog(profile),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    InkWell(
                      onTap: () => _showAddProfileDialog(),
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppColors.surfaceBorder, width: 1.0, style: BorderStyle.solid),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: AppColors.accentCyan),
                            SizedBox(width: 6),
                            Text(
                              'ADD CONNECTION PROFILE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accentCyan,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 18),

        // ==========================================
        // 2. ACCORDION: RECENT DEVICES
        // ==========================================
        _buildAccordionHeader(
          title: 'RECENT DEVICES',
          icon: Icons.history_rounded,
          count: settingsState.recentDevices.length,
          isExpanded: _isRecentDevicesExpanded,
          onTap: () {
            Haptics.selection();
            setState(() => _isRecentDevicesExpanded = !_isRecentDevicesExpanded);
          },
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _isRecentDevicesExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    if (settingsState.recentDevices.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 20, color: AppColors.textMuted),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No recent connection history. Connect to an OBS instance to see quick-reconnect shortcuts here.',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ...settingsState.recentDevices.map((device) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                              side: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(5),
                              onTap: () {
                                Haptics.medium();
                                ref.read(obsProvider.notifier).connect(
                                  host: device.host,
                                  port: device.port,
                                  password: device.password,
                                  name: device.name,
                                  software: device.software,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                                      ),
                                      child: const Icon(
                                        Icons.router_rounded,
                                        color: AppColors.textSecondary,
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                              letterSpacing: 0.3,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceElevated,
                                                  borderRadius: BorderRadius.circular(2),
                                                  border: Border.all(color: AppColors.surfaceBorderBold, width: 1),
                                                ),
                                                child: Text(
                                                  device.software.shortName,
                                                  style: const TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.accentCyan,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  '${device.host}:${device.port} • ${Formatters.formatRelativeTime(device.lastUsed)}',
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 11,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () {
                                            Haptics.medium();
                                            ref.read(obsProvider.notifier).connect(
                                              host: device.host,
                                              port: device.port,
                                              password: device.password,
                                              name: device.name,
                                              software: device.software,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.connectedGreen,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: const Size(0, 28),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                          ),
                                          child: const Text(
                                            'CONNECT',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Save as Profile',
                                          icon: const Icon(Icons.bookmark_add_outlined, size: 17, color: AppColors.accentCyan),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _showAddProfileDialog(
                                            initialName: device.name,
                                            initialHost: device.host,
                                            initialPort: device.port,
                                            initialPassword: device.password,
                                            initialSoftware: device.software,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove',
                                          icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            Haptics.light();
                                            ref.read(settingsProvider.notifier).removeRecentDevice(device.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      InkWell(
                        onTap: _showClearRecentsDialog,
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.textMuted),
                              SizedBox(width: 6),
                              Text(
                                'CLEAR RECENT DEVICES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 18),

        // Section: System Preferences
        const Text(
          'PREFERENCES & ACCESSIBILITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),

        Material(
          color: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
            side: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: settingsState.hapticsEnabled,
                title: const Text('Haptic Vibration Feedback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: const Text('Tactile response on switches & macro presses', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                activeThumbColor: AppColors.connectedGreen,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).setHapticsEnabled(val);
                },
              ),
              const Divider(height: 1, color: AppColors.surfaceBorder),
              SwitchListTile(
                value: settingsState.keepScreenOn,
                title: const Text('Keep Screen Awake (Always On)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: const Text('Prevents device screen from dimming or turning off while using the app', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                activeThumbColor: AppColors.connectedGreen,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).setKeepScreenOn(val);
                },
              ),
              const Divider(height: 1, color: AppColors.surfaceBorder),
              SwitchListTile(
                value: settingsState.autoReconnect,
                title: const Text('Auto-Reconnect on Launch & Resume', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: const Text('Automatically reconnect to active broadcast engine when opening app or returning from background', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                activeThumbColor: AppColors.connectedGreen,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).setAutoReconnect(val);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Telemetry details card (CPU, Frame drops, Memory)
        if (isConnected) ...[
          const Text(
            'BROADCAST ENGINE TELEMETRY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
            ),
            child: Column(
              children: [
                _buildTelemetryRow('ENGINE FPS', '${obsState.stats.activeFps.toStringAsFixed(1)} FPS'),
                const Divider(height: 14, color: AppColors.surfaceBorder),
                _buildTelemetryRow('CPU USAGE', '${obsState.stats.cpuUsage.toStringAsFixed(1)}%'),
                const Divider(height: 14, color: AppColors.surfaceBorder),
                _buildTelemetryRow('MEMORY ALLOCATION', '${obsState.stats.memoryUsage.toStringAsFixed(1)} MB'),
                const Divider(height: 14, color: AppColors.surfaceBorder),
                _buildTelemetryRow('AVERAGE FRAME TIME', '${obsState.stats.averageFrameTimeMs.toStringAsFixed(1)} ms'),
                const Divider(height: 14, color: AppColors.surfaceBorder),
                _buildTelemetryRow('NETWORK BITRATE', '${obsState.stats.kbitsPerSec} kbps'),
                const Divider(height: 14, color: AppColors.surfaceBorder),
                _buildTelemetryRow('DROPPED FRAMES', '${obsState.stats.droppedFrames} frames'),
              ],
            ),
          ),
        ],

        const SizedBox(height: 30),
      ],
    );
  }

  // Bauhaus Collapsible Section Header (Accordion Header)
  Widget _buildAccordionHeader({
    required String title,
    required IconData icon,
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
