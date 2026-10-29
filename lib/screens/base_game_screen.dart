import '../utils/game_pause.dart';
import 'settings_screen.dart';
import '../services/game_effects.dart';
import 'dart:math';
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
  /// False when the score slot is a live countdown, so it must not tap every second.
  final bool tickOnScoreChange;
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
    this.tickOnScoreChange = true,
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

  Future<void> _openSettings() async {
    // The game stays mounted underneath; hold its timers and the session clock meanwhile.
    GamePause.paused.value = true;
    _stopwatch.stop();
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } finally {
      GamePause.paused.value = false;
      if (mounted) _stopwatch.start();
    }
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
    if (widget.isGameWon && !oldWidget.isGameWon) {
      GameEffects.instance.win();
    } else if (widget.isGameOver && !oldWidget.isGameOver) {
      GameEffects.instance.lose();
    } else if (widget.tickOnScoreChange &&
        widget.currentScoreValue != oldWidget.currentScoreValue &&
        !widget.isGameWon &&
        !widget.isGameOver) {
      GameEffects.instance.tick(); // any score/move change = one light tap
    }
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
    // Short screens (compact phones, small desktop windows) get tighter chrome
    // so the board keeps as much room as possible.
    final compact = MediaQuery.sizeOf(context).height < _kCompactHeight;
    final gap = compact ? 6.0 : 12.0;
    final buttonPadding =
        EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 8 : 12);

    final Widget hudBox = Container(
                margin: EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: compact ? 4.0 : 8.0),
                padding: EdgeInsets.all(compact ? 8.0 : 12.0),
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
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      runAlignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (hasHighScore)
                          _buildHudStatCard(
                            context,
                            widget.highScoreLabel ?? 'Best',
                            widget.highScoreValue!,
                            Colors.amber.shade700,
                            Icons.emoji_events,
                            compact: compact,
                          ),
                        if (hasCurrentScore)
                          _buildHudStatCard(
                            context,
                            widget.currentScoreLabel ?? 'Score',
                            widget.currentScoreValue!,
                            theme.colorScheme.secondary,
                            Icons.play_circle_outline,
                            compact: compact,
                          ),
                      ],
                    ),
                    if (widget.statusText != null &&
                        !widget.isGameWon &&
                        !widget.isGameOver) ...[
                      SizedBox(height: compact ? 4 : 8),
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
              );

    final List<Widget> bannerList = <Widget>[
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
    ];

    final Widget buttonsRow = Padding(
                padding: EdgeInsets.fromLTRB(
                    16, compact ? 4 : 16, 16, compact ? 8 : 16),
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  runAlignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (widget.onUndo != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'),
                        onPressed: (widget.isGameWon || widget.isGameOver)
                            ? null
                            : widget.onUndo,
                        style: ElevatedButton.styleFrom(padding: buttonPadding),
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
                        style: ElevatedButton.styleFrom(padding: buttonPadding),
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Exit'),
                      onPressed: () => _handleExit(context),
                      style: ElevatedButton.styleFrom(
                        padding: buttonPadding,
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );

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
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              // A pushed route keeps this screen's state, so the game resumes where it was.
              onPressed: _openSettings,
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // Wide, landscape-ish windows (desktop, Play Games on PC,
              // tablets): stats and buttons in a side panel, board on the right.
              final wide = box.maxWidth >= _kWideWidth &&
                  box.maxWidth >= box.maxHeight * 1.2;
              if (wide) {
                final panelWidth = min(380.0, box.maxWidth * 0.38);
                return Row(
                  children: [
                    SizedBox(
                      width: panelWidth,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            hudBox,
                            ...bannerList,
                            SizedBox(height: gap),
                            buttonsRow,
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      // Boards that size themselves from MediaQuery must see the
                      // board area, not the whole window.
                      child: LayoutBuilder(
                        builder: (context, area) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              size: Size(area.maxWidth, area.maxHeight)),
                          child: _FitToHeight(
                            topExtra: widget.topHudExtra,
                            gap: gap,
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              // Portrait: below _kMinBodyHeight (tiny window or very large
              // text) the whole screen scrolls; above it scrolling is off so
              // board drags are safe.
              return SingleChildScrollView(
                physics: box.maxHeight >= _kMinBodyHeight
                    ? const NeverScrollableScrollPhysics()
                    : null,
                child: SizedBox(
                  width: double.infinity,
                  height: max(box.maxHeight, _kMinBodyHeight),
                  child: Column(
                    children: [
                      hudBox,
                      ...bannerList,
                      // Game area: optional top extra plus the board, scaled
                      // down to fit when the screen is short.
                      Expanded(
                        child: _FitToHeight(
                          topExtra: widget.topHudExtra,
                          gap: gap,
                          child: widget.child,
                        ),
                      ),
                      SizedBox(height: gap),
                      buttonsRow,
                    ],
                  ),
                ),
              );
            },
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
    IconData icon, {
    bool compact = false,
  }) {
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
          padding: EdgeInsets.symmetric(
              horizontal: 16.0, vertical: compact ? 6.0 : 10.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Windows at least this wide (and wider than tall) use the side-panel layout.
const double _kWideWidth = 720;

/// Below this body height the whole screen scrolls instead of overflowing.
const double _kMinBodyHeight = 540;

/// Screens shorter than this (in logical pixels) use tighter spacing.
const double _kCompactHeight = 740;

/// Height the game area is laid out at when the real area is shorter. Boards
/// and their controls are designed for at least this much room.
const double _kDesignHeight = 480;

/// Below this scale the content would be too small to use, so it scrolls
/// vertically instead of shrinking further.
const double _kMinScale = 0.55;

/// Lays out [topExtra] and [child] as if the area were at least
/// [_kDesignHeight] tall, then scales the result down to the real height.
///
/// When the area is at least [_kDesignHeight] tall nothing is scaled. [child]
/// always gets bounded constraints, so games that use `Expanded` or
/// `LayoutBuilder` keep working.
class _FitToHeight extends StatelessWidget {
  const _FitToHeight({
    required this.topExtra,
    required this.gap,
    required this.child,
  });

  final Widget? topExtra;
  final double gap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        Widget content(double h) => SizedBox(
              width: width,
              height: h,
              child: Column(
                children: [
                  if (topExtra != null) ...[
                    SizedBox(height: gap * 2 / 3),
                    topExtra!,
                  ],
                  SizedBox(height: gap),
                  Expanded(child: child),
                ],
              ),
            );

        if (height >= _kDesignHeight) return content(height);

        if (height / _kDesignHeight >= _kMinScale) {
          return FittedBox(child: content(_kDesignHeight));
        }
        // Extremely short area: keep a readable size and let it scroll.
        return SingleChildScrollView(
          child: SizedBox(
            width: width,
            height: _kDesignHeight * _kMinScale,
            child: FittedBox(child: content(_kDesignHeight)),
          ),
        );
      },
    );
  }
}
