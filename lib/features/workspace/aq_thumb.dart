import 'package:flutter/material.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../data/datasources/mock_business_data.dart';
import '../../data/models/enums.dart';
import '../maintenance/maintenance_models.dart';
import 'aq_home.dart' show aqImg;

/// The square picture at the start of a record row (a service, a business, a submission). A bundled
/// photograph when there is one, otherwise a monogram for a person or business, otherwise an icon,
/// so a row never has an empty leading box. Decorative: the row carries its own accessibility label.
class AQThumb extends StatelessWidget {
  final String? asset;
  final String? monogramOf;
  final String icon;
  final double size;
  const AQThumb({super.key, this.asset, this.monogramOf, this.icon = 'home', this.size = 56});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final a = asset;
    final m = monogramOf;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AQRadius.medium),
        child: SizedBox(
          width: size,
          height: size,
          child: a != null
              ? aqImg(a, cacheWidth: (size * 3).round())
              : ColoredBox(
                  color: c.surfaceSelected,
                  child: Center(
                    child: m != null
                        ? Text(aqInitials(m), style: AQTypography.of(context, AQText.titleSmall, color: c.accentDeep))
                        : AQIcon(icon, size: size * 0.42, color: c.accent),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A thumbnail followed by the gap before the row's text.
Widget aqRowLead(Widget thumb) => Padding(
  padding: const EdgeInsetsDirectional.only(end: AQSpacing.x3),
  child: thumb,
);

String aqInitials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty && RegExp(r'^[A-Za-z؀-ۿ]').hasMatch(p)).toList();
  if (parts.isEmpty) return '·';
  final first = parts.first.characters.first;
  return parts.length == 1 ? first.toUpperCase() : (first + parts[1].characters.first).toUpperCase();
}

/// One picture per maintenance service, the same wherever that service appears.
String maintenanceServiceImage(MaintenanceService s) => switch (s) {
  MaintenanceService.plumber => 'assets/businesses/b4/03_Plumbing_maintenance_under_sink.jpg',
  MaintenanceService.ac => 'assets/businesses/b4/05_Technician_servicing_air_conditi.jpg',
  MaintenanceService.pool => 'assets/properties/p1/27_39_Private_pool_closeup_photography.jpg',
  MaintenanceService.kitchen => 'assets/properties/p1/16_Contemporary_kitchen_interior_ar.jpg',
};

/// The cover photograph of a business (the first of its gallery, as everywhere else it appears), or null.
String? businessCoverById(String id) {
  for (final b in mockBusinesses) {
    if (b.id == id && b.galleryUrls.isNotEmpty) return b.galleryUrls.first;
  }
  return null;
}

/// A representative photograph of a kind of property, the same for every property of that kind.
String propertyTypeImage(PropertyType t) => switch (t) {
  PropertyType.apartment || PropertyType.penthouse => 'assets/properties/p5/05_Modern_apartment_building_exterior.jpg',
  PropertyType.residentialLand || PropertyType.agriculturalLand || PropertyType.farm => 'assets/properties/p3/01_Aerial_view_of_residential_plot.jpg',
  PropertyType.shop || PropertyType.office || PropertyType.warehouse || PropertyType.building => 'assets/properties/p6/04_Modern_commercial_building_exterior.jpg',
  _ => 'assets/properties/p4/03_Contemporary_villa_exterior_in_g.jpg',
};
