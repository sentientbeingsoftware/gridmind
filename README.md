# GridMind

A collection of engaging puzzle, memory, and arcade games built with Flutter. GridMind features twenty-two distinct grid-based mini-games that challenge different cognitive skills: memory, pathfinding, pattern recognition, arithmetic, spatial alignment, and strategic thinking.

## Games

### 🧠 Simon Game
A classic memory game where players must repeat increasingly longer sequences of flashing colored buttons.
- **Configurable difficulty**: Choose from 2-9 buttons with varying pattern speeds.
- **Adaptive layout**: Buttons automatically arrange based on the selected count.
- **Progressive challenge**: Sequences get longer with each successful round.

### 🧩 Slide and Solve
A pattern rearrangement puzzle where players slide rows and columns to match a target configuration.
- **Multiple grid sizes**: 3x3, 4x4, and 5x5 grids for different difficulty levels.
- **Touch controls**: Intuitive drag gestures for row and column manipulation.
- **Move tracking**: Counts moves to encourage efficient solutions.

### 🎯 Collapse
A match-3 style block clearing game with customizable mechanics.
- **Choose collapse mechanics**: Blocks can fall from top, bottom, left, or right.
- **Strategic matching**: Match 3-5 blocks to clear them and score points.
- **Smart shuffling**: Automatic board shuffling when no moves are available.

### 🗺️ Path Weaver
A pathfinding puzzle game where players navigate a route from start to finish.
- **Solvability check**: Real-time BFS path solver that guarantees a valid solution and draws optional guide lines.
- **Interactive routing**: Intuitive drag gestures and tap controls to draw and undo routes.
- **Diverse obstacles**: Dynamic board features including blockers, directional one-way walls, and power-ups.

### 🔢 Sum Grid
An arithmetic grid puzzle where players select adjacent cells that add up to target numbers.
- **Timed and Classic Modes**: Challenge yourself under time constraints or play at your own pace.
- **Collapse physics**: Selected blocks collapse, bringing down new numbers.

### 💡 Binary Lights
A Lights Out-style toggle matching puzzle.
- **Deterministic boards**: Guaranteeing solvable board generation.
- **Orthogonal toggles**: Tapping a tile toggles its state and that of its orthogonal neighbors.

### 🔄 Pattern Echo
A transformation memory game.
- **Visual translation**: Recreate grid patterns after they are rotated, mirrored, or translated.
- **Transformation modes**: Mental (static) or visual (animated rotation) transformations.

### ❓ Missing Piece
An observation and speed memory puzzle.
- **Content variation**: Match numbers or colors shown briefly in a showcase phase.
- **Selector options**: Correctly choose missing pieces from multiple choice options.

### ⏳ Sequence Trail
A rapid numerical selection game.
- **Countdown lifetimes**: Click tiles in ascending order before they expire.
- **Teleport shuffles**: Watch tiles randomly rearrange to keep you on your toes.

### 🎨 Grid Painter
A Picross-style paint optimization challenge.
- **Multiple paint modes**: Draw, Erase, and Navigate.
- **Picross clues**: Highlights column and row clues dynamically to guide your blueprint painting.

### 🪞 Mirror Match
A symmetry replication puzzle.
- **Symmetry axes**: Align colors horizontally, vertically, or rotationally.
- **Lock indicators**: Keep track of permanent clues that cannot be altered.

### 👾 Shape Shift
An adjacent tile-swapping arrangement puzzle.
- **Target pattern**: Replicate target shapes on the main grid.
- **Move limit challenges**: Solve the transition within strict move boundaries.

### 🌊 Color Flood
A queue-based flood-fill color game.
- **BFS flooding algorithm**: Fill connected grids starting from the top-left corner.
- **Tactical selectors**: Choose colors strategically to flood the board in as few moves as possible.

### 🏃 Grid Runner
A real-time arcade trail puzzle (Snake + Tron hybrid).
- **Avoid self-intersection**: Run without hitting grid boundaries or crossing your own trail.
- **Collect gems**: Steer with on-screen D-pad controls to clear all glowing gems.

