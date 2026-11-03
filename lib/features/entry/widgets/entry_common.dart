import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/aq/aq_scene.dart';

/// The one master logo vector. Never redrawn; dark mode only remaps colours.
class MasterLogo extends StatelessWidget {
  final double width;
  const MasterLogo({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SvgPicture.asset(
        'assets/logo/aqarati_master.svg',
        width: width,
        semanticsLabel: Localizations.localeOf(context).languageCode == 'ar' ? 'عقاراتي — رحلتك العقارية' : 'AQARATI — Your Property Journey',
        // Dark mode: same master vector, brown strokes lifted to light bronze. The ivory counters
        // (tagline letters, Q tail) must become the dark page colour, not bronze, or they fill in.
        colorMapper: Theme.of(context).brightness == Brightness.dark ? const _DarkLogoColors() : null,
      ),
    );
  }
}

/// Route transition family used across onboarding (see AQRoute).
Page<T> brandPage<T>({required LocalKey key, required Widget child}) => AQRoute.forward<T>(key: key, child: child);

class _DarkLogoColors extends ColorMapper {
  const _DarkLogoColors();
  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    if (rgb == 0xECE3D7) return const Color(0xFF1A1613);
    if (rgb == 0x825C3F || rgb == 0x7F583C || rgb == 0x674830) return const Color(0xFFD9B793);
    return color;
  }
}
