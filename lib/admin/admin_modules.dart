import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/aq/aq_tokens.dart';
import '../core/aq/aq_typography.dart';
import '../features/search/aq_filter_sheet.dart' show AQChoicePill;
import '../features/viewing/domain/viewing_presentation.dart' show AQTone;
import '../features/viewing/widgets/viewing_format.dart';
import 'admin_auth.dart';
import 'admin_directory.dart';
import 'admin_directory_screens.dart' show adminConfirm;
import '../features/workspace/aq_home.dart' show aqImg;
import 'admin_images.dart';
import 'admin_models.dart';
import 'admin_widgets.dart';
import 'admin_ui.dart';
import 'admin_l10n.dart';

/// The platform management modules that share one list-and-detail pattern: property listings,
/// trusted brokers, development projects, construction, architecture and design portfolios,
/// maintenance, viewings and requests, content, announcements. Every record is fictional and lives
/// in memory; a status change is local, asks first, and is written to the Activity log.
enum ModKey { listings, brokers, projects, construction, design, maintenance, viewings, content, announcements }

class ModRecord {
  final String id, title, subtitle, status;
  final List<(String, String)> fields;
  const ModRecord(this.id, this.title, this.subtitle, this.status, this.fields);
  ModRecord withStatus(String s) => ModRecord(id, title, subtitle, s, fields);
}

class ModAction {
  final String label, target, warning;
  final bool primary;
  const ModAction(this.label, this.target, this.warning, {this.primary = false});
}

class ModuleDef {
  final ModKey key;
  final String title, subtitle, searchHint, recordNoun;
  final List<String> statuses;
  final Map<String, (AQTone, String)> look;

  /// What may be done from each status.
  final Map<String, List<ModAction>> actions;
  const ModuleDef(this.key, this.title, this.subtitle, this.searchHint, this.recordNoun, this.statuses, this.look, this.actions);
  String get route => '/m/${key.name}';
}

const _ok = (AQTone.success, 'check');
const _wait = (AQTone.pending, 'clock');
const _bad = (AQTone.danger, 'lock');
const _off = (AQTone.neutral, 'close');
const _warn = (AQTone.warning, 'alert');

