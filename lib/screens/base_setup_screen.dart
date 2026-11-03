import 'package:flutter/material.dart';
import '../models/game_metadata.dart';
import '../services/app_persistence_service.dart';
import '../theme/theme_controller.dart';
import 'walkthrough_dialog.dart';

/// Generic setup screen that dynamically renders setup controls for any game
class BaseSetupScreen extends StatefulWidget {
  final GameMetadata game;

  const BaseSetupScreen({
    super.key,
    required this.game,
  });

  @override
  State<BaseSetupScreen> createState() => _BaseSetupScreenState();
}

class _BaseSetupScreenState extends State<BaseSetupScreen> {
  final AppPersistenceService _persistence = AppPersistenceService();
  Map<String, dynamic> _currentConfig = {};
  int _highScore = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  Future<void> _loadInitialConfig() async {
    final savedConfig = await _persistence.getLastConfig(widget.game.id);
    final mergedConfig = widget.game.resolveConfig(savedConfig);

    if (!mounted) return;
    setState(() {
      _currentConfig = mergedConfig;
    });
    
    await _updateHighScore();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
    // First launch of this game: show the walkthrough once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowWalkthrough(context, widget.game);
    });
  }

  Future<void> _resetWalkthrough() async {
    await _persistence.resetWalkthrough(widget.game.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Walkthrough will show next time you open this game')),
    );
  }

  Future<void> _updateHighScore() async {
    final score = await _persistence.getConfigHighScore(widget.game.id, _currentConfig);
    if (!mounted) return;
    setState(() {
      _highScore = score;
    });
  }

  Future<void> _onOptionChanged(String key, dynamic value) async {
    setState(() {
      _currentConfig[key] = value;
      _currentConfig = widget.game.resolveConfig(_currentConfig); // re-apply dependent caps
    });
    await _persistence.setLastConfig(widget.game.id, _currentConfig);
    if (!mounted) return;
    await _updateHighScore();
  }

  void _startGame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => widget.game.gameBuilder(context, _currentConfig),
      ),
    ).then((_) {
      // Re-load high score when returning to the setup screen
      _updateHighScore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return _buildScaffold(context, null);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildScaffold(
        context,
        controller.backgroundFor(Theme.of(context).brightness),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, Color? background) {
    if (_loading) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final hasHighScore = _highScore > 0;
    final formattedScore = widget.game.scoreFormatter != null 
        ? widget.game.scoreFormatter!(_highScore, _currentConfig)
        : _highScore.toString();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text('${widget.game.title} - Setup'),
        elevation: 0,
        backgroundColor: background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            key: const Key('walkthrough_show'),
            tooltip: 'Show walkthrough',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showWalkthroughDialog(context, widget.game),
          ),
          IconButton(
            key: const Key('walkthrough_reset'),
            tooltip: 'Reset walkthrough (show on next launch)',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetWalkthrough,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0).copyWith(bottom: 24.0 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Description Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Icon(widget.game.icon, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.game.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.game.category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.game.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // High Score Banner
            if (hasHighScore)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  border: Border.all(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: theme.colorScheme.tertiary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Personal Best: $formattedScore',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Configuration Options Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'Customize Board Rules',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ...widget.game.configOptions.map((option) {
                      final currentVal = _currentConfig[option.key];
                      final shown = option is SliderConfigOption && option.maxFor != null
                          ? option.withMax(option.maxFor!(_currentConfig).clamp(option.min, option.max))
                          : option;
                      return shown.buildControl(
                        context, 
                        currentVal, 
                        (newVal) => _onOptionChanged(option.key, newVal),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Start Game
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text('Start Game'),
                onPressed: _startGame,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
