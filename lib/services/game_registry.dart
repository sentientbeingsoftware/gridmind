import 'package:flutter/material.dart';
import '../models/game_metadata.dart';
import '../models/pattern_speed.dart';
import '../models/collapse_models.dart';
import '../screens/simon_game_screen.dart';
import '../screens/slide_and_solve_game_screen.dart';
import '../screens/collapse_game_screen.dart';
import '../screens/path_weaver_game_screen.dart';
import '../screens/sum_grid_game_screen.dart';
import '../screens/binary_lights_game_screen.dart';
import '../screens/pattern_echo_game_screen.dart';
import '../screens/missing_piece_game_screen.dart';
import '../screens/sequence_trail_game_screen.dart';
import '../screens/grid_painter_game_screen.dart';
import '../screens/mirror_match_game_screen.dart';
import '../screens/shape_shift_game_screen.dart';
import '../screens/color_flood_game_screen.dart';
import '../screens/grid_runner_game_screen.dart';
import '../screens/chain_reaction_game_screen.dart';
import '../screens/rotate_matrix_game_screen.dart';
import '../screens/pulse_game_screen.dart';
import '../screens/grid_miner_game_screen.dart';
import '../screens/gravity_shift_game_screen.dart';
import '../screens/territory_game_screen.dart';
import '../screens/cluster_game_screen.dart';
import '../screens/word_search_game_screen.dart';

