import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart' show aqBack;
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/entry_strings.dart' show localeProvider, themeModeProvider;
import '../../core/localization/flow_strings.dart';
import '../../data/repositories/app_state_providers.dart' show recentSearchesProvider;
import '../devbuild/db_workspace.dart' show DbShellPage;
import '../onboarding/interests.dart';
import '../search/aq_filter_sheet.dart' show AQChoicePill;
import '../viewing/widgets/viewing_format.dart' show aqLargeText;
import '../viewing/widgets/viewing_scaffold.dart';
import 'app_settings.dart';

/// Where a settings page lives. The same pages serve the customer Account area and the business
/// workspaces, each inside its own shell, so the navigation never changes under the person.
class SettingsCtx {
  final String base;
  final bool pro;
  const SettingsCtx(this.base, {this.pro = false});
  String back() => pro ? (base.startsWith('/agent') ? '/agent/settings' : '/pro/settings') : '/app/account';
}

const kCustomerSettings = SettingsCtx('/app/account/settings');
const kProSettings = SettingsCtx('/pro/settings/p', pro: true);
const kAgentSettings = SettingsCtx('/agent/settings/p', pro: true);

class SettingsPage extends StatelessWidget {
  final SettingsCtx ctx;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Where Back goes when it is not the settings home (the password page returns to Security).
  final String? backTo;
  const SettingsPage({super.key, required this.ctx, required this.title, this.subtitle, required this.children, this.backTo});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, backTo ?? ctx.back());
    if (ctx.pro) {
      return DbShellPage(title: title, subtitle: subtitle, onBack: back, children: children);
    }
    return AQViewingScaffold(title: title, subtitle: subtitle, backLabel: f.t('common.back'), onBack: back, children: [...children, const SizedBox(height: AQSpacing.x6)]);
  }
}

/// A titled block of rows on one surface.
class SettingsBlock extends StatelessWidget {
  final String? title, caption;
  final List<Widget> children;
  const SettingsBlock({super.key, this.title, this.caption, required this.children});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x2),
              child: Semantics(header: true, child: Text(title!, style: AQTypography.of(context, AQText.titleMedium))),
            ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x2),
              child: Text(caption!, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x2),
            decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: c.hairline),
                  children[i],
                ],
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class SwitchRow extends StatelessWidget {
  final String title;
  final String? sub;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const SwitchRow({super.key, required this.title, this.sub, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final enabled = onChanged != null;
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      focusable: true,
      onFocus: () {},
      label: sub == null ? title : '$title. $sub',
      excludeSemantics: true,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: AQPressable(
        onTap: enabled ? () => onChanged!(!value) : null,
        pressedScale: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AQSpacing.x2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AQTypography.of(context, AQText.bodyMedium, color: enabled ? c.ink : c.inkFaint)),
                      if (sub != null) Text(sub!, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                      if (!enabled) Text(f.t('st.off'), style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
                    ],
                  ),
                ),
                const SizedBox(width: AQSpacing.x3),
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Switch(value: value, onChanged: enabled ? (_) {} : null, activeTrackColor: c.accent, activeThumbColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A label with a value, for facts that are not editable here.
class InfoRow extends StatelessWidget {
  final String label, value;
  const InfoRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
    // Narrow phones stack the pair (label over value) instead of squeezing two columns.
    child: LayoutBuilder(
      builder: (context, box) {
        final l = Text(label, style: AQTypography.of(context, AQText.bodySmall, soft: true));
        final v = Text(value, style: AQTypography.of(context, AQText.bodyMedium));
        if (box.maxWidth < 300 || aqLargeText(context)) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [l, const SizedBox(height: 2), v]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 4, child: l), Expanded(flex: 6, child: v)]);
      },
    ),
  );
}

Widget _choices(List<(String, bool, VoidCallback)> items) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
  child: Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [for (final i in items) AQChoicePill(label: i.$1, selected: i.$2, onTap: i.$3)]),
);

// ------------------------------------------------------------------ account and security

