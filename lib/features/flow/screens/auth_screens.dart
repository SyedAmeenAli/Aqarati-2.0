import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_auth_scaffold.dart';
import '../../../core/aq/aq_forms.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/domain/account_models.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../data/api/account_api.dart';
import '../../entry/admin_link.dart';
import '../../entry/models/entry_experience.dart';
import '../../entry/models/signup_purpose.dart';
import '../../viewing/widgets/viewing_components.dart' show AQNoticeCard;
import '../state/signup_state.dart';

/// Where a hydrated session belongs. Authentication is not verification:
/// business users go on to documents / verification status, not "approved".
String routeForSession(MeSession me) {
  if (me.account == AccountState.otpPending) return '/otp';
  final cfg = me.purpose == null ? null : roleConfigs[me.purpose];
  if (cfg == null || !cfg.needsDocuments) return '/app/home';
  return switch (me.grant) {
    null || GrantState.draft => '/onboarding/verification-intro',
    GrantState.approved => me.purpose == SignupPurpose.realEstateAgent ? '/agent' : (me.purpose == SignupPurpose.userToShop ? '/app/home' : '/pro'),
    _ => '/verification',
  };
}

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Secure-data reassurance used on credential screens.
class _SecureNote extends StatelessWidget {
  final String text;
  const _SecureNote(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AQIcon('shield', size: AQIconSize.medium, color: c.accent),
        const SizedBox(width: AQSpacing.x3),
        Expanded(child: Text(text, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
      ]),
    );
  }
}

/// Firebase email + password. Credentials never reach the Aqarati API; after
/// sign-in the session is hydrated with GET /me and routed by account state.
class LoginScreen extends ConsumerStatefulWidget {
  /// The entry experience the person came through (`user` or `agent`). Context only.
  final String? experience;
  /// Where to go after signing in (an in-app path the person was sent away from). Ignored unless it is a plain local path.
  final String? next;
  const LoginScreen({super.key, this.experience, this.next});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _bannerKey;
  String? _emailErr, _passErr;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return; // never double-submit
    final emailOk = _emailRe.hasMatch(_email.text.trim());
    setState(() {
      _emailErr = emailOk ? null : 'err.email';
      _passErr = _password.text.isEmpty ? 'common.required' : null;
      _bannerKey = null;
    });
    if (!emailOk || _password.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(_email.text.trim(), _password.text);
      final me = await ref.read(accountApiProvider).getMe();
      if (!mounted) return;
      AQHaptics.confirm();
      final want = entryExperienceFrom(widget.experience);
      final isAgent = me.purpose == SignupPurpose.realEstateAgent;
      final isUser = me.purpose == null || me.purpose == SignupPurpose.userToShop;
      final mismatch = (want == EntryExperience.agent && !isAgent) || (want == EntryExperience.user && !isUser);
      if (mismatch) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(FlowStrings.of(context).t(want == EntryExperience.agent ? 'xp.mismatch.agent' : 'xp.mismatch.user'))));
      }
      final n = widget.next;
      context.go(n != null && n.startsWith('/') && !n.startsWith('//') ? n : routeForSession(me));
    } on AuthException catch (e) {
      if (mounted) setState(() => _bannerKey = switch (e.error) { AuthError.network => 'common.networkError', AuthError.tooManyRequests => 'login.tooMany', AuthError.unavailable => 'login.unavailable', _ => 'login.invalid' });
    } on ApiException catch (_) {
      if (mounted) setState(() => _bannerKey = 'common.networkError');
    } catch (_) {
      if (mounted) setState(() => _bannerKey = 'common.genericError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return AQAuthScaffold(
      title: f.t('login.title'),
      subtitle: f.t('login.sub'),
      onBack: () => aqBack(context, '/entry'),
      backLabel: f.t('common.back'),
      actionLabel: f.t('login.createShort'),
      onAction: () => context.push(entryExperienceFrom(widget.experience)?.signupRoute ?? '/onboarding/purpose'),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        AQPrimaryButton(label: f.t('login.action'), loading: _busy, onPressed: _submit),
        // Discoverable but quiet: the Admin Console is a separate application with its own sign-in.
        const AdminConsoleLink(),
      ]),
      children: [
        // Its own component with a clear gap below it, the same spacing the fields use between themselves.
        if (entryExperienceFrom(widget.experience) != null) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x4), child: AQNoticeCard(icon: widget.experience == 'agent' ? 'agent' : 'user', title: f.t(widget.experience == 'agent' ? 'xp.login.agent' : 'xp.login.user'), body: '')),
        if (_bannerKey != null) AQErrorBanner(text: f.t(_bannerKey!)),
        AQTextField(label: f.t('field.email'), controller: _email, keyboardType: TextInputType.emailAddress, autofill: const [AutofillHints.email], error: _emailErr == null ? null : f.t(_emailErr!), onChanged: (_) => _emailErr == null ? null : setState(() => _emailErr = null)),
        AQPasswordField(
          label: f.t('field.password'),
          controller: _password,
          showLabel: f.t('field.show'),
          hideLabel: f.t('field.hide'),
          action: TextInputAction.done,
          error: _passErr == null ? null : f.t(_passErr!),
          onChanged: (_) => _passErr == null ? null : setState(() => _passErr = null),
          onSubmitted: (_) => _submit(),
        ),
        Align(alignment: AlignmentDirectional.centerEnd, child: AQTextButton(label: f.t('login.forgot'), color: AQColors.of(context).accent, onPressed: () => context.push('/forgot-password'))),
        const SizedBox(height: AQSpacing.x4),
        _SecureNote(f.t('login.secure')),
      ],
    );
  }
}