final kModules = <ModKey, ModuleDef>{
  ModKey.listings: const ModuleDef(
    ModKey.listings,
    'Property listings',
    'Every listing on the platform, whoever posted it. Moderation of new submissions is under Listing moderation.',
    'Search title, owner or place',
    'listing',
    ['Live', 'Hidden', 'Removed'],
    {'Live': _ok, 'Hidden': _wait, 'Removed': _bad},
    {
      'Live': [ModAction('Hide', 'Hidden', 'The listing would stop being shown to customers in this demo.'), ModAction('Remove', 'Removed', 'Removing is simulated: nothing is deleted.')],
      'Hidden': [ModAction('Restore', 'Live', 'The listing would be shown again in this demo.', primary: true), ModAction('Remove', 'Removed', 'Removing is simulated: nothing is deleted.')],
      'Removed': [ModAction('Restore', 'Hidden', 'The listing comes back as hidden in this demo.', primary: true)],
    },
  ),
  ModKey.brokers: const ModuleDef(
    ModKey.brokers,
    'Agents and trusted brokers',
    'Real estate agents and whether they carry the Trusted Broker mark. Accounts shows the same people as accounts.',
    'Search name or city',
    'broker',
    ['Standard', 'Trusted', 'Under review'],
    {'Standard': _off, 'Trusted': _ok, 'Under review': _wait},
    {
      'Standard': [ModAction('Mark trusted', 'Trusted', 'The agent would carry the Trusted Broker mark in this demo.', primary: true), ModAction('Send to review', 'Under review', 'The agent moves to review in this demo.')],
      'Trusted': [ModAction('Remove trusted mark', 'Standard', 'The mark would be removed in this demo.'), ModAction('Send to review', 'Under review', 'The agent moves to review in this demo.')],
      'Under review': [ModAction('Mark trusted', 'Trusted', 'The agent would carry the Trusted Broker mark in this demo.', primary: true), ModAction('Mark standard', 'Standard', 'The review would end without the mark in this demo.')],
    },
  ),
  ModKey.projects: const ModuleDef(
    ModKey.projects,
    'Development projects',
    'Projects submitted by development companies.',
    'Search project or developer',
    'project',
    ['Draft', 'Under review', 'Published', 'Changes requested'],
    {'Draft': _off, 'Under review': _wait, 'Published': _ok, 'Changes requested': _warn},
    {
      'Under review': [ModAction('Publish', 'Published', 'The project would be shown to customers in this demo.', primary: true), ModAction('Request changes', 'Changes requested', 'The developer would be asked to change the project in this demo.')],
      'Published': [ModAction('Unpublish', 'Under review', 'The project returns to review in this demo.')],
      'Changes requested': [ModAction('Back to review', 'Under review', 'The project returns to review in this demo.', primary: true)],
      'Draft': [],
    },
  ),
  ModKey.construction: const ModuleDef(
    ModKey.construction,
    'Construction companies and projects',
    'Company records and the projects they list.',
    'Search company or project',
    'record',
    ['Active', 'Under review', 'Suspended'],
    {'Active': _ok, 'Under review': _wait, 'Suspended': _bad},
    {
      'Active': [ModAction('Suspend', 'Suspended', 'Suspending is simulated: no real company is affected.'), ModAction('Send to review', 'Under review', 'The record moves to review in this demo.')],
      'Under review': [ModAction('Set active', 'Active', 'The record would be treated as active in this demo.', primary: true), ModAction('Suspend', 'Suspended', 'Suspending is simulated: no real company is affected.')],
      'Suspended': [ModAction('Set active', 'Active', 'The record would be treated as active in this demo.', primary: true)],
    },
  ),
  ModKey.design: const ModuleDef(
    ModKey.design,
    'Architecture and design portfolios',
    'Studios and designers, and the portfolios they show.',
    'Search studio or portfolio',
    'portfolio',
    ['Active', 'Under review', 'Suspended'],
    {'Active': _ok, 'Under review': _wait, 'Suspended': _bad},
    {
      'Active': [ModAction('Suspend', 'Suspended', 'Suspending is simulated: no real studio is affected.'), ModAction('Send to review', 'Under review', 'The portfolio moves to review in this demo.')],
      'Under review': [ModAction('Set active', 'Active', 'The portfolio would be shown in this demo.', primary: true), ModAction('Suspend', 'Suspended', 'Suspending is simulated: no real studio is affected.')],
      'Suspended': [ModAction('Set active', 'Active', 'The portfolio would be shown in this demo.', primary: true)],
    },
  ),
  ModKey.maintenance: const ModuleDef(
    ModKey.maintenance,
    'Maintenance providers and requests',
    'Requests customers sent to maintenance providers.',
    'Search request, provider or customer',
    'request',
    ['New', 'Scheduled', 'Completed', 'Cancelled'],
    {'New': _warn, 'Scheduled': _wait, 'Completed': _ok, 'Cancelled': _off},
    {
      'New': [ModAction('Schedule', 'Scheduled', 'The visit would be marked as scheduled in this demo.', primary: true), ModAction('Cancel', 'Cancelled', 'The request would be cancelled in this demo.')],
      'Scheduled': [ModAction('Mark completed', 'Completed', 'The visit would be marked as done in this demo.', primary: true), ModAction('Cancel', 'Cancelled', 'The request would be cancelled in this demo.')],
      'Completed': [],
      'Cancelled': [],
    },
  ),
  ModKey.viewings: const ModuleDef(
    ModKey.viewings,
    'Viewings and professional requests',
    'Viewing appointments and requests sent to professionals.',
    'Search property, agent or customer',
    'request',
    ['Requested', 'Confirmed', 'Completed', 'Cancelled'],
    {'Requested': _warn, 'Confirmed': _wait, 'Completed': _ok, 'Cancelled': _off},
    {
      'Requested': [ModAction('Confirm', 'Confirmed', 'The appointment would be marked as confirmed in this demo.', primary: true), ModAction('Cancel', 'Cancelled', 'The appointment would be cancelled in this demo.')],
      'Confirmed': [ModAction('Mark completed', 'Completed', 'The appointment would be marked as done in this demo.', primary: true), ModAction('Cancel', 'Cancelled', 'The appointment would be cancelled in this demo.')],
      'Completed': [],
      'Cancelled': [],
    },
  ),
  ModKey.content: const ModuleDef(
    ModKey.content,
    'Categories and content',
    'The categories and property types customers browse, and the home sections built from them.',
    'Search category or section',
    'item',
    ['Visible', 'Hidden'],
    {'Visible': _ok, 'Hidden': _off},
    {
      'Visible': [ModAction('Hide', 'Hidden', 'The item would be hidden from customers in this demo.')],
      'Hidden': [ModAction('Show', 'Visible', 'The item would be shown to customers in this demo.', primary: true)],
    },
  ),
  ModKey.announcements: const ModuleDef(
    ModKey.announcements,
    'Notifications and announcements',
    'Messages to customers or professionals. Nothing is delivered: sending is simulated.',
    'Search title or audience',
    'announcement',
    ['Draft', 'Sent (sample)'],
    {'Draft': _off, 'Sent (sample)': _ok},
    {
      'Draft': [ModAction('Send (sample)', 'Sent (sample)', 'Sending is simulated. No message reaches any person.', primary: true)],
      'Sent (sample)': [],
    },
  ),
};

