import '../services/game_effects.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/game_metadata.dart';
import '../services/game_registry.dart';
import '../theme/theme_controller.dart';
import 'walkthrough_dialog.dart';
import 'feedback_screen.dart';
import '../services/app_persistence_service.dart';
import '../services/telemetry_service.dart';
import '../services/audio_service.dart';

/// Settings screen that allows users to configure app preferences
/// Includes theme selection and developer support links
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State class for the settings screen that manages theme changes
/// and handles external URL launches for developer support
class _SettingsScreenState extends State<SettingsScreen> {
  /// Local copy of the current theme mode for immediate UI feedback
  ThemeMode _currentThemeMode = ThemeMode.system;

  /// URL for Coff.ee support platform
  final Uri _coffeeURL = Uri.parse('https://coff.ee/sentientbn');

  /// URL for Ko-fi support platform
  final Uri _kofiUrl = Uri.parse('https://ko-fi.com/sentientbeingapps');

  /// Terms of Service and Privacy Policy hosted by Sentient Being Software
  final Uri _privacyPolicyUrl = Uri.parse(
    'https://www.sentientbeingsoftware.com/support/terms',
  );

  /// Dynamic map of game ID → high score, populated from all registered games
  final Map<String, int> _highScores = {};
  bool _loadingScores = true;
  final AppPersistenceService _appPersistenceService = AppPersistenceService();
  bool _telemetryEnabled = false;
  bool _musicEnabled = true;
  bool _soundEffects = true;
  bool _haptics = true;
  String _musicTrackId = kDefaultMusicTrackId;
  final TelemetryService _telemetry = TelemetryService();

  // Palette state
  String _paletteType = 'random';
  List<Color> _customPalette = [
    Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.purple,
    Colors.orange, Colors.cyan, Colors.pink, Colors.teal
  ];
  final List<List<Color>> _presets = [
    // Classic
    [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.purple, Colors.orange, Colors.cyan, Colors.pink, Colors.teal],
    // Pastel
    [const Color(0xFFFFB3BA), const Color(0xFFBAE1FF), const Color(0xFFBAFFC9), const Color(0xFFFFFFBA), const Color(0xFFFFDFBA), const Color(0xFFB3FFD9), const Color(0xFFB3B3FF), const Color(0xFFFFB3FF), const Color(0xFFB3FFF6)],
    // High Contrast
    [Colors.black, Colors.white, Colors.yellow, Colors.cyan, Colors.deepOrange, Colors.lime, Colors.blue, Colors.pink, Colors.red],
    // Color Blind
    [const Color(0xFF377eb8), const Color(0xFFff7f00), const Color(0xFF984ea3), const Color(0xFF4daf4a), const Color(0xFFf781bf), const Color(0xFFa65628), const Color(0xFF999999), const Color(0xFFe41a1c), const Color(0xFFdede00)],
  ];

  @override
  void initState() {
    super.initState();
    final themeController = ThemeScope.maybeOf(context);
    if (themeController != null) {
      _currentThemeMode = themeController.value;
    }
    _loadAllScores();
    _loadPalette();
    _loadTelemetryStatus();
    _loadMusicStatus();
  }

  Future<void> _loadMusicStatus() async {
    final enabled = await _appPersistenceService.getMusicEnabled();
    final trackId = await _appPersistenceService.getMusicTrack();
    final sfx = await _appPersistenceService.getSoundEffectsEnabled();
    final hap = await _appPersistenceService.getHapticsEnabled();
    if (mounted) {
      setState(() {
        _soundEffects = sfx;
        _haptics = hap;
        _musicEnabled = enabled;
        _musicTrackId = musicTrackById(trackId).id;
      });
    }
  }

  Future<void> _loadTelemetryStatus() async {
    final enabled = await _telemetry.isEnabled();
    if (mounted) {
      setState(() {
        _telemetryEnabled = enabled;
      });
    }
  }