/// Firebase password-reset EMAIL only (no SMS reset). The confirmation is the
/// same whether or not an account exists.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false, _sent = false;
  String? _err, _bannerKey;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final ok = _emailRe.hasMatch(_email.text.trim());
    setState(() {
      _err = ok ? null : 'err.email';
      _bannerKey = null;
    });
    if (!ok) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _bannerKey = e.error == AuthError.network ? 'common.networkError' : e.error == AuthError.unavailable ? 'login.unavailable' : 'common.genericError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    if (_sent) {
      return AQAuthScaffold(
        showLogo: false,
        centered: true,
        title: f.t('forgot.sentTitle'),
        subtitle: f.t('forgot.sentBody'),
        onBack: () => context.go('/login'),
        backLabel: f.t('common.back'),
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          AQPrimaryButton(label: f.t('forgot.toLogin'), onPressed: () => context.go('/login')),
          AQTextButton(label: f.t('forgot.different'), onPressed: () => setState(() => _sent = false)),
        ]),
        children: const [SizedBox(height: AQSpacing.x4), AQAnimatedCheck(size: 96)],
      );
    }
    return AQAuthScaffold(
      title: f.t('forgot.title'),
      subtitle: f.t('forgot.sub'),
      onBack: () => aqBack(context, '/login'),
      backLabel: f.t('common.back'),
      actionLabel: f.t('login.action'),
      onAction: () => context.go('/login'),
      bottom: AQPrimaryButton(label: f.t('forgot.action'), loading: _busy, onPressed: _submit),
      children: [
        if (_bannerKey != null) AQErrorBanner(text: f.t(_bannerKey!)),
        AQTextField(label: f.t('field.email'), controller: _email, keyboardType: TextInputType.emailAddress, action: TextInputAction.done, autofill: const [AutofillHints.email], error: _err == null ? null : f.t(_err!), onChanged: (_) => _err == null ? null : setState(() => _err = null), onSubmitted: (_) => _submit()),
        const SizedBox(height: AQSpacing.x2),
        _SecureNote(f.t('forgot.safe')),
      ],
    );
  }
}

/// Reached from the Firebase reset email link (`/reset-password?oobCode=...`).
/// Succeeds only after Firebase confirms.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? oobCode;
  const ResetPasswordScreen({super.key, this.oobCode});
  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _done = false, _expired = false;
  String? _pwErr, _confirmErr, _bannerKey;

  @override
  void initState() {
    super.initState();
    _expired = widget.oobCode == null || widget.oobCode!.isEmpty;
  }

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _pwErr = !passwordMeetsPolicy(_pw.text) ? 'err.passwordRules' : null;
      _confirmErr = _confirm.text != _pw.text || _confirm.text.isEmpty ? 'err.passwordMismatch' : null;
      _bannerKey = null;
    });
    if (_pwErr != null || _confirmErr != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).confirmPasswordReset(widget.oobCode!, _pw.text);
      if (mounted) setState(() => _done = true);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.error == AuthError.expiredCode) {
            _expired = true;
          } else {
            _bannerKey = e.error == AuthError.network ? 'common.networkError' : 'common.genericError';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    if (_done) {
      return AQAuthScaffold(
        showLogo: false,
        centered: true,
        title: f.t('reset.doneTitle'),
        subtitle: f.t('reset.done'),
        onBack: () => context.go('/login'),
        backLabel: f.t('common.back'),
        bottom: AQPrimaryButton(label: f.t('forgot.toLogin'), onPressed: () => context.go('/login')),
        children: const [SizedBox(height: AQSpacing.x4), AQAnimatedCheck(size: 96)],
      );
    }
    if (_expired) {
      return AQAuthScaffold(
        title: f.t('reset.title'),
        onBack: () => context.go('/login'),
        backLabel: f.t('common.back'),
        bottom: AQPrimaryButton(label: f.t('reset.requestNew'), onPressed: () => context.go('/forgot-password')),
        children: [AQErrorBanner(text: f.t('reset.expired'))],
      );
    }
    return AQAuthScaffold(
      title: f.t('reset.title'),
      subtitle: f.t('reset.sub'),
      onBack: () => context.go('/login'),
      backLabel: f.t('common.back'),
      bottom: AQPrimaryButton(label: f.t('reset.action'), loading: _busy, onPressed: _submit),
      children: [
        if (_bannerKey != null) AQErrorBanner(text: f.t(_bannerKey!)),
        ListenableBuilder(
          listenable: Listenable.merge([_pw, _confirm]),
          builder: (context, _) {
            final p = _pw.text;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AQPasswordField(label: f.t('field.newPassword'), controller: _pw, showLabel: f.t('field.show'), hideLabel: f.t('field.hide'), newPassword: true, error: _pwErr == null ? null : f.t(_pwErr!)),
              AQRequirementList(items: [
                (label: f.t('pw.req.length'), met: p.length >= kMinPasswordLength),
                (label: f.t('pw.req.upper'), met: RegExp(r'[A-Z]').hasMatch(p)),
                (label: f.t('pw.req.number'), met: RegExp(r'\d').hasMatch(p)),
              ]),
              AQPasswordField(label: f.t('field.confirmPassword'), controller: _confirm, showLabel: f.t('field.show'), hideLabel: f.t('field.hide'), action: TextInputAction.done, error: _confirmErr == null ? null : f.t(_confirmErr!), helper: _confirm.text.isNotEmpty && _confirm.text == p ? f.t('reset.match') : null, onSubmitted: (_) => _submit()),
            ]);
          },
        ),
      ],
    );
  }
}
