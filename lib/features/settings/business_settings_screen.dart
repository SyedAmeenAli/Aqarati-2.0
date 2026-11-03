import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show meProvider, verificationProvider;
import '../role_home/role_home_model.dart';
import '../search/aq_filter_sheet.dart' show AQChoicePill;
import 'settings_screens.dart';

/// Every service a business can offer. The primary one is fixed by the account's role; the rest are
/// additional services on the same account.
const kServiceKeys = ['brokerage', 'development', 'construction', 'architecture', 'interior', 'exterior', 'maintenance'];

String primaryServiceOf(HomeRole r) => switch (r) {
  HomeRole.agent => 'brokerage',
  HomeRole.developer => 'development',
  HomeRole.construction => 'construction',
  HomeRole.architecture => 'architecture',
  HomeRole.interiorExterior => 'interior',
  HomeRole.buyer => 'brokerage',
};

class BusinessProfile {
  final String owner, name, phone, email, location, about;
  final Map<String, String> details;
  final Set<String> services;
  final List<String> team;
  const BusinessProfile({
    this.owner = 'Demo owner',
    this.name = 'Demo business',
    this.phone = '9000 0000',
    this.email = 'business@example.test',
    this.location = 'Muscat',
    this.about = '',
    this.details = const {},
    this.services = const {},
    this.team = const [],
  });
  BusinessProfile copyWith({String? owner, String? name, String? phone, String? email, String? location, String? about, Map<String, String>? details, Set<String>? services, List<String>? team}) => BusinessProfile(
    owner: owner ?? this.owner,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    location: location ?? this.location,
    about: about ?? this.about,
    details: details ?? this.details,
    services: services ?? this.services,
    team: team ?? this.team,
  );
}

/// The one business account of this session. Additional services live here, on the same record,
/// so adding a service never creates a second account.
class BusinessProfileNotifier extends StateNotifier<BusinessProfile> {
  BusinessProfileNotifier() : super(const BusinessProfile());
  void save(BusinessProfile p) => state = p;
  void toggleService(String key) {
    final next = {...state.services};
    next.contains(key) ? next.remove(key) : next.add(key);
    state = state.copyWith(services: next);
  }

  void addMember(String name) => state = state.copyWith(team: [...state.team, name]);
  void removeMember(String name) => state = state.copyWith(team: [...state.team]..remove(name));
}

final businessProfileProvider = StateNotifierProvider<BusinessProfileNotifier, BusinessProfile>((ref) => BusinessProfileNotifier());

/// Role-specific fields: an architecture studio never sees a contractor grade.
List<(String key, String labelKey)> roleFields(HomeRole r) => switch (r) {
  HomeRole.agent => [('licence', 'st.bz.licence'), ('areas', 'st.bz.areas')],
  HomeRole.developer => [('reg', 'st.bz.reg'), ('types', 'st.bz.types')],
  HomeRole.construction => [('grade', 'st.bz.grade'), ('trades', 'st.bz.trades')],
  HomeRole.architecture => [('practice', 'st.bz.practice'), ('specialities', 'st.bz.specialities')],
  HomeRole.interiorExterior => [('styles', 'st.bz.styles'), ('areas', 'st.bz.areas')],
  HomeRole.buyer => const [],
};

class BusinessSettingsScreen extends ConsumerStatefulWidget {
  final HomeRole role;
  const BusinessSettingsScreen({super.key, required this.role});
  @override
  ConsumerState<BusinessSettingsScreen> createState() => _BusinessSettingsState();
}

class _BusinessSettingsState extends ConsumerState<BusinessSettingsScreen> {
  late final _name = TextEditingController(text: ref.read(businessProfileProvider).name);
  late final _owner = TextEditingController(text: ref.read(businessProfileProvider).owner);
  late final _phone = TextEditingController(text: ref.read(businessProfileProvider).phone);
  late final _email = TextEditingController(text: ref.read(businessProfileProvider).email);
  late final _location = TextEditingController(text: ref.read(businessProfileProvider).location);
  late final _about = TextEditingController(text: ref.read(businessProfileProvider).about);
  late final Map<String, TextEditingController> _extra = {
    for (final e in roleFields(widget.role)) e.$1: TextEditingController(text: ref.read(businessProfileProvider).details['${widget.role.name}.${e.$1}'] ?? ''),
  };
  final _member = TextEditingController();
  bool _saved = false, _tried = false;