Map<ModKey, List<ModRecord>> seedModules() => {
  ModKey.listings: const [
    ModRecord('L1', '4-Bedroom Villa, Al Mouj', 'Sami Agent Demo', 'Live', [('Owner', 'Sami Agent Demo'), ('Place', 'Al Mouj, Muscat'), ('Price', 'OMR 185,000'), ('Source', 'Agent listing')]),
    ModRecord('L2', 'Modern Family Villa, Salalah', 'Sami Agent Demo', 'Live', [('Owner', 'Sami Agent Demo'), ('Place', 'Salalah, Dhofar'), ('Price', 'OMR 115,000'), ('Source', 'Agent listing')]),
    ModRecord('L3', 'Sea view villa (e-Broker)', 'Prototype owner', 'Hidden', [('Owner', 'Prototype owner'), ('Place', 'Bawshar, Muscat'), ('Price', 'OMR 250,000'), ('Source', 'Aqary e-Broker')]),
    ModRecord('L4', 'Office floor, Ruwi', 'Horizon Developments (demo)', 'Live', [('Owner', 'Horizon Developments (demo)'), ('Place', 'Ruwi, Muscat'), ('Price', 'OMR 320 / month'), ('Source', 'Developer listing')]),
    ModRecord('L5', 'Duplicate studio flat', 'Faisal Agent Test', 'Removed', [('Owner', 'Faisal Agent Test'), ('Place', 'Nizwa'), ('Price', 'OMR 210 / month'), ('Note', 'Removed as a duplicate (fictional).')]),
  ],
  ModKey.brokers: const [
    ModRecord('B1', 'Sami Agent Demo', 'Muscat', 'Trusted', [('Licence', 'Demo licence 1042'), ('City', 'Muscat'), ('Listings', '7'), ('Reviews', '4.7 (sample)')]),
    ModRecord('B2', 'Rana Agent Example', 'Salalah', 'Under review', [('Licence', 'Demo licence 2210'), ('City', 'Salalah'), ('Listings', '0'), ('Note', 'Documents are in the verification queue.')]),
    ModRecord('B3', 'Khalid Broker Sample', 'Sohar', 'Standard', [('Licence', 'Demo licence 3318'), ('City', 'Sohar'), ('Listings', '3'), ('Reviews', '4.1 (sample)')]),
    ModRecord('B4', 'Maha Agent Demo', 'Muscat', 'Standard', [('Licence', 'Demo licence 4476'), ('City', 'Muscat'), ('Listings', '5'), ('Reviews', '4.4 (sample)')]),
  ],
  ModKey.projects: const [
    ModRecord('P1', 'Al Khuwair Residences', 'Horizon Developments (demo)', 'Published', [('Developer', 'Horizon Developments (demo)'), ('Units', '48'), ('Place', 'Al Khuwair, Muscat'), ('Handover', 'Q4 2027 (sample)')]),
    ModRecord('P2', 'Qurum Heights', 'Coastline Projects (demo)', 'Under review', [('Developer', 'Coastline Projects (demo)'), ('Units', '120'), ('Place', 'Qurum, Muscat'), ('Handover', 'Q2 2028 (sample)')]),
    ModRecord('P3', 'Sur Marina Villas', 'Coastline Projects (demo)', 'Changes requested', [('Developer', 'Coastline Projects (demo)'), ('Units', '24'), ('Place', 'Sur'), ('Feedback', 'Site plan image is unreadable (fictional).')]),
    ModRecord('P4', 'Nizwa Garden Homes', 'Horizon Developments (demo)', 'Draft', [('Developer', 'Horizon Developments (demo)'), ('Units', '16'), ('Place', 'Nizwa'), ('Note', 'Not submitted yet.')]),
  ],
  ModKey.construction: const [
    ModRecord('C1', 'Gulf Builders (demo)', 'Muscat', 'Active', [('Company', 'Gulf Builders (demo)'), ('Projects listed', '6'), ('City', 'Muscat'), ('Grade', 'Grade A (sample)')]),
    ModRecord('C2', 'Al Rawda Contracting (demo)', 'Sohar', 'Under review', [('Company', 'Al Rawda Contracting (demo)'), ('Projects listed', '0'), ('City', 'Sohar'), ('Note', 'Registration is in the verification queue.')]),
    ModRecord('C3', 'Sahari Contracting', 'Sohar', 'Active', [('Company', 'Sahari Contracting'), ('Projects listed', '3'), ('City', 'Sohar'), ('Grade', 'Grade B (sample)')]),
    ModRecord('C4', 'Dune Works (demo)', 'Nizwa', 'Suspended', [('Company', 'Dune Works (demo)'), ('Projects listed', '2'), ('City', 'Nizwa'), ('Note', 'Suspended after a complaint (fictional).')]),
  ],
  ModKey.design: const [
    ModRecord('D1', 'Studio Nakhal (demo)', 'Architecture', 'Active', [('Studio', 'Studio Nakhal (demo)'), ('Discipline', 'Architecture'), ('Portfolio pieces', '12'), ('City', 'Muscat')]),
    ModRecord('D2', 'Arc Atelier (demo)', 'Architecture', 'Under review', [('Studio', 'Arc Atelier (demo)'), ('Discipline', 'Architecture'), ('Portfolio pieces', '4'), ('City', 'Muscat')]),
    ModRecord('D3', 'Maison Interiors (demo)', 'Interior design', 'Active', [('Studio', 'Maison Interiors (demo)'), ('Discipline', 'Interior design'), ('Portfolio pieces', '9'), ('City', 'Muscat')]),
    ModRecord('D4', 'Terrace Outdoors (demo)', 'Exterior design', 'Suspended', [('Studio', 'Terrace Outdoors (demo)'), ('Discipline', 'Exterior design'), ('Portfolio pieces', '7'), ('Note', 'Portfolio images reported as copied (fictional).')]),
  ],
  ModKey.maintenance: const [
    ModRecord('M1', 'Plumbing, leaking sink', 'Layla Demo to Muscat Plumbing (sample)', 'New', [('Customer', 'Layla Demo'), ('Provider', 'Muscat Plumbing (sample)'), ('Category', 'Plumbing'), ('Preferred', 'Thursday morning')]),
    ModRecord('M2', 'AC servicing', 'Omar Sample to CoolAir Oman (sample)', 'Scheduled', [('Customer', 'Omar Sample'), ('Provider', 'CoolAir Oman (sample)'), ('Category', 'Air conditioning'), ('Visit', 'Saturday 10:00')]),
    ModRecord('M3', 'Pool cleaning', 'Layla Demo to Blue Pools (sample)', 'Completed', [('Customer', 'Layla Demo'), ('Provider', 'Blue Pools (sample)'), ('Category', 'Pool'), ('Visit', 'Last Monday')]),
    ModRecord('M4', 'Kitchen refit quote', 'Omar Sample to Hearth Kitchens (sample)', 'Cancelled', [('Customer', 'Omar Sample'), ('Provider', 'Hearth Kitchens (sample)'), ('Category', 'Kitchen'), ('Note', 'Cancelled by the customer.')]),
  ],
  ModKey.viewings: const [
    ModRecord('V1', 'Viewing: 4-Bedroom Villa, Al Mouj', 'Layla Demo with Sami Agent Demo', 'Requested', [('Customer', 'Layla Demo'), ('Agent', 'Sami Agent Demo'), ('Property', '4-Bedroom Villa, Al Mouj'), ('Requested for', 'Friday 16:00')]),
    ModRecord('V2', 'Viewing: Modern Family Villa, Salalah', 'Omar Sample with Sami Agent Demo', 'Confirmed', [('Customer', 'Omar Sample'), ('Agent', 'Sami Agent Demo'), ('Property', 'Modern Family Villa, Salalah'), ('When', 'Sunday 11:00')]),
    ModRecord('V3', 'Request: architecture consultation', 'Layla Demo to Studio Nakhal (demo)', 'Requested', [('Customer', 'Layla Demo'), ('Professional', 'Studio Nakhal (demo)'), ('Kind', 'Architecture consultation'), ('Note', 'Extension of a family home.')]),
    ModRecord('V4', 'Viewing: Office floor, Ruwi', 'Omar Sample with Maha Agent Demo', 'Completed', [('Customer', 'Omar Sample'), ('Agent', 'Maha Agent Demo'), ('Property', 'Office floor, Ruwi'), ('When', 'Last Tuesday')]),
  ],
  ModKey.content: const [
    ModRecord('K1', 'Residential', 'Category', 'Visible', [('Kind', 'Category'), ('Types', 'Villa, apartment, townhouse, residential land'), ('Shown on', 'Buy, Rent, Explore')]),
    ModRecord('K2', 'Commercial', 'Category', 'Visible', [('Kind', 'Category'), ('Types', 'Office, shop, warehouse, commercial land'), ('Shown on', 'Buy, Rent, Explore')]),
    ModRecord('K3', 'Agriculture', 'Category', 'Visible', [('Kind', 'Category'), ('Types', 'Farm, agricultural land'), ('Shown on', 'Buy, Rent, Explore')]),
    ModRecord('K4', 'Industrial', 'Category', 'Hidden', [('Kind', 'Category'), ('Types', 'Factory, industrial land'), ('Shown on', 'Nowhere while hidden')]),
    ModRecord('K5', 'Explore more with AQARATI', 'Home section', 'Visible', [('Kind', 'Home section'), ('Shown on', 'Home (User to Shop)')]),
  ],
  ModKey.announcements: const [
    ModRecord('N1', 'Welcome to the new AQARATI', 'All customers', 'Sent (sample)', [('Audience', 'All customers'), ('Message', 'Thank you for trying the new app. (Sample text.)')]),
    ModRecord('N2', 'Verify your business to appear in search', 'Professionals', 'Draft', [('Audience', 'Professionals'), ('Message', 'Complete verification to be listed. (Sample text.)')]),
  ],
};

