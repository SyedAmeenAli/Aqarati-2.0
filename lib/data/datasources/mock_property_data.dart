import '../models/enums.dart';
import '../models/money.dart';
import '../models/property.dart';
import '../models/property_verification.dart';

const _p1Images = [
  'assets/properties/p1/01_Aerial_view_of_waterfront_villa.jpg',
  'assets/properties/p1/02_Infinity_pool_overlooking_marina.jpg',
  'assets/properties/p1/04_Master_bedroom_overlooking_marina.jpg',
  'assets/properties/p1/06_Rooftop_terrace_overlooking_marina.jpg',
  'assets/properties/p1/07_Waterfront_villa_with_infinity_pool.jpg',
  'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
  'assets/properties/p1/09_Doubleheight_living_room_interior.jpg',
  'assets/properties/p1/10_Entrance_foyer_and_staircase_design.jpg',
  'assets/properties/p1/16_Contemporary_kitchen_interior_ar.jpg',
];

const _p1Videos = [
  'assets/properties/p1/video/01_Drone_footage_of_villa_exterior.mp4',
  'assets/properties/p1/video/02_Kitchen_and_dining_walkthrough_v.mp4',
  'assets/properties/p1/video/03_Master_bedroom_walkthrough_villa.mp4',
  'assets/properties/p1/video/04_Villa_entrance_walkthrough_video.mp4',
  'assets/properties/p1/video/05_Villa_exterior_walkthrough_shot.mp4',
  'assets/properties/p1/video/06_Villa_living_room_walkthrough.mp4',
  'assets/properties/p1/video/07_Villa_pool_and_marina_reveal.mp4',
];

const _p2Images = [
  'assets/properties/p2/06_Seaview_balcony_overlooking_coa.jpg',
  'assets/properties/p2/01_Apartment_balcony_detail_view.jpg',
  'assets/properties/p2/02_Apartment_buildings_in_Muscat.jpg',
  'assets/properties/p2/05_Living_room_overlooking_balcony.jpg',
  'assets/properties/p2/07_Compact_contemporary_apartment_k.jpg',
  'assets/properties/p2/08_Open_living_and_dining_apartment.jpg',
];

const _p3Images = [
  'assets/properties/p3/01_Aerial_view_of_residential_plot.jpg',
  'assets/properties/p3/02_Elevated_view_of_vacant_plot.jpg',
  'assets/properties/p3/03_Street_frontage_of_residential_plot.jpg',
  'assets/properties/p3/04_Survey_stake_boundary_marker.jpg',
  'assets/properties/p3/05_Vacant_plot_facing_distant_hills.jpg',
];

const _p4Images = [
  'assets/properties/p4/01_Contemporary_family_villa_comple.jpg',
  'assets/properties/p4/02_Contemporary_villa_at_sunset.jpg',
  'assets/properties/p4/06_Courtyard_villa_architecture_design.jpg',
  'assets/properties/p4/07_Family_garden_view_at_villa.jpg',
  'assets/properties/p4/09_Family_villa_in_Seeb.jpg',
  'assets/properties/p4/10_Guest_annex_bathroom_interior.jpg',
  'assets/properties/p4/11_Guest_annex_building_exterior.jpg',
  'assets/properties/p4/19_37_Outdoor_majlis_at_contemporary_home.jpg',
  'assets/properties/p4/21_49_Third_bedroom_in_villa.jpg',
  'assets/properties/p4/22_52_Villa_front_entrance_with_garden.jpg',
];

const _p5Images = [
  'assets/properties/p5/03_Contemporary_apartment_property_.jpg',
  'assets/properties/p5/04_Modern_apartment_building_entrance.jpg',
  'assets/properties/p5/05_Modern_apartment_building_exterior.jpg',
  'assets/properties/p5/08_Shared_pool_at_apartment_building.jpg',
  'assets/properties/p5/09_Galley_kitchen_with_light_cabinetry.jpg',
  'assets/properties/p5/10_Modern_bedroom_photography.jpg',
  'assets/properties/p5/11_Second_bedroom_interior_photography.jpg',
  'assets/properties/p5/16_25_Master_ensuite_bathroom_interior.jpg',
];

const _p6Images = [
  'assets/properties/p6/02_Empty_contemporary_commercial_sh.jpg',
  'assets/properties/p6/01_Commercial_strip_architectural_p.jpg',
  'assets/properties/p6/03_Empty_retail_interior_floor_plan.jpg',
  'assets/properties/p6/04_Modern_commercial_building_exterior.jpg',
  'assets/properties/p6/05_Rear_utility_area_of_shop.jpg',
];

/// Demo photographs for the two fictional non-residential fixtures below. They reuse existing project
/// images (construction and landscape photography), so they are placeholders, not the real places.
const _p7Images = [
  'assets/businesses/b2/04_Construction_site_structure_in_M.jpg',
  'assets/businesses/b2/03_Construction_equipment_at_buildi.jpg',
  'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg',
];
const _p8Images = [
  'assets/location/12_Nizwa_Fort_and_mountains_landscape.jpg',
  'assets/location/05_Desert_landscape_with_rugged_mou.jpg',
  'assets/location/08_Modern_family_home_in_Nizwa.jpg',
];

