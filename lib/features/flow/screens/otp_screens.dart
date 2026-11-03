import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_auth_scaffold.dart';
import '../../../core/aq/aq_forms.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/config/backend_mode.dart';
import '../../../core/domain/account_models.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../data/api/account_api.dart';
import '../../entry/models/signup_purpose.dart';
import '../../entry/widgets/entry_common.dart' show MasterLogo;
import '../state/otp_state.dart';
import '../state/signup_state.dart' show isValidOmanMobile;
import '../widgets/journey.dart';

String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Phone verification. Every documented state is represented: sending, sent,
/// entering, verifying, invalid, expired, resend cooldown (server-seeded),
/// rate limited, network/SMS problems, wrong number, success then automatic continuation.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _pinKey = GlobalKey<AQOtpFieldState>();
  String _code = '';
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(otpControllerProvider.notifier).send());
    // Drives the quiet expiry countdown (display only; the server decides validity).
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _back(MeSession? me) {
    final p = me?.purpose;
    if (p == null) return context.go('/login');
    context.go(signupPurposeOptions.firstWhere((o) => o.id == p).route);
  }

  Future<void> _wrongNumber(MeSession? me) async {
    final changed = await showAQSheet<bool>(context, builder: (_) => _ChangeNumberSheet(last4: me?.phoneLast4));
    if (changed == true && mounted) {
      _pinKey.currentState?.clear();
      setState(() => _code = '');
      ref.invalidate(meProvider);
      await ref.read(otpControllerProvider.notifier).restartForNewNumber();
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final st = ref.watch(otpControllerProvider);
    final ctl = ref.read(otpControllerProvider.notifier);
    final me = ref.watch(meProvider).valueOrNull;

    ref.listen<OtpState>(otpControllerProvider, (prev, next) async {
      if (prev?.phase != OtpPhase.verified && next.phase == OtpPhase.verified) {
        AQHaptics.success();
        // Let the success state land, then continue automatically.
        final wait = AQMotion.reduced(context) ? const Duration(milliseconds: 300) : const Duration(milliseconds: 1100);
        final router = GoRouter.of(context);
        await Future<void>.delayed(wait);
        if (mounted) router.go('/account/active');
      }
      if ((next.phase == OtpPhase.invalid || next.phase == OtpPhase.expired) && prev?.phase != next.phase) {
        _pinKey.currentState?.clear();
        setState(() => _code = '');
      }
    });

    final fieldState = switch (st.phase) {
      OtpPhase.verifying => AQOtpState.verifying,
      OtpPhase.verified => AQOtpState.success,
      OtpPhase.invalid || OtpPhase.expired || OtpPhase.rateLimited || OtpPhase.error => AQOtpState.error,
      _ => AQOtpState.idle,
    };
    final subtitle = switch (st.phase) {
      OtpPhase.notSent || OtpPhase.sending => f.t('otp.sending'),
      OtpPhase.verifying => f.t('otp.verifying'),
      OtpPhase.verified => f.t('otp.continuing'),
      _ => me?.phoneLast4 == null ? f.t('otp.sentNoPhone') : f.t('otp.sent', {'last4': me!.phoneLast4!}),
    };
    final resendLabel = st.cooldown > 0 ? f.t('otp.resendIn', {'s': _mmss(st.cooldown)}) : (st.phase == OtpPhase.notSent ? f.t('otp.send') : f.t('otp.resend'));
    final busy = st.phase == OtpPhase.sending || st.phase == OtpPhase.verifying;

    // Expiry comes from the server's expiresAt; we only count it down for display.
    final left = st.expiresAt?.difference(DateTime.now());
    final expiredLocal = left != null && left.isNegative;
    final expiryLine = st.expiresAt == null
        ? f.t('otp.expiresHint')
        : (expiredLocal ? f.t('otp.expiredLocal') : f.t('otp.expiresIn', {'t': _mmss(left!.inSeconds)}));
    final slow = st.phase == OtpPhase.sent && st.cooldown == 0 && !expiredLocal;

    return AQAuthScaffold(
      title: st.phase == OtpPhase.verified ? f.t('otp.verified') : f.t('otp.title'),
      subtitle: subtitle,
      onBack: () => _back(me),
      backLabel: f.t('common.back'),
      progress: me?.purpose == null ? null : journeyProgress(context, me!.purpose!, JourneyAt.phone),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        AQPrimaryButton(
          label: f.t('otp.verifyCta'),
          loading: st.phase == OtpPhase.verifying,
          onPressed: _code.length == 6 && st.canType ? () => ctl.verify(_code) : null,
        ),
        if (kUseDemoBackend) Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: Text(f.t('otp.demoHint'), style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep))),
      ]),
      children: [
        if (st.errorKey != null && st.phase != OtpPhase.invalid) AQErrorBanner(text: f.t(st.errorKey!)),
        AQOtpField(
          key: _pinKey,
          label: f.t('otp.codeLabel'),
          state: fieldState,
          enabled: st.canType,
          onChanged: (v) => setState(() => _code = v),
          onCompleted: ctl.verify,
        ),
        if (st.phase == OtpPhase.invalid)
          Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: Center(child: Text(f.t('otp.invalid'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, color: c.danger)))),
        if (st.phase != OtpPhase.verified) ...[
          const SizedBox(height: AQSpacing.x5),
          Center(child: Text(expiryLine, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, color: expiredLocal ? c.danger : c.inkSoft))),
          if (slow) Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Center(child: Text(f.t('otp.slow'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, color: c.inkSoft)))),
          const SizedBox(height: AQSpacing.x2),
          Center(child: Text(f.t('otp.didnt'), style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
          Center(
            child: AQTextButton(
              label: resendLabel,
              color: st.canResend ? c.accent : c.inkFaint,
              onPressed: st.canResend && !busy ? ctl.send : null,
            ),
          ),
          Center(child: AQTextButton(label: f.t('otp.wrong'), color: c.accent, onPressed: busy ? null : () => _wrongNumber(me))),
        ],
      ],
    );
  }
}

