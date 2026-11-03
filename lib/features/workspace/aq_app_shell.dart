import '../account/profile_photo.dart';
import '../viewing/widgets/viewing_scaffold.dart' show AQShellInset;
import '../entry/models/signup_purpose.dart' show SignupPurpose;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_documents.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/config/backend_mode.dart';
import '../../core/domain/account_models.dart';
import '../../core/localization/entry_strings.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart';
import '../devbuild/db_models.dart' show proTypeOfPurpose;
import '../flow/screens/approval_screens.dart' show workspaceCaps;
import '../flow/widgets/flow_common.dart';
import '../notifications/notifications.dart';
import 'aq_explore.dart';
import '../role_home/role_home_model.dart' show HomeRole, homeResolutionProvider;
import '../role_home/role_home_screen.dart';

const _tabs = ['/app/home', '/app/explore', '/app/activity', '/app/account'];

/// Which tab a location belongs to, so the selected item is always right: the four tab pages
/// themselves, Account-side pages, and the browsing pages a Home action opens (Buy, Rent, Sell,
/// Favorites, services) which stay under Home.
int customerTabFor(String path) {
  for (var i = 0; i < _tabs.length; i++) {
    if (path.startsWith(_tabs[i])) return i;
  }
  const account = ['/notifications', '/engagements', '/reviews', '/account'];
  if (account.any(path.startsWith)) return 3;
  if (path.startsWith('/viewings')) return 2;
  if (path.startsWith('/search') || path.startsWith('/map')) return 1;
  return 0;
}

/// Authenticated shell: quiet backdrop, the page, and the floating glass nav.
/// Only this shell hosts [AQGlassNav].
class AQAppShell extends StatefulWidget {
  final Widget child;
  const AQAppShell({super.key, required this.child});
  @override
  State<AQAppShell> createState() => _AQAppShellState();
}

class _AQAppShellState extends State<AQAppShell> {
  final _nav = AQNavController();

  @override
  void dispose() {
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final location = GoRouterState.of(context).uri.path;
    final index = customerTabFor(location);
    final items = [
      AQNavItem('home', f.t('nav.home')),
      AQNavItem('explore', f.t('nav.explore')),
      AQNavItem('activity', f.t('nav.activity')),
      AQNavItem('account', f.t('nav.account')),
    ];
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(fit: StackFit.expand, children: [
        // Home and Explore keep a restrained architectural wash; Activity, Account and the lists under them are clean.
        if (location.startsWith('/app/home') || location.startsWith('/app/explore'))
          const AQBackdrop(asset: 'assets/entry/oman_terrace_2k.jpg', quiet: true)
        else
          ColoredBox(color: c.background),
        // Pages inside the shell leave room for the navigation and keep sticky bars above it.
        AQShellInset(
          height: 84 + MediaQuery.paddingOf(context).bottom,
          child: NotificationListener<ScrollNotification>(onNotification: _nav.onScroll, child: widget.child),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // While Home hands an agent or business account over to its workspace (or the session is still
          // loading), the Shop navigation is not shown: the person never sees Shop chrome around Work.
          child: Consumer(builder: (context, ref, _) {
            final me = ref.watch(meProvider);
            final role = ref.watch(homeResolutionProvider).role;
            final handingOver = location.startsWith('/app/home') && ((me.isLoading && !me.hasValue && !me.hasError) || role != HomeRole.buyer);
            if (handingOver) return const SizedBox.shrink();
            return AQGlassNav(
              items: items,
              index: index,
              controller: _nav,
              onSelected: (i) {
                _nav.setCompact(false);
                // Tapping the tab you are already on returns to that tab's first page (e.g. out of a workspace or directory page).
                if (i != index || location != _tabs[i]) context.go(_tabs[i]);
              },
            );
          }),
        ),
      ]),
    );
  }
}

/// Shared page frame for the tabs: title, scrolling body, room for the nav.
class _TabPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _TabPage({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x6, AQSpacing.gutter, 128),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.displaySmall))),
              const SizedBox(height: AQSpacing.x6),
              ...children,
            ]),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: AQTypography.of(context, AQText.bodyMedium, soft: true));
}

