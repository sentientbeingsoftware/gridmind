import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/app_info.dart';

void main() {
  test('kAppVersion matches pubspec.yaml version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(kAppVersion, match!.group(1));
  });
}
