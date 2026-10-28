import 'package:flutter/painting.dart';

/// Rough human name for a colour, for screen-reader labels on boards whose
/// cells differ only by colour.
String colorName(Color c) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.lightness < 0.15) return 'black';
  if (hsl.lightness > 0.9) return 'white';
  if (hsl.saturation < 0.15) return 'gray';
  final h = hsl.hue;
  if (h < 15 || h >= 345) return hsl.lightness > 0.7 ? 'pink' : 'red';
  if (h < 45) return hsl.lightness < 0.4 ? 'brown' : 'orange';
  if (h < 70) return 'yellow';
  if (h < 165) return 'green';
  if (h < 200) return 'cyan';
  if (h < 255) return 'blue';
  if (h < 290) return 'purple';
  return 'pink';
}