### 💥 Chain Reaction
An explosive single-player clearing game.
- **Cascading cascade ticks**: Distribute atoms orthogonally. Out-of-bounds atoms are destroyed, allowing the grid to be fully cleared.
- **Stability colors**: Glowing red/orange cells alert players to critical unstable states.

### 🔄 Rotate Matrix
An alignment transformation puzzle.
- **Quadrant Selectors**: Divide the grid into four 2x2 or 3x3 quadrant matrices. Select quadrants simply by tapping any of their cells.
- **Spin Controls**: Press Rotate Clockwise (↻) or Rotate Counter-Clockwise (↺) below the board to rotate cells.
- **Target Goal**: Scramble back to the target pattern block layout.

### 🪐 Gravity Shift
- **Gravity Direction Puzzle**: Slide elements across the grid by tilting gravity to navigate obstacles and hit target locations.
- **Move Tracker**: Optimize moves to achieve target alignment with minimum step count.

### 🌊 Pulse
- **Rhythmic Timing**: Tap cells in sequence at the exact moment a rhythmic pulse wave reaches them.
- **Velocity options**: Custom speed configurations from Slow (800ms) to Fast (300ms).

### ⛏️ Grid Miner
- **Exploration grid mining**: Collect resources scattered across a grid while tracking moves.
- **Configurable conditions**: Sliders and dropdowns adjusting difficulty levels and play modes.

### 🗺️ Territory
- **Area Enclosure**: Capture and secure target territory percentages on a grid grid by claim taps.
- **Move Limitations**: Try to secure control before running out of turns.

---

## Features

### 🎨 Premium Aesthetics
- **Material Design 3**: Fully updated M3 Seeded palette support.
- **Global Colors & Themes**: Set custom palette presets (Preset, Pastel, High Contrast, Color Blind) and toggle Dark/Light modes.
- **Micro-Animations**: Features pulsing unstable cells, sliding tiles, and glowing nodes.

### 🛡️ Reusable Shell Architecture
- **Unified HUD Shell**: Renders consistent score cards, high-score tracking, and confirm-exit banners via `BaseGameScreen`.
- **Schema-Driven Setup**: Employs `BaseSetupScreen` and `GameRegistry` to automatically build configuration options (sliders, dropdowns) for all twenty-two games.

### 📊 Anonymous Telemetry & Diagnostics
- **Opt-In Control**: Telemetry is off by default. A first-run consent prompt asks permission, and a toggle in Settings > Privacy lets users change their choice at any time. Disabling instantly clears any buffered local usage data.
- **Centralized Instrumentation**: Leverages `BaseGameScreen` to automatically track game session start, completion, duration, status (victory, game_over, quit), and configuration.
- **Lightweight Queueing & Batch Transmit**: Caches events locally via `SharedPreferences` and automatically flushes them to a centralized HTTP server in batches of 5 events to minimize network battery and data overhead.

### 🔧 Robust Tech Stack
- **Persistence**: Configuration-aware local storage (`SharedPreferences`) saving high scores uniquely per game config.
- **Compilation**: Passes all strict Flutter analysis rules and null-safety compilation requirements.
- **Testing**: Comprehensive widget coverage containing over 80+ tests running green.

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.8.0 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- An IDE (Android Studio, VS Code, or IntelliJ IDEA)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/sentientbeingsoftware/gridmind.git
   cd gridmind
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Building for Release

```bash
flutter build apk --release       # Android APK
flutter build appbundle --release # Android App Bundle (Google Play)
flutter build ios --release       # iOS
flutter build web --release       # Web
```

---

## Project Structure