/// "Is this the right number?" Keep it, or edit and request a new code.
class _ChangeNumberSheet extends ConsumerStatefulWidget {
  final String? last4;
  const _ChangeNumberSheet({required this.last4});
  @override
  ConsumerState<_ChangeNumberSheet> createState() => _ChangeNumberSheetState();
}

class _ChangeNumberSheetState extends ConsumerState<_ChangeNumberSheet> {
  final _phone = TextEditingController();
  bool _editing = false, _busy = false;
  String? _err;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final f = FlowStrings.of(context);
    final number = _phone.text.replaceAll(' ', '');
    if (!isValidOmanMobile(number)) {
      setState(() => _err = f.t('err.phone'));
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref.read(accountApiProvider).changePhone(number);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = f.t('otp.cn.fail');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AQSpacing.x6, AQSpacing.x2, AQSpacing.x6, AQSpacing.x2),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text(f.t('otp.cn.title'), style: AQTypography.of(context, AQText.headlineMedium))),
        const SizedBox(height: AQSpacing.x3),
        Directionality(textDirection: TextDirection.ltr, child: Text('+968 ${widget.last4 == null ? '' : '•••• ${widget.last4}'}', style: AQTypography.of(context, AQText.titleLarge, color: c.inkSoft))),
        const SizedBox(height: AQSpacing.x5),
        if (!_editing) ...[
          AQPrimaryButton(label: f.t('otp.cn.keep'), trailingChevron: false, onPressed: () => Navigator.of(context).pop(false)),
          const SizedBox(height: AQSpacing.x2),
          AQSecondaryButton(label: f.t('otp.cn.edit'), trailingChevron: false, onPressed: () => setState(() => _editing = true)),
        ] else ...[
          AQPhoneField(label: f.t('field.phone'), hint: f.t('field.phoneHint'), controller: _phone, error: _err, valid: isValidOmanMobile(_phone.text), onChanged: (_) => setState(() => _err = null)),
          AQPrimaryButton(label: f.t('otp.cn.save'), loading: _busy, trailingChevron: false, onPressed: _save),
        ],
        const SizedBox(height: AQSpacing.x2),
      ]),
    );
  }
}

/// Shown after phone verification. For business roles it states plainly that an
/// active account is not an approved business role.
class AccountActiveScreen extends ConsumerWidget {
  const AccountActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    final purpose = me.valueOrNull?.purpose;
    final cfg = purpose == null ? null : roleConfigs[purpose];
    final business = cfg?.needsDocuments ?? false;
    return AQAuthScaffold(
      showLogo: false,
      centered: true,
      // Phone is verified: there is nothing "behind" this, so no Back to Welcome.
      showBack: false,
      progress: purpose == null ? null : journeyProgress(context, purpose, JourneyAt.ready),
      title: f.t('active.title'),
      subtitle: business ? f.t('active.business') : f.t('active.buyer'),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        // A shopper goes straight to Home, which is the service-discovery entry point. The "What are you looking for?"
        // step is no longer part of the sequence; its Skip destination was this same /app/home.
        AQPrimaryButton(label: business ? f.t('active.docs') : f.t('active.home'), onPressed: () => context.go(business ? '/onboarding/verification-intro' : '/app/home')),
        AQTextButton(label: f.t('ev.cta'), color: AQColors.of(context).accent, onPressed: () => context.push('/verify-email')),
      ]),
      children: [
        const SizedBox(height: AQSpacing.x4),
        const AQAnimatedCheck(size: 104),
        const SizedBox(height: AQSpacing.x8),
        MasterLogo(width: 120),
        const SizedBox(height: AQSpacing.x6),
        AQErrorBanner(tone: AQBannerTone.info, text: f.t('secure.note')),
      ],
    );
  }
}
