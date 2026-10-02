import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../dialogs/connection_guide_dialog.dart';

/// Shared empty/disconnected state widget used by Switcher, Multiview,
/// and LandscapeMultiviewScreen. Keeps the disconnected experience identical
/// across all scene-content screens.
class ObsDisconnectedPrompt extends StatelessWidget {
  final double topInset;
  final double bottomInset;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onConnect;
  final String buttonLabel;

  const ObsDisconnectedPrompt({
    super.key,
    required this.topInset,
    required this.bottomInset,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onConnect,
    this.buttonLabel = 'CONNECT CONTROLLER',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, topInset + 16, 28, bottomInset + 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.link_rounded, size: 20),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ConnectionGuideDialog.show(context),
              icon: const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.accentCyan),
              label: const Text(
                'HOW TO CONNECT? SETUP GUIDE',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