  @override
  void dispose() {
    for (final c in [_name, _owner, _phone, _email, _location, _about, _member, ..._extra.values]) {
      c.dispose();
    }
    super.dispose();
  }

  SettingsCtx get _ctx => widget.role == HomeRole.agent ? kAgentSettings : kProSettings;

  void _save() {
    setState(() => _tried = true);
    if (_name.text.trim().isEmpty || _owner.text.trim().isEmpty) return;
    final cur = ref.read(businessProfileProvider);
    ref.read(businessProfileProvider.notifier).save(
      cur.copyWith(
        name: _name.text.trim(),
        owner: _owner.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        location: _location.text.trim(),
        about: _about.text.trim(),
        details: {...cur.details, for (final e in _extra.entries) '${widget.role.name}.${e.key}': e.value.text.trim()},
      ),
    );
    setState(() => _saved = true);
  }

  Future<void> _delete() async {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(f.t('st.bz.delete.q')),
        content: Text(f.t('st.bz.delete.b')),
        actions: [
          AQTextButton(label: f.t('common.cancel'), color: c.inkSoft, onPressed: () => Navigator.of(d).pop(false)),
          AQTextButton(label: f.t('st.bz.delete.go'), color: c.danger, onPressed: () => Navigator.of(d).pop(true)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(meProvider);
    ref.invalidate(verificationProvider);
    if (mounted) context.go('/entry');
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final role = widget.role;
    final profile = ref.watch(businessProfileProvider);
    final primary = primaryServiceOf(role);
    final ctx = _ctx;
    Widget field(String label, TextEditingController ctl, {String? error, TextInputType? type, int lines = 1}) => Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x3),
      child: AQTextField(label: label, controller: ctl, error: error, keyboardType: type, minLines: lines, maxLines: lines == 1 ? 1 : 5, onChanged: (_) => setState(() => _saved = false)),
    );
    Widget link(String label, String page) => _SettingsLink(label: label, onTap: () => context.push('${ctx.base}/$page'));

    return SettingsPage(
      ctx: SettingsCtx(ctx.base, pro: true),
      title: f.t('st.bz.title'),
      subtitle: f.t('st.bz.sub'),
      children: [
        SettingsBlock(
          title: f.t('st.bz.owner'),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: field(f.t('st.bz.ownerName'), _owner, error: _tried && _owner.text.trim().isEmpty ? f.t('st.su.e.subject') : null),
            ),
          ],
        ),
        SettingsBlock(
          title: f.t('st.bz.profile'),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field(f.t('st.bz.name'), _name, error: _tried && _name.text.trim().isEmpty ? f.t('st.su.e.subject') : null),
                  Padding(
                    padding: const EdgeInsets.only(top: AQSpacing.x4),
                    child: Text(f.t('st.bz.primary'), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
                  ),
                  const SizedBox(height: AQSpacing.x2),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Semantics(
                      label: '${f.t('st.bz.primary')}: ${f.t('st.svc.$primary')}',
                      excludeSemantics: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(18)),
                        child: Text(f.t('st.svc.$primary'), style: AQTypography.of(context, AQText.labelMedium, color: c.onAccent)),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('st.bz.primary.b'), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                  Padding(
                    padding: const EdgeInsets.only(top: AQSpacing.x4),
                    child: Text(f.t('st.bz.services'), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
                  ),
                  const SizedBox(height: AQSpacing.x2),
                  Wrap(
                    spacing: AQSpacing.x2,
                    runSpacing: AQSpacing.x2,
                    children: [
                      for (final k in kServiceKeys)
                        if (k != primary) AQChoicePill(label: f.t('st.svc.$k'), selected: profile.services.contains(k), onTap: () => ref.read(businessProfileProvider.notifier).toggleService(k)),
                    ],
                  ),
                  Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('st.bz.services.b'), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                  field(f.t('st.bz.phone'), _phone, type: TextInputType.phone),
                  field(f.t('st.bz.email'), _email, type: TextInputType.emailAddress),
                  field(f.t('st.bz.location'), _location),
                  field(f.t('st.bz.about'), _about, lines: 3),
                ],
              ),
            ),
          ],
        ),
        if (roleFields(role).isNotEmpty)
          SettingsBlock(
            title: f.t('st.bz.role'),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final e in roleFields(role)) field(f.t(e.$2), _extra[e.$1]!)]),
              ),
            ],
          ),
        AQPrimaryButton(label: f.t('st.save'), trailingChevron: false, onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: AQSpacing.x3),
            child: AQErrorBanner(tone: AQBannerTone.success, text: f.t('st.bz.saved')),
          ),
        const SizedBox(height: AQSpacing.x5),
        SettingsBlock(
          title: f.t('st.bz.verification'),
          caption: f.t('st.bz.verification.b'),
          children: [_SettingsLink(label: f.t('st.bz.verification'), onTap: () => context.push('/verification/details'))],
        ),
        SettingsBlock(
          title: f.t('st.bz.branding'),
          children: [SwitchRowLike(title: f.t('st.bz.branding'), sub: f.t('st.bz.branding.b'))],
        ),
        SettingsBlock(
          title: f.t('st.bz.team'),
          caption: f.t('st.bz.team.b'),
          children: [
            for (final m in profile.team)
              Row(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3), child: Text(m, style: AQTypography.of(context, AQText.bodyMedium)))),
                  AQTextButton(label: f.t('db.pf.remove'), color: c.inkSoft, onPressed: () => ref.read(businessProfileProvider.notifier).removeMember(m)),
                ],
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: AQTextField(label: f.t('st.bz.inviteName'), controller: _member, action: TextInputAction.done)),
                  const SizedBox(width: AQSpacing.x2),
                  SizedBox(
                    width: 104,
                    child: AQSecondaryButton(
                      label: f.t('st.bz.invite'),
                      compact: true,
                      trailingChevron: false,
                      onPressed: () {
                        final n = _member.text.trim();
                        if (n.isEmpty) return;
                        ref.read(businessProfileProvider.notifier).addMember(n);
                        _member.clear();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsBlock(
          title: f.t('st.bz.shared'),
          children: [
            link(f.t('st.nt.title'), 'notifications'),
            link(f.t('st.lg.title'), 'language'),
            link(f.t('st.ap.title'), 'appearance'),
            link(f.t('st.sec.title'), 'security'),
            link(f.t('st.pv.title'), 'privacy'),
            link(f.t('st.su.title'), 'support'),
            link(f.t('st.ab.title'), 'about'),
          ],
        ),
        AQSecondaryButton(label: f.t('st.bz.delete'), trailingChevron: false, foreground: c.danger, onPressed: _delete),
      ],
    );
  }
}

class _SettingsLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SettingsLink({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        pressedScale: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(children: [
            Expanded(child: Text(label, style: AQTypography.of(context, AQText.bodyMedium))),
            AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
          ]),
        ),
      ),
    );
  }
}

/// A disabled row that explains why it is off.
class SwitchRowLike extends StatelessWidget {
  final String title, sub;
  const SwitchRowLike({super.key, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AQTypography.of(context, AQText.bodyMedium, color: c.inkFaint)),
          Text(sub, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        ],
      ),
    );
  }
}

/// `/pro/settings`: the business settings of whichever professional role is signed in.
class ProBusinessSettingsScreen extends ConsumerWidget {
  const ProBusinessSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BusinessSettingsScreen(role: ref.watch(homeResolutionProvider).role);
}