  Future<void> _loadAllScores() async {
    setState(() { _loadingScores = true; });
    try {
      // Iterate over ALL registered games, loading last config + high score
      final results = <String, int>{};

      // Slide and Solve keeps one row per board size.
      final configGames = GameRegistry.games.where((g) => g.id != 'slideandsolve');
      final configScores = await Future.wait(configGames.map((game) async {
        // Mirror BaseSetupScreen: saved config values, falling back to defaults,
        // so the key matches what the game writes even if options were never changed.
        final saved = await _appPersistenceService.getLastConfig(game.id);
        final config = game.resolveConfig(saved);
        return MapEntry(
          game.id,
          await _appPersistenceService.getConfigHighScore(game.id, config),
        );
      }));
      final slideScores = await Future.wait([3, 4, 5].map((size) async => MapEntry(
            'slideandsolve_$size',
            await _appPersistenceService
                .getConfigHighScore('slideandsolve', {'gridSize': size.toDouble()}),
          )));
      results.addEntries(slideScores);
      results.addEntries(configScores);

      if (mounted) {
        setState(() {
          _highScores.clear();
          _highScores.addAll(results);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingScores = false;
        });
      }
    }
  }

  Future<void> _confirmClearAllScores() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all high scores?'),
        content: const Text('This permanently deletes your best scores for every game. It cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _clearAllScores();
  }

  Future<void> _clearAllScores() async {
    await _appPersistenceService.clearAllHighScores();
    if (mounted) {
      setState(() {
        _highScores.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All high scores cleared.')),
      );
    }
  }

  Future<void> _loadPalette() async {
    try {
      final results = await Future.wait([
        _appPersistenceService.getPaletteType(),
        _appPersistenceService.getCustomPalette(),
      ]);
      final type = results[0] as String;
      final custom = results[1] as List<Color>;

      if (mounted) {
        setState(() {
          _paletteType = type;
          if (custom.isNotEmpty) {
            _customPalette = List<Color>.from(custom);
            while (_customPalette.length < 9) {
              _customPalette.add(Colors.primaries[_customPalette.length % Colors.primaries.length]);
            }
            if (_customPalette.length > 9) {
              _customPalette = _customPalette.sublist(0, 9);
            }
          }
        });
      }
    } finally {
      // No action needed in finally
    }
  }

  Future<void> _savePalette({BuildContext? rootContext}) async {
    final svc = _appPersistenceService;
    await svc.setPaletteType(_paletteType);
    if (_paletteType == 'custom') {
      await svc.setCustomPalette(_customPalette);
    }
    if (mounted) {
      ThemeScope.maybeOf(context)?.setPalette(
        _paletteType,
        customSeed: _customPalette.isNotEmpty ? _customPalette.first : null,
      );
    }
    if (rootContext != null && rootContext.mounted) {
      ScaffoldMessenger.of(rootContext).hideCurrentSnackBar();
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Color palette saved!')),
      );
    }
  }

  /// Changes the app theme and updates both local and global state
  /// This method communicates with the main app state to apply theme changes
  void _changeTheme(ThemeMode themeMode) {
    // Update the main app's theme state
    ThemeScope.maybeOf(context)?.setMode(themeMode);
    // Update local state for immediate UI feedback
    setState(() {
      _currentThemeMode = themeMode;
    });
  }

  /// Launches the Coff.ee support URL in external browser
  /// Shows error message if URL cannot be launched
  Future<void> _launchCoffeeUrl() async {
    if (!await launchUrl(_coffeeURL, mode: LaunchMode.externalApplication)) {
      // Show error message if URL couldn't be launched
      if (mounted) {
        // Check if the widget is still in the tree before showing SnackBar
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $_coffeeURL')));
      }
    }
  }

  /// Launches the Ko-fi support URL in external browser
  /// Shows error message if URL cannot be launched
  Future<void> _launchKofiUrl() async {
    if (!await launchUrl(_kofiUrl, mode: LaunchMode.externalApplication)) {
      // Show error message if URL couldn't be launched
      if (mounted) {
        // Check if the widget is still in the tree before showing SnackBar
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $_kofiUrl')));
      }
    }
  }

