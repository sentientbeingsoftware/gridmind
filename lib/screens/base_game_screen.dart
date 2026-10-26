import 'package:flutter/material.dart';
import '../services/telemetry_service.dart';

/// Reusable base game screen shell that provides a premium, unified HUD layout
/// for all mini-games in the GridMind suite.
class BaseGameScreen extends StatefulWidget {
  /// The title of the game (e.g., "Simon Game", "Path Weaver")
  final String title;

  /// Optional label/value for the high score or best score display
  final String? highScoreLabel;
  final String? highScoreValue;

  /// Optional label/value for the current score or current moves display
  final String? currentScoreLabel;
  final String? currentScoreValue;

  /// Current status message or instruction (e.g., "Watch the Pattern", "Your Turn")
  final String? statusText;

  /// Color for the status message text (falls back to primary color if null)
  final Color? statusTextColor;

  /// Indicates if the game is successfully won/completed
  final bool isGameWon;

  /// Indicates if the game is over (loss or no moves left)
  final bool isGameOver;

  /// Message displayed when the game is won
  final String victoryMessage;

  /// Message displayed when the game is over
  final String gameOverMessage;

  /// Extra widget inserted above the main game board (e.g., Target Pattern in Slide & Solve)
  final Widget? topHudExtra;

  /// The main interactive game grid/board widget
  final Widget child;

  /// Callback to reset or restart the game
  final VoidCallback? onReset;

  /// Callback to undo the last move
  final VoidCallback? onUndo;

  /// Callback to show help/instructions dialog
  final VoidCallback? onHelp;

  /// Custom actions displayed in the AppBar
  final List<Widget>? appBarActions;

  /// Flag indicating if the game is currently actively being played
  /// Used to show a confirmation dialog before popping the screen
  final bool isGameInProgress;

  /// Optional game identification string for telemetry
  final String? gameId;

  /// Optional game configuration details for telemetry
  final Map<String, dynamic>? gameConfig;

  const BaseGameScreen({
    super.key,
    required this.title,
    this.highScoreLabel = 'Best',
    this.highScoreValue,
    this.currentScoreLabel = 'Score',
    this.currentScoreValue,
    this.statusText,
    this.statusTextColor,
    this.isGameWon = false,
    this.isGameOver = false,
    this.victoryMessage = 'You Win!',
    this.gameOverMessage = 'Game Over!',
    this.topHudExtra,
    required this.child,
    this.onReset,
    this.onUndo,
    this.onHelp,
    this.appBarActions,
    this.isGameInProgress = false,
    this.gameId,
    this.gameConfig,
  });

  @override
  State<BaseGameScreen> createState() => _BaseGameScreenState();
}

class _BaseGameScreenState extends State<BaseGameScreen> {
  final TelemetryService _telemetry = TelemetryService();
  late DateTime _sessionStartTime;
  late Stopwatch _stopwatch;
  bool _loggedEndEvent = false;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _stopwatch = Stopwatch()..start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _logQuitEvent();
    super.dispose();
  }

  void _logQuitEvent() {
    if (widget.gameId != null && !_loggedEndEvent) {
      if (!widget.isGameWon && !widget.isGameOver) {
        _telemetry
            .logGameSession(
          gameId: widget.gameId!,
          startTime: _sessionStartTime,
          durationSeconds: _stopwatch.elapsed.inSeconds,
          status: 'quit',
          config: widget.gameConfig ?? {},
        )
            .catchError((e) {
          debugPrint('Telemetry logQuitEvent error: $e');
        });
      }
    }
  }

  @override
  void didUpdateWidget(BaseGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameId != null && !_loggedEndEvent) {
      if (widget.isGameWon && !oldWidget.isGameWon) {
        _stopwatch.stop();
        _loggedEndEvent = true;
        _telemetry.logGameSession(
          gameId: widget.gameId!,
          startTime: _sessionStartTime,
          durationSeconds: _stopwatch.elapsed.inSeconds,
          status: 'victory',
          config: widget.gameConfig ?? {},
        );
      } else if (widget.isGameOver && !oldWidget.isGameOver) {
        _stopwatch.stop();
        _loggedEndEvent = true;
        _telemetry.logGameSession(
          gameId: widget.gameId!,
          startTime: _sessionStartTime,
          durationSeconds: _stopwatch.elapsed.inSeconds,
          status: 'game_over',
          config: widget.gameConfig ?? {},
        );
      }
    }
  }

  /// Returns to the main menu (root route), skipping the game's setup screen.
  void _goToMainMenu(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleExit(BuildContext context) async {
    if (widget.isGameInProgress && !widget.isGameWon && !widget.isGameOver) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Exit Game?'),
            ],
          ),
          content: const Text(
              'Are you sure you want to exit? Your current progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Exit'),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        _goToMainMenu(context);
      }
    } else {
      _goToMainMenu(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHighScore =
        widget.highScoreValue != null && widget.highScoreValue!.isNotEmpty;
    final hasCurrentScore = widget.currentScoreValue != null &&
        widget.currentScoreValue!.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to menu',
            onPressed: () => _handleExit(context),
          ),
          actions: [
            if (widget.onHelp != null)
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'How to play',
                onPressed: widget.onHelp,
              ),
            if (widget.onReset != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Restart',
                onPressed: () {
                  _stopwatch.reset();
                  _stopwatch.start();
                  _sessionStartTime = DateTime.now();
                  _loggedEndEvent = false;
                  if (widget.onReset != null) widget.onReset!();
                },
              ),
            ...?widget.appBarActions,
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Unified premium HUD Container
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (hasHighScore)
                          _buildHudStatCard(
                            context,
                            widget.highScoreLabel ?? 'Best',
                            widget.highScoreValue!,
                            Colors.amber.shade700,
                            Icons.emoji_events,
                          ),
                        if (hasCurrentScore)
                          _buildHudStatCard(
                            context,
                            widget.currentScoreLabel ?? 'Score',
                            widget.currentScoreValue!,
                            theme.colorScheme.secondary,
                            Icons.play_circle_outline,
                          ),
                      ],
                    ),
                    if (widget.statusText != null &&
                        !widget.isGameWon &&
                        !widget.isGameOver) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.statusText!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.statusTextColor ??
                                theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Victory / Defeat Overlay banner
              if (widget.isGameWon)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.victoryMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (widget.isGameOver)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.gameOverMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Slide and Solve target grids or other top features
              if (widget.topHudExtra != null) ...[
                const SizedBox(height: 8),
                widget.topHudExtra!,
              ],

              const SizedBox(height: 12),

              // Game board itself
              Expanded(child: widget.child),

              const SizedBox(height: 12),

              // Action buttons row (Undo, Reset, Exit)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (widget.onUndo != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'),
                        onPressed: (widget.isGameWon || widget.isGameOver)
                            ? null
                            : widget.onUndo,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    if (widget.onReset != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Restart'),
                        onPressed: () {
                          _stopwatch.reset();
                          _stopwatch.start();
                          _sessionStartTime = DateTime.now();
                          _loggedEndEvent = false;
                          if (widget.onReset != null) widget.onReset!();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Exit'),
                      onPressed: () => _handleExit(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHudStatCard(
    BuildContext context,
    String label,
    String value,
    Color accentColor,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