```
lib/
├── main.dart                          # App entry point, MenuScreen, and SettingsScreen
├── models/                            # Data models and structures
│   ├── collapse_models.dart           # CollapseLevel configurations and mechanic enums
│   ├── game_metadata.dart             # Dynamic option config definitions
│   ├── pattern_speed.dart             # Simon Game speed configurations
│   └── slide_and_solve_models.dart    # Slide and Solve level/configuration definitions
├── screens/                           # Game UI and setup screens
│   ├── base_game_screen.dart          # Reusable unified game screen HUD
│   ├── base_setup_screen.dart         # Reusable configuration setup screen
│   ├── binary_lights_game_screen.dart  # Binary Lights game board
│   ├── chain_reaction_game_screen.dart # Chain Reaction game board
│   ├── collapse_game_screen.dart       # Collapse match-3 game board
│   ├── color_flood_game_screen.dart    # Color Flood game board
│   ├── gravity_shift_game_screen.dart  # Gravity Shift game board
│   ├── grid_miner_game_screen.dart     # Grid Miner exploration game board
│   ├── grid_painter_game_screen.dart   # Grid Painter game board
│   ├── grid_runner_game_screen.dart    # Grid Runner game board
│   ├── mirror_match_game_screen.dart   # Mirror Match game board
│   ├── missing_piece_game_screen.dart  # Missing Piece game board
│   ├── path_weaver_game_screen.dart    # Path Weaver grid game board
│   ├── pattern_echo_game_screen.dart   # Pattern Echo game board
│   ├── pulse_game_screen.dart          # Pulse rhythmic timing game board
│   ├── rotate_matrix_game_screen.dart  # Rotate Matrix game board
│   ├── sequence_trail_game_screen.dart # Sequence Trail game board
│   ├── shape_shift_game_screen.dart    # Shape Shift game board
│   ├── simon_game_screen.dart          # Simon interactive game page
│   ├── slide_and_solve_game_screen.dart # Slide and Solve puzzle board page
│   ├── sum_grid_game_screen.dart       # Sum Grid game board
│   ├── territory_game_screen.dart      # Territory area enclosure game board
│   └── services/                      # Screen-scoped services
│       ├── app_persistence_service.dart # Local persistence wrapper for SharedPreferences
│       └── telemetry_service.dart     # Central telemetry data collection and HTTP dispatch
├── services/                          # Global services
│   └── game_registry.dart             # Central GameRegistry schema and launchers
└── utils/                             # Shared utility helper classes
    └── grid_utils.dart                # Generic helper functions for 2D grids (equality, cloning)
```

---

## Feedback & Issues
Bug reports and feature requests live at <https://github.com/sentientbeingsoftware/gridmind/issues>.

**Feedback sent from the app (Settings > Submit Feedback / Report Issue) is posted as a public GitHub issue in that repository.** Anyone can read it. Do not include personal information (names, email addresses, home addresses, passwords, or anything else you would not post publicly) in the title or description. The optional email field is not posted to the issue; it is stored privately and used only to reply to you if needed. Every report also includes the app version, your OS version and an anonymous session ID. The optional "Attach diagnostic metadata" switch additionally adds your game settings and high scores. The privacy policy is linked in Settings > Privacy and is available at <https://www.sentientbeingsoftware.com/support/terms>.

## Contributing
Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Report security problems privately as described in [SECURITY.md](SECURITY.md), not as a public issue.

## License
Copyright 2025-2026 Sentient Being Software LLC.

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) and [NOTICE](NOTICE) files for details.

## Support
If you enjoy GridMind, consider supporting the developer:
- [Buy me a coffee on Coff.ee](https://coff.ee/sentientbn)
- [Support on Ko-fi](https://ko-fi.com/sentientbeingapps)

## Build-time secrets

Feedback and telemetry tokens are injected at build time and never committed.
Create `dart_defines.json` (git-ignored) in the repo root:

```json
{ "FEEDBACK_API_KEY": "...", "TELEMETRY_TOKEN": "..." }
```

Then run `flutter run --dart-define-from-file=dart_defines.json` (VS Code launch
configs already do this). CI reads the `FEEDBACK_API_KEY` and `TELEMETRY_TOKEN`
repository secrets.

**Pull requests from forks:** GitHub does not pass repository secrets to workflows
triggered by pull requests from forks, so both values are empty in those builds.
Analysis and tests do not use them, and the app still compiles; only the app's
calls to the feedback and telemetry backend would be rejected. Builds on `main`
after a merge use the real secrets. Details are in
[CONTRIBUTING.md](CONTRIBUTING.md#continuous-integration-and-secrets).