class SecuritySettingsScreen extends StatelessWidget {
  final SettingsCtx ctx;
  const SecuritySettingsScreen(this.ctx, {super.key});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return SettingsPage(
      ctx: ctx,
      title: f.t('st.sec.title'),
      subtitle: f.t('st.sec.sub'),
      children: [
        SettingsBlock(
          title: f.t('st.sec.password'),
          caption: f.t('st.sec.password.b'),
          children: [
            Semantics(
              button: true,
              focusable: true,
              onFocus: () {},
              label: f.t('st.sec.password'),
              excludeSemantics: true,
              onTap: () => context.push('${ctx.base}/password'),
              child: AQPressable(
                onTap: () => context.push('${ctx.base}/password'),
                pressedScale: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Row(children: [
                    Expanded(child: Text(f.t('st.sec.password'), style: AQTypography.of(context, AQText.bodyMedium))),
                    AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
                  ]),
                ),
              ),
            ),
          ],
        ),
        SettingsBlock(title: f.t('st.sec.session'), children: [InfoRow(f.t('st.sec.session'), f.t('st.sec.session.b'))]),
        SettingsBlock(title: f.t('st.sec.methods'), children: [InfoRow(f.t('st.sec.methods'), f.t('st.sec.methods.b'))]),
      ],
    );
  }
}

