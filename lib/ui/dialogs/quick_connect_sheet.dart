import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/discovery_service.dart';
import '../../core/utils/haptics.dart';
import '../../models/connection_state.dart';
import '../../providers/obs_provider.dart';
import '../../providers/settings_provider.dart';
import '../screens/barcode_scanner_screen.dart';
import 'connection_guide_dialog.dart';

class QuickConnectSheet extends ConsumerStatefulWidget {
  final Future<List<DiscoveredObsServer>> Function({
    StreamingSoftware? software,
    int? customPort,
    String? preferredHost,
    void Function(double progress, String status)? onProgress,
    void Function(DiscoveredObsServer server)? onDiscovered,
    bool Function()? isCancelled,
  })? discoveryScanner;

  const QuickConnectSheet({super.key, this.discoveryScanner});

  static Future<void> show(
    BuildContext context, {
    Future<List<DiscoveredObsServer>> Function({
      StreamingSoftware? software,
      int? customPort,
      String? preferredHost,
      void Function(double progress, String status)? onProgress,
      void Function(DiscoveredObsServer server)? onDiscovered,
      bool Function()? isCancelled,
    })? discoveryScanner,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickConnectSheet(discoveryScanner: discoveryScanner),
    );
  }

  @override
  ConsumerState<QuickConnectSheet> createState() => _QuickConnectSheetState();
}

class _QuickConnectSheetState extends ConsumerState<QuickConnectSheet> {
  final ScrollController _scrollController = ScrollController();
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isScanning = false;
  bool _cancelScan = false;
  double _scanProgress = 0.0;
  String _scanStatusText = '';
  List<DiscoveredObsServer> _discoveredServers = [];

  late StreamingSoftware _selectedSoftware;

