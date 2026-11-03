import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/localization/entry_strings.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../core/config/demo_mode.dart';
import '../../../data/demo/demo_providers.dart';
import '../demo_entry.dart';
import '../models/signup_purpose.dart';
import '../../workspace/aq_home.dart' show aqImg;
import '../widgets/entry_common.dart' show MasterLogo;

/// Captures sign-up intent only: nothing is created, sent or persisted here,
/// and choosing a role does not mean the person is verified. The journey length
/// depends on the role, so no fixed "step x of 3" is shown.
class PurposeSelectionScreen extends ConsumerStatefulWidget {
  /// Shows only the four business and professional roles (Register as a Business or Professional).
  final bool businessOnly;
  const PurposeSelectionScreen({super.key, this.businessOnly = false});

  @override
  ConsumerState<PurposeSelectionScreen> createState() => _PurposeSelectionScreenState();
}

class _PurposeSelectionScreenState extends ConsumerState<PurposeSelectionScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  SignupPurpose? _selected;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: AQMotion.reveal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AQMotion.reduced(context)) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  String _imageFor(SignupPurpose p) => switch (p) {
        SignupPurpose.constructionCompany => 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg',
        SignupPurpose.propertyDevelopmentCompany => 'assets/properties/p4/18_31_Modern_Omani_villa_architectural.jpg',
        SignupPurpose.buildingArchitecture => 'assets/businesses/b1/03_Architectural_model_of_contempor.jpg',
        SignupPurpose.interiorExteriorDesign => 'assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg',
        _ => 'assets/entry/oman_terrace_2k.jpg',
      };

  Alignment _cropFor(SignupPurpose? p) => switch (p) {
        SignupPurpose.realEstateAgent => const Alignment(-0.5, 1),
        SignupPurpose.constructionCompany => const Alignment(0.5, 0.7),
        SignupPurpose.propertyDevelopmentCompany => const Alignment(0.9, 0.9),
        SignupPurpose.buildingArchitecture => const Alignment(0.2, 0.5),
        SignupPurpose.interiorExteriorDesign => const Alignment(-0.9, 0.8),
        _ => Alignment.bottomCenter,
      };

  /// Demo builds only: jump straight into this role's home page (see [demoEnterAs]).
  void _skip(SignupPurposeOption o) {
    demoSkipInto(context, ref, o.id);
  }

  void _continue(EntryStrings s) {
    final selected = _selected;
    if (selected == null) return;
    final option = signupPurposeOptions.firstWhere((o) => o.id == selected);
    try {
      AQHaptics.confirm();
      context.push(option.route);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.navFailed, style: AQTypography.of(context, AQText.bodyMedium, color: Colors.white)),
        action: SnackBarAction(label: s.retry, onPressed: () => _continue(s)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = EntryStrings.of(context);
    final c = AQColors.of(context);
    final compact = AQLayout.compact(context);
    final selected = _selected == null ? null : signupPurposeOptions.firstWhere((o) => o.id == _selected);
    final logoWidth = (AQLayout.contentWidth(context) * (compact ? 0.2 : 0.22)).clamp(72.0, 120.0);

    final options = widget.businessOnly
        ? [for (final o in signupPurposeOptions) if (o.id != SignupPurpose.userToShop && o.id != SignupPurpose.realEstateAgent) o]
        : signupPurposeOptions;
    final f = FlowStrings.of(context);
    final rows = <Widget>[];
    final demoOn = kDemoMode && ref.watch(demoBackendStateProvider) != null;
    if (widget.businessOnly) {
      // Four substantial picture cards, two across; the whole card selects. One "Skip for now" lives in
      // the footer (demo builds), not on every card.
      final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
      final cols = large ? 1 : 2;
      for (var i = 0; i < options.length; i += cols) {
        rows.add(AQReveal(
          animation: _enter,
          begin: 0.28 + i * 0.05,
          end: 0.82 + i * 0.03,
          dy: 8,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) const SizedBox(width: AQSpacing.x3),
                Expanded(
                  child: i + j < options.length
                      ? _BizCard(
                          image: _imageFor(options[i + j].id),
                          icon: options[i + j].icon,
                          title: options[i + j].title(s),
                          description: options[i + j].description(s),
                          selected: _selected == options[i + j].id,
                          onTap: () => setState(() => _selected = options[i + j].id),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ]),
          ),
        ));
        if (i + cols < options.length) rows.add(const SizedBox(height: AQSpacing.x3));
      }
    }
    for (var i = 0; !widget.businessOnly && i < options.length; i += 2) {
      final a = options[i], b = options[i + 1];
      final demo = kDemoMode && ref.watch(demoBackendStateProvider) != null;
      Widget tile(SignupPurposeOption o) => AQChoiceTile(
            icon: o.icon,
            title: o.title(s),
            description: o.description(s),
            selected: _selected == o.id,
            onTap: () => setState(() => _selected = o.id),
            skipLabel: demo ? s.skip : null,
            skipSemantics: demo ? '${s.skip}: ${o.title(s)}' : null,
            onSkip: demo ? () => _skip(o) : null,
          );
      rows.add(AQReveal(
        animation: _enter,
        begin: 0.28 + i * 0.05,
        end: 0.82 + i * 0.03,
        dy: 8,
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: tile(a)), const SizedBox(width: AQSpacing.x3), Expanded(child: tile(b))])),
      ));
      if (i + 2 < options.length) rows.add(const SizedBox(height: AQSpacing.x3));
    }

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
          // The photograph re-frames very slightly for the chosen role; one scene, one language.
          TweenAnimationBuilder<Alignment>(
            tween: AlignmentTween(end: _cropFor(_selected)),
            duration: AQMotion.scaled(context, AQMotion.slow),
            curve: AQMotion.standardCurve,
            builder: (context, a, _) => AQBackdrop(asset: 'assets/entry/oman_terrace_2k.jpg', alignment: a),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
                    child: AQTopBar(onBack: () => aqBack(context, widget.businessOnly ? '/entry' : '/entry'), backLabel: s.back),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, 0, AQSpacing.gutter, AQSpacing.x4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // The business registration leads with its title: the cards need the room.
                        if (!widget.businessOnly) ...[
                          Center(child: AQReveal(animation: _enter, begin: 0, end: 0.45, dy: 10, child: MasterLogo(width: logoWidth))),
                          SizedBox(height: compact ? AQSpacing.x4 : AQSpacing.x6),
                        ],
                        AQReveal(animation: _enter, begin: 0.08, end: 0.55, dy: 8, child: Semantics(header: true, child: Text(widget.businessOnly ? f.t('biz.title') : s.purposeTitle, style: AQTypography.of(context, AQText.headlineLarge)))),
                        const SizedBox(height: AQSpacing.x3),
                        AQReveal(animation: _enter, begin: 0.16, end: 0.65, dy: 6, child: Text(widget.businessOnly ? f.t('biz.sub') : s.purposeSub, style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
                        SizedBox(height: compact ? AQSpacing.x5 : AQSpacing.x6),
                        ...rows,
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x4),
                    child: AQReveal(
                      animation: _enter,
                      begin: 0.55,
                      end: 1,
                      dy: 6,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Supportive line for the chosen role (reserved height so nothing jumps).
                        if (!widget.businessOnly)
                        SizedBox(
                          height: compact ? 40 : 48,
                          child: AnimatedSwitcher(
                            duration: AQMotion.scaled(context, AQMotion.standard),
                            child: selected == null
                                ? const SizedBox.shrink(key: ValueKey('none'))
                                : Align(
                                    key: ValueKey(selected.id),
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(selected.tagline(s), maxLines: 2, overflow: TextOverflow.fade, style: AQTypography.of(context, AQText.bodyMedium, color: c.accentDeep, italic: true)),
                                  ),
                          ),
                        ),
                      AQPrimaryButton(
                        compact: compact,
                        label: s.continueLabel,
                        semanticsLabel: selected == null ? s.continueLabel : s.continueWith(selected.title(s)),
                        onPressed: selected == null ? null : () => _continue(s),
                      ),
                      if (widget.businessOnly && demoOn)
                        AQTextButton(
                          label: f.t('biz.skipNow'),
                          color: c.accentDeep,
                          onPressed: selected == null ? null : () => _skip(selected),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One business type as a picture card: a photograph, an icon, the name, what it is for, and a clear
/// selected state. The whole card is the target.
class _BizCard extends StatelessWidget {
  final String image, icon, title, description;
  final bool selected;
  final VoidCallback onTap;
  const _BizCard({required this.image, required this.icon, required this.title, required this.description, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      selected: selected,
      onFocus: () {},
      label: '$title. $description',
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: selected ? c.accent : c.hairline, width: selected ? 2 : 1),
            boxShadow: [BoxShadow(color: c.ink.withValues(alpha: selected ? 0.14 : (c.isDark ? 0 : 0.05)), blurRadius: selected ? 16 : 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.medium - 1),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AspectRatio(
                aspectRatio: 1.75,
                child: Stack(fit: StackFit.expand, children: [
                  ExcludeSemantics(child: aqImg(image, cacheWidth: 520)),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x66000000)]))),
                  PositionedDirectional(
                    top: AQSpacing.x2,
                    start: AQSpacing.x2,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                      child: Center(child: AQIcon(icon, size: 18, color: c.accentDeep)),
                    ),
                  ),
                  PositionedDirectional(
                    top: AQSpacing.x2,
                    end: AQSpacing.x2,
                    child: AnimatedContainer(
                      duration: AQMotion.scaled(context, AQMotion.fast),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: selected ? c.accent : Colors.white.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.6),
                      ),
                      child: selected ? Center(child: AQIcon('check', size: 15, color: c.onAccent)) : null,
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(AQSpacing.x3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                  const SizedBox(height: 4),
                  Text(description, maxLines: 4, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