class AdminModulesNotifier extends StateNotifier<Map<ModKey, List<ModRecord>>> {
  AdminModulesNotifier(this._log) : super(seedModules());
  final void Function(String actor, String text, String target) _log;

  ModRecord? record(ModKey k, String id) {
    for (final r in state[k] ?? const <ModRecord>[]) {
      if (r.id == id) return r;
    }
    return null;
  }

  void setStatus(ModKey k, String id, String status, String actor) {
    final r = record(k, id);
    if (r == null || r.status == status) return;
    state = {
      ...state,
      k: [for (final x in state[k]!) x.id == id ? x.withStatus(status) : x],
    };
    _log(actor, '${kModules[k]!.title}: set to ${status.toLowerCase()}', r.title);
  }

  /// Announcements are the one module where the console creates a record.
  void addAnnouncement(String title, String audience, String message, String actor) {
    final id = 'N${(state[ModKey.announcements]?.length ?? 0) + 1}';
    state = {
      ...state,
      ModKey.announcements: [
        ModRecord(id, title, audience, 'Draft', [('Audience', audience), ('Message', message)]),
        ...state[ModKey.announcements]!,
      ],
    };
    _log(actor, 'Created announcement draft', title);
  }
}

final adminModulesProvider = StateNotifierProvider<AdminModulesNotifier, Map<ModKey, List<ModRecord>>>(
  (ref) => AdminModulesNotifier((a, t, g) => ref.read(adminDirectoryProvider.notifier).record(a, t, g)),
);

