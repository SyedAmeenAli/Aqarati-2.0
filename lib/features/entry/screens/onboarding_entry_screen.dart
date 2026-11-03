import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/localization/entry_strings.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../data/api/account_api.dart';
import '../../flow/screens/auth_screens.dart' show routeForSession;
import '../../workspace/aq_home.dart' show AQSlideSwitch;
import '../models/entry_experience.dart';
import '../../../core/startup/intro_state.dart';
import '../../../core/startup/logo_handoff.dart';
import '../models/onboarding_page.dart';
import '../widgets/entry_common.dart' show MasterLogo;

/// Public entry (onboarding page 1). Content waits for the startup film's
/// handover, then arrives with a short staggered fade-and-rise.
class OnboardingEntryScreen extends ConsumerStatefulWidget {
  final int pageIndex;
  const OnboardingEntryScreen({super.key, this.pageIndex = 0});

  @override
  ConsumerState<OnboardingEntryScreen> createState() => _OnboardingEntryScreenState();
}

class _OnboardingEntryScreenState extends ConsumerState<OnboardingEntryScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  AuthProviderKind? _busy;

  OnboardingPage get _page => onboardingPages[widget.pageIndex];

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: AQMotion.hero);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReveal(ref.read(introStateProvider)));
  }

  void _maybeReveal(IntroState s) {
    if (!introAllowsReveal(s) || _enter.isAnimating || _enter.value > 0) return;
    if (AQMotion.reduced(context)) {
      _enter.value = 1;
    } else {
      // Let the film's logo travel home first; the live logo takes over as it lands.
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted) _enter.forward();
      });
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _signIn(AuthProviderKind kind) async {
    final s = EntryStrings.of(context);
    setState(() => _busy = kind);
    final result = await ref.read(authRepositoryProvider).signInWithProvider(kind);
    if (!mounted) return;
    setState(() => _busy = null);
    final messenger = ScaffoldMessenger.of(context);
    final style = AQTypography.of(context, AQText.bodyMedium, color: Colors.white);
    switch (result) {
      case AuthSuccess():
        // The account decides where it belongs, not the door that was chosen.
        try {
          final me = await ref.read(accountApiProvider).getMe();
          if (!mounted) return;
          context.go(routeForSession(me));
        } catch (_) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text(s.providerUnavailable, style: style)));
        }
      case AuthUnavailable():
        messenger.showSnackBar(SnackBar(content: Text(s.providerUnavailable, style: style)));
      case AuthFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message, style: style)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<IntroState>(introStateProvider, (_, next) => _maybeReveal(next));
    final s = EntryStrings.of(context);
    final c = AQColors.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final hh = MediaQuery.sizeOf(context).height;
    final compact = AQLayout.compact(context);
    final measure = AQLayout.contentWidth(context) * 0.84;
    // Pick the largest display step whose longest line ("Property Journey") still fits one line.
    final headlineRole = hh < 740 ? AQText.displaySmall : compact ? AQText.displayMedium : (AQLayout.contentWidth(context) >= 480 ? AQText.displayLarge : AQText.displayMedium);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        body: Stack(fit: StackFit.expand, children: [
          AQBackdrop(asset: _page.backgroundAsset),
          SafeArea(
            child: LayoutBuilder(builder: (context, box) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AQSpacing.gutter),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const SizedBox(height: AQControl.tap),
                              SizedBox(height: LogoHandoff.topGap(box.maxHeight)),
                              Center(child: AQReveal(animation: _enter, begin: 0, end: 0.5, dy: 12, child: MasterLogo(width: LogoHandoff.entryWidth(w, hh)))),
                              SizedBox(height: box.maxHeight > 780 ? AQSpacing.x10 : (box.maxHeight > 650 ? AQSpacing.x5 : AQSpacing.x3)),
                              AQReveal(
                                animation: _enter,
                                begin: 0.12,
                                end: 0.62,
                                dy: 8,
                                child: Semantics(
                                  header: true,
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(text: '${s.headlineA}\n'),
                                      TextSpan(text: s.headlineB, style: AQTypography.of(context, headlineRole, color: c.accent, italic: true)),
                                    ]),
                                    style: AQTypography.of(context, headlineRole),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? AQSpacing.x2 : AQSpacing.x4),
                              AQReveal(
                                animation: _enter,
                                begin: 0.25,
                                end: 0.72,
                                dy: 6,
                                child: ConstrainedBox(constraints: BoxConstraints(maxWidth: measure), child: Text(s.support, style: AQTypography.of(context, compact ? AQText.bodyMedium : AQText.bodyLarge, soft: true))),
                              ),
                            ]),
                            const SizedBox(height: AQSpacing.x4),
                            Column(children: [
                              // A pager only exists when there is more than one real page.
                              if (onboardingPages.length > 1) ...[
                                AQReveal(animation: _enter, begin: 0.35, end: 0.8, dy: 6, child: _Pager(count: onboardingPages.length, index: widget.pageIndex, label: s.pageLabel)),
                                SizedBox(height: compact ? AQSpacing.x3 : AQSpacing.x5),
                              ] else
                                SizedBox(height: compact ? AQSpacing.x1 : AQSpacing.x3),
                              AQReveal(
                                animation: _enter,
                                begin: 0.45,
                                end: 0.9,
                                dy: 8,
                                child: Column(children: [
                                  _ExperienceChooser(compact: compact),
                                  SizedBox(height: compact ? AQSpacing.x2 : AQSpacing.x3),
                                  AQPrimaryButton(compact: compact, label: s.createAccount, onPressed: () => context.push(ref.read(entryExperienceProvider).signupRoute)),
                                  SizedBox(height: compact ? 10 : AQSpacing.x3),
                                  AQSecondaryButton(compact: compact, label: s.login, onPressed: () => context.push(ref.read(entryExperienceProvider).loginRoute)),
                                  SizedBox(height: compact ? 10 : AQSpacing.x3),
                                  AQSecondaryButton(compact: compact, label: FlowStrings.of(context).t('biz.cta'), leadingIcon: 'development', onPressed: () => context.push('/signup/business')),
                                  SizedBox(height: compact ? AQSpacing.x3 : AQSpacing.x5),
                                  _OrLabel(text: s.orContinueWith),
                                  SizedBox(height: compact ? AQSpacing.x3 : AQSpacing.x4),
                                  IntrinsicHeight(
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                      Expanded(child: _ProviderButton(label: s.google, icon: 'assets/icons/google_g.svg', loading: _busy == AuthProviderKind.google, onTap: () => _signIn(AuthProviderKind.google))),
                                      const SizedBox(width: AQSpacing.x3),
                                      Expanded(child: _ProviderButton(label: s.apple, icon: 'assets/icons/apple_logo.svg', tintIcon: true, loading: _busy == AuthProviderKind.apple, onTap: () => _signIn(AuthProviderKind.apple))),
                                    ]),
                                  ),
                                ]),
                              ),
                              SizedBox(height: compact ? 0 : AQSpacing.x2),
                              AQReveal(animation: _enter, begin: 0.6, end: 1, dy: 4, child: const _LanguageButton()),
                              const SizedBox(height: AQSpacing.x1),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

