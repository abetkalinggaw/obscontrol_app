import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/constants/app_theme.dart';
import 'core/services/storage_service.dart';
import 'models/connection_state.dart';
import 'providers/obs_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for dark-first design
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0D0E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize persistent storage
  final storageService = await StorageService.init();

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storageService)],
      child: const ObsControlApp(),
    ),
  );
}

class ObsControlApp extends ConsumerStatefulWidget {
  const ObsControlApp({super.key});

  @override
  ConsumerState<ObsControlApp> createState() => _ObsControlAppState();
}

class _ObsControlAppState extends ConsumerState<ObsControlApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _checkAndReconnect();
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      final keepScreenOn = ref.read(settingsProvider).keepScreenOn;
      if (keepScreenOn) {
        WakelockPlus.enable();
      }
      _checkAndReconnect();
    }
  }

  void _checkAndReconnect() {
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    final obsNotifier = ref.read(obsProvider.notifier);
    final obsState = ref.read(obsProvider);

    if (settings.autoReconnect &&
        !obsNotifier.userExplicitlyDisconnected &&
        (obsState.status == ObsConnectionStatus.disconnected ||
            obsState.status == ObsConnectionStatus.error)) {
      obsNotifier.connectCurrentProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBS Mobile Controller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
