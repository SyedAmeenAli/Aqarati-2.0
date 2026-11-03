import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_auth_scaffold.dart';
import '../../../core/aq/aq_forms.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/domain/account_models.dart';
import '../../../core/localization/entry_strings.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../core/config/demo_mode.dart';
import '../../devbuild/db_service_toggles.dart';
import '../../entry/demo_entry.dart';
import '../../entry/models/signup_purpose.dart';
import '../state/signup_state.dart';
import '../widgets/journey.dart';

/// ONE form for all six public sign-up paths, driven by [RoleFormConfig].
/// Built only from AQ system components. Conversational steps over one data model.
class SignupFormScreen extends ConsumerStatefulWidget {
  final SignupPurpose purpose;
  const SignupFormScreen({super.key, required this.purpose});
  @override
  ConsumerState<SignupFormScreen> createState() => _SignupFormScreenState();
}

class _SignupFormScreenState extends ConsumerState<SignupFormScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _business = TextEditingController();
  final _agency = TextEditingController();
  final _companyEmail = TextEditingController();
  final _companyAddress = TextEditingController();
  // Passwords live only in these controllers: never in state, drafts or logs.
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _linkTerms = TapGestureRecognizer();
  final _linkPrivacy = TapGestureRecognizer();
  bool _seeded = false;
  int _lastStep = 0;
  bool _forward = true;

  RoleFormConfig get cfg => roleConfigs[widget.purpose]!;

  @override
  void initState() {
    super.initState();
    _linkTerms.onTap = () => context.push('/legal/terms');
    _linkPrivacy.onTap = () => context.push('/legal/privacy');
  }

  @override
  void dispose() {
    _linkTerms.dispose();
    _linkPrivacy.dispose();
    for (final c in [_first, _last, _phone, _email, _business, _agency, _companyEmail, _companyAddress, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(SignupFormValues v) {
    _seeded = true;
    _first.text = v.firstName;
    _last.text = v.lastName;
    _phone.text = v.phone;
    _email.text = v.email;
    _business.text = v.businessName;
    _agency.text = v.agencyName;
    _companyEmail.text = v.companyEmail;
    _companyAddress.text = v.companyAddress;
  }

  void _push() {
    final ctl = ref.read(signupControllerProvider(widget.purpose).notifier);
    ctl.update(ref.read(signupControllerProvider(widget.purpose)).values.copyWith(
          firstName: _first.text,
          lastName: _last.text,
          phone: _phone.text.replaceAll(' ', ''),
          email: _email.text,
          businessName: _business.text,
          agencyName: _agency.text,
          companyEmail: _companyEmail.text,
          companyAddress: _companyAddress.text,
        ));
  }

  Future<void> _primary() async {
    final ctl = ref.read(signupControllerProvider(widget.purpose).notifier);
    FocusScope.of(context).unfocus();
    if (ctl.isLast) {
      final ok = await ctl.submit(password: _password.text, confirm: _confirm.text);
      if (ok && mounted) context.go('/otp');
    } else {
      ctl.next();
    }
  }

  String _businessQuestion() => switch (widget.purpose) {
        SignupPurpose.realEstateAgent => 'signup.q.business.agent',
        SignupPurpose.constructionCompany || SignupPurpose.propertyDevelopmentCompany => 'signup.q.business.company',
        _ => 'signup.q.business.practice',
      };

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final st = ref.watch(signupControllerProvider(widget.purpose));
    final ctl = ref.read(signupControllerProvider(widget.purpose).notifier);
    if (st.loaded && !_seeded) _seed(st.values);
    final c = AQColors.of(context);
    final option = signupPurposeOptions.firstWhere((o) => o.id == widget.purpose);

    if (!st.loaded) {
      return AQAuthScaffold(
        title: f.t('signup.q.you'),
        children: [Center(child: Semantics(label: f.t('common.loading'), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))))],
      );
    }

    final steps = stepsFor(cfg);
    final step = steps[st.stepIndex];
    // Direction of travel for the step transition (Next forward, Back reverse).
    if (st.stepIndex != _lastStep) {
      _forward = st.stepIndex > _lastStep;
      _lastStep = st.stepIndex;
    }
    String? err(String field) => st.errors[field] == null ? null : f.t(st.errors[field]!);
    final v = st.values;
    final title = switch (step) {
      SignupStep.you => 'signup.q.you',
      SignupStep.contact => 'signup.q.contact',
      SignupStep.business => _businessQuestion(),
      SignupStep.account => 'signup.q.account',
    };

    final Widget body;
    switch (step) {
      case SignupStep.you:
        body = Column(children: [
          AQTextField(label: f.t('field.firstName'), controller: _first, autofill: const [AutofillHints.givenName], valid: v.firstName.trim().isNotEmpty, error: err('firstName'), onChanged: (_) => _push()),
          AQTextField(label: f.t('field.lastName'), controller: _last, autofill: const [AutofillHints.familyName], valid: v.lastName.trim().isNotEmpty, error: err('lastName'), action: TextInputAction.done, onChanged: (_) => _push()),
        ]);
      case SignupStep.contact:
        body = Column(children: [
          AQTextField(label: f.t('field.email'), controller: _email, keyboardType: TextInputType.emailAddress, autofill: const [AutofillHints.email], valid: isValidEmail(v.email), error: err('email'), onChanged: (_) => _push()),
          AQPhoneField(label: f.t('field.phone'), hint: f.t('field.phoneHint'), controller: _phone, valid: isValidOmanMobile(v.phone), error: err('phone'), onChanged: (_) => _push()),
        ]);
      case SignupStep.business:
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (cfg.hasAgencyName) AQTextField(label: f.t('field.agencyName'), controller: _agency, valid: v.agencyName.trim().isNotEmpty, error: err('agencyName'), onChanged: (_) => _push()),
          if (cfg.hasBusinessName) AQTextField(label: f.t('field.businessName'), controller: _business, valid: v.businessName.trim().isNotEmpty, error: err('businessName'), onChanged: (_) => _push()),
          if (cfg.hasCompanyContact) ...[
            AQTextField(label: f.t('field.companyEmail'), helper: f.t('field.companyEmail.help'), controller: _companyEmail, keyboardType: TextInputType.emailAddress, autofill: const [AutofillHints.email], valid: isValidEmail(v.companyEmail), error: err('companyEmail'), onChanged: (_) => _push()),
            AQTextField(label: f.t(cfg.companyAddressRequired ? 'field.companyAddress' : 'field.companyAddressOptional'), controller: _companyAddress, keyboardType: TextInputType.streetAddress, valid: v.companyAddress.trim().isNotEmpty, error: err('companyAddress'), onChanged: (_) => _push()),
          ],
          if (cfg.hasServiceType)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: Text(f.t('field.serviceType'), style: AQTypography.of(context, AQText.labelMedium, soft: true))),
              DbServiceToggles(allowNone: false, value: st.values.serviceType, onChanged: (x) { if (x != null) ctl.update(st.values.copyWith(serviceType: x)); }),
              if (err('serviceType') != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x1), child: Text(err('serviceType')!, style: AQTypography.of(context, AQText.bodySmall, color: AQColors.of(context).danger))),
            ]),
          if (cfg.needsDocuments) AQErrorBanner(tone: AQBannerTone.info, text: f.t('signup.docsLater')),
        ]);
      case SignupStep.account:
        body = ListenableBuilder(
          listenable: Listenable.merge([_password, _confirm]),
          builder: (context, _) {
            final p = _password.text;
            final policy = passwordMeetsPolicy(p);
            final linkStyle = AQTypography.of(context, AQText.bodyMedium, color: c.accent).copyWith(decoration: TextDecoration.underline, decorationColor: c.accent);
            final baseStyle = AQTypography.of(context, AQText.bodyMedium, soft: true);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AQPasswordField(label: f.t('field.password'), controller: _password, showLabel: f.t('field.show'), hideLabel: f.t('field.hide'), newPassword: true, error: err('password')),
              // Requirements guide while the password is being written, then fold into one calm line.
              AQAnimatedSize(
                duration: AQMotion.scaled(context, AQMotion.standard),
                curve: AQMotion.standardCurve,
                alignment: Alignment.topCenter,
                child: policy
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: AQSpacing.x4, left: AQSpacing.x1),
                        child: Row(children: [
                          AQIcon('check', size: AQIconSize.small, color: c.success),
                          const SizedBox(width: AQSpacing.x2),
                          Expanded(child: Text(f.t('pw.ok'), style: AQTypography.of(context, AQText.bodySmall, color: c.success))),
                        ]),
                      )
                    : AQRequirementList(items: [
                        (label: f.t('pw.req.length'), met: p.length >= kMinPasswordLength),
                        (label: f.t('pw.req.upper'), met: RegExp(r'[A-Z]').hasMatch(p)),
                        (label: f.t('pw.req.number'), met: RegExp(r'\d').hasMatch(p)),
                      ]),
              ),
              AQPasswordField(label: f.t('field.confirmPassword'), controller: _confirm, showLabel: f.t('field.show'), hideLabel: f.t('field.hide'), action: TextInputAction.done, error: err('confirm')),
              AQCheckRow(
                value: st.values.consent,
                label: f.t('signup.consent'),
                error: err('consent'),
                onChanged: (x) => ctl.update(st.values.copyWith(consent: x)),
                actions: {
                  CustomSemanticsAction(label: f.t('legal.terms')): () => context.push('/legal/terms'),
                  CustomSemanticsAction(label: f.t('legal.privacy')): () => context.push('/legal/privacy'),
                },
                richLabel: Text.rich(
                  TextSpan(style: baseStyle, children: [
                    TextSpan(text: f.t('signup.consent.pre')),
                    TextSpan(text: f.t('legal.terms'), style: linkStyle, recognizer: _linkTerms),
                    TextSpan(text: f.t('signup.consent.and')),
                    TextSpan(text: f.t('legal.privacy'), style: linkStyle, recognizer: _linkPrivacy),
                    TextSpan(text: f.t('signup.consent.post')),
                  ]),
                ),
              ),
              AQErrorBanner(tone: AQBannerTone.info, text: cfg.needsDocuments ? f.t('signup.docsLater') : f.t('signup.noDocs')),
            ]);
          },
        );
    }

    final conflict = st.bannerKey == 'signup.conflict';

    return AQAuthScaffold(
      title: f.t(title),
      subtitle: st.stepIndex == 0 ? option.tagline(EntryStrings.of(context)) : null,
      onBack: () {
        if (!ctl.back()) aqBack(context, '/onboarding/purpose');
      },
      backLabel: f.t('common.back'),
      progress: journeyProgress(context, widget.purpose, JourneyAt.signup, step: step),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (conflict)
          _ConflictCard(onOtherEmail: () => ctl.goToStep(SignupStep.contact))
        else if (st.bannerKey != null)
          AQErrorBanner(text: f.t(st.bannerKey!)),
        AQPrimaryButton(label: ctl.isLast ? f.t('signup.create') : f.t('common.next'), loading: st.submitting, onPressed: _primary),
        // Presentation shortcut for the two customer-facing roles; demo builds only.
        if (kDemoMode && (widget.purpose == SignupPurpose.userToShop || widget.purpose == SignupPurpose.realEstateAgent))
          AQTextButton(label: f.t('demo.skip'), color: c.inkSoft, onPressed: () => demoSkipInto(context, ref, widget.purpose)),
        const SizedBox(height: AQSpacing.x2),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          AQIcon('lock', size: AQIconSize.small, color: c.inkFaint),
          const SizedBox(width: AQSpacing.x2),
          Flexible(child: Text(f.t('signup.draftSaved'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint).copyWith(fontSize: 11.5))),
        ]),
      ]),
      children: [AQStepSwitcher(stepKey: step, forward: _forward, child: body)],
    );
  }
}

/// Recovery surface for an account conflict: never a dead-end banner.
/// Wording stays within the safe error contract (no account details are revealed).
class _ConflictCard extends StatelessWidget {
  final VoidCallback onOtherEmail;
  const _ConflictCard({required this.onOtherEmail});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AQSpacing.x3),
        padding: const EdgeInsets.all(AQSpacing.x4),
        decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(AQRadius.medium)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.t('conflict.title'), style: AQTypography.of(context, AQText.titleMedium)),
          const SizedBox(height: 2),
          Text(f.t('conflict.body'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
          const SizedBox(height: AQSpacing.x2),
          Wrap(spacing: AQSpacing.x1, children: [
            AQTextButton(label: f.t('conflict.signin'), color: c.accent, onPressed: () => context.push('/login')),
            AQTextButton(label: f.t('conflict.forgot'), color: c.accent, onPressed: () => context.push('/forgot-password')),
            AQTextButton(label: f.t('conflict.other'), color: c.accent, onPressed: onOtherEmail),
          ]),
        ]),
      ),
    );
  }
}
