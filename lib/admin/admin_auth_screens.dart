import '../core/aq/aq_glass.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/aq/aq_demo.dart';
import '../core/aq/aq_forms.dart';
import '../core/aq/aq_tokens.dart';
import '../core/aq/aq_typography.dart';
import '../core/config/demo_mode.dart';
import '../data/api/account_api.dart' show ApiException;
import '../features/entry/widgets/entry_common.dart' show MasterLogo;
import 'admin_auth.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'admin_ui.dart';
import 'admin_widgets.dart' show AdminAmbient;
import 'admin_widgets.dart' show AdminLangButton;
import 'admin_l10n.dart';

class _AuthFrame extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const _AuthFrame({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: AdminAmbient(
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AQSpacing.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AdminLangButton(),
                  ),
                  // The logo settles in, then the card rises under it.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: 0.85 + 0.15 * v, child: child)),
                    child: const Align(alignment: Alignment.center, child: MasterLogo(width: 104)),
                  ),
                  const SizedBox(height: 22),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 28 * (1 - v)), child: child)),
                    child: AQGlass(
                    radius: 32,
                    blur: 18,
                    fill: 0.72,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Admin console',
                          style: AQTypography.of(
                            context,
                            AQText.labelMedium,
                            color: c.accentDeep,
                          ),
                        ),
                        const SizedBox(height: AQSpacing.x1),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: AQTypography.of(
                              context,
                              AQText.headlineMedium,
                            ),
                          ),
                        ),
                        const SizedBox(height: AQSpacing.x2),
                        Text(
                          subtitle,
                          style: AQTypography.of(
                            context,
                            AQText.bodyMedium,
                            soft: true,
                          ),
                        ),
                        const SizedBox(height: 22),
                        ...children,
                      ],
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )),
    );
  }
}