/// Role and verification cards for a signed-in session.
List<Widget> _sessionSections(BuildContext context, MeSession m) {
  final f = FlowStrings.of(context);
  final cfg = m.purpose == null ? null : roleConfigs[m.purpose];
  final business = cfg != null && cfg.needsDocuments && m.grant != null;
  return [
    if (business)
      AQReviewSection(title: f.t('home.verification'), children: [
        const SizedBox(height: AQSpacing.x2),
        Align(alignment: AlignmentDirectional.centerStart, child: AQStatusBadge(grant: m.grant!, stage: m.stage)),
        const SizedBox(height: AQSpacing.x2),
        if (m.grant == GrantState.approved) _Body(f.t('home.verified')),
        AQTextButton(label: f.t('home.viewStatus'), trailingIcon: 'chevron-right', onPressed: () => context.go('/verification')),
      ]),
    if (business && m.grant == GrantState.approved && m.purpose != null)
      AQReviewSection(title: f.t('home.workspace'), children: [
        Padding(padding: const EdgeInsets.only(top: AQSpacing.x2, bottom: AQSpacing.x1), child: Text(f.t('ws.t.${m.purpose!.name}'), style: AQTypography.of(context, AQText.titleSmall))),
        for (final k in workspaceCaps(m.purpose!)) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(f.t(k), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
        if (proTypeOfPurpose(m.purpose) != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: AQPrimaryButton(label: f.t('db.ws.open'), trailingChevron: false, onPressed: () => context.push('/app/account/workspace'))),
      ]),
  ];
}

Widget _guestCard(BuildContext context) {
  final f = FlowStrings.of(context);
  return AQReviewSection(title: f.t('guest.title'), children: [
    const SizedBox(height: AQSpacing.x2),
    _Body(f.t('guest.body')),
    const SizedBox(height: AQSpacing.x4),
    AQPrimaryButton(label: f.t('guest.create'), onPressed: () => context.push('/onboarding/purpose')),
    const SizedBox(height: AQSpacing.x2),
    AQSecondaryButton(label: f.t('guest.login'), trailingChevron: false, onPressed: () => context.push('/login')),
    const SizedBox(height: AQSpacing.x1),
  ]);
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) => const RoleHomeScreen();
}

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});
  @override
  Widget build(BuildContext context) {
    final q = GoRouterState.of(context).uri.queryParameters;
    return AQExploreScreen(key: ValueKey('explore-${q['q']}-${q['focus']}'), initialQuery: q['q'], focus: q['focus'] == '1');
  }
}

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    final current = ref.watch(localeProvider).languageCode;
    final m = me.valueOrNull;
    final unread = m == null ? 0 : ref.watch(unreadNotificationsProvider);
    final theme = ref.watch(themeModeProvider);
    final canProfile = m != null && (m.purpose == SignupPurpose.userToShop || m.purpose == SignupPurpose.realEstateAgent);
    return _TabPage(title: f.t('account.title'), children: [
      const AQDemoNotice(),
      if (kUseDemoBackend) const SizedBox(height: AQSpacing.x4),
      if (me.isLoading && m == null) const AQSkeleton(),
      if (m == null && me.hasError) _guestCard(context),
      if (m != null) ..._sessionSections(context, m),
      if (m != null) _ProfileHeader(role: m.purpose == null ? null : roleTitle(context, m.purpose!), phoneLast4: m.phoneLast4),
      if (m != null)
        _SettingsGroup(title: f.t('acct.group.account'), rows: [
          _SettingsRow(icon: 'user', title: f.t('pp.title'), onTap: () => context.push('/app/account/photo')),
          if (canProfile) _SettingsRow(icon: 'account', title: f.t('pf.row'), onTap: () => context.push('/app/account/profile')),
          _SettingsRow(icon: 'bell', title: f.t('ntf.row'), value: unread > 0 ? '$unread' : null, onTap: () => context.push('/notifications')),
          _SettingsRow(icon: 'lock', title: f.t('st.security'), onTap: () => context.push('/app/account/settings/security')),
          _SettingsRow(icon: 'bookmark', title: f.t('account.saved'), onTap: () => context.push('/saved')),
        ]),
      _SettingsGroup(title: f.t('st.grp.prefs'), rows: [
        _SettingsRow(icon: 'bell', title: f.t('st.notif'), onTap: () => context.push('/app/account/settings/notifications')),
        _SettingsRow(icon: 'globe', title: f.t('st.langRegion'), value: current == 'ar' ? 'العربية' : 'English', onTap: () => context.push('/app/account/settings/language')),
        _SettingsRow(icon: theme == ThemeMode.dark ? 'moon' : 'sun', title: f.t('st.appearance'), value: theme == ThemeMode.dark ? f.t('account.dark') : (theme == ThemeMode.light ? f.t('account.light') : f.t('st.ap.system')), onTap: () => context.push('/app/account/settings/appearance')),
        _SettingsRow(icon: 'sliders', title: f.t('st.prefs'), onTap: () => context.push('/app/account/settings/preferences')),
      ]),
      _SettingsGroup(title: f.t('st.grp.help'), rows: [
        _SettingsRow(icon: 'shield', title: f.t('st.privacy'), onTap: () => context.push('/app/account/settings/privacy')),
        _SettingsRow(icon: 'info', title: f.t('st.support'), onTap: () => context.push('/app/account/settings/support')),
        _SettingsRow(icon: 'verified', title: f.t('st.about'), onTap: () => context.push('/app/account/settings/about')),
      ]),
      if (m != null)
        _SettingsGroup(title: f.t('acct.group.session'), rows: [
          _SettingsRow(
            icon: 'lock',
            title: f.t('account.signOut'),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(meProvider);
              ref.invalidate(verificationProvider);
              if (context.mounted) context.go('/entry');
            },
          ),
          _SettingsRow(icon: 'alert', title: f.t('del.row'), danger: true, onTap: () => context.push('/account/delete')),
        ]),
    ]);
  }
}

