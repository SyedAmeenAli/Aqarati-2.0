import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;

import '../features/ads/ad_repository.dart' show kSampleCampaigns, kSampleCampaignsAr;
import 'admin_strings_ar.dart';

/// Language of the Admin Console. The console is written in English; every user-visible string is
/// looked up here when the app language is Arabic. The language comes from the app's own locale
/// (the same switch as the rest of AQARATI), so the console never drifts from it.
///
/// ARABIC IS DRAFT COPY and needs native review before launch.
class AdminLang {
  AdminLang._();

  /// Set by the console shell from the active locale, before any screen builds.
  static bool ar = false;

  /// English strings that were looked up while the language was Arabic and had no translation.
  /// Tests assert this stays empty after walking every screen.
  static final Set<String> missing = {};

  static final Map<String, String> _cache = {};

  /// The fictional sample campaigns, in the Arabic the customer app already shows for them.
  static final Map<String, String> _campaigns = {
    for (final c in kSampleCampaigns)
      if (kSampleCampaignsAr[c.$1] case final ar?) ...{c.$3: ar.$1, c.$4: ar.$3, c.$5: ar.$4, c.$6: ar.$5},
    'Muscat Furnishings (sample)': 'مفروشات مسقط (نموذج)',
    'Autumn showroom event': 'فعالية معرض الخريف',
    'Paused sample campaign': 'حملة تجريبية متوقفة مؤقتاً',
    'Visit': 'زيارة',
    'Seeb Land Fund (sample)': 'صندوق أراضي السيب (نموذج)',
    'Plots near the new road': 'قطع أراضٍ قرب الطريق الجديد',
    'Sample campaign waiting for review': 'حملة تجريبية بانتظار المراجعة',
    'See plots': 'عرض القطع',
  };
  static final List<(RegExp, String, List<String>)> _patterns = [
    for (final e in kAdminArPatterns.entries) _compile(e.key, e.value),
  ];

  static (RegExp, String, List<String>) _compile(String template, String ar) {
    final names = <String>[];
    final buf = StringBuffer('^');
    final re = RegExp(r'\{(\w+)\}');
    var last = 0;
    for (final mt in re.allMatches(template)) {
      buf.write(RegExp.escape(template.substring(last, mt.start)));
      names.add(mt.group(1)!);
      buf.write('(.+?)');
      last = mt.end;
    }
    buf.write(RegExp.escape(template.substring(last)));
    buf.write(r'$');
    return (RegExp(buf.toString(), dotAll: true), ar, names);
  }

  static final _fsi = String.fromCharCode(0x2068), _pdi = String.fromCharCode(0x2069);
  static final _isolates = RegExp('${String.fromCharCode(0x2068)}(.*?)${String.fromCharCode(0x2069)}', dotAll: true);
  static final _hasLetters = RegExp(r'[A-Za-z]');

  static final _arabicLetters = RegExp(r'[؀-ۿ]');

  /// Translates [en] when the language is Arabic; otherwise returns it unchanged.
  static String t(String en) {
    if (!ar || en.isEmpty) return en;
    return _cache.putIfAbsent(en, () {
      final out = _numerals(_translate(en));
      // Names wrapped for bidi isolation (VFmt.iso) are data, not interface text. A string that
      // already contains Arabic was translated earlier and is not looked up again.
      final outside = en.replaceAll(_isolates, '');
      if (out == en && _hasLetters.hasMatch(outside) && !_arabicLetters.hasMatch(en) && !_exempt(en)) missing.add(en);
      return out;
    });
  }

  static Map<String, String>? _lowerIndex;

  static const _indic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static final _number = RegExp(r'(?<![A-Za-z0-9_@./\-])(\d+(?:[.,]\d+)*)(?![A-Za-z0-9@_/\-])');