  /// Opens the privacy policy in the external browser.
  /// Shows a message if the URL cannot be launched.
  Future<void> _launchPrivacyPolicy() async {
    if (!await launchUrl(_privacyPolicyUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $_privacyPolicyUrl')),
        );
      }
    }
  }

  void _showPaletteModal() async {
    final rootContext = context;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalState) {
            return Padding(
              padding: MediaQuery.of(ctx).viewInsets,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'Color Palette',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      RadioGroup<String>(
                        groupValue: _paletteType,
                        onChanged: (v) async {
                          if (v != null) {
                            modalState(() => _paletteType = v);
                            setState(() => _paletteType = v);
                            await _savePalette(rootContext: rootContext);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPaletteRadioTile(ctx, 'preset1', 'Classic', _presets[0]),
                            _buildPaletteRadioTile(ctx, 'preset2', 'Pastel', _presets[1]),
                            _buildPaletteRadioTile(ctx, 'preset3', 'High Contrast', _presets[2]),
                            _buildPaletteRadioTile(ctx, 'preset4', 'Color Blind', _presets[3]),
                            _buildPaletteRadioTile(ctx, 'custom', 'Custom', _customPalette),
                            const RadioListTile<String>(
                              dense: true,
                              value: 'random',
                              title: Text('Random (different each game)'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaletteRadioTile(BuildContext ctx, String value, String title, List<Color> colors) {
    final theme = Theme.of(ctx);
    final borderColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2);
    return RadioListTile<String>(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
      value: value,
      title: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          ...colors.asMap().entries.take(7).map((entry) {
            final i = entry.key;
            final c = entry.value;
            return Container(
              width: 18,
              height: 18,
              margin: EdgeInsets.symmetric(horizontal: i == 0 ? 0 : 2),
              decoration: BoxDecoration(
                color: c,
                border: Border.all(color: borderColor, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
          if (colors.length > 7)
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: borderColor, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(child: Text('+', style: TextStyle(fontSize: 12))),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // --- Theme Section ---
          _buildSettingsSection(
            theme,
            title: 'Theme',
            icon: Icons.brightness_6_outlined,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: const Text('Theme Mode'),
                subtitle: Text(
                  _currentThemeMode == ThemeMode.system
                      ? 'System default'
                      : _currentThemeMode == ThemeMode.light
                          ? 'Light'
                          : 'Dark',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: DropdownButton<ThemeMode>(
                  value: _currentThemeMode,
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  ],
                  onChanged: (ThemeMode? themeMode) {
                    if (themeMode != null) {
                      _changeTheme(themeMode);
                    }
                  },
                  underline: const SizedBox.shrink(),
                ),
              ),
            ],
          ),

          // --- Color Palette Section ---
          _buildSettingsSection(
            theme,
            title: 'Color Palette',
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: const Text('Game Color Palette'),
                subtitle: Text(
                  'Current: ${_paletteTypeLabel(_paletteType)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showPaletteModal,
              ),
            ],
          ),

          // --- Sound Section ---
          _buildSettingsSection(
            theme,
            title: 'Sound',
            icon: Icons.volume_up_outlined,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Icon(Icons.music_note_outlined, color: theme.colorScheme.secondary),
                title: const Text('Background Music'),
                subtitle: const Text('Turn off to keep listening to your own podcasts or audiobooks.'),
                value: _musicEnabled,
                onChanged: (val) async {
                  setState(() => _musicEnabled = val);
                  final audio = AudioScope.maybeOf(context);
                  if (audio != null) {
                    await audio.setEnabled(val);
                  } else {
                    await _appPersistenceService.setMusicEnabled(val);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Icon(Icons.graphic_eq, color: theme.colorScheme.secondary),
                title: const Text('Sound Effects'),
                subtitle: const Text('Win and lose jingles, and Simon tones.'),
                value: _soundEffects,
                onChanged: (val) async {
                  setState(() => _soundEffects = val);
                  GameEffects.instance.apply(sound: val);
                  await _appPersistenceService.setSoundEffectsEnabled(val);
                },
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Icon(Icons.vibration, color: theme.colorScheme.secondary),
                title: const Text('Haptic Feedback'),
                subtitle: const Text('A light tap on each move and a stronger one at the end.'),
                value: _haptics,
                onChanged: (val) async {
                  setState(() => _haptics = val);
                  GameEffects.instance.apply(haptics: val);
                  await _appPersistenceService.setHapticsEnabled(val);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.library_music_outlined, color: theme.colorScheme.secondary),
                title: const Text('Music Track'),
                trailing: DropdownButton<String>(
                  key: const Key('music_track_dropdown'),
                  value: _musicTrackId,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final t in kMusicTracks)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: _musicEnabled
                      ? (id) async {
                          if (id == null) return;
                          setState(() => _musicTrackId = id);
                          final audio = AudioScope.maybeOf(context);
                          if (audio != null) {
                            await audio.setTrack(musicTrackById(id));
                          } else {
                            await _appPersistenceService.setMusicTrack(id);
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),

          // --- Telemetry Section ---
          _buildSettingsSection(
            theme,
            title: 'Privacy',
            icon: Icons.shield_outlined,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Icon(
                  Icons.analytics_outlined,
                  color: theme.colorScheme.secondary,
                ),
                title: const Text('Anonymous Diagnostics'),
                subtitle: const Text('Share anonymized game usage stats to help improve GridMind.'),
                value: _telemetryEnabled,
                onChanged: (val) async {
                  await _telemetry.setEnabled(val);
                  setState(() {
                    _telemetryEnabled = val;
                  });
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('Read how GridMind handles your data'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: _launchPrivacyPolicy,
              ),
              ListTile(
                key: const Key('settings_reopen_intro'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.help_outline),
                title: const Text('App Walkthrough'),
                subtitle: const Text('Reopen the GridMind introduction'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => showAppIntroDialog(context),
              ),
            ],
          ),

          // --- High Scores Section ---
          _buildSettingsSection(
            theme,
            title: 'High Scores',
            icon: Icons.emoji_events_outlined,
            trailing: IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: _loadingScores ? null : _confirmClearAllScores,
              tooltip: 'Clear All High Scores',
            ),
            children: [
              _loadingScores
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _highScores.entries.where((e) => e.value > 0).isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No high scores recorded yet. Play some games!',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in _highScores.entries)
                              if (entry.value > 0) ...[
                                Builder(
                                  builder: (ctx) {
                                    final gameId = entry.key;
                                    final game = gameId.startsWith('slideandsolve_')
                                        ? _findGameById('slideandsolve')
                                        : _findGameById(gameId);
                                    final title = gameId.startsWith('slideandsolve_')
                                        ? 'Slide ${_gameIdSuffixToLabel(gameId)}'
                                        : (game?.title ?? gameId);
                                    return _buildScoreRow(
                                      theme,
                                      title,
                                      _formatHighScore(gameId, entry.value),
                                      game?.icon ?? Icons.grid_4x4,
                                    );
                                  },
                                ),
                              ],
                          ],
                        ),
            ],
          ),

          const SizedBox(height: 16),

          // --- Feedback Section ---
          _buildSettingsSection(
            theme,
            title: 'Feedback & Bug Reports',
            icon: Icons.feedback_outlined,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.report_problem_outlined),
                title: const Text('Submit Feedback / Report Issue'),
                subtitle: const Text('Report bugs or suggest features (posted as a public GitHub issue)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  final Map<String, dynamic> diagnostics = {
                    'high_scores': Map<String, int>.from(_highScores),
                    'palette_type': _paletteType,
                    'theme_mode': _currentThemeMode.toString(),
                  };
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeedbackScreen(diagnostics: diagnostics),
                    ),
                  );
                },
              ),
            ],
          ),

          // --- Support Section ---
          _buildSettingsSection(
            theme,
            title: 'Support the Developer',
            icon: Icons.favorite,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.coffee, color: Color(0xFF6F4E37)),
                title: const Text('Buy me a Coffee'),
                subtitle: const Text('One-time support via Coff.ee'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _launchCoffeeUrl,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.local_cafe, color: Color(0xFF543075)),
                title: const Text('Support on Ko-fi'),
                subtitle: const Text('One-time or monthly support via Ko-fi'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _launchKofiUrl,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildScoreRow(ThemeData theme, String label, String score, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            score,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Maps the internal palette type string to a human-readable label
  String _paletteTypeLabel(String type) {
    switch (type) {
      case 'preset1': return 'Classic';
      case 'preset2': return 'Pastel';
      case 'preset3': return 'High Contrast';
      case 'preset4': return 'Color Blind';
      case 'custom':  return 'Custom';
      case 'random':  return 'Random';
      default:        return type;
    }
  }

  /// Finds a GameMetadata by ID from the registry, or returns null if not found
  GameMetadata? _findGameById(String gameId) {
    try {
      return GameRegistry.games.firstWhere((g) => g.id == gameId);
    } catch (_) {
      return null;
    }
  }

  /// Converts a slideandsolve suffixed ID (e.g. "slideandsolve_3") to label (e.g. "3x3")
  String _gameIdSuffixToLabel(String gameId) {
    final size = gameId.split('_').last;
    return '${size}x$size';
  }

  /// Formats a high score value based on the game type
  String _formatHighScore(String gameId, int score) {
    if (gameId.startsWith('slideandsolve_')) {
      return score == 0 ? 'N/A' : '$score moves';
    }
    // Default: use the game's scoreFormatter if available
    final game = _findGameById(gameId);
    if (game?.scoreFormatter != null) {
      return game!.scoreFormatter!(score, {});
    }
    return '$score';
  }
}