/// Fictional demo properties. Coherent, Oman-only, never presented as real listings.
final List<Property> mockProperties = [
  Property(
    id: 'p1',
    title: '4-Bedroom Villa in Al Mouj',
    locationLabel: 'Al Mouj, Muscat, Oman',
    area: 'Muscat',
    type: PropertyType.villa,
    transactionType: TransactionType.buy,
    price: const Money(185000),
    bedrooms: 4,
    bathrooms: 5,
    areaSqm: 312,
    parkingSpaces: 2,
    verification: const PropertyVerification(status: VerificationStatus.verified),
    imageUrls: _p1Images,
    videoUrls: _p1Videos,
    listedByBusinessId: 'b1',
    amenities: const ['Private pool', 'Marina view', 'Maid room', 'Garden'],
    latitude: 23.6480,
    longitude: 58.2661,
    description:
        'A spacious family villa set within the Al Mouj waterfront community, '
        'with private pool access and views over the marina.',
  ),
  Property(
    id: 'p2',
    title: 'Sea-View Apartment in Qurum',
    locationLabel: 'Qurum, Muscat, Oman',
    area: 'Muscat',
    type: PropertyType.apartment,
    transactionType: TransactionType.rent,
    price: const Money(950),
    bedrooms: 2,
    bathrooms: 2,
    areaSqm: 128,
    parkingSpaces: 1,
    verification: const PropertyVerification(status: VerificationStatus.underReview),
    imageUrls: _p2Images,
    listedByBusinessId: 'b1',
    amenities: const ['Sea view', 'Shared pool', 'Gym access'],
    latitude: 23.6140,
    longitude: 58.4780,
    description:
        'A bright two-bedroom apartment overlooking the Qurum coastline, '
        'walking distance to the beach promenade.',
  ),
  Property(
    id: 'p3',
    title: 'Residential Plot in Al Khoudh',
    locationLabel: 'Al Khoudh, Muscat, Oman',
    area: 'Muscat',
    type: PropertyType.residentialLand,
    transactionType: TransactionType.buy,
    price: const Money(72000),
    areaSqm: 600,
    verification: const PropertyVerification(status: VerificationStatus.verified),
    imageUrls: _p3Images,
    listedByBusinessId: 'b2',
    latitude: 23.5859,
    longitude: 58.1697,
    description: 'A clear residential plot close to Sultan Qaboos University, '
        'ready for construction with approved utility access.',
  ),
  Property(
    id: 'p4',
    title: 'Modern Family Villa in Salalah',
    locationLabel: 'Salalah, Oman',
    area: 'Salalah',
    type: PropertyType.villa,
    transactionType: TransactionType.buy,
    price: const Money(115000),
    bedrooms: 5,
    bathrooms: 6,
    areaSqm: 420,
    parkingSpaces: 2,
    verification: const PropertyVerification(status: VerificationStatus.submitted),
    imageUrls: _p4Images,
    listedByBusinessId: 'b2',
    amenities: const ['Large garden', 'Guest annex'],
    latitude: 17.0151,
    longitude: 54.0924,
    description: 'A generous five-bedroom villa in a quiet Salalah neighbourhood, '
        'well suited to a large family.',
  ),
  Property(
    id: 'p5',
    title: '2-Bedroom Apartment in Al Khuwair',
    locationLabel: 'Al Khuwair, Muscat, Oman',
    area: 'Muscat',
    type: PropertyType.apartment,
    transactionType: TransactionType.rent,
    price: const Money(450),
    bedrooms: 2,
    bathrooms: 2,
    areaSqm: 105,
    parkingSpaces: 1,
    verification: const PropertyVerification(status: VerificationStatus.verified),
    imageUrls: _p5Images,
    listedByBusinessId: 'b1',
    latitude: 23.5933,
    longitude: 58.4113,
    description: 'A well-maintained apartment close to Al Khuwair\'s main commercial street.',
  ),
  Property(
    id: 'p6',
    title: 'Commercial Shop in Ruwi',
    locationLabel: 'Ruwi, Muscat, Oman',
    area: 'Muscat',
    type: PropertyType.shop,
    transactionType: TransactionType.lease,
    price: const Money(7800),
    areaSqm: 85,
    verification: const PropertyVerification(status: VerificationStatus.verified),
    imageUrls: _p6Images,
    listedByBusinessId: 'b2',
    latitude: 23.5893,
    longitude: 58.5470,
    description: 'A ground-floor retail shop on a high-footfall Ruwi street.',
  ),
  Property(
    id: 'p7',
    title: 'Demo Warehouse, Sohar Industrial Estate (fictional)',
    locationLabel: 'Sohar, Oman',
    area: 'Sohar',
    type: PropertyType.warehouse,
    transactionType: TransactionType.lease,
    price: const Money(2400),
    areaSqm: 1200,
    verification: const PropertyVerification(status: VerificationStatus.verified),
    imageUrls: _p7Images,
    listedByBusinessId: 'b2',
    latitude: 24.3560,
    longitude: 56.6900,
    description: 'DEMO RECORD. An invented industrial unit with loading access, used to review how an industrial listing is presented. It is not a real property.',
  ),
  Property(
    id: 'p8',
    title: 'Demo Farm, Nizwa (fictional)',
    locationLabel: 'Nizwa, Ad Dakhiliyah, Oman',
    area: 'Nizwa',
    type: PropertyType.farm,
    transactionType: TransactionType.buy,
    price: const Money(95000),
    areaSqm: 18000,
    verification: const PropertyVerification(status: VerificationStatus.verified),
    imageUrls: _p8Images,
    listedByBusinessId: 'b2',
    latitude: 22.9333,
    longitude: 57.5300,
    description: 'DEMO RECORD. An invented agricultural plot with a falaj water share, used to review how an agricultural listing is presented. It is not a real property.',
  ),
];
