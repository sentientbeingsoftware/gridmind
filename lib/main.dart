import 'package:flutter/material.dart';
import 'screens/menu_screen.dart';
import 'services/audio_service.dart';
import 'services/score_migration.dart';
import 'services/telemetry_service.dart';
import 'theme/theme_controller.dart';

/// Main entry point for the Grid Mind application
/// Initializes the Flutter app and sets up the root widget
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ScoreMigration.run();
  } catch (e) {
    // Never block launch on a best-effort migration; it retries next start.
    debugPrint('Score migration failed: $e');
  }
  runApp(const MyApp());
}

/// Root application widget that manages the overall app state and theme
/// Uses StatefulWidget to allow dynamic theme changes from the settings screen
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// State class for the main app that manages theme mode and provides
/// theme change functionality to child widgets
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  /// Current theme mode for the application
  /// Can be light, dark, or system (follows device settings)
  final ThemeController _themeController = ThemeController();
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeController.load();
    _audioService.load();
    TelemetryService().flushPending(); // send events left from a previous run
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) TelemetryService().flushPending();
    _audioService.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return AudioScope(
      service: _audioService,
      child: ThemeScope(
        controller: _themeController,
        child: ListenableBuilder(
          listenable: _themeController,
          builder: (context, _) => _buildApp(_themeController.value),
        ),
      ),
    );
  }

  Widget _buildApp(ThemeMode themeMode) {
    return MaterialApp(
      title: 'Grid Mind',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode, // Controls which theme is active
      // Light theme configuration with Material 3 design system
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      // Dark theme configuration with Material 3 design system
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const MenuScreen(),
    );
  }
}