/// Step 1: separate admin credentials. The reason for coming back here (an ended session) is shown
/// above the form. A wrong email or password gives one answer, never which of the two was wrong.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _tried = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Preview builds only: the same simulated sign-in and code, with the demo super admin.
  Future<void> _demoEnter() async {
    if (!kDemoMode || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(adminAuthProvider.notifier);
      await auth.signIn('super@demo.test', DemoAdminStore.demoPassword);
      await auth.verifyTotp(DemoAdminStore.demoCode);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'We could not open the demo console. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _tried = true);
    if (_email.text.trim().isEmpty || _password.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminAuthProvider.notifier)
          .signIn(_email.text.trim(), _password.text);
    } on AdminAuthException {
      if (mounted) {
        setState(() => _error = 'The email or password is not right.');
      }
    } on ApiException {
      if (mounted) {
        setState(() => _error = 'We could not reach the service. Try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'We could not sign you in. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(adminAuthProvider).notice;
    return _AuthFrame(
      title: tr('Sign in'),
      subtitle: tr('Use your admin account. You will be asked for a one-time code next.'),
      children: [
        if (notice == 'expired')
          Padding(
            padding: EdgeInsets.only(bottom: AQSpacing.x4),
            child: AQErrorBanner(
              tone: AQBannerTone.info,
              text: tr('Your session ended. Sign in again to continue.'),
            ),
          ),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminField(
                label: tr('Email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofill: const [AutofillHints.username],
                error: _tried && _email.text.trim().isEmpty
                    ? 'Enter your admin email.'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AQSpacing.x4),
              AdminPasswordField(
                label: tr('Password'),
                controller: _password,
                showLabel: tr('Show password'),
                hideLabel: tr('Hide password'),
                action: TextInputAction.done,
                error: _tried && _password.text.isEmpty
                    ? 'Enter your password.'
                    : null,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AQSpacing.x4),
            child: AQErrorBanner(text: tr(_error!)),
          ),
        const SizedBox(height: AQSpacing.x5),
        AdminPrimaryButton(
          expand: true,
          label: tr('Continue'),
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: AQSpacing.x5),
        // A frontend prototype: sign-in and the one-time code are simulated, not security.
        Text(
          'Prototype only. Sign-in and the one-time code on this page are simulated; they do not protect anything.',
          style: AQTypography.of(
            context,
            AQText.bodySmall,
            color: AQColors.of(context).inkFaint,
          ),
        ),
        if (kDemoMode) ...[
          const SizedBox(height: AQSpacing.x3),
          AdminSecondaryButton(
            expand: true,
            label: tr('Open the demo console'),
            trailingChevron: false,
            onPressed: _busy ? null : _demoEnter,
          ),
          Padding(
            padding: const EdgeInsets.only(top: AQSpacing.x1),
            child: Text(
              'Preview shortcut: signs in as the demo super admin through the same simulated sign-in and code. It protects nothing.',
              style: AQTypography.of(
                context,
                AQText.bodySmall,
                color: AQColors.of(context).inkFaint,
              ),
            ),
          ),
          const SizedBox(height: AQSpacing.x3),
          const AQDemoNotice(),
          const SizedBox(height: AQSpacing.x2),
          Text(
            'Demo accounts: reviewer@demo.test, senior@demo.test, super@demo.test, auditor@demo.test. Password ${DemoAdminStore.demoPassword}. The demo one-time code is ${DemoAdminStore.demoCode}.',
            style: AQTypography.of(
              context,
              AQText.bodySmall,
              color: AQColors.of(context).inkFaint,
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: AQSpacing.x2),
            child: Text(
              'Demo accounts are shown only in a build made for previews.',
              style: AQTypography.of(
                context,
                AQText.bodySmall,
                color: AQColors.of(context).inkFaint,
              ),
            ),
          ),
        if (ref.watch(adminExitProvider) != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AdminTextButton(
              label: tr('Back to AQARATI'),
              color: AQColors.of(context).accent,
              onPressed: ref.read(adminExitProvider),
            ),
          ),
      ],
    );
  }
}

/// Step 2: the one-time code. Without it nothing in the console opens.
class AdminTotpScreen extends ConsumerStatefulWidget {
  const AdminTotpScreen({super.key});
  @override
  ConsumerState<AdminTotpScreen> createState() => _AdminTotpScreenState();
}

class _AdminTotpScreenState extends ConsumerState<AdminTotpScreen> {
  AQOtpState _state = AQOtpState.idle;
  String? _error;
  final _key = GlobalKey<AQOtpFieldState>();

  Future<void> _submit(String code) async {
    setState(() {
      _state = AQOtpState.verifying;
      _error = null;
    });
    try {
      await ref.read(adminAuthProvider.notifier).verifyTotp(code);
    } on AdminTotpException {
      if (mounted) {
        setState(() {
          _state = AQOtpState.error;
          _error = 'That code is not right. Enter the current code.';
        });
        _key.currentState?.clear();
      }
    } on AdminSessionExpiredException {
      ref.read(adminAuthProvider.notifier).expire();
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = AQOtpState.error;
          _error = 'We could not check the code. Try again.';
        });
        _key.currentState?.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: tr('One-time code'),
      subtitle: tr('Enter the 6-digit code from your authenticator app.'),
      children: [
        AQOtpField(
          key: _key,
          label: tr('One-time code'),
          state: _state,
          enabled: _state != AQOtpState.verifying,
          onCompleted: _submit,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AQSpacing.x4),
            child: AQErrorBanner(text: tr(_error!)),
          ),
        const SizedBox(height: AQSpacing.x5),
        AdminSecondaryButton(
          label: tr('Back to sign in'),
          trailingChevron: false,
          onPressed: _state == AQOtpState.verifying
              ? null
              : () => ref.read(adminAuthProvider.notifier).backToLogin(),
        ),
        if (kDemoMode) ...[
          const SizedBox(height: AQSpacing.x5),
          const AQDemoNotice(),
        ],
      ],
    );
  }
}