/// User to Shop or Real Estate Agent. Chooses the journey that opens first; never a permission.
class _ExperienceChooser extends ConsumerWidget {
  final bool compact;
  const _ExperienceChooser({required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final x = ref.watch(entryExperienceProvider);
    return Column(children: [
      AQSlideSwitch(
        labels: [f.t('xp.user'), f.t('xp.agent')],
        index: x.index,
        onChanged: (i) => ref.read(entryExperienceProvider.notifier).state = EntryExperience.values[i],
      ),
    ]);
  }
}

class _Pager extends StatelessWidget {
  final int count, index;
  final String label;
  const _Pager({required this.count, required this.index, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AQMotion.scaled(context, AQMotion.standard),
            curve: AQMotion.standardCurve,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            width: i == index ? 36 : 8,
            height: 8,
            decoration: BoxDecoration(color: i == index ? c.accent : c.accent.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(4)),
          ),
      ]),
    );
  }
}

class _OrLabel extends StatelessWidget {
  final String text;
  const _OrLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final line = Expanded(child: Container(height: 1, color: c.hairline));
    return Row(children: [
      line,
      Padding(padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4), child: Text(text, style: AQTypography.of(context, AQText.labelSmall, color: c.inkSoft))),
      line,
    ]);
  }
}

class _ProviderButton extends StatelessWidget {
  final String label, icon;
  final bool loading, tintIcon;
  final VoidCallback onTap;
  const _ProviderButton({required this.label, required this.icon, required this.onTap, this.loading = false, this.tintIcon = false});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: label,
      excludeSemantics: true,
      onTap: loading ? null : onTap,
      child: AQPressable(
        onTap: loading ? null : onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: AQLayout.compact(context) ? 48 : AQControl.button),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: AQSpacing.x2),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AQRadius.medium)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
            else
              SvgPicture.asset(icon, width: 20, height: 20, colorFilter: tintIcon ? ColorFilter.mode(c.ink, BlendMode.srcIn) : null),
            const SizedBox(width: AQSpacing.x2),
            Flexible(child: Text(label, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.labelMedium).copyWith(height: 1.25))),
          ]),
        ),
      ),
    );
  }
}

class _LanguageButton extends ConsumerWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = EntryStrings.of(context);
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: s.selectLanguage,
      value: s.language,
      excludeSemantics: true,
      onTap: () => showAQSheet<void>(context, builder: (sheet) {
          final current = ref.read(localeProvider).languageCode;
          void pick(String code) {
            ref.read(localeProvider.notifier).state = Locale(code);
            Navigator.of(sheet).pop();
          }

          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AQSpacing.x6, AQSpacing.x2, AQSpacing.x6, AQSpacing.x2),
              child: Align(alignment: AlignmentDirectional.centerStart, child: Text(s.selectLanguage, style: AQTypography.of(context, AQText.labelSmall, soft: true))),
            ),
            AQSheetRow(title: 'English', selected: current == 'en', onTap: () => pick('en')),
            AQSheetRow(title: 'العربية', selected: current == 'ar', onTap: () => pick('ar')),
          ]);
        }),
      child: AQPressable(
        pressedScale: 0.97,
        onTap: () => showAQSheet<void>(context, builder: (sheet) {
          final current = ref.read(localeProvider).languageCode;
          void pick(String code) {
            ref.read(localeProvider.notifier).state = Locale(code);
            Navigator.of(sheet).pop();
          }

          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AQSpacing.x6, AQSpacing.x2, AQSpacing.x6, AQSpacing.x2),
              child: Align(alignment: AlignmentDirectional.centerStart, child: Text(s.selectLanguage, style: AQTypography.of(context, AQText.labelSmall, soft: true))),
            ),
            AQSheetRow(title: 'English', selected: current == 'en', onTap: () => pick('en')),
            AQSheetRow(title: 'العربية', selected: current == 'ar', onTap: () => pick('ar')),
          ]);
        }),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AQControl.tap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AQIcon('globe', size: AQIconSize.medium, color: c.ink),
              const SizedBox(width: AQSpacing.x2),
              Text(s.language, style: AQTypography.of(context, AQText.bodyMedium)),
              const SizedBox(width: AQSpacing.x1),
              AQIcon('chevron-down', size: AQIconSize.small, color: c.inkSoft),
            ]),
          ),
        ),
      ),
    );
  }
}