  /// Counts and amounts follow the rest of the app in Arabic: Arabic-Indic digits. Identifiers
  /// (R3, U1), e-mail addresses, money written as "OMR 185,000" and Latin-only text keep theirs.
  static String _numerals(String s) {
    if (!RegExp(r'\d').hasMatch(s)) return s;
    final hasArabic = _arabicLetters.hasMatch(s);
    if (!hasArabic && !RegExp(r'^\d+(?:[.,]\d+)*$').hasMatch(s)) return s;
    return s.replaceAllMapped(_number, (mt) {
      final start = mt.start;
      if (start >= 4 && s.substring(start - 4, start) == 'OMR ') return mt.group(0)!;
      return mt.group(1)!.split('').map((ch) {
        final d = int.tryParse(ch);
        if (d != null) return _indic[d];
        return ch == '.' ? '٫' : '٬';
      }).join();
    });
  }

  static bool _exempt(String s) =>
      kAdminArKeep.contains(s) || kAdminAr.containsKey(s) || _campaigns.containsKey(s) || s.endsWith('.pdf') || RegExp(r'^[A-Z]{1,3}\d+$').hasMatch(s) || RegExp(r'^[\w.+-]+@[\w.-]+$').hasMatch(s) || RegExp(r'^https?://|^/').hasMatch(s);

  static String _translate(String s) {
    // Names isolated for bidi (VFmt.iso) are translated inside their isolate marks.
    if (s.contains(_fsi)) {
      return s.replaceAllMapped(_isolates, (mt) => '$_fsi${_translate(mt.group(1)!)}$_pdi');
    }
    final whole = _lookup(s);
    if (whole != null) return whole;
    // Joined phrases: "a · b", "a, b", "a: b" translate part by part. A part may itself contain the
    // separator ("Cranes and plant, ready in Muscat"), so the longest known run of parts wins.
    for (final sep in const [' · ', ', ', ' – ', ': ']) {
      if (!s.contains(sep)) continue;
      final parts = s.split(sep);
      final out = <String>[];
      var changed = false;
      var i = 0;
      while (i < parts.length) {
        var matched = false;
        for (var j = parts.length; j > i; j--) {
          final run = parts.sublist(i, j).join(sep);
          final k = _lookup(run);
          if (k != null) {
            out.add(k);
            changed = true;
            i = j;
            matched = true;
            break;
          }
        }
        if (!matched) {
          out.add(parts[i]);
          i++;
        }
      }
      if (changed) return out.join(sep == ', ' ? '، ' : sep);
    }
    return s;
  }

  /// A whole-string translation, or null when there is none: exact text, a built-from-parts
  /// pattern, a sample campaign, or a differently-cased title.
  static String? _lookup(String s) {
    final exact = kAdminAr[s] ?? _campaigns[s];
    if (exact != null) return exact;
    for (final p in _patterns) {
      final mt = p.$1.firstMatch(s);
      if (mt == null) continue;
      var out = p.$2;
      for (var i = 0; i < p.$3.length; i++) {
        out = out.replaceAll('{${p.$3[i]}}', _translate(mt.group(i + 1)!));
      }
      return out;
    }
    // A trailing period does not make a different sentence.
    if (s.endsWith('.') && s.length > 3) {
      final base = kAdminAr[s.substring(0, s.length - 1)];
      if (base != null) return '$base.';
    }
    // Titles are sometimes lower-cased inside a sentence ("Back to agents and trusted brokers").
    final idx = _lowerIndex ??= {for (final e in kAdminAr.entries) e.key.toLowerCase(): e.value};
    return idx[s.toLowerCase()];
  }
}

/// Short form used in call sites: `tr('Back')`.
String tr(String en) => AdminLang.t(en);

/// `Text` for the Admin Console: identical to Flutter's, except the string is looked up in the
/// console's Arabic table when the language is Arabic. Admin files import this in place of the
/// Material `Text`.
class Text extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextScaler? textScaler;
  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.textScaler,
  });

  @override
  Widget build(BuildContext context) => m.Text(
    AdminLang.t(data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel == null ? null : AdminLang.t(semanticsLabel!),
    textScaler: textScaler,
  );
}