/// Registry holding game schemas and builders for launching all games
class GameRegistry {
  static final List<GameMetadata> games = [
    GameMetadata(
      id: 'simon',
      title: 'Simon Game',
      description:
          'A classic memory game where players repeat increasingly longer flashing color sequences.',
      icon: Icons.memory,
      category: 'Memory & Pattern Recognition',
      lowerIsBetter: false,
      scoreFormatter: (s, _) => '$s rounds',
      configOptions: [
        SliderConfigOption(
          key: 'numberOfSquares',
          label: 'Number of Buttons',
          defaultValue: 4.0,
          min: 2.0,
          max: 9.0,
          divisions: 7,
        ),
        DropdownConfigOption<PatternSpeed>(
          key: 'patternSpeed',
          label: 'Pattern Speed',
          defaultValue: PatternSpeed.normal,
          items: const [
            DropdownMenuItem(value: PatternSpeed.slow, child: Text('Slow')),
            DropdownMenuItem(value: PatternSpeed.normal, child: Text('Normal')),
            DropdownMenuItem(value: PatternSpeed.fast, child: Text('Fast')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final squares = (config['numberOfSquares'] is num)
            ? (config['numberOfSquares'] as num).round()
            : int.tryParse(config['numberOfSquares']?.toString() ?? '') ?? 4;
        final speedVal = config['patternSpeed'];
        PatternSpeed speed = PatternSpeed.normal;
        if (speedVal is PatternSpeed) {
          speed = speedVal;
        } else if (speedVal != null) {
          speed = PatternSpeed.values.firstWhere(
            (e) => e.toString().split('.').last == speedVal.toString(),
            orElse: () => PatternSpeed.normal,
          );
        }
        return SimonGameScreen(numberOfSquares: squares, patternSpeed: speed);
      },
    ),
    GameMetadata(
      id: 'slideandsolve',
      title: 'Slide and Solve',
      description:
          'Slide rows and columns to match a side-by-side target configuration.',
      icon: Icons.grid_4x4,
      category: 'Spatial Puzzle Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 3.0,
          min: 3.0,
          max: 5.0,
          divisions: 2,
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 3;
        return SlideAndSolveGameScreen(gridSize: size);
      },
    ),
    GameMetadata(
      id: 'collapse',
      title: 'Collapse',
      description:
          'Match-3 style block clearing game with customizable rules and multi-directional gravity.',
      icon: Icons.blur_on,
      category: 'Spatial Puzzle Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 8.0,
          min: 5.0,
          max: 12.0,
          divisions: 7,
        ),
        DropdownConfigOption<CollapseMechanic>(
          key: 'mechanic',
          label: 'Gravity Mechanic',
          defaultValue: CollapseMechanic.fromTop,
          items: const [
            DropdownMenuItem(
                value: CollapseMechanic.fromTop, child: Text('Fall from Top')),
            DropdownMenuItem(
                value: CollapseMechanic.fromBottom,
                child: Text('Fall from Bottom')),
            DropdownMenuItem(
                value: CollapseMechanic.fromLeft,
                child: Text('Fall from Left')),
            DropdownMenuItem(
                value: CollapseMechanic.fromRight,
                child: Text('Fall from Right')),
          ],
        ),
        SliderConfigOption(
          key: 'targetScore',
          label: 'Target Score',
          defaultValue: 1000.0,
          min: 500.0,
          max: 5000.0,
          divisions: 9,
        ),
        SliderConfigOption(
          key: 'minMatchCount',
          label: 'Min Match Count',
          defaultValue: 3.0,
          min: 3.0,
          max: 5.0,
          divisions: 2,
        ),
        SliderConfigOption(
          key: 'moves',
          label: 'Moves Limit',
          defaultValue: 25.0,
          min: 10.0,
          max: 50.0,
          divisions: 8,
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 8;

        final mechVal = config['mechanic'];
        CollapseMechanic mech = CollapseMechanic.fromTop;
        if (mechVal is CollapseMechanic) {
          mech = mechVal;
        } else if (mechVal != null) {
          mech = CollapseMechanic.values.firstWhere(
            (e) => e.toString().split('.').last == mechVal.toString(),
            orElse: () => CollapseMechanic.fromTop,
          );
        }

        final target = (config['targetScore'] is num)
            ? (config['targetScore'] as num).round()
            : int.tryParse(config['targetScore']?.toString() ?? '') ?? 1000;

        final minMatch = (config['minMatchCount'] is num)
            ? (config['minMatchCount'] as num).round()
            : int.tryParse(config['minMatchCount']?.toString() ?? '') ?? 3;

        final moves = (config['moves'] is num)
            ? (config['moves'] as num).round()
            : int.tryParse(config['moves']?.toString() ?? '') ?? 25;

        final customLevel = CollapseLevel(
          name: 'Custom Play',
          levelNumber: 0,
          gridSize: size,
          mechanic: mech,
          targetScore: target,
          availableColors: kAllPossibleBlockColors.sublist(0, 5),
          minMatchCount: minMatch,
          moves: moves,
        );
        return CollapseGameScreen(level: customLevel);
      },
    ),
    GameMetadata(
      id: 'pathweaver',
      title: 'Path Weaver',
      description:
          'Route a path from start to end past obstacles with power-ups and one-way walls.',
      icon: Icons.alt_route,
      category: 'Spatial Puzzle Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 7.0,
          min: 5.0,
          max: 12.0,
          divisions: 7,
        ),
        SliderConfigOption(
          key: 'obstacleDensity',
          label: 'Obstacle Density',
          defaultValue: 0.15,
          min: 0.0,
          max: 0.40,
          divisions: 8,
          labelFormatter: (v) => '${(v * 100).round()}%',
        ),
        SwitchConfigOption(
          key: 'oneWayPaths',
          label: 'Enable One-Way Paths',
          defaultValue: false,
        ),
        SwitchConfigOption(
          key: 'powerUps',
          label: 'Enable Power-Ups',
          defaultValue: true,
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 7;

        final obs = (config['obstacleDensity'] is num)
            ? (config['obstacleDensity'] as num).toDouble()
            : double.tryParse(config['obstacleDensity']?.toString() ?? '') ??
                0.15;

        final oneWay =
            config['oneWayPaths'] == true || config['oneWayPaths'] == 'true';
        final power =
            config['powerUps'] == true || config['powerUps'] == 'true';

        return PathWeaverGameScreen(
          gridSize: size,
          obstacleDensity: obs,
          oneWayPaths: oneWay,
          powerUps: power,
        );
      },
    ),
    GameMetadata(
      id: 'sumgrid',
      title: 'Sum Grid',
      description:
          'Select adjacent numbers to add up to the target sum before running out of time or moves.',
      icon: Icons.add_box,
      category: 'Logic & Arithmetic Games',
      lowerIsBetter: false,
      scoreFormatter: (s, config) {
        final mode = config['gameMode']?.toString() ?? 'timed';
        return mode == 'classic' ? '$s moves' : '$s points';
      },
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 5.0,
          min: 4.0,
          max: 8.0,
          divisions: 4,
        ),
        DropdownConfigOption<String>(
          key: 'gameMode',
          label: 'Game Mode',
          defaultValue: 'timed',
          items: const [
            DropdownMenuItem(value: 'timed', child: Text('Timed Mode')),
            DropdownMenuItem(value: 'classic', child: Text('Classic Mode')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'targetMode',
          label: 'Target Formula',
          defaultValue: 'random',
          items: const [
            DropdownMenuItem(value: 'fixed', child: Text('Fixed Target (10)')),
            DropdownMenuItem(
                value: 'random', child: Text('Random Targets (10-22)')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 5;
        final mode = config['gameMode']?.toString() ?? 'timed';
        final target = config['targetMode']?.toString() ?? 'random';
        return SumGridGameScreen(
          gridSize: size,
          gameMode: mode,
          targetMode: target,
        );
      },
    ),
    GameMetadata(
      id: 'binarylights',
      title: 'Binary Lights',
      description:
          'Toggle cells and their neighbors to match a target pattern or turn all lights off.',
      icon: Icons.lightbulb,
      category: 'Spatial Puzzle Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 3.0,
          max: 6.0,
          divisions: 3,
        ),
        DropdownConfigOption<String>(
          key: 'gameMode',
          label: 'Game Mode',
          defaultValue: 'classic',
          items: const [
            DropdownMenuItem(
                value: 'classic', child: Text('Classic (All Off)')),
            DropdownMenuItem(value: 'pattern', child: Text('Pattern Match')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Limit',
          defaultValue: 'zen',
          items: const [
            DropdownMenuItem(value: 'zen', child: Text('Zen Mode (Unlimited)')),
            DropdownMenuItem(value: 'challenge', child: Text('Challenge Mode')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final mode = config['gameMode']?.toString() ?? 'classic';
        final move = config['moveMode']?.toString() ?? 'zen';
        return BinaryLightsGameScreen(
          gridSize: size,
          gameMode: mode,
          moveMode: move,
        );
      },
    ),
    GameMetadata(
      id: 'pattern_echo',
      title: 'Pattern Echo',
      description:
          'Recreate briefly illuminated patterns. Turn up complexity with mental or visual rotation and mirrors.',
      icon: Icons.repeat_on,
      category: 'Memory & Pattern Recognition',
      lowerIsBetter: false,
      scoreFormatter: (s, _) => '$s points',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 3.0,
          max: 5.0,
          divisions: 2,
        ),
        DropdownConfigOption<String>(
          key: 'transformationMode',
          label: 'Transformation Mode',
          defaultValue: 'mixed',
          items: const [
            DropdownMenuItem(
                value: 'none', child: Text('Normal (No Transform)')),
            DropdownMenuItem(value: 'rotate', child: Text('Rotated Patterns')),
            DropdownMenuItem(value: 'mirror', child: Text('Mirrored Patterns')),
            DropdownMenuItem(
                value: 'mixed', child: Text('Mixed Transformations')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'displayMode',
          label: 'Game Style',
          defaultValue: 'mental',
          items: const [
            DropdownMenuItem(
                value: 'mental', child: Text('Mental (Mentally Rotate)')),
            DropdownMenuItem(
                value: 'visual',
                child: Text('Visual (Grid Rotates on Screen)')),
          ],
        ),
        SliderConfigOption(
          key: 'lives',
          label: 'Lives Limit',
          defaultValue: 3.0,
          min: 1.0,
          max: 5.0,
          divisions: 4,
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final trans = config['transformationMode']?.toString() ?? 'mixed';
        final display = config['displayMode']?.toString() ?? 'mental';
        final lives = (config['lives'] is num)
            ? (config['lives'] as num).round()
            : int.tryParse(config['lives']?.toString() ?? '') ?? 3;
        return PatternEchoGameScreen(
          gridSize: size,
          transformationMode: trans,
          displayMode: display,
          lives: lives,
        );
      },
    ),
    GameMetadata(
      id: 'missing_piece',
      title: 'Missing Piece',
      description:
          'Memorize a grid pattern of numbers or colors. Then, identify the missing parts.',
      icon: Icons.extension,
      category: 'Memory & Pattern Recognition',
      lowerIsBetter: false,
      scoreFormatter: (s, _) => '$s points',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 3.0,
          min: 3.0,
          max: 5.0,
          divisions: 2,
        ),
        DropdownConfigOption<String>(
          key: 'contentType',
          label: 'Content Type',
          defaultValue: 'numbers',
          items: const [
            DropdownMenuItem(value: 'numbers', child: Text('Numbers (1-9)')),
            DropdownMenuItem(
                value: 'colors', child: Text('Colors (Theme Colors)')),
          ],
        ),
        SliderConfigOption(
          key: 'initialHiddenCount',
          label: 'Initial Missing Pieces',
          defaultValue: 1.0,
          min: 1.0,
          max: 4.0,
          divisions: 3,
        ),
        SliderConfigOption(
          key: 'lives',
          label: 'Lives Limit',
          defaultValue: 3.0,
          min: 1.0,
          max: 5.0,
          divisions: 4,
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 3;
        final type = config['contentType']?.toString() ?? 'numbers';
        final hidden = (config['initialHiddenCount'] is num)
            ? (config['initialHiddenCount'] as num).round()
            : int.tryParse(config['initialHiddenCount']?.toString() ?? '') ?? 1;
        final lives = (config['lives'] is num)
            ? (config['lives'] as num).round()
            : int.tryParse(config['lives']?.toString() ?? '') ?? 3;
        return MissingPieceGameScreen(
          gridSize: size,
          contentType: type,
          initialHiddenCount: hidden,
          lives: lives,
        );
      },
    ),
    GameMetadata(
      id: 'sequence_trail',
      title: 'Sequence Trail',
      description:
          'Tap numbers in ascending order before their individual countdown timers run out.',
      icon: Icons.onetwothree,
      category: 'Memory & Pattern Recognition',
      lowerIsBetter: false,
      scoreFormatter: (s, _) => '$s points',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 3.0,
          max: 5.0,
          divisions: 2,
        ),
        SliderConfigOption(
          key: 'timeLimit',
          label: 'Time Limit (Seconds per Tile)',
          defaultValue: 5.0,
          min: 2.0,
          max: 8.0,
          divisions: 6,
        ),
        SwitchConfigOption(
          key: 'enableDecoys',
          label: 'Enable Decoy Tiles (X)',
          defaultValue: false,
        ),
        SwitchConfigOption(
          key: 'enableMoving',
          label: 'Enable Teleporting Numbers',
          defaultValue: false,
        ),
        SliderConfigOption(
          key: 'lives',
          label: 'Lives Limit',
          defaultValue: 3.0,
          min: 1.0,
          max: 5.0,
          divisions: 4,
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final time = (config['timeLimit'] is num)
            ? (config['timeLimit'] as num).toDouble()
            : double.tryParse(config['timeLimit']?.toString() ?? '') ?? 5.0;
        final decoys =
            config['enableDecoys'] == true || config['enableDecoys'] == 'true';
        final moving =
            config['enableMoving'] == true || config['enableMoving'] == 'true';
        final lives = (config['lives'] is num)
            ? (config['lives'] as num).round()
            : int.tryParse(config['lives']?.toString() ?? '') ?? 3;
        return SequenceTrailGameScreen(
          gridSize: size,
          timeLimit: time,
          enableDecoys: decoys,
          enableMoving: moving,
          lives: lives,
        );
      },
    ),
    GameMetadata(
      id: 'grid_painter',
      title: 'Grid Painter',
      description:
          'Draw target patterns on a grid using a moving paintbrush. Optimize moves to match the blueprint exactly.',
      icon: Icons.format_paint,
      category: 'Spatial Puzzle Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 5.0,
          min: 3.0,
          max: 6.0,
          divisions: 3,
        ),
        DropdownConfigOption<String>(
          key: 'gameMode',
          label: 'Game Mode',
          defaultValue: 'show',
          items: const [
            DropdownMenuItem(
                value: 'show', child: Text('Show Target Blueprint')),
            DropdownMenuItem(
                value: 'picross', child: Text('Pure Picross (Clues Only)')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Limit',
          defaultValue: 'zen',
          items: const [
            DropdownMenuItem(value: 'zen', child: Text('Zen Mode (Unlimited)')),
            DropdownMenuItem(value: 'challenge', child: Text('Challenge Mode')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 5;
        final mode = config['gameMode']?.toString() ?? 'show';
        final move = config['moveMode']?.toString() ?? 'zen';
        return GridPainterGameScreen(
          gridSize: size,
          gameMode: mode,
          moveMode: move,
        );
      },
    ),
    GameMetadata(
      id: 'mirror_match',
      title: 'Mirror Match',
      description:
          'Manipulate half of the grid so that it mirrors the other half perfectly.',
      icon: Icons.flip,
      category: 'Spatial Puzzle Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 4.0,
          max: 12.0,
          divisions: 4,
        ),
        DropdownConfigOption<String>(
          key: 'symmetryType',
          label: 'Symmetry Line',
          defaultValue: 'vertical',
          items: const [
            DropdownMenuItem(
                value: 'vertical', child: Text('Vertical (Left-Right)')),
            DropdownMenuItem(
                value: 'horizontal', child: Text('Horizontal (Top-Bottom)')),
            DropdownMenuItem(
                value: 'rotational', child: Text('Rotational (Center-Point)')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Limit',
          defaultValue: 'zen',
          items: const [
            DropdownMenuItem(value: 'zen', child: Text('Zen Mode (Unlimited)')),
            DropdownMenuItem(value: 'challenge', child: Text('Challenge Mode')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final sym = config['symmetryType']?.toString() ?? 'vertical';
        final move = config['moveMode']?.toString() ?? 'zen';
        return MirrorMatchGameScreen(
          gridSize: size,
          symmetryType: sym,
          moveMode: move,
        );
      },
    ),
    GameMetadata(
      id: 'shape_shift',
      title: 'Shape Shift',
      description:
          'Swap adjacent tiles to match the target color grid configuration.',
      icon: Icons.swap_horizontal_circle_outlined,
      category: 'Spatial Puzzle Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 3.0,
          min: 3.0,
          max: 5.0,
          divisions: 2,
        ),
        SliderConfigOption(
          key: 'colorCount',
          label: 'Color Count',
          defaultValue: 3.0,
          min: 2.0,
          max: 4.0,
          divisions: 2,
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Limit',
          defaultValue: 'zen',
          items: const [
            DropdownMenuItem(value: 'zen', child: Text('Zen Mode (Unlimited)')),
            DropdownMenuItem(value: 'challenge', child: Text('Challenge Mode')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 3;
        final colors = (config['colorCount'] is num)
            ? (config['colorCount'] as num).round()
            : int.tryParse(config['colorCount']?.toString() ?? '') ?? 3;
        final move = config['moveMode']?.toString() ?? 'zen';
        return ShapeShiftGameScreen(
          gridSize: size,
          colorCount: colors,
          moveMode: move,
        );
      },
    ),
    GameMetadata(
      id: 'color_flood',
      title: 'Color Flood',
      description:
          'Flood-fill the board with a single color starting from the top-left cell.',
      icon: Icons.water_drop_outlined,
      category: 'Fast Arcade Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 8.0,
          min: 4.0,
          max: 30.0,
          divisions: 26,
        ),
        SliderConfigOption(
          key: 'colorCount',
          label: 'Color Count',
          defaultValue: 4.0,
          min: 3.0,
          max: 14.0,
          divisions: 11,
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Limit',
          defaultValue: 'zen',
          items: const [
            DropdownMenuItem(value: 'zen', child: Text('Zen Mode (Unlimited)')),
            DropdownMenuItem(value: 'challenge', child: Text('Challenge Mode')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 8;
        final colors = (config['colorCount'] is num)
            ? (config['colorCount'] as num).round()
            : int.tryParse(config['colorCount']?.toString() ?? '') ?? 4;
        final move = config['moveMode']?.toString() ?? 'zen';
        return ColorFloodGameScreen(
          gridSize: size,
          colorCount: colors,
          moveMode: move,
        );
      },
    ),
    GameMetadata(
      id: 'grid_runner',
      title: 'Grid Runner',
      description:
          'Navigate the grid to collect gems without hitting the walls or crossing your own trail.',
      icon: Icons.directions_run_outlined,
      category: 'Fast Arcade Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s steps',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 8.0,
          min: 6.0,
          max: 12.0,
          divisions: 3,
        ),
        DropdownConfigOption<String>(
          key: 'speed',
          label: 'Speed',
          defaultValue: 'normal',
          items: const [
            DropdownMenuItem(value: 'slow', child: Text('Slow (500ms)')),
            DropdownMenuItem(value: 'normal', child: Text('Normal (350ms)')),
            DropdownMenuItem(value: 'fast', child: Text('Fast (200ms)')),
          ],
        ),
        SliderConfigOption(
          key: 'gemCount',
          label: 'Gems to Collect',
          defaultValue: 4.0,
          min: 2.0,
          max: 8.0,
          divisions: 6,
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 8;
        final speed = config['speed']?.toString() ?? 'normal';
        final gems = (config['gemCount'] is num)
            ? (config['gemCount'] as num).round()
            : int.tryParse(config['gemCount']?.toString() ?? '') ?? 4;
        return GridRunnerGameScreen(
          gridSize: size,
          speed: speed,
          gemCount: gems,
        );
      },
    ),
    GameMetadata(
      id: 'chain_reaction',
      title: 'Chain Reaction',
      description:
          'Trigger explosive chain reactions to clear the board with limited taps.',
      icon: Icons.flash_on_outlined,
      category: 'Fast Arcade Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s taps',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 6.0,
          min: 5.0,
          max: 8.0,
          divisions: 3,
        ),
        DropdownConfigOption<String>(
          key: 'difficulty',
          label: 'Difficulty',
          defaultValue: 'medium',
          items: const [
            DropdownMenuItem(
                value: 'easy', child: Text('Easy (Low density, more taps)')),
            DropdownMenuItem(value: 'medium', child: Text('Medium (Normal)')),
            DropdownMenuItem(
                value: 'hard', child: Text('Hard (High density, tight taps)')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Mode',
          defaultValue: 'challenge',
          items: const [
            DropdownMenuItem(
                value: 'zen', child: Text('Zen Mode (Unlimited taps)')),
            DropdownMenuItem(
                value: 'challenge',
                child: Text('Challenge Mode (Limited taps)')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 6;
        final difficulty = config['difficulty']?.toString() ?? 'medium';
        final moveMode = config['moveMode']?.toString() ?? 'challenge';
        return ChainReactionGameScreen(
          gridSize: size,
          difficulty: difficulty,
          moveMode: moveMode,
        );
      },
    ),
    GameMetadata(
      id: 'rotate_matrix',
      title: 'Rotate Matrix',
      description:
          'Spin quadrant sections of the grid to match a target pattern.',
      icon: Icons.rotate_right_outlined,
      category: 'Transformation Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 4.0,
          max: 10.0,
          divisions: 3,
        ),
        DropdownConfigOption<String>(
          key: 'difficulty',
          label: 'Difficulty',
          defaultValue: 'medium',
          items: const [
            DropdownMenuItem(
                value: 'easy', child: Text('Easy (3-4 scramble steps)')),
            DropdownMenuItem(
                value: 'medium', child: Text('Medium (5 scramble steps)')),
            DropdownMenuItem(
                value: 'hard', child: Text('Hard (8 scramble steps)')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Mode',
          defaultValue: 'challenge',
          items: const [
            DropdownMenuItem(
                value: 'zen', child: Text('Zen Mode (Unlimited moves)')),
            DropdownMenuItem(
                value: 'challenge',
                child: Text('Challenge Mode (Limited moves)')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final difficulty = config['difficulty']?.toString() ?? 'medium';
        final moveMode = config['moveMode']?.toString() ?? 'challenge';
        return RotateMatrixGameScreen(
          gridSize: size,
          difficulty: difficulty,
          moveMode: moveMode,
        );
      },
    ),
    GameMetadata(
      id: 'gravity_shift',
      title: 'Gravity Shift',
      description: 'Slide tiles under gravity to match a target pattern.',
      icon: Icons.arrow_upward,
      category: 'Transformation Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 4.0,
          max: 10.0,
          divisions: 3,
        ),
        DropdownConfigOption<String>(
          key: 'difficulty',
          label: 'Difficulty',
          defaultValue: 'medium',
          items: const [
            DropdownMenuItem(
                value: 'easy', child: Text('Easy (3 scramble steps)')),
            DropdownMenuItem(
                value: 'medium', child: Text('Medium (5 scramble steps)')),
            DropdownMenuItem(
                value: 'hard', child: Text('Hard (8 scramble steps)')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Mode',
          defaultValue: 'challenge',
          items: const [
            DropdownMenuItem(
                value: 'zen', child: Text('Zen Mode (Unlimited moves)')),
            DropdownMenuItem(
                value: 'challenge',
                child: Text('Challenge Mode (Limited moves)')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final difficulty = config['difficulty']?.toString() ?? 'medium';
        final moveMode = config['moveMode']?.toString() ?? 'challenge';
        return GravityShiftGameScreen(
          gridSize: size,
          difficulty: difficulty,
          moveMode: moveMode,
        );
      },
    ),
    GameMetadata(
      id: 'pulse',
      title: 'Pulse',
      description: 'Timed rhythmic taps matching a grid wave.',
      icon: Icons.access_time,
      category: 'Transformation Games',
      lowerIsBetter: false,
      scoreFormatter: (s, _) => '$s taps',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 4.0,
          max: 6.0,
          divisions: 1,
        ),
        DropdownConfigOption<String>(
          key: 'speed',
          label: 'Speed',
          defaultValue: 'normal',
          items: const [
            DropdownMenuItem(value: 'slow', child: Text('Slow (800 ms)')),
            DropdownMenuItem(value: 'normal', child: Text('Normal (500 ms)')),
            DropdownMenuItem(value: 'fast', child: Text('Fast (300 ms)')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final speed = config['speed']?.toString() ?? 'normal';
        return PulseGameScreen(
          gridSize: size,
          speed: speed,
        );
      },
    ),
    GameMetadata(
      id: 'grid_miner',
      title: 'Grid Miner',
      description: 'Collect resources on a grid with move limits.',
      icon: Icons.build,
      category: 'Exploration Games',
      lowerIsBetter: false,
      scoreFormatter: (s, _) => '\$s resources',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 4.0,
          max: 6.0,
          divisions: 1,
        ),
        DropdownConfigOption<String>(
          key: 'difficulty',
          label: 'Difficulty',
          defaultValue: 'easy',
          items: const [
            DropdownMenuItem(value: 'easy', child: Text('Easy')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'hard', child: Text('Hard')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Mode',
          defaultValue: 'challenge',
          items: const [
            DropdownMenuItem(
                value: 'zen', child: Text('Zen Mode (Unlimited moves)')),
            DropdownMenuItem(
                value: 'challenge',
                child: Text('Challenge Mode (Limited moves)')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final difficulty = config['difficulty']?.toString() ?? 'easy';
        final moveMode = config['moveMode']?.toString() ?? 'challenge';
        final maxMoves = config['maxMoves'] is num
            ? (config['maxMoves'] as num).round()
            : null;
        return GridMinerGameScreen(
          gridSize: size,
          difficulty: difficulty,
          moveMode: moveMode,
          maxMoves: maxMoves,
        );
      },
    ),
    GameMetadata(
      id: 'territory',
      title: 'Territory',
      description:
          'Expand your territory to adjacent weighted cells and reach the target value within the move limit.',
      icon: Icons.layers,
      category: 'Score-Attack Games',
      lowerIsBetter: true,
      scoreFormatter: (s, _) => '$s moves',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 3.0,
          max: 10.0,
          divisions: 7,
        ),
        SliderConfigOption(
          key: 'targetArea',
          label: 'Target Value',
          defaultValue: 12.0,
          min: 6.0,
          max: 60.0,
          divisions: 27,
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Mode',
          defaultValue: 'challenge',
          items: const [
            DropdownMenuItem(
                value: 'zen', child: Text('Zen Mode (Unlimited moves)')),
            DropdownMenuItem(value: 'challenge', child: Text('Challenge Mode')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'traps',
          label: 'Hidden Traps',
          defaultValue: 'low',
          items: const [
            DropdownMenuItem(value: 'off', child: Text('Off')),
            DropdownMenuItem(value: 'low', child: Text('Low (~5%)')),
            DropdownMenuItem(value: 'high', child: Text('High (~10%)')),
          ],
        ),
        SwitchConfigOption(key: 'rival', label: 'Rival (claims cells)', defaultValue: false),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final targetArea = (config['targetArea'] is num)
            ? (config['targetArea'] as num).round()
            : int.tryParse(config['targetArea']?.toString() ?? '') ?? 12;
        final moveMode = config['moveMode']?.toString() ?? 'challenge';
        return TerritoryGameScreen(
          gridSize: size,
          targetArea: targetArea,
          moveMode: moveMode,
          traps: config['traps']?.toString() ?? 'low',
          rival: config['rival'] == true,
        );
      },
    ),
    GameMetadata(
      id: 'cluster',
      title: 'Cluster',
      description:
          'Connect matching colors to maximize cluster sizes within move limits.',
      icon: Icons.bubble_chart,
      category: 'Score-Attack Games',
      lowerIsBetter: false,
      scoreFormatter: (s, _) => '$s tiles',
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 4.0,
          min: 4.0,
          max: 6.0,
          divisions: 2,
        ),
        SliderConfigOption(
          key: 'colorCount',
          label: 'Color Count',
          defaultValue: 3.0,
          min: 2.0,
          max: 5.0,
          divisions: 3,
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Move Mode',
          defaultValue: 'challenge',
          items: const [
            DropdownMenuItem(
                value: 'zen', child: Text('Zen Mode (Unlimited Swaps)')),
            DropdownMenuItem(value: 'challenge', child: Text('Challenge Mode')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 4;
        final colors = (config['colorCount'] is num)
            ? (config['colorCount'] as num).round()
            : int.tryParse(config['colorCount']?.toString() ?? '') ?? 3;
        final moveMode = config['moveMode']?.toString() ?? 'challenge';
        return ClusterGameScreen(
          gridSize: size,
          colorCount: colors,
          moveMode: moveMode,
        );
      },
    ),
    GameMetadata(
      id: 'wordsearch',
      title: 'Word Search',
      description: 'Find a list of hidden words inside the letter grid.',
      icon: Icons.search,
      category: 'Word Puzzle Games',
      lowerIsBetter: false,
      scoreFormatter: (s, config) {
        final isChallenge = config['moveMode']?.toString() == 'challenge';
        return isChallenge ? '$s seconds left' : '$s completed';
      },
      configOptions: [
        SliderConfigOption(
          key: 'gridSize',
          label: 'Grid Size',
          defaultValue: 8.0,
          min: 6.0,
          max: 20.0,
          divisions: 14,
        ),
        SliderConfigOption(
          key: 'wordCount',
          label: 'Word Count',
          defaultValue: 4.0,
          min: 3.0,
          max: 20.0,
          divisions: 17,
        ),
        DropdownConfigOption<String>(
          key: 'moveMode',
          label: 'Mode',
          defaultValue: 'challenge',
          items: const [
            DropdownMenuItem(value: 'zen', child: Text('Zen Mode (Untimed)')),
            DropdownMenuItem(
                value: 'challenge', child: Text('Challenge (Timed)')),
          ],
        ),
        DropdownConfigOption<String>(
          key: 'category',
          label: 'Category',
          defaultValue: 'Random',
          items: const [
            DropdownMenuItem(value: 'Random', child: Text('Random Category')),
            DropdownMenuItem(value: 'Animals', child: Text('Animals')),
            DropdownMenuItem(value: 'Fruits', child: Text('Fruits')),
            DropdownMenuItem(value: 'Colors', child: Text('Colors')),
            DropdownMenuItem(value: 'GridMind', child: Text('GridMind')),
            DropdownMenuItem(value: 'Programming', child: Text('Programming')),
            DropdownMenuItem(value: 'Countries', child: Text('Countries')),
            DropdownMenuItem(value: 'Sports', child: Text('Sports')),
            DropdownMenuItem(value: 'Space', child: Text('Space')),
            DropdownMenuItem(value: 'Food', child: Text('Food')),
            DropdownMenuItem(value: 'Science', child: Text('Science')),
          ],
        ),
      ],
      gameBuilder: (context, config) {
        final size = (config['gridSize'] is num)
            ? (config['gridSize'] as num).round()
            : int.tryParse(config['gridSize']?.toString() ?? '') ?? 8;
        final count = (config['wordCount'] is num)
            ? (config['wordCount'] as num).round()
            : int.tryParse(config['wordCount']?.toString() ?? '') ?? 4;
        final moveMode = config['moveMode']?.toString() ?? 'challenge';
        final category = config['category']?.toString() ?? 'Random';
        return WordSearchGameScreen(
          gridSize: size,
          wordCount: count,
          moveMode: moveMode,
          category: category,
        );
      },
    ),
  ];
}
