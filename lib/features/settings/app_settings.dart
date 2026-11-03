import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Preferences that are local to this device and this browser. Nothing here is sent anywhere.
class AppSettings {
  /// Text size multiplier: 1.0, 1.15 or 1.3.
  final double textScale;
  final bool reducedMotion;

  /// In-app notification categories (name to on/off). Email and push need a service and are not here.
  final Map<String, bool> notifications;
  final Map<String, bool> privacy;
  final Set<String> locations;

  const AppSettings({
    this.textScale = 1,
    this.reducedMotion = false,
    this.notifications = const {'viewings': true, 'maintenance': true, 'ebroker': true, 'engagements': true, 'offers': false},
    this.privacy = const {'suggestions': true, 'recents': true},
    this.locations = const {},
  });

  AppSettings copyWith({
    double? textScale,
    bool? reducedMotion,
    Map<String, bool>? notifications,
    Map<String, bool>? privacy,
    Set<String>? locations,
  }) => AppSettings(
    textScale: textScale ?? this.textScale,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    notifications: notifications ?? this.notifications,
    privacy: privacy ?? this.privacy,
    locations: locations ?? this.locations,
  );

  String toJson() => jsonEncode({
    'textScale': textScale,
    'reducedMotion': reducedMotion,
    'notifications': notifications,
    'privacy': privacy,
    'locations': locations.toList(),
  });

  factory AppSettings.fromJson(String raw) {
    const d = AppSettings();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      Map<String, bool> flags(Object? v, Map<String, bool> base) => {
        ...base,
        if (v is Map) for (final e in v.entries) if (e.value is bool) e.key.toString(): e.value as bool,
      };
      final scale = (m['textScale'] as num?)?.toDouble() ?? 1;
      return AppSettings(
        textScale: const [1.0, 1.15, 1.3].contains(scale) ? scale : 1,
        reducedMotion: m['reducedMotion'] == true,
        notifications: flags(m['notifications'], d.notifications),
        privacy: flags(m['privacy'], d.privacy),
        locations: {if (m['locations'] is List) for (final x in m['locations'] as List) x.toString()},
      );
    } catch (_) {
      return d;
    }
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings());

  void load(AppSettings s) => state = s;
  void setTextScale(double v) => state = state.copyWith(textScale: v);
  void setReducedMotion(bool v) => state = state.copyWith(reducedMotion: v);
  void setNotification(String key, bool v) => state = state.copyWith(notifications: {...state.notifications, key: v});
  void setPrivacy(String key, bool v) => state = state.copyWith(privacy: {...state.privacy, key: v});
  void toggleLocation(String name) {
    final next = {...state.locations};
    next.contains(name) ? next.remove(name) : next.add(name);
    state = state.copyWith(locations: next);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) => AppSettingsNotifier());

/// A message sent through Support or Report a problem. Held in memory only: nothing is delivered.
class SupportTicket {
  final String reference, kind, subject, message;
  final DateTime at;
  const SupportTicket(this.reference, this.kind, this.subject, this.message, this.at);
}

class SupportNotifier extends StateNotifier<List<SupportTicket>> {
  SupportNotifier() : super(const []);
  SupportTicket add(String kind, String subject, String message) {
    final t = SupportTicket('PROTO-${1001 + state.length}', kind, subject, message, DateTime.now());
    state = [t, ...state];
    return t;
  }
}

final supportTicketsProvider = StateNotifierProvider<SupportNotifier, List<SupportTicket>>((ref) => SupportNotifier());
