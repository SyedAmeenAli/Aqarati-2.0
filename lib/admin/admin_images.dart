import 'package:flutter/material.dart' hide Text;

import '../core/aq/aq_primitives.dart';
import '../core/aq/aq_tokens.dart';
import '../features/workspace/aq_home.dart' show aqImg;
import 'admin_directory.dart' show AcctRole;
import 'admin_modules.dart' show ModKey;

/// Pictures for the Admin Console's fictional records, so a listing, project, company or portfolio
/// is recognisable at a glance. Each record keeps one picture wherever it appears (list, detail,
/// queue). People (agents, brokers, owners) have no photograph: they get a monogram, never a stock face.
const _modImages = <String, String>{
  'listings:L1': 'assets/properties/p1/07_Waterfront_villa_with_infinity_pool.jpg',
  'listings:L2': 'assets/properties/p4/09_Family_villa_in_Seeb.jpg',
  'listings:L3': 'assets/properties/p4/13_03_Beachfront_property_exterior_arc.jpg',
  'listings:L4': 'assets/properties/p6/04_Modern_commercial_building_exterior.jpg',
  'listings:L5': 'assets/properties/p5/07_Modern_apartment_building_street.jpg',
  'projects:P1': 'assets/properties/p5/05_Modern_apartment_building_exterior.jpg',
  'projects:P2': 'assets/properties/p2/02_Apartment_buildings_in_Muscat.jpg',
  'projects:P3': 'assets/properties/p4/14_05_Contemporary_Omani_villas_exteri.jpg',
  'projects:P4': 'assets/properties/p4/06_Courtyard_villa_architecture_design.jpg',
  'construction:C1': 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg',
  'construction:C2': 'assets/businesses/b2/04_Construction_site_structure_in_M.jpg',
  'construction:C3': 'assets/businesses/b2/02_Concrete_structural_construction.jpg',
  'construction:C4': 'assets/businesses/b2/03_Construction_equipment_at_buildi.jpg',
  'design:D1': 'assets/businesses/b1/05_Contemporary_architectural_facad.jpg',
  'design:D2': 'assets/businesses/b1/03_Architectural_model_of_contempor.jpg',
  'design:D3': 'assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg',
  'design:D4': 'assets/properties/p4/07_Family_garden_view_at_villa.jpg',
  'maintenance:M1': 'assets/businesses/b4/03_Plumbing_maintenance_under_sink.jpg',
  'maintenance:M2': 'assets/businesses/b4/05_Technician_servicing_air_conditi.jpg',
  'maintenance:M3': 'assets/properties/p1/27_39_Private_pool_closeup_photography.jpg',
  'maintenance:M4': 'assets/businesses/b3/02_Modern_designer_bathroom_interio.jpg',
  'viewings:V1': 'assets/properties/p1/07_Waterfront_villa_with_infinity_pool.jpg',
  'viewings:V2': 'assets/properties/p4/09_Family_villa_in_Seeb.jpg',
  'viewings:V3': 'assets/businesses/b1/05_Contemporary_architectural_facad.jpg',
  'viewings:V4': 'assets/properties/p6/04_Modern_commercial_building_exterior.jpg',
  'content:K1': 'assets/properties/p4/02_Contemporary_villa_at_sunset.jpg',
  'content:K2': 'assets/properties/p6/01_Commercial_strip_architectural_p.jpg',
  'content:K3': 'assets/properties/p3/05_Vacant_plot_facing_distant_hills.jpg',
  'content:K4': 'assets/location/15_Sohar_coastal_landscape_development.jpg',
  'content:K5': 'assets/location/10_Muscat_corniche_at_warm_evening.jpg',
};

/// The picture of an Admin module record, or null for a record that has none (people, announcements).
String? adminModImage(ModKey k, String id) => _modImages['${k.name}:$id'];

/// A cover picture for a business account, chosen by its kind of work. People (shoppers, agents) have none.
String? adminRoleCover(AcctRole role) => switch (role) {
      AcctRole.development => 'assets/properties/p2/02_Apartment_buildings_in_Muscat.jpg',
      AcctRole.construction => 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg',
      AcctRole.architecture => 'assets/businesses/b1/05_Contemporary_architectural_facad.jpg',
      AcctRole.interior => 'assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg',
      _ => null,
    };

/// A rounded square picture, or an icon when [asset] is null. Admin shows no initials: they would be
/// untranslated Latin letters on an Arabic screen.
class AdminThumb extends StatelessWidget {
  final String? asset;
  final String icon;
  final double size;
  const AdminThumb({super.key, this.asset, this.icon = 'account', this.size = 48});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final a = asset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AQRadius.medium),
      child: SizedBox(
        width: size,
        height: size,
        child: a != null
            ? ExcludeSemantics(child: aqImg(a, cacheWidth: (size * 3).round()))
            : ColoredBox(color: c.surfaceSelected, child: Center(child: AQIcon(icon, size: size * 0.42, color: c.accent))),
      ),
    );
  }
}

/// A table cell that leads with a picture: thumbnail, then the record's own cell content.
class AdminThumbCell extends StatelessWidget {
  final Widget thumb;
  final Widget child;
  const AdminThumbCell({super.key, required this.thumb, required this.child});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      thumb,
      const SizedBox(width: AQSpacing.x3),
      Flexible(child: child),
    ],
  );
}
