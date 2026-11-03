import 'dart:io';

import 'package:aqarati_app/core/aq/aq_primitives.dart';
import 'package:aqarati_app/features/pro/pro_shell.dart' show proTabsFor;
import 'package:aqarati_app/features/role_home/role_home_model.dart' show HomeRole;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against the images and icons going missing again: asset files exist and are declared, every icon
/// name used by a navigation bar resolves to a real SVG, and every bundled icon actually renders.
List<File> _dart(String dir) => Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
Set<String> _svgNames() => Directory('assets/icons/aq').listSync().whereType<File>().map((f) => f.uri.pathSegments.last.replaceAll('.svg', '')).toSet();

void main() {
  test('every asset path named in the source exists on disk and its folder is declared in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'^\s+-\s+(assets/\S+/)\s*$', multiLine: true).allMatches(pubspec).map((m) => m.group(1)!).toSet();
    final ref = RegExp(r'''assets/[A-Za-z0-9_./\-]+\.(?:jpg|jpeg|png|webp|svg|gif|mp4)''');
    final missing = <String>[], undeclared = <String>[];
    for (final f in [..._dart('lib'), ..._dart('test')]) {
      for (final m in ref.allMatches(f.readAsStringSync())) {
        final path = m.group(0)!;
        if (!File(path).existsSync()) missing.add('$path (in ${f.path})');
        final dir = '${path.substring(0, path.lastIndexOf('/'))}/';
        if (!declared.contains(dir)) undeclared.add('$path (in ${f.path})');
      }
    }
    expect(missing, isEmpty, reason: 'referenced files that do not exist');
    expect(undeclared, isEmpty, reason: 'referenced files whose folder is not listed under flutter: assets:');
  });

  test('every AQIcon name written in the source has an SVG in assets/icons/aq', () {
    final have = _svgNames();
    final used = <String, String>{};
    for (final f in _dart('lib')) {
      for (final m in RegExp(r"AQIcon\(\s*'([a-z0-9-]+)'").allMatches(f.readAsStringSync())) {
        used[m.group(1)!] = f.path;
      }
    }
    expect(used, isNotEmpty);
    expect([for (final e in used.entries) if (!have.contains(e.key)) '${e.key} (${e.value})'], isEmpty);
  });

  test('every navigation icon (customer, agent, admin, every professional role on phone and wide) has an SVG', () {
    final have = _svgNames();
    final names = <String>{};
    for (final role in HomeRole.values) {
      for (final compact in [true, false]) {
        for (final t in proTabsFor(role, compact: compact)) {
          names.add(t.icon);
        }
      }
    }
    final shell = File('lib/features/workspace/aq_app_shell.dart').readAsStringSync();
    names.addAll(RegExp(r"AQNavItem\('([a-z0-9-]+)'").allMatches(shell).map((m) => m.group(1)!));
    final agent = File('lib/features/agent/agent_shell.dart').readAsStringSync();
    final list = RegExp(r"_agentIcons = \[([^\]]+)\]").firstMatch(agent)!.group(1)!;
    names.addAll(RegExp(r"'([a-z0-9-]+)'").allMatches(list).map((m) => m.group(1)!));
    final admin = File('lib/admin/admin_widgets.dart').readAsStringSync();
    final adminIcons = RegExp(r"_NavItem\('[^']+',\s*'([a-z0-9-]+)'").allMatches(admin).map((m) => m.group(1)!).toList();
    expect(adminIcons.length, greaterThanOrEqualTo(15), reason: 'the admin sidebar items were found');
    names.addAll(adminIcons);
    expect(names.length, greaterThan(15));
    expect([for (final n in names) if (!have.contains(n)) n], isEmpty, reason: 'navigation icons without an SVG');
  });

  testWidgets('every bundled icon really renders (no fallback ring) in light and dark colours', (t) async {
    final names = _svgNames().toList()..sort();
    for (final color in [const Color(0xFF2D2823), const Color(0xFFF3EBDD)]) {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Wrap(children: [for (final n in names) AQIcon(n, color: color)]),
        ),
      ));
      await t.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNWidgets(names.length));
      expect(find.byKey(const ValueKey('aq-icon-fallback')), findsNothing, reason: 'an icon asset failed to load');
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('an icon name with no asset shows the fallback ring instead of a blank gap', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: AQIcon('no-such-icon-name'))));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('aq-icon-fallback')), findsOneWidget);
  });
}
