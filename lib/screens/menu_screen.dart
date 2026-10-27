import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';
import '../models/game_metadata.dart';
import '../services/game_registry.dart';
import 'base_setup_screen.dart';
import '../services/app_persistence_service.dart';
import 'settings_screen.dart';
import 'telemetry_consent_dialog.dart';
import 'walkthrough_dialog.dart';

/// Main menu screen that provides navigation to all available games
/// Displays buttons for each game type and settings
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final AppPersistenceService _persistence = AppPersistenceService();
  final Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showTelemetryConsentIfNeeded(context);
      if (!mounted) return;
      await maybeShowAppIntro(context);
    });
  }

  Future<void> _loadFavorites() async {
    final favs = await _persistence.getFavorites();
    if (mounted) {
      setState(() {
        _favorites
          ..clear()
          ..addAll(favs);
      });
    }
  }

  Future<void> _toggleFavorite(String gameId) async {
    final updated = await _persistence.toggleFavorite(gameId);
    if (mounted) {
      setState(() {
        _favorites
          ..clear()
          ..addAll(updated);
      });
    }
  }

  /// Sorts a list of games so favorited ones appear first, preserving
  /// original order within each group.
  List<GameMetadata> _sortFavoritesFirst(List<GameMetadata> games) {
    final favorited = <GameMetadata>[];
    final notFavorited = <GameMetadata>[];
    for (final g in games) {
      if (_favorites.contains(g.id)) {
        favorited.add(g);
      } else {
        notFavorited.add(g);
      }
    }
    return [...favorited, ...notFavorited];
  }

  /// GameRegistry.games is static, so the grouping never changes at runtime.
  static final Map<String, List<GameMetadata>> _categorizedGames = () {
    final grouped = <String, List<GameMetadata>>{};
    for (final game in GameRegistry.games) {
      grouped.putIfAbsent(game.category, () => []).add(game);
    }
    return grouped;
  }();

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
    final categorizedGames = _categorizedGames;

    final theme = Theme.of(context);

    // Collect all favorited games across categories for the top section
    final allFavorited = categorizedGames.values
        .expand((list) => list)
        .where((g) => _favorites.contains(g.id))
        .toList();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: const Text('Grid Mind', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header banner
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Brain-Training Grid Puzzles',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${GameRegistry.games.length} games across ${categorizedGames.length} categories. Find your favorites and challenge your mind!',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Favorites section at the top (only if any favorites exist)
          if (allFavorited.isNotEmpty) ...[
            _buildSectionHeader(theme, 'Favorites', allFavorited.length),
            ...allFavorited.map((game) => _buildGameTile(game, theme)),
            const SizedBox(height: 8),
          ],

          // Category sections
          ...categorizedGames.entries.map((entry) {
            final category = entry.key;
            final games = _sortFavoritesFirst(entry.value);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(theme, category, games.length),
                ...games.map((game) => _buildGameTile(game, theme)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.4),
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTile(GameMetadata game, ThemeData theme) {
    final isFavorited = _favorites.contains(game.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(game.icon, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                game.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isFavorited)
              const Icon(
                Icons.favorite,
                color: Colors.redAccent,
                size: 16,
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            game.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFavorited ? Icons.star : Icons.star_outline,
                color: isFavorited
                    ? Colors.amber
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                size: 22,
              ),
              onPressed: () => _toggleFavorite(game.id),
              tooltip: isFavorited ? 'Unfavorite' : 'Favorite',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(6),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BaseSetupScreen(game: game),
            ),
          );
        },
      ),
    );
  }
}
