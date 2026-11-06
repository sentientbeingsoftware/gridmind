import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/main.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Spike: system-level interactions (not mergeable). Run: patrol test --target patrol_test/system_test.dart -d emulator-5556
void main() {
  patrolTest('system nav bar, notification shade, home/resume', ($) async {
    SharedPreferences.setMockInitialValues({
      'telemetry_consent_answered': true,
      'telemetry_enabled': false,
      'walkthrough_seen__app_intro': true,
    });
    await $.pumpWidgetAndSettle(const MyApp());
    // System-level: press Home (nav bar), reopen via recents, open/close notification shade.
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openNotifications();
    final notifs = await $.platform.mobile.getNotifications();
    // ignore: avoid_print
    print('PATROL notifications visible: ${notifs.length}');
    await $.platform.android.pressBack();
    await $.platform.mobile.openApp();
    await $.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    // Permission dialog API (no GridMind feature requests one; call is a no-op without dialog).
    final granted = await $.platform.mobile.isPermissionDialogVisible(
        timeout: const Duration(seconds: 1));
    expect(granted, isFalse);
    // Toggle system dark mode and airplane/wifi via system APIs.
    await $.platform.mobile.enableDarkMode();
    await $.platform.mobile.disableDarkMode();
    await $.platform.mobile.pressRecentApps();
    await $.platform.mobile.pressHome();
  });
}
