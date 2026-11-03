import 'dart:io';

import 'package:aqarati_app/core/config/demo_mode.dart' show kDemoMode;
import 'package:aqarati_app/data/models/enums.dart';
import 'package:aqarati_app/features/devbuild/db_models.dart';
import 'package:aqarati_app/features/maintenance/maintenance_models.dart';
import 'package:aqarati_app/features/pro/pro_shell.dart' show proTabsFor;
import 'package:aqarati_app/features/role_home/role_home_model.dart' show HomeRole;
import 'package:aqarati_app/features/workspace/aq_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the picture and icon mapping: every visual entity has a real bundled photograph, one entity keeps
/// one photograph, and no navigation bar gives two different destinations the same glyph.
void main() {
  group('project and service pictures', () {
    test('every project type has a bundled cover in the preview build and none in a real build', () {
      for (final t in PropertyType.values) {
        final c = DbProject.demoCoverFor('demo-p1', t);
        if (kDemoMode) {
          expect(c, isNotNull, reason: '${t.name} has no cover');
          expect(File(c!).existsSync(), isTrue, reason: c);
        } else {
          expect(c, isNull, reason: 'a real build must not borrow a photograph the project does not own');
        }
      }
    });

    test('the same project keeps the same cover, and different projects of one type vary', () {
      expect(DbProject.demoCoverFor('demo-p1', PropertyType.villa), DbProject.demoCoverFor('demo-p1', PropertyType.villa));
      if (kDemoMode) {
        final covers = {for (var i = 0; i < 12; i++) DbProject.demoCoverFor('proj-$i', PropertyType.villa)};
        expect(covers.length, greaterThan(1), reason: 'every villa project would show one picture');
      }
    });

    test('approved project media wins over the preview cover', () {
      final p = DbProject(
        id: 'x', orgId: 'o', name: 'n', propertyType: PropertyType.villa, governorate: 'Muscat', wilayat: 'Seeb',
        status: ProjectStatus.approved, rawStatus: 'approved', updatedAt: DateTime(2026), mediaUrls: const ['assets/businesses/b1/05_Contemporary_architectural_facad.jpg'],
      );
      expect(p.cover, 'assets/businesses/b1/05_Contemporary_architectural_facad.jpg');
    });

    test('every maintenance service has a distinct bundled photograph', () {
      final imgs = {for (final s in MaintenanceService.values) maintenanceServiceImage(s)};
      expect(imgs.length, MaintenanceService.values.length);
      for (final i in imgs) {
        expect(File(i).existsSync(), isTrue, reason: i);
      }
    });

    test('every property type has a representative photograph that exists', () {
      for (final t in PropertyType.values) {
        expect(File(propertyTypeImage(t)).existsSync(), isTrue, reason: t.name);
      }
    });

    testWidgets('AQThumb draws an image, a monogram or an icon, never an empty box', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(children: const [
            AQThumb(asset: 'assets/businesses/b4/03_Plumbing_maintenance_under_sink.jpg'),
            AQThumb(monogramOf: 'Sami Agent Demo'),
            AQThumb(icon: 'home'),
          ]),
        ),
      ));
      await t.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('SA'), findsOneWidget);
      expect(aqInitials('Wadi Architecture'), 'WA');
      expect(aqInitials('Rawaq'), 'R');
    });
  });

  group('icon mapping', () {
    test('no navigation bar gives two destinations the same glyph', () {
      for (final role in HomeRole.values) {
        for (final compact in [true, false]) {
          final tabs = proTabsFor(role, compact: compact).map((e) => e.icon).toList();
          expect(tabs.toSet().length, tabs.length, reason: '$role compact=$compact repeats a glyph: $tabs');
        }
      }
      // One glyph per destination: the phone bar repeats three sidebar items, so compare by route.
      final byRoute = <String, String>{
        for (final m in RegExp(r"_NavItem\('[^']+',\s*'([a-z0-9-]+)',\s*'([^']+)'").allMatches(File('lib/admin/admin_widgets.dart').readAsStringSync())) m.group(2)!: m.group(1)!,
      };
      expect(byRoute.length, greaterThanOrEqualTo(15));
      expect(byRoute.values.toSet().length, byRoute.length, reason: 'the Admin sidebar repeats a glyph: ${byRoute.values.toList()}');
    });

    test('unrelated actions do not borrow the activity pulse', () {
      final shell = File('lib/features/workspace/aq_app_shell.dart').readAsStringSync();
      expect(shell.contains("icon: 'bell', title: f.t('ntf.row')"), isTrue, reason: 'Notifications uses a bell');
      expect(shell.contains("icon: 'bookmark', title: f.t('account.saved')"), isTrue, reason: 'Saved uses a bookmark');
      expect(shell.contains("icon: 'sliders', title: f.t('st.prefs')"), isTrue, reason: 'Preferences uses sliders');
    });
  });
}