/// Who is signed in: a plain header, not another card to tap.
class _ProfileHeader extends StatelessWidget {
  final String? role, phoneLast4;
  const _ProfileHeader({this.role, this.phoneLast4});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x5),
      child: Container(
        padding: const EdgeInsets.all(AQSpacing.x4),
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline), boxShadow: AQElevation.subtle),
        child: Row(children: [
        Semantics(button: true, label: f.t('pp.title'), excludeSemantics: true, onTap: () => context.push('/app/account/photo'), child: AQPressable(onTap: () => context.push('/app/account/photo'), child: const AQAvatar(size: 64))),
        const SizedBox(width: AQSpacing.x4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role ?? f.t('account.title'), style: AQTypography.of(context, AQText.headlineSmall)),
            if (phoneLast4 != null) Text('${f.t('account.phone')} •••• $phoneLast4', style: AQTypography.of(context, AQText.bodySmall, soft: true)),
          ]),
        ),
      ]),
      ),
    );
  }
}

/// A titled group of settings rows on one surface, separated by hairlines.
class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _SettingsGroup({required this.title, required this.rows});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2, left: AQSpacing.x1), child: Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.labelMedium, soft: true)))),
        Container(
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: c.hairline, indent: AQSpacing.x4, endIndent: AQSpacing.x4),
              rows[i],
            ],
          ]),
        ),
      ]),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String icon, title;
  final String? value;
  final bool danger;
  final VoidCallback onTap;
  const _SettingsRow({required this.icon, required this.title, required this.onTap, this.value, this.danger = false});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final fg = danger ? c.danger : c.ink;
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: value == null ? title : '$title, $value',
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x2),
            child: Row(children: [
              AQIcon(icon, size: 20, color: danger ? c.danger : c.accent),
              const SizedBox(width: AQSpacing.x3),
              Expanded(child: Text(title, style: AQTypography.of(context, AQText.bodyMedium, color: fg))),
              if (value != null) Padding(padding: const EdgeInsetsDirectional.only(end: AQSpacing.x2), child: Text(value!, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
              AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
            ]),
          ),
        ),
      ),
    );
  }
}