/// Filtering behind each list (pure).
List<ModRecord> filterModule(List<ModRecord> all, {String query = '', String? status}) {
  final q = query.trim().toLowerCase();
  return [
    for (final r in all)
      if ((status == null || r.status == status) &&
          (q.isEmpty || '${r.title} ${r.subtitle} ${r.fields.map((f) => f.$2).join(' ')}'.toLowerCase().contains(q)))
        r,
  ];
}

String _actor(WidgetRef ref) => ref.read(adminAuthProvider).session?.name ?? 'Admin';

class AdminModuleListScreen extends ConsumerStatefulWidget {
  final ModKey modKey;
  const AdminModuleListScreen({super.key, required this.modKey});
  @override
  ConsumerState<AdminModuleListScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<AdminModuleListScreen> {
  final _q = TextEditingController();
  String? _status;

  @override
  void didUpdateWidget(covariant AdminModuleListScreen old) {
    super.didUpdateWidget(old);
    if (old.modKey != widget.modKey) {
      _q.clear();
      _status = null;
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _newAnnouncement() async {
    final title = TextEditingController();
    final msg = TextEditingController();
    String audience = 'All customers';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('New announcement'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AdminField(label: tr('Title'), controller: title),
              const SizedBox(height: AQSpacing.x3),
              AdminField(label: tr('Message'), controller: msg, minLines: 2, maxLines: 4),
              const SizedBox(height: AQSpacing.x3),
              Wrap(spacing: AQSpacing.x2, children: [
                for (final a in const ['All customers', 'Agents', 'Professionals'])
                  AQChoicePill(label: tr(a), selected: audience == a, onTap: () => set(() => audience = a)),
              ]),
            ]),
          ),
          actions: [
            AdminTextButton(label: tr('Cancel'), color: AQColors.of(d).inkSoft, onPressed: () => Navigator.of(d).pop(false)),
            AdminTextButton(label: tr('Save draft'), color: AQColors.of(d).accent, onPressed: () => Navigator.of(d).pop(true)),
          ],
        ),
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty && mounted) {
      ref.read(adminModulesProvider.notifier).addAnnouncement(title.text.trim(), audience, msg.text.trim(), _actor(ref));
    }
    title.dispose();
    msg.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = kModules[widget.modKey]!;
    final all = ref.watch(adminModulesProvider)[widget.modKey] ?? const [];
    final shown = filterModule(all, query: _q.text, status: _status);
    final canWrite = ref.watch(adminAuthProvider).session?.role.canDecide ?? false;
    return AdminFrame(
      section: def.route,
      title: def.title,
      subtitle: def.subtitle,
      stats: [(tr('Total'), all.length), (tr('Showing'), shown.length)],
      actions: [
        if (widget.modKey == ModKey.announcements && canWrite)
          AdminPrimaryButton(label: tr('New announcement'), leadingIcon: 'plus', trailingChevron: false, compact: true, onPressed: _newAnnouncement),
      ],
      children: [
        AdminSearchField(controller: _q, hint: def.searchHint, onChanged: (_) => setState(() {})),
        const SizedBox(height: AQSpacing.x3),
        adminFilterRow(context, 'Status', [
          ('All', _status == null, () => setState(() => _status = null)),
          for (final s in def.statuses) ('$s · ${all.where((r) => r.status == s).length}', _status == s, () => setState(() => _status = _status == s ? null : s)),
        ]),
        if (shown.isEmpty)
          AdminNotice(icon: 'search', title: tr('No ${def.recordNoun}s match'), body: tr('Change the search or the status filter.'))
        else
          AdminTable(
            headers: const ['Record', 'Detail', 'Status'],
            flex: const [4, 4, 2],
            rows: [
              for (final r in shown)
                AdminTableRow(
                  key: r.id,
                  semantics: tr('${r.title}, ${r.subtitle}, ${r.status}'),
                  onTap: () => context.go('${def.route}/${r.id}'),
                  cells: [
                    _recordLead(context, widget.modKey, r),
                    Text(r.subtitle, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
                    Align(alignment: AlignmentDirectional.centerStart, child: adminStatusPill(r.status, def.look[r.status] ?? _off)),
                  ],
                ),
            ],
          ),
        adminDemoNotice(),
      ],
    );
  }
}

