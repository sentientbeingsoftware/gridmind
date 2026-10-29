import 'package:flutter/material.dart';
import '../utils/color_names.dart';

/// Lets the player edit the nine Custom palette colours with hue, saturation and
/// brightness sliders. Returns the new list on Save, null on Cancel.
Future<List<Color>?> showCustomPaletteEditor(BuildContext context, List<Color> initial) {
  return showDialog<List<Color>>(
    context: context,
    builder: (_) => _CustomPaletteDialog(initial: initial),
  );
}

class _CustomPaletteDialog extends StatefulWidget {
  final List<Color> initial;
  const _CustomPaletteDialog({required this.initial});

  @override
  State<_CustomPaletteDialog> createState() => _CustomPaletteDialogState();
}

class _CustomPaletteDialogState extends State<_CustomPaletteDialog> {
  late final List<HSVColor> _colors = widget.initial.map(HSVColor.fromColor).toList();
  int _selected = 0;

  void _edit(HSVColor Function(HSVColor) change) => setState(() => _colors[_selected] = change(_colors[_selected]));

  Widget _slider(String label, double value, double max, ValueChanged<double> onChanged) => Row(
        children: [
          SizedBox(width: 84, child: Text(label)),
          Expanded(child: Slider(value: value.clamp(0, max), max: max, onChanged: onChanged)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final hsv = _colors[_selected];
    final border = Theme.of(context).colorScheme.onSurface;
    return AlertDialog(
      title: const Text('Custom colors'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _colors.length; i++)
                  Semantics(
                    button: true,
                    selected: i == _selected,
                    label: 'Color ${i + 1} of ${_colors.length}, ${colorName(_colors[i].toColor())}',
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _colors[i].toColor(),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: border, width: i == _selected ? 3 : 1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _slider('Hue', hsv.hue, 360, (v) => _edit((c) => c.withHue(v))),
            _slider('Saturation', hsv.saturation, 1, (v) => _edit((c) => c.withSaturation(v))),
            _slider('Brightness', hsv.value, 1, (v) => _edit((c) => c.withValue(v))),
            const Text('Color 1 also sets the app theme.', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop([for (final c in _colors) c.toColor()]),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
