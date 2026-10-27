import 'package:flutter/material.dart';

/// Base class representing a configuration option for a game
abstract class ConfigOption<T> {
  final String key;
  final String label;
  final T defaultValue;

  ConfigOption({
    required this.key,
    required this.label,
    required this.defaultValue,
  });

  Widget buildControl(BuildContext context, T currentValue, ValueChanged<T> onChanged);

  /// Converts a value restored from JSON back to this option's type.
  /// Returns [defaultValue] if the stored value is unusable.
  dynamic decode(dynamic stored) => stored is T ? stored : defaultValue;
}

/// A slider configuration control for numeric range inputs
class SliderConfigOption extends ConfigOption<double> {
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? labelFormatter;

  SliderConfigOption({
    required super.key,
    required super.label,
    required super.defaultValue,
    required this.min,
    required this.max,
    this.divisions,
    this.labelFormatter,
  });

  @override
  Widget buildControl(BuildContext context, double currentValue, ValueChanged<double> onChanged) {
    final displayVal = labelFormatter != null 
        ? labelFormatter!(currentValue)
        : (divisions != null ? currentValue.round().toString() : currentValue.toStringAsFixed(2));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $displayVal', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: currentValue,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A simple toggle switch control for boolean inputs
class SwitchConfigOption extends ConfigOption<bool> {
  SwitchConfigOption({
    required super.key,
    required super.label,
    required super.defaultValue,
  });

  @override
  Widget buildControl(BuildContext context, bool currentValue, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      value: currentValue,
      onChanged: onChanged,
    );
  }
}

/// A dropdown selector control for picking from a list of options
class DropdownConfigOption<T> extends ConfigOption<T> {
  final List<DropdownMenuItem<T>> items;

  DropdownConfigOption({
    required super.key,
    required super.label,
    required super.defaultValue,
    required this.items,
  });

  /// Enums are persisted by name; map the stored name back to the item value.
  @override
  dynamic decode(dynamic stored) {
    for (final item in items) {
      final v = item.value;
      if (v == stored || (v is Enum && stored is String && v.name == stored)) return v;
    }
    return defaultValue;
  }

  @override
  Widget buildControl(BuildContext context, T currentValue, ValueChanged<T> onChanged) {
    // Label above a full-width dropdown so long labels never get squeezed
    // into a one-character column.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<T>(
            isExpanded: true,
            value: currentValue,
            items: items,
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}

/// Model carrying full game classification details and dynamic screen builders
class GameMetadata {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final List<ConfigOption> configOptions;
  final Widget Function(BuildContext context, Map<String, dynamic> config) gameBuilder;
  final bool lowerIsBetter;
  final String Function(int score, Map<String, dynamic> config)? scoreFormatter;

  /// Optional step-by-step walkthrough. When empty, [walkthroughSteps] falls
  /// back to the description plus generic tips.
  final List<String> walkthrough;

  List<String> get walkthroughSteps => walkthrough.isNotEmpty
      ? walkthrough
      : [
          description,
          'Pick your board rules on the setup screen, then tap Start Game.',
          'Your best score is saved per rule set - try beating it!',
        ];

  /// Saved setup values merged over defaults, decoded to their real types.
  /// This is the exact config used for score keys, so setup, game and
  /// settings screens must all build it through here.
  Map<String, dynamic> resolveConfig(Map<String, dynamic>? saved) => {
        for (final o in configOptions)
          o.key: saved?[o.key] == null ? o.defaultValue : o.decode(saved![o.key]),
      };

  GameMetadata({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.configOptions,
    required this.gameBuilder,
    this.lowerIsBetter = false,
    this.scoreFormatter,
    this.walkthrough = const [],
  });
}
