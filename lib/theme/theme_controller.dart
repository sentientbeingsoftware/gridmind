import 'package:flutter/material.dart';
import '../services/app_persistence_service.dart';

/// Owns the app-wide [ThemeMode] and color palette preset, and persists changes.
///
/// Listeners are notified when either the mode or the palette changes.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  final AppPersistenceService _persistence = AppPersistenceService();

  String _paletteType = 'random';
  Color? _customSeed;

  String get paletteType => _paletteType;

  Future<void> load() async {
    value = await _persistence.getThemeMode();
    _paletteType = await _persistence.getPaletteType();
    final custom = await _persistence.getCustomPalette();
    _customSeed = custom.isNotEmpty ? custom.first : null;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    await _persistence.setThemeMode(mode);
  }

  /// Updates the in-memory palette (persistence is handled by the caller).
  void setPalette(String type, {Color? customSeed}) {
    _paletteType = type;
    if (customSeed != null) _customSeed = customSeed;
    notifyListeners();
  }

  /// Accent color of the selected preset, or null for 'random'.
  Color? get _seed {
    switch (_paletteType) {
      case 'preset1':
        return Colors.blue;
      case 'preset2':
        return const Color(0xFFFFB3BA);
      case 'preset3':
        return null; // handled as pure black / white
      case 'preset4':
        return const Color(0xFF377eb8);
      case 'custom':
        return _customSeed;
      default:
        return null;
    }
  }

  /// Screen background matching the selected preset while respecting
  /// [brightness]. Returns null when the default theme background applies.
  Color? backgroundFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (_paletteType == 'preset3') {
      return dark ? Colors.black : Colors.white;
    }
    final seed = _seed;
    if (seed == null) return null;
    final base = dark ? const Color(0xFF121212) : Colors.white;
    return Color.alphaBlend(seed.withValues(alpha: dark ? 0.22 : 0.14), base);
  }
}

/// Exposes the [ThemeController] to descendants without coupling them to
/// the private state class of [MyApp].
class ThemeScope extends InheritedWidget {
  const ThemeScope({super.key, required this.controller, required super.child});

  final ThemeController controller;

  /// Returns null when no scope exists (e.g. a screen mounted alone in a test).
  static ThemeController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ThemeScope>()?.controller;

  @override
  bool updateShouldNotify(ThemeScope oldWidget) => controller != oldWidget.controller;
}
