import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

/// Speaks [message] through the screen reader (no-op when none is running).
void announce(BuildContext context, String message) {
  final view = View.maybeOf(context);
  if (view == null) return;
  SemanticsService.sendAnnouncement(view, message, Directionality.of(context));
}
