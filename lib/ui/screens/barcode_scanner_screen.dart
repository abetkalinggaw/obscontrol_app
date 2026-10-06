import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/obs_qr_parser.dart';
import '../../models/connection_state.dart';
import '../../providers/obs_provider.dart';
import '../../providers/settings_provider.dart';

/// Full-screen Flat Precision QR and Barcode scanner for OBS Studio WebSocket.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  /// If [autoConnect] is true, immediately initiates connection upon valid scan.
  /// If false, returns the parsed [ObsConnectionData] to the caller via [Navigator.pop].
  final bool autoConnect;

  const BarcodeScannerScreen({
    super.key,
    this.autoConnect = true,
  });

  static Future<ObsConnectionData?> open(BuildContext context, {bool autoConnect = true}) {
    return Navigator.push<ObsConnectionData>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(autoConnect: autoConnect),
      ),
    );
  }

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _laserController;
  bool _isProcessing = false;
  bool _torchOn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _handleScannedContent(rawValue.trim());
        break;
      }
    }
  }

  void _handleScannedContent(String rawContent) {
    final parsed = ObsQrParser.parse(rawContent);

    if (parsed == null) {
      Haptics.light();
      setState(() {
        _errorMessage = 'Invalid OBS QR Code. Please scan code from OBS Studio.';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _errorMessage = null);
      });
      return;
    }

    Haptics.heavy();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    _showConnectionConfirmationDialog(parsed);
  }

  void _showConnectionConfirmationDialog(ObsConnectionData data) {
    bool saveAsProfile = true;
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        side: BorderSide(color: AppColors.surfaceBorderBold, width: 1.5),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorderBold,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Flat Header Title
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.connectedGreen,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'OBS WEBSOCKET ENDPOINT DETECTED',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('HOST ADDRESS', data.host),
                      const Divider(height: 12, color: AppColors.surfaceBorder),
                      _buildInfoRow('PORT', data.port.toString()),
                      const Divider(height: 12, color: AppColors.surfaceBorder),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PASSWORD',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                data.password.isEmpty
                                    ? 'None (Open)'
                                    : (obscurePassword ? '••••••••' : data.password),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              if (data.password.isNotEmpty)
                                IconButton(
                                  icon: Icon(
                                    obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  padding: const EdgeInsets.only(left: 6),
                                  onPressed: () => setSheetState(() => obscurePassword = !obscurePassword),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Save as profile checkbox
                InkWell(
                  onTap: () => setSheetState(() => saveAsProfile = !saveAsProfile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: saveAsProfile,
                            activeColor: AppColors.connectedGreen,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) => setSheetState(() => saveAsProfile = val ?? true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Save to Connection Profiles',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      flex: 40,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          // Restart scanner so camera resumes after bottom sheet pauses it
                          _scannerController.start();
                          setState(() => _isProcessing = false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        ),
                        child: const Text('RESCAN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 60,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext); // Close sheet

                          if (saveAsProfile) {
                            final profileName = data.name ?? 'OBS Studio (${data.host})';
                            final profileId = 'profile_${DateTime.now().millisecondsSinceEpoch}';
                            final profile = ObsConnectionProfile(
                              id: profileId,
                              name: profileName,
                              host: data.host,
                              port: data.port,
                              password: data.password,
                              lastUsed: DateTime.now(),
                            );
                            ref.read(settingsProvider.notifier).saveProfile(profile);
                            ref.read(settingsProvider.notifier).setActiveProfile(profileId);
                          }

                          if (widget.autoConnect) {
                            ref.read(obsProvider.notifier).connect(
                              host: data.host,
                              port: data.port,
                              password: data.password,
                              name: data.name,
                            );
                            if (mounted && Navigator.canPop(context)) {
                              Navigator.pop(context, data); // Close scanner screen
                            }
                          } else {
                            if (mounted && Navigator.canPop(context)) {
                              Navigator.pop(context, data); // Return data to caller
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.connectedGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        ),
                        child: Text(
                          widget.autoConnect ? 'CONNECT NOW' : 'USE DETAILS',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5),
        ),
        Text(
          value,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  /// Opens the device image gallery and attempts to decode a QR code from the chosen image.
  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return; // user cancelled

      Haptics.selection();
      final result = await _scannerController.analyzeImage(picked.path);

      if (result == null || result.barcodes.isEmpty) {
        if (mounted) {
          setState(() => _errorMessage = 'No QR code found in the selected image.');
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _errorMessage = null);
          });
        }
        return;
      }

      // Use the first valid barcode value
      for (final barcode in result.barcodes) {
        final raw = barcode.rawValue;
        if (raw != null && raw.trim().isNotEmpty) {
          _handleScannedContent(raw.trim());
          return;
        }
      }

      if (mounted) {
        setState(() => _errorMessage = 'No valid OBS QR data found in image.');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _errorMessage = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not read image. Try again.');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _errorMessage = null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanAreaSize = math.min(screenSize.width * 0.72, 280.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          ),

          // 2. Dark Overlay with Cutout Viewfinder
          Positioned.fill(
            child: CustomPaint(
              painter: _ViewfinderOverlayPainter(
                cutoutSize: scanAreaSize,
                laserProgress: _laserController.value,
              ),
            ),
          ),

          // Animated repaint for laser scanline
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _laserController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _LaserScanPainter(
                    cutoutSize: scanAreaSize,
                    laserProgress: _laserController.value,
                  ),
                );
              },
            ),
          ),

          // 3. Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.surfaceBorderBold, width: 1.0),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'OBS QR & BARCODE SCANNER',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      size: 20,
                      color: _torchOn ? AppColors.previewAmber : AppColors.textSecondary,
                    ),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      Haptics.selection();
                      await _scannerController.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios_rounded, size: 20, color: AppColors.textSecondary),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Haptics.selection();
                      _scannerController.switchCamera();
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Error / Notice Banner
          if (_errorMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.liveRed,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Bottom Instructions & Action Controls
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'ALIGN OBS STUDIO QR CODE IN FRAME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'OBS Studio: Tools → WebSocket Server Settings → Show Connect Info',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.accentCyan),
                    label: const Text(
                      'SELECT FROM GALLERY',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.surface.withValues(alpha: 0.85),
                      foregroundColor: AppColors.accentCyan,
                      side: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the Flat dark cutout and corner bracket reticle
class _ViewfinderOverlayPainter extends CustomPainter {
  final double cutoutSize;
  final double laserProgress;

  _ViewfinderOverlayPainter({
    required this.cutoutSize,
    required this.laserProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);

    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2 - 30; // slightly above center
    final rect = Rect.fromLTWH(left, top, cutoutSize, cutoutSize);

    // Cutout hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Hairline Border
    final borderPaint = Paint()
      ..color = AppColors.surfaceBorderBold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, borderPaint);

    // Corner Target Brackets (Program red & cyan accents)
    const bracketLength = 22.0;
    const bracketWidth = 3.0;

    final cyanPaint = Paint()
      ..color = AppColors.accentCyan
      ..strokeWidth = bracketWidth
      ..strokeCap = StrokeCap.square;

    final yellowPaint = Paint()
      ..color = AppColors.previewAmber
      ..strokeWidth = bracketWidth
      ..strokeCap = StrokeCap.square;

    final redPaint = Paint()
      ..color = AppColors.liveRed
      ..strokeWidth = bracketWidth
      ..strokeCap = StrokeCap.square;

    // Top-Left (Cyan)
    canvas.drawLine(Offset(left, top), Offset(left + bracketLength, top), cyanPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + bracketLength), cyanPaint);

    // Top-Right (Yellow)
    canvas.drawLine(Offset(left + cutoutSize, top), Offset(left + cutoutSize - bracketLength, top), yellowPaint);
    canvas.drawLine(Offset(left + cutoutSize, top), Offset(left + cutoutSize, top + bracketLength), yellowPaint);

    // Bottom-Left (Yellow)
    canvas.drawLine(Offset(left, top + cutoutSize), Offset(left + bracketLength, top + cutoutSize), yellowPaint);
    canvas.drawLine(Offset(left, top + cutoutSize), Offset(left, top + cutoutSize - bracketLength), yellowPaint);

    // Bottom-Right (Red)
    canvas.drawLine(Offset(left + cutoutSize, top + cutoutSize), Offset(left + cutoutSize - bracketLength, top + cutoutSize), redPaint);
    canvas.drawLine(Offset(left + cutoutSize, top + cutoutSize), Offset(left + cutoutSize, top + cutoutSize - bracketLength), redPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.cutoutSize != cutoutSize;
  }
}

/// Dynamic laser scanline painter
class _LaserScanPainter extends CustomPainter {
  final double cutoutSize;
  final double laserProgress;

  _LaserScanPainter({
    required this.cutoutSize,
    required this.laserProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2 - 30;
    final currentY = top + (cutoutSize * laserProgress);

    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.accentCyan.withValues(alpha: 0.1),
          AppColors.accentCyan,
          AppColors.accentCyan.withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromLTWH(left, currentY, cutoutSize, 2))
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(left + 4, currentY), Offset(left + cutoutSize - 4, currentY), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _LaserScanPainter oldDelegate) {
    return oldDelegate.laserProgress != laserProgress || oldDelegate.cutoutSize != cutoutSize;
  }
}