/// The first cell of a record row: its picture (or a monogram for a person) beside its title.
/// Categories, announcements and viewings of services keep a plain title where a picture would mean nothing.
Widget _recordLead(BuildContext context, ModKey key, ModRecord r) {
  final title = Text(r.title, style: AQTypography.of(context, AQText.titleSmall));
  final img = adminModImage(key, r.id);
  if (img != null) return AdminThumbCell(thumb: AdminThumb(asset: img, size: 52), child: title);
  if (key == ModKey.brokers) return AdminThumbCell(thumb: AdminThumb(icon: 'agent', size: 52), child: title);
  return title;
}

class AdminModuleDetailScreen extends ConsumerWidget {
  final ModKey modKey;
  final String id;
  const AdminModuleDetailScreen({super.key, required this.modKey, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = kModules[modKey]!;
    ref.watch(adminModulesProvider);
    final dir = ref.watch(adminDirectoryProvider);
    final r = ref.read(adminModulesProvider.notifier).record(modKey, id);
    final can = ref.watch(adminAuthProvider).session?.role.canDecide ?? false;
    if (r == null) {
      return AdminFrame(section: def.route, title: def.title, onBack: () => context.go(def.route), backLabel: tr('Back to ${def.title.toLowerCase()}'), children: [AdminNotice(title: tr('We could not find this record.'))]);
    }
    final history = dir.audit.where((e) => e.target == r.title && e.text.startsWith(def.title)).toList();
    final actions = def.actions[r.status] ?? const <ModAction>[];
    return AdminFrame(
      section: def.route,
      title: r.title,
      subtitle: r.subtitle,
      onBack: () => context.go(def.route),
      backLabel: tr('Back to ${def.title.toLowerCase()}'),
      actions: [adminStatusPill(r.status, def.look[r.status] ?? _off)],
      children: [
        if (adminModImage(modKey, r.id) case final img?)
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AQRadius.large),
              child: SizedBox(height: 160, width: double.infinity, child: ExcludeSemantics(child: aqImg(img, cacheWidth: 900))),
            ),
          ),
        AdminKeyValues([('Status', r.status), ...r.fields]),
        adminSection(context, 'Actions'),
        if (!can)
          AdminNotice(icon: 'lock', title: tr('Read-only'), body: tr('Your role can view these records but not change them.'))
        else if (actions.isEmpty)
          AdminNotice(title: tr('Nothing to do here'), body: tr('This record is in a final state in the demo.'))
        else
          Wrap(
            spacing: AQSpacing.x3,
            runSpacing: AQSpacing.x3,
            children: [
              for (final a in actions)
                a.primary
                      ? AdminPrimaryButton(label: a.label, trailingChevron: false, onPressed: () => _go(context, ref, r, a))
                      : AdminSecondaryButton(label: a.label, trailingChevron: false, onPressed: () => _go(context, ref, r, a)),
            ],
          ),
        adminSection(context, 'Activity on this record'),
        if (history.isEmpty)
          AdminNotice(title: tr('No administrative activity yet.'))
        else
          AdminTable(
            headers: const ['When', 'Who', 'Action'],
            flex: const [3, 3, 4],
            rows: [
              for (final (i, e) in history.indexed)
                AdminTableRow(key: 'h$i', semantics: tr('${e.actor}, ${e.text}'), cells: [Text('${VFmt.shortDate(context, e.at)}, ${VFmt.time(context, e.at)}'), Text(e.actor), Text(e.text)]),
            ],
          ),
        adminDemoNotice(),
      ],
    );
  }

  Future<void> _go(BuildContext context, WidgetRef ref, ModRecord r, ModAction a) async {
    final ok = await adminConfirm(context, title: tr('${a.label}: ${r.title}?'), body: a.warning, action: a.label);
    if (ok) ref.read(adminModulesProvider.notifier).setStatus(modKey, r.id, a.target, _actor(ref));
  }
}