  @override
  void initState() {
    super.initState();
    final currentProfile = ref.read(settingsProvider).activeProfile;
    _selectedSoftware = currentProfile.software;
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _cancelScan = true;
    _scrollController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSoftwareChanged(StreamingSoftware sw) {
    if (_selectedSoftware == sw) return;
    setState(() {
      final prevDefault = _selectedSoftware.defaultPort;
      final currentPort = int.tryParse(_portController.text.trim());
      _selectedSoftware = sw;
      if (_portController.text.isEmpty || currentPort == prevDefault) {
        _portController.clear();
      }
    });
  }

  Future<void> _startLanScan() async {
    setState(() {
      _isScanning = true;
      _cancelScan = false;
      _scanProgress = 0.0;
      _scanStatusText = 'Starting local network scan...';
      _discoveredServers.clear();
    });

    final scanner = widget.discoveryScanner ?? DiscoveryService.scanLocalNetwork;
    try {
      final results = await scanner(
        software: _selectedSoftware,
        customPort: int.tryParse(_portController.text.trim()),
        preferredHost: _hostController.text.trim().isNotEmpty ? _hostController.text.trim() : null,
        isCancelled: () => !mounted || _cancelScan,
        onProgress: (p, status) {
          if (mounted && !_cancelScan) {
            setState(() {
              _scanProgress = p;
              _scanStatusText = status;
            });
          }
        },
        onDiscovered: (server) {
          if (mounted && !_cancelScan) {
            setState(() {
              if (!_discoveredServers.any((s) => s.ip == server.ip && s.port == server.port)) {
                _discoveredServers.add(server);
              }
            });
          }
        },
      );

      if (mounted && !_cancelScan) {
        setState(() {
          _isScanning = false;
          _discoveredServers = results;
          if (results.isEmpty) {
            _scanStatusText = 'No active broadcast instances found on local subnet.';
          } else {
            _scanStatusText = 'Found ${results.length} instance(s)!';
          }
        });
      }
    } catch (e) {
      if (mounted && !_cancelScan) {
        setState(() {
          _isScanning = false;
          _scanStatusText = 'Scan error: $e';
        });
      }
    }
  }

  void _stopLanScan() {
    if (_isScanning) {
      setState(() {
        _cancelScan = true;
        _isScanning = false;
        _scanStatusText = 'Scan stopped.';
      });
    }
  }

  void _inputDiscoveredServer(DiscoveredObsServer server) {
    Haptics.selection();
    setState(() {
      _hostController.text = server.ip;
      _portController.text = server.port.toString();
      _selectedSoftware = server.software;
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Inputted ${server.ip}:${server.port} into Quick Connect'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  void _connect(String host, int port, String password) {
    Haptics.medium();
    ref.read(obsProvider.notifier).connect(
      host: host,
      port: port,
      password: password,
      software: _selectedSoftware,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final obsState = ref.watch(obsProvider);
    final isConnecting = obsState.status == ObsConnectionStatus.connecting;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          top: BorderSide(
            color: AppColors.surfaceBorderActive,
            width: 1.0,
          ),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Handle
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorderActive,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
                const SizedBox(height: 16),

                // Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Connect',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () => ConnectionGuideDialog.show(
                              context,
                              initialSoftware: _selectedSoftware,
                            ),
                            borderRadius: BorderRadius.circular(3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedSoftware.setupHint,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.accentCyan),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => ConnectionGuideDialog.show(
                            context,
                            initialSoftware: _selectedSoftware,
                          ),
                          icon: const Icon(Icons.help_outline_rounded, color: AppColors.accentCyan, size: 22),
                          tooltip: 'Connection Guide',
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Software Selector Segment
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                  ),
                  child: Row(
                    children: StreamingSoftware.values.map((sw) {
                      final isSelected = _selectedSoftware == sw;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Haptics.selection();
                            _onSoftwareChanged(sw);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: isSelected
                                  ? Border.all(color: AppColors.accentCyan, width: 1.0)
                                  : Border.all(color: Colors.transparent, width: 1.0),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              sw.displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                if (_selectedSoftware != StreamingSoftware.vmix) ...[
                  const SizedBox(height: 10),
                  // Scan QR Code Action Button
                  InkWell(
                    onTap: () async {
                      Haptics.selection();
                      final scanned = await BarcodeScannerScreen.open(context, autoConnect: false);
                      if (scanned != null) {
                        setState(() {
                          _hostController.text = scanned.host;
                          _portController.text = scanned.port.toString();
                          _passwordController.text = scanned.password;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppColors.surfaceBorderActive,
                          width: 1.0,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.accentCyan),
                          SizedBox(width: 8),
                          Text(
                            'SCAN OBS WEBSOCKET QR CODE',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Form inputs
                Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'IP Address / Host',
                          hintText: '192.168.1.100',
                          prefixIcon: Icon(Icons.computer_rounded, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Port',
                          hintText: _selectedSoftware.defaultPort.toString(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: _selectedSoftware == StreamingSoftware.vmix
                        ? 'Password (optional in vMix)'
                        : 'Server Password (if enabled)',
                    hintText: _selectedSoftware == StreamingSoftware.vmix
                        ? 'Leave blank if unauthenticated'
                        : 'WebSocket Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Connect Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isConnecting
                        ? null
                        : () {
                            final rawHost = _hostController.text.trim();
                            final host = rawHost.isNotEmpty ? rawHost : '192.168.1.100';
                            final port = int.tryParse(_portController.text.trim()) ??
                                _selectedSoftware.defaultPort;
                            final password = _passwordController.text;
                            _connect(host, port, password);
                          },
                    child: isConnecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'CONNECT',
                            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                  ),
                ),

            const SizedBox(height: 16),

            // Auto-Discovery Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Local Network Discovery',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_isScanning)
                  TextButton.icon(
                    onPressed: _stopLanScan,
                    icon: const Icon(Icons.stop_circle_outlined, size: 16, color: AppColors.liveRed),
                    label: const Text(
                      'Stop Scan',
                      style: TextStyle(fontSize: 12, color: AppColors.liveRed, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _startLanScan,
                    icon: const Icon(Icons.radar_rounded, size: 16, color: AppColors.accentCyan),
                    label: const Text(
                      'Scan LAN',
                      style: TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),

            if (_isScanning) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: _scanProgress, backgroundColor: AppColors.surfaceBorder, color: AppColors.accentCyan),
              const SizedBox(height: 6),
              Text(
                _scanStatusText,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ] else if (_scanStatusText.isNotEmpty && _discoveredServers.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _scanStatusText,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],

            if (_discoveredServers.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._discoveredServers.map((server) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(5),
                      onTap: () => _inputDiscoveredServer(server),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(2),
                                          border: Border.all(color: AppColors.surfaceBorderBold, width: 1),
                                        ),
                                        child: Text(
                                          server.software.shortName,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.accentCyan,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          server.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${server.ip}:${server.port}',
                                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _inputDiscoveredServer(server),
                              icon: const Icon(Icons.input_rounded, size: 14),
                              label: const Text(
                                'Input',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentCyan,
                                foregroundColor: AppColors.surface,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