/// The password-change prototype. It validates every rule on the screen and, when the entries are
/// acceptable, says so as a simulation. There is no authentication service, so nothing is sent and
/// no password changes; the screen never says otherwise.
class ChangePasswordScreen extends StatefulWidget {
  final SettingsCtx ctx;
  const ChangePasswordScreen(this.ctx, {super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePasswordScreen> {
  final _cur = TextEditingController(), _new = TextEditingController(), _again = TextEditingController();
  bool _tried = false, _done = false;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  bool get _longEnough => _new.text.length >= 8;
  bool get _hasNumber => RegExp(r'\d').hasMatch(_new.text);
  bool get _differs => _new.text.isNotEmpty && _new.text != _cur.text;
  bool get _matches => _again.text.isNotEmpty && _again.text == _new.text;

  String? _errCur(FlowStrings f) => _cur.text.isEmpty ? f.t('st.sec.e.current') : null;
  String? _errNew(FlowStrings f) {
    if (!_longEnough) return f.t('st.sec.e.short');
    if (!_hasNumber) return f.t('st.sec.e.number');
    if (_new.text == _cur.text) return f.t('st.sec.e.same');
    return null;
  }

  String? _errAgain(FlowStrings f) => _again.text != _new.text ? f.t('st.sec.e.match') : null;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    String? show(String? e) => _tried ? e : null;
    final back = '${widget.ctx.base}/security';
    Widget rule(bool ok, String key) => Semantics(
      container: true,
      label: '${f.t(key)}: ${f.t(ok ? 'st.sec.rule.met' : 'st.sec.rule.open')}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          AQIcon(ok ? 'check' : 'clock', size: 16, color: ok ? c.accentDeep : c.inkFaint),
          const SizedBox(width: AQSpacing.x2),
          Expanded(child: Text(f.t(key), style: AQTypography.of(context, AQText.bodySmall, color: ok ? c.ink : c.inkSoft))),
        ]),
      ),
    );
    return SettingsPage(
      ctx: widget.ctx,
      backTo: back,
      title: f.t('st.sec.password'),
      subtitle: f.t('st.sec.password.b'),
      children: [
        if (_done)
          SettingsBlock(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
                child: Column(
                  key: const ValueKey('password-simulated'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      AQIcon('info', size: 20, color: c.accent),
                      const SizedBox(width: AQSpacing.x2),
                      Expanded(child: Semantics(header: true, child: Text(f.t('st.sec.sim.t'), style: AQTypography.of(context, AQText.titleMedium)))),
                    ]),
                    const SizedBox(height: AQSpacing.x2),
                    Text(f.t('st.sec.done'), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
                    const SizedBox(height: AQSpacing.x4),
                    AQPrimaryButton(label: f.t('st.sec.backTo'), trailingChevron: false, onPressed: () => context.go(back)),
                  ],
                ),
              ),
            ],
          )
        else
          SettingsBlock(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AQPasswordField(label: f.t('st.sec.current'), controller: _cur, showLabel: f.t('st.sec.show'), hideLabel: f.t('st.sec.hide'), error: show(_errCur(f)), onChanged: (_) => setState(() {})),
                    const SizedBox(height: AQSpacing.x3),
                    AQPasswordField(label: f.t('st.sec.new'), controller: _new, showLabel: f.t('st.sec.show'), hideLabel: f.t('st.sec.hide'), error: show(_errNew(f)), newPassword: true, onChanged: (_) => setState(() {})),
                    const SizedBox(height: AQSpacing.x2),
                    Column(
                      key: const ValueKey('password-rules'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(f.t('st.sec.rules'), style: AQTypography.of(context, AQText.labelMedium, soft: true))),
                        rule(_longEnough, 'st.sec.rule.len'),
                        rule(_hasNumber, 'st.sec.rule.num'),
                        rule(_differs, 'st.sec.rule.diff'),
                        rule(_matches, 'st.sec.rule.match'),
                      ],
                    ),
                    const SizedBox(height: AQSpacing.x3),
                    AQPasswordField(label: f.t('st.sec.confirm'), controller: _again, showLabel: f.t('st.sec.show'), hideLabel: f.t('st.sec.hide'), error: show(_errAgain(f)), action: TextInputAction.done, onChanged: (_) => setState(() {})),
                    const SizedBox(height: AQSpacing.x4),
                    AQPrimaryButton(
                      label: f.t('st.sec.check'),
                      trailingChevron: false,
                      onPressed: () => setState(() {
                        _tried = true;
                        _done = _errCur(f) == null && _errNew(f) == null && _errAgain(f) == null;
                      }),
                    ),
                    const SizedBox(height: AQSpacing.x3),
                    Text(f.t('st.sec.noServer'), style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ notifications

class NotificationSettingsScreen extends ConsumerWidget {
  final SettingsCtx ctx;
  const NotificationSettingsScreen(this.ctx, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    Widget row(String key) => SwitchRow(title: f.t('st.nt.$key'), sub: f.t('st.nt.$key.b'), value: s.notifications[key] ?? false, onChanged: (v) => n.setNotification(key, v));
    return SettingsPage(
      ctx: ctx,
      title: f.t('st.nt.title'),
      subtitle: f.t('st.nt.sub'),
      children: [
        SettingsBlock(children: [for (final k in const ['viewings', 'maintenance', 'ebroker', 'engagements', 'offers']) row(k)]),
        SettingsBlock(
          title: f.t('st.nt.channels'),
          children: [
            SwitchRow(title: f.t('st.nt.email'), value: false, onChanged: null),
            SwitchRow(title: f.t('st.nt.push'), value: false, onChanged: null),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ language and region

class LanguageSettingsScreen extends ConsumerWidget {
  final SettingsCtx ctx;
  const LanguageSettingsScreen(this.ctx, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final current = ref.watch(localeProvider).languageCode;
    return SettingsPage(
      ctx: ctx,
      title: f.t('st.lg.title'),
      subtitle: f.t('st.lg.sub'),
      children: [
        SettingsBlock(
          title: f.t('st.lg.language'),
          children: [
            _choices([
              ('English', current == 'en', () => ref.read(localeProvider.notifier).state = const Locale('en')),
              ('العربية', current == 'ar', () => ref.read(localeProvider.notifier).state = const Locale('ar')),
            ]),
          ],
        ),
        SettingsBlock(
          title: f.t('st.lg.region'),
          caption: f.t('st.lg.note'),
          children: [
            InfoRow(f.t('st.lg.region'), f.t('st.lg.oman')),
            InfoRow(f.t('st.lg.currency'), f.t('st.lg.omr')),
            InfoRow(f.t('st.lg.phone'), '+968'),
            InfoRow(f.t('st.lg.area'), f.t('st.lg.sqm')),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ appearance and accessibility

class AppearanceSettingsScreen extends ConsumerWidget {
  final SettingsCtx ctx;
  const AppearanceSettingsScreen(this.ctx, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final theme = ref.watch(themeModeProvider);
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    void setTheme(ThemeMode m) => ref.read(themeModeProvider.notifier).state = m;
    return SettingsPage(
      ctx: ctx,
      title: f.t('st.ap.title'),
      subtitle: f.t('st.ap.sub'),
      children: [
        SettingsBlock(
          title: f.t('st.ap.theme'),
          children: [
            _choices([
              (f.t('st.ap.light'), theme == ThemeMode.light, () => setTheme(ThemeMode.light)),
              (f.t('st.ap.dark'), theme == ThemeMode.dark, () => setTheme(ThemeMode.dark)),
              (f.t('st.ap.system'), theme == ThemeMode.system, () => setTheme(ThemeMode.system)),
            ]),
          ],
        ),
        SettingsBlock(
          title: f.t('st.ap.textSize'),
          children: [
            _choices([
              (f.t('st.ap.size1'), s.textScale == 1, () => n.setTextScale(1)),
              (f.t('st.ap.size2'), s.textScale == 1.15, () => n.setTextScale(1.15)),
              (f.t('st.ap.size3'), s.textScale == 1.3, () => n.setTextScale(1.3)),
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: Text(f.t('st.ap.preview'), style: AQTypography.of(context, AQText.bodyMedium)),
            ),
          ],
        ),
        SettingsBlock(
          children: [SwitchRow(title: f.t('st.ap.motion'), sub: f.t('st.ap.motion.b'), value: s.reducedMotion, onChanged: n.setReducedMotion)],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ privacy

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  final SettingsCtx ctx;
  const PrivacySettingsScreen(this.ctx, {super.key});
  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacyState();
}

class _PrivacyState extends ConsumerState<PrivacySettingsScreen> {
  bool _cleared = false;
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    return SettingsPage(
      ctx: widget.ctx,
      title: f.t('st.pv.title'),
      subtitle: f.t('st.pv.sub'),
      children: [
        SettingsBlock(
          children: [
            SwitchRow(title: f.t('st.pv.suggestions'), sub: f.t('st.pv.suggestions.b'), value: s.privacy['suggestions'] ?? true, onChanged: (v) => n.setPrivacy('suggestions', v)),
            SwitchRow(title: f.t('st.pv.recents'), sub: f.t('st.pv.recents.b'), value: s.privacy['recents'] ?? true, onChanged: (v) => n.setPrivacy('recents', v)),
            SwitchRow(title: f.t('st.pv.analytics'), value: false, onChanged: null),
          ],
        ),
        SettingsBlock(title: f.t('st.pv.data'), children: [InfoRow(f.t('st.pv.data'), f.t('st.pv.data.b'))]),
        AQSecondaryButton(
          label: f.t('st.pv.clear'),
          trailingChevron: false,
          onPressed: () {
            ref.read(recentSearchesProvider.notifier).state = [];
            setState(() => _cleared = true);
          },
        ),
        if (_cleared)
          Padding(
            padding: const EdgeInsets.only(top: AQSpacing.x3),
            child: AQErrorBanner(tone: AQBannerTone.success, text: f.t('st.pv.cleared')),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ saved preferences

const kPreferredLocations = ['Muscat', 'Salalah', 'Sohar', 'Nizwa', 'Sur', 'Al Mouj', 'Seeb', 'Bawshar'];

class SavedPreferencesScreen extends ConsumerWidget {
  final SettingsCtx ctx;
  const SavedPreferencesScreen(this.ctx, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final interests = ref.watch(interestsProvider);
    final s = ref.watch(appSettingsProvider);
    return SettingsPage(
      ctx: ctx,
      title: f.t('st.pf.title'),
      subtitle: f.t('st.pf.sub'),
      children: [
        SettingsBlock(
          title: f.t('st.pf.interests'),
          children: [
            _choices([
              for (final i in Interest.values)
                (
                  f.t('int.${i.name}'),
                  interests.contains(i),
                  () => ref.read(interestsProvider.notifier).update((v) => v.contains(i) ? ({...v}..remove(i)) : {...v, i}),
                ),
            ]),
          ],
        ),
        SettingsBlock(
          title: f.t('st.pf.locations'),
          children: [
            _choices([for (final l in kPreferredLocations) (l, s.locations.contains(l), () => ref.read(appSettingsProvider.notifier).toggleLocation(l))]),
          ],
        ),
        SettingsBlock(
          children: [
            _LinkRow(label: f.t('st.pf.saved'), onTap: () => context.push('/saved')),
            InfoRow(f.t('st.pf.searches'), f.t('st.pf.searches.b')),
          ],
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.label, required this.onTap});
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
          child: Row(
            children: [
              Expanded(child: Text(label, style: AQTypography.of(context, AQText.bodyMedium))),
              AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ support

class SupportScreen extends ConsumerStatefulWidget {
  final SettingsCtx ctx;
  const SupportScreen(this.ctx, {super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportState();
}

class _SupportState extends ConsumerState<SupportScreen> {
  final _subject = TextEditingController(), _message = TextEditingController();
  String _kind = 'question';
  bool _tried = false;
  String? _sent;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final tickets = ref.watch(supportTicketsProvider);
    String? subjErr() => _tried && _subject.text.trim().isEmpty ? f.t('st.su.e.subject') : null;
    String? msgErr() => _tried && _message.text.trim().isEmpty ? f.t('st.su.e.message') : null;
    return SettingsPage(
      ctx: widget.ctx,
      title: f.t('st.su.title'),
      subtitle: f.t('st.su.sub'),
      children: [
        SettingsBlock(
          title: f.t('st.su.faq'),
          children: [
            for (var i = 1; i <= 4; i++)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  title: Text(f.t('st.faq.$i.q'), style: AQTypography.of(context, AQText.bodyMedium)),
                  iconColor: c.accent,
                  collapsedIconColor: c.inkSoft,
                  expandedAlignment: AlignmentDirectional.centerStart,
                  children: [Text(f.t('st.faq.$i.a'), style: AQTypography.of(context, AQText.bodySmall, soft: true))],
                ),
              ),
          ],
        ),
        SettingsBlock(
          title: '${f.t('st.su.contact')} / ${f.t('st.su.report')}',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(f.t('st.su.kind'), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
                  const SizedBox(height: AQSpacing.x2),
                  Wrap(
                    spacing: AQSpacing.x2,
                    runSpacing: AQSpacing.x2,
                    children: [for (final k in const ['question', 'problem', 'feedback']) AQChoicePill(label: f.t('st.su.k.$k'), selected: _kind == k, onTap: () => setState(() => _kind = k))],
                  ),
                  const SizedBox(height: AQSpacing.x4),
                  AQTextField(label: f.t('st.su.subject'), controller: _subject, error: subjErr(), onChanged: (_) => setState(() {})),
                  const SizedBox(height: AQSpacing.x3),
                  AQTextField(label: f.t('st.su.message'), controller: _message, error: msgErr(), minLines: 3, maxLines: 6, keyboardType: TextInputType.multiline, action: TextInputAction.newline, onChanged: (_) => setState(() {})),
                  const SizedBox(height: AQSpacing.x4),
                  AQPrimaryButton(
                    label: f.t('st.su.send'),
                    trailingChevron: false,
                    onPressed: () {
                      setState(() => _tried = true);
                      if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) return;
                      final t = ref.read(supportTicketsProvider.notifier).add(_kind, _subject.text.trim(), _message.text.trim());
                      setState(() {
                        _sent = t.reference;
                        _subject.clear();
                        _message.clear();
                        _tried = false;
                      });
                    },
                  ),
                  if (_sent != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AQSpacing.x3),
                      child: AQErrorBanner(tone: AQBannerTone.success, text: f.t('st.su.sent', {'ref': _sent!})),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (tickets.isNotEmpty)
          SettingsBlock(
            title: f.t('st.su.tickets'),
            children: [for (final t in tickets) InfoRow('${t.reference} · ${f.t('st.su.k.${t.kind}')}', t.subject)],
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ legal and about

class AboutScreen extends StatelessWidget {
  final SettingsCtx ctx;
  const AboutScreen(this.ctx, {super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    Widget doc(String title, String body) => Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AQSpacing.x3),
        title: Text(title, style: AQTypography.of(context, AQText.bodyMedium)),
        iconColor: c.accent,
        collapsedIconColor: c.inkSoft,
        expandedAlignment: AlignmentDirectional.centerStart,
        children: [Text(body, style: AQTypography.of(context, AQText.bodySmall, soft: true))],
      ),
    );
    return SettingsPage(
      ctx: ctx,
      title: f.t('st.ab.title'),
      subtitle: f.t('st.ab.sub'),
      children: [
        SettingsBlock(children: [doc(f.t('st.ab.terms'), f.t('st.ab.terms.b')), doc(f.t('st.ab.privacy'), f.t('st.ab.privacy.b'))]),
        SettingsBlock(children: [InfoRow(f.t('st.ab.version'), f.t('st.ab.version.v'))]),
        Text(f.t('st.ab.note'), style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
      ],
    );
  }
}

/// The page for a path segment, shared by the customer, business and agent areas.
Widget settingsPageFor(String name, SettingsCtx ctx) => switch (name) {
  'security' => SecuritySettingsScreen(ctx),
  'password' => ChangePasswordScreen(ctx),
  'notifications' => NotificationSettingsScreen(ctx),
  'language' => LanguageSettingsScreen(ctx),
  'appearance' => AppearanceSettingsScreen(ctx),
  'privacy' => PrivacySettingsScreen(ctx),
  'preferences' => SavedPreferencesScreen(ctx),
  'support' => SupportScreen(ctx),
  _ => AboutScreen(ctx),
};

/// The settings pages plus the pages that sit under one (the password prototype under Security).
const kSettingsRoutes = [...kSettingsPages, 'password'];
const kSettingsPages = ['security', 'notifications', 'language', 'appearance', 'privacy', 'preferences', 'support', 'about'];