// ------------------------------------------------------------------ analytics

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final mods = ref.watch(adminModulesProvider);
    final dir = ref.watch(adminDirectoryProvider);
    int n(ModKey k, String s) => (mods[k] ?? const []).where((r) => r.status == s).length;
    final phone = MediaQuery.sizeOf(context).width < 640;
    final tileWidth = phone ? (MediaQuery.sizeOf(context).width - AQSpacing.gutter * 2 - AQSpacing.x3) / 2 : 240.0;
    Widget tile(String label, String value, {bool sample = false}) => SizedBox(
      width: tileWidth,
      child: AdminPanel(
        padding: EdgeInsets.all(phone ? AQSpacing.x3 : AQSpacing.x4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AQTypography.of(context, phone ? AQText.headlineMedium : AQText.displaySmall)),
          Text(label, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
          if (sample) Text('Sample figure', style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)),
        ]),
      ),
    );
    const weeks = [38, 44, 41, 52, 57, 63, 71];
    return AdminFrame(
      section: '/analytics',
      title: tr('Analytics'),
      subtitle: tr('Counts come from the records in this demo. Anything marked Sample figure is invented and measures nothing.'),
      children: [
        adminSection(context, 'From the demo records'),
        Wrap(spacing: AQSpacing.x3, runSpacing: AQSpacing.x3, children: [
          tile('Accounts', '${dir.accounts.length}'),
          tile('Live listings', '${n(ModKey.listings, 'Live')}'),
          tile('Trusted brokers', '${n(ModKey.brokers, 'Trusted')}'),
          tile('Published projects', '${n(ModKey.projects, 'Published')}'),
          tile('Open maintenance requests', '${n(ModKey.maintenance, 'New') + n(ModKey.maintenance, 'Scheduled')}'),
          tile('Viewings waiting', '${n(ModKey.viewings, 'Requested')}'),
        ]),
        adminSection(context, 'Sample figures'),
        Wrap(spacing: AQSpacing.x3, runSpacing: AQSpacing.x3, children: [
          tile('Sample visits this week', '4,820', sample: true),
          tile('Sample enquiries this week', '312', sample: true),
          tile('Sample banner taps this week', '146', sample: true),
        ]),
        const SizedBox(height: AQSpacing.x4),
        AdminPanel(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text('Sample enquiries by week', style: AQTypography.of(context, AQText.titleSmall))),
            const SizedBox(height: AQSpacing.x3),
            for (final (i, w) in weeks.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 72, child: Text('Week ${i + 1}', style: AQTypography.of(context, AQText.bodySmall))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: w / 80, minHeight: 8, color: c.accent, backgroundColor: c.hairline))),
                  SizedBox(width: 36, child: Text('$w', textAlign: TextAlign.end, style: AQTypography.of(context, AQText.labelMedium))),
                ]),
              ),
          ]),
        ),
        adminDemoNotice(),
      ],
    );
  }
}

// ------------------------------------------------------------------ settings

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(adminAuthProvider).session;
    return AdminFrame(
      section: '/settings',
      title: tr('Profile and settings'),
      subtitle: tr('Your demo admin profile.'),
      children: [
        AdminKeyValues([
          ('Name', s?.name ?? '-'),
          ('Role', s == null ? '-' : roleLabel(s.role)),
          ('Can decide on reviews', (s?.role.canDecide ?? false) ? 'Yes' : 'No (read-only)'),
          ('Can manage ads', (s?.role.canManageAds ?? false) ? 'Yes' : 'No'),
          ('Sign-in', 'Simulated. Nothing protects this console.'),
          ('Two-step code', 'Illustrative. Any real use needs a real service.'),
        ]),
        adminSection(context, 'Session'),
        AdminSecondaryButton(
            label: tr('Sign out'),
            trailingChevron: false,
            onPressed: () => ref.read(adminAuthProvider.notifier).signOut(),
          ),
        adminDemoNotice(),
      ],
    );
  }
}
