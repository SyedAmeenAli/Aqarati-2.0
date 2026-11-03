import 'dart:io';

import 'package:aqarati_app/features/workspace/aq_app_shell.dart' show customerTabFor;
import 'package:flutter_test/flutter_test.dart';

/// The shared customer shell owns the bottom navigation. These checks read the real router so a
/// browsing screen cannot quietly drop out of it again.
String _shellBlock(String src) {
  final i = src.indexOf('ShellRoute(');
  var d = 0, j = src.indexOf('(', i);
  for (; j < src.length; j++) {
    if (src[j] == '(') d++;
    if (src[j] == ')' && --d == 0) break;
  }
  return src.substring(i, j);
}

void main() {
  final router = File('lib/core/router/app_router.dart').readAsStringSync();
  final extra = File('lib/core/router/extra_routes.dart').readAsStringSync();
  final shell = _shellBlock(router);
  final extraShell = extra.substring(extra.indexOf('extraShellRoutes'));
  final extraStandalone = extra.substring(0, extra.indexOf('extraShellRoutes'));

  test('browsing screens are hosted by the shell (they keep the navigation)', () {
    for (final p in [
      '/app/home', '/app/explore', '/app/activity', '/app/account',
      '/properties/categories', '/properties/types', '/properties/all',
      '/saved', '/professionals', '/business/:id',
      '/calculators', '/notifications', '/map', '/search', '/search/start',
    ]) {
      expect(shell.contains("path: '$p',"), isTrue, reason: p);
    }
    for (final p in ['/sell', '/sell/:id', '/engagements', '/reviews', '/app/account/profile', '/broker']) {
      expect(extraShell.contains("path: '$p',"), isTrue, reason: p);
    }
  });

  test('focused wizards and forms stay outside it', () {
    for (final p in ['/sell/new', '/sell/:id/edit', '/business/:id/engage', '/review/:kind/:id']) {
      expect(extraStandalone.contains("path: '$p',"), isTrue, reason: p);
      expect(extraShell.contains("path: '$p',"), isFalse, reason: p);
    }
    // A property page is full screen: its pinned Enquire / Book viewing bar is the only bottom element.
    expect(router.contains("path: '/property/:id',"), isTrue);
    expect(shell.contains("path: '/property/:id',"), isFalse);
    for (final p in ['/property/:id/viewing', '/login', '/entry', '/agent/listings']) {
      expect(shell.contains("path: '$p',"), isFalse, reason: p);
    }
  });

  test('exactly four tabs and each location selects the right one', () {
    expect(customerTabFor('/app/home'), 0);
    expect(customerTabFor('/properties/categories'), 0);
    expect(customerTabFor('/property/p1'), 0);
    expect(customerTabFor('/saved'), 0);
    expect(customerTabFor('/app/explore'), 1);
    expect(customerTabFor('/app/explore/build/results'), 1);
    expect(customerTabFor('/search/start'), 1);
    expect(customerTabFor('/map'), 1);
    expect(customerTabFor('/app/activity'), 2);
    expect(customerTabFor('/app/account'), 3);
    expect(customerTabFor('/app/account/profile'), 3);
    expect(customerTabFor('/notifications'), 3);
    expect(customerTabFor('/engagements'), 3);
  });
}
