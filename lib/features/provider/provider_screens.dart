import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_status.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/backend_mode.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException;
import '../devbuild/db_widgets.dart'
    show DbErrorCard, DbFieldFrame, DbNotice, DbPillRow;
import '../ebroker/ebroker_models.dart' show isJpgOrPng;
import '../flow/state/document_state.dart'
    show documentPickerProvider, kMaxDocumentBytes;
import '../maintenance/maintenance_models.dart';
import '../maintenance/maintenance_repository.dart';
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/screens/viewing_kit.dart'
    show AQViewingSectionTitle, AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_thumb.dart';
import 'provider_repository.dart';

(AQTone, String) _statusLook(MaintenanceStatus s) => switch (s) {
  MaintenanceStatus.requested => (AQTone.pending, 'clock'),
  MaintenanceStatus.confirmed => (AQTone.success, 'check'),
  MaintenanceStatus.declined => (AQTone.danger, 'close'),
  MaintenanceStatus.cancelled => (AQTone.neutral, 'close'),
  MaintenanceStatus.completed => (AQTone.success, 'check'),
};

Widget _statusPill(FlowStrings f, MaintenanceStatus s) {
  final (tone, icon) = _statusLook(s);
  return AQStatusPill(
    label: f.t('mnt.st.${s.name}'),
    tone: tone,
    icon: icon,
    dense: true,
  );
}

// ------------------------------------------------------------------ invitation

class ProviderInviteScreen extends ConsumerStatefulWidget {
  final String? code;
  const ProviderInviteScreen({super.key, this.code});
  @override
  ConsumerState<ProviderInviteScreen> createState() => _InviteState();
}

class _InviteState extends ConsumerState<ProviderInviteScreen> {
  late final TextEditingController _code = TextEditingController(
    text: widget.code ?? '',
  );
  final _name = TextEditingController();
  final _phone = TextEditingController();
  InviteInfo? _info;
  final Set<MaintenanceService> _services = {};
  String? _cr, _licence;
  bool _checking = false, _saving = false, _tried = false;
  String? _codeErr, _failKey, _fileErr;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final f = FlowStrings.of(context);
    if (_code.text.trim().isEmpty) {
      setState(() => _codeErr = f.t('prv.inv.err.empty'));
      return;
    }
    setState(() {
      _checking = true;
      _codeErr = null;
    });
    try {
      final info = await ref
          .read(providerInviteRepositoryProvider)
          .check(_code.text);
      if (mounted) {
        setState(() {
          _info = info;
          _services
            ..clear()
            ..addAll(info.services);
        });
      }
    } on InviteException catch (e) {
      if (mounted) {
        setState(() => _codeErr = f.t('prv.inv.err.${e.problem.name}'));
      }
    } catch (_) {
      if (mounted) setState(() => _codeErr = f.t('prv.inv.err.net'));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pick(bool cr) async {
    final f = FlowStrings.of(context);
    final d = await ref.read(documentPickerProvider).pick();
    if (d == null || !mounted) return;
    final b = d.bytes;
    final ok =
        d.sizeBytes <= kMaxDocumentBytes &&
        (isJpgOrPng(b) ||
            (b.length > 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44));
    setState(() {
      if (ok) {
        _fileErr = null;
        if (cr) {
          _cr = d.name;
        } else {
          _licence = d.name;
        }
      } else {
        _fileErr = f.t('prv.setup.hint');
      }
    });
  }

  String? get _eName => _name.text.trim().isEmpty ? 'prv.setup.err.name' : null;
  String? get _ePhone => RegExp(r'^\d{8}$').hasMatch(_phone.text.trim())
      ? null
      : 'prv.setup.err.phone';
  String? get _eServices => _services.isEmpty ? 'prv.setup.err.services' : null;
  String? get _eCr => _cr == null ? 'prv.setup.err.cr' : null;
  String? get _eLic => _licence == null ? 'prv.setup.err.licence' : null;

  Future<void> _submit() async {
    setState(() => _tried = true);
    if ([_eName, _ePhone, _eServices, _eCr, _eLic].any((e) => e != null) ||
        _saving) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failKey = null;
    });
    try {
      await ref
          .read(providerInviteRepositoryProvider)
          .accept(
            _code.text,
            ProviderSetup(
              businessName: _name.text.trim(),
              phone: _phone.text.trim(),
              services: _services.toList(),
              crName: _cr!,
              licenceName: _licence!,
            ),
          );
      ref.invalidate(providerAccountProvider);
      if (mounted) context.go('/provider');
    } catch (_) {
      if (mounted) setState(() => _failKey = 'prv.setup.fail');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    void back() => aqBack(context, '/app/account');
    final info = _info;
    String? ek(String? k) => _tried ? k : null;
    String? et(String? k) => _tried && k != null ? f.t(k) : null;
    Widget fileTile(String label, String? name, bool cr, String? e) =>
        DbFieldFrame(
          label: label,
          required: true,
          error: ek(e),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name == null ? f.t('prv.setup.hint') : VFmt.iso(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AQTypography.of(
                    context,
                    AQText.bodyMedium,
                    soft: true,
                  ),
                ),
              ),
              AQTextButton(
                label: name == null
                    ? f.t('prv.setup.pick')
                    : f.t('prv.setup.replace'),
                color: c.accent,
                onPressed: () => _pick(cr),
              ),
            ],
          ),
        );
    return AQViewingScaffold(
      title: info == null ? f.t('prv.inv.title') : f.t('prv.setup.title'),
      subtitle: info == null ? f.t('prv.inv.sub') : f.t('prv.setup.sub'),
      backLabel: f.t('common.back'),
      onBack: back,
      bottom: AQBottomActionBar(
        primary: info == null
            ? AQPrimaryButton(
                label: f.t('prv.inv.check'),
                trailingChevron: false,
                loading: _checking,
                onPressed: _checking ? null : _check,
              )
            : AQPrimaryButton(
                label: f.t('prv.setup.submit'),
                trailingChevron: false,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
      ),
      children: [
        if (_failKey != null) AQErrorBanner(text: f.t(_failKey!)),
        if (info == null) ...[
          AQTextField(
            label: f.t('prv.inv.code'),
            controller: _code,
            error: _codeErr,
            action: TextInputAction.done,
            onSubmitted: (_) => _check(),
            onChanged: (_) {
              if (_codeErr != null) setState(() => _codeErr = null);
            },
          ),
          const SizedBox(height: AQSpacing.x3),
          DbNotice(f.t('prv.inv.notpublic'), icon: 'lock'),
        ] else ...[
          AQTextField(
            label: f.t('prv.setup.name'),
            controller: _name,
            error: et(_eName),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AQSpacing.x3),
          AQTextField(
            label: f.t('prv.setup.phone'),
            controller: _phone,
            keyboardType: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            error: et(_ePhone),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AQSpacing.x3),
          DbFieldFrame(
            label: f.t('prv.setup.services'),
            required: true,
            error: ek(_eServices),
            child: DbPillRow(
              pills: [
                for (final s in info.services)
                  (
                    f.t('mnt.svc.${s.name}'),
                    _services.contains(s),
                    () => setState(() {
                      if (!_services.remove(s)) _services.add(s);
                    }),
                  ),
              ],
            ),
          ),
          AQViewingSectionTitle(f.t('prv.setup.cr')),
          fileTile(f.t('prv.setup.cr'), _cr, true, _eCr),
          const SizedBox(height: AQSpacing.x3),
          fileTile(f.t('prv.setup.licence'), _licence, false, _eLic),
          if (_fileErr != null)
            Padding(
              padding: const EdgeInsets.only(top: AQSpacing.x1),
              child: Text(
                _fileErr!,
                style: AQTypography.of(
                  context,
                  AQText.bodySmall,
                  color: c.danger,
                ),
              ),
            ),
        ],
        const SizedBox(height: AQSpacing.x4),
        if (kUseDemoBackend) DbNotice(f.t('prv.demo'), icon: 'info'),
      ],
    );
  }
}

// ------------------------------------------------------------------ workspace

class ProviderHomeScreen extends ConsumerStatefulWidget {
  const ProviderHomeScreen({super.key});
  @override
  ConsumerState<ProviderHomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<ProviderHomeScreen> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/app/account');
    final acc = ref.watch(providerAccountProvider);
    return acc.when(
      loading: () => AQViewingScaffold(
        title: f.t('prv.home.title'),
        backLabel: f.t('common.back'),
        onBack: back,
        children: const [AQViewingSkeleton(height: 96)],
      ),
      error: (e, _) => AQViewingScaffold(
        title: f.t('prv.home.title'),
        backLabel: f.t('common.back'),
        onBack: back,
        children: [
          DbErrorCard(
            error: e,
            onRetry: () => ref.invalidate(providerAccountProvider),
          ),
        ],
      ),
      data: (a) {
        if (a == null) {
          return AQViewingScaffold(
            title: f.t('prv.home.title'),
            backLabel: f.t('common.back'),
            onBack: back,
            bottom: AQBottomActionBar(
              primary: AQPrimaryButton(
                label: f.t('prv.noaccess.cta'),
                trailingChevron: false,
                onPressed: () => context.push('/provider/invite'),
              ),
            ),
            children: [
              AQNoticeCard(
                icon: 'lock',
                title: f.t('prv.noaccess.t'),
                body: f.t('prv.noaccess.b'),
              ),
            ],
          );
        }
        final tone = switch (a.grant) {
          ProviderGrant.approved => AQTone.success,
          ProviderGrant.pendingVerification => AQTone.pending,
          ProviderGrant.resubmissionRequired => AQTone.warning,
        };
        return AQViewingScaffold(
          title: VFmt.iso(a.businessName),
          subtitle: f.t('prv.home.title'),
          backLabel: f.t('common.back'),
          onBack: back,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AQStatusPill(
                label: f.t('prv.grant.${a.grant.name}'),
                tone: tone,
                icon: a.canWork ? 'verified' : 'clock',
              ),
            ),
            const SizedBox(height: AQSpacing.x3),
            if (a.grant == ProviderGrant.pendingVerification)
              AQNoticeCard(
                icon: 'clock',
                title: f.t('prv.pending.t'),
                body: f.t('prv.pending.b'),
                tone: AQTone.pending,
              ),
            if (a.grant == ProviderGrant.resubmissionRequired)
              AQNoticeCard(
                icon: 'alert',
                title: f.t('prv.resub.t'),
                body: f.t('prv.resub.b'),
                tone: AQTone.warning,
              ),
            if (kShowReviewTools) _QaProvider(a),
            if (a.canWork) ..._requests(context, f, a),
            const SizedBox(height: AQSpacing.x4),
            const AQDemoNotice(),
          ],
        );
      },
    );
  }

  List<Widget> _requests(
    BuildContext context,
    FlowStrings f,
    ProviderAccount a,
  ) {
    final async = ref.watch(providerRequestsProvider(a.providerId));
    return [
      const SizedBox(height: AQSpacing.x3),
      DbPillRow(
        pills: [
          (
            f.t('prv.f.open'),
            !_history,
            () => setState(() => _history = false),
          ),
          (
            f.t('prv.f.history'),
            _history,
            () => setState(() => _history = true),
          ),
        ],
      ),
      const SizedBox(height: AQSpacing.x3),
      async.when(
        loading: () => const AQViewingSkeleton(height: 84),
        error: (e, _) => AQErrorBanner(
          text: f.t('prv.error'),
          action: AQTextButton(
            label: f.t('common.retry'),
            color: AQColors.of(context).accent,
            onPressed: () =>
                ref.invalidate(providerRequestsProvider(a.providerId)),
          ),
        ),
        data: (all) {
          final list = all.where((b) => b.isOpen != _history).toList();
          if (list.isEmpty) {
            return AQEmptyViewingState(
              title: f.t(_history ? 'prv.empty.hist.t' : 'prv.empty.t'),
              body: f.t(_history ? 'prv.empty.hist.b' : 'prv.empty.b'),
            );
          }
          return Column(
            children: [
              for (final b in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  child: _RequestCard(b),
                ),
            ],
          );
        },
      ),
    ];
  }
}

class _RequestCard extends StatelessWidget {
  final MaintenanceBooking b;
  const _RequestCard(this.b);
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label:
          '${f.t('mnt.svc.${b.service.name}')}, ${VFmt.fullDate(context, b.date)}, ${f.t('mnt.st.${b.status.name}')}',
      excludeSemantics: true,
      onTap: () => context.push('/provider/requests/${b.id}'),
      child: AQPressable(
        onTap: () => context.push('/provider/requests/${b.id}'),
        child: AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Row(
            children: [
              aqRowLead(AQThumb(asset: maintenanceServiceImage(b.service), icon: 'construction')),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.t('mnt.svc.${b.service.name}'),
                      style: AQTypography.of(context, AQText.titleSmall),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${VFmt.shortDate(context, b.date)} · ${f.t('mnt.win.${b.window.name}')}',
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                    const SizedBox(height: AQSpacing.x2),
                    _statusPill(f, b.status),
                  ],
                ),
              ),
              const AQIcon('chevron-right', size: 18, directional: true),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ request detail

class ProviderRequestScreen extends ConsumerStatefulWidget {
  final String id;
  const ProviderRequestScreen({super.key, required this.id});
  @override
  ConsumerState<ProviderRequestScreen> createState() => _RequestState();
}

class _RequestState extends ConsumerState<ProviderRequestScreen> {
  bool _busy = false;
  String? _doneKey, _errorKey;
  // The operation that failed last, so "Try again" repeats exactly that one.
  VoidCallback? _retry;

  Future<void> _run(
    ProviderAccount a,
    Future<MaintenanceBooking> Function(ProviderWorkRepository r) op,
    String done,
  ) async {
    if (_busy) return;
    _retry = null;
    setState(() {
      _busy = true;
      _doneKey = null;
      _errorKey = null;
    });
    final k = (providerId: a.providerId, id: widget.id);
    try {
      await op(ref.read(providerWorkRepositoryProvider));
      ref.invalidate(providerRequestProvider(k));
      ref.invalidate(providerRequestsProvider(a.providerId));
      if (mounted) setState(() => _doneKey = done);
    } catch (e) {
      final conflict = e is ApiException && e.code == ApiErrorCode.conflict;
      // A conflict means the request moved on elsewhere, so it is read again. Any other failure
      // leaves the request exactly as it was shown (the service did not change it) and offers
      // the same operation once more; the page is never blanked just because an answer failed.
      if (conflict) ref.invalidate(providerRequestProvider(k));
      if (mounted) {
        setState(() {
          _errorKey = conflict ? 'prv.d.conflict' : 'prv.d.err';
          if (!conflict) _retry = () => _run(a, op, done);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(ProviderAccount a) async {
    final f = FlowStrings.of(context);
    final yes = await showAQSheet<bool>(
      context,
      useRootNavigator: true,
      builder: (s) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AQSpacing.gutter,
          AQSpacing.x2,
          AQSpacing.gutter,
          AQSpacing.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                f.t('prv.d.declineT'),
                style: AQTypography.of(s, AQText.headlineSmall),
              ),
            ),
            const SizedBox(height: AQSpacing.x2),
            Text(
              f.t('prv.d.declineB'),
              style: AQTypography.of(s, AQText.bodyMedium, soft: true),
            ),
            const SizedBox(height: AQSpacing.x4),
            AQPrimaryButton(
              label: f.t('prv.d.keep'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(false),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: f.t('prv.d.declineYes'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(true),
            ),
          ],
        ),
      ),
    );
    if (yes == true) {
      await _run(
        a,
        (r) => r.respond(a.providerId, widget.id, confirm: false),
        'prv.d.done.decline',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/provider');
    final acc = ref.watch(providerAccountProvider);
    Widget shell(List<Widget> children, {Widget? bottom}) => AQViewingScaffold(
      title: f.t('prv.d.title'),
      backLabel: f.t('common.back'),
      onBack: back,
      bottom: bottom,
      children: children,
    );
    final a = acc.valueOrNull;
    if (acc.isLoading && a == null) {
      return shell(const [AQViewingSkeleton(height: 96)]);
    }
    if (a == null || !a.canWork) {
      return shell([
        AQNoticeCard(
          icon: 'lock',
          title: f.t('prv.noaccess.t'),
          body: f.t('prv.noaccess.b'),
        ),
      ]);
    }
    final k = (providerId: a.providerId, id: widget.id);
    return ref
        .watch(providerRequestProvider(k))
        .when(
          loading: () => shell(const [AQViewingSkeleton(height: 96)]),
          error: (e, _) => shell([
            if (e is ProviderNotYoursException)
              AQNoticeCard(
                icon: 'lock',
                title: f.t('prv.d.denied.t'),
                body: f.t('prv.d.denied.b'),
              )
            else
              DbErrorCard(
                error: e,
                onRetry: () => ref.invalidate(providerRequestProvider(k)),
              ),
          ]),
          data: (b) {
            if (b == null) {
              return shell([
                AQNoticeCard(
                  icon: 'info',
                  title: f.t('prv.d.notFound'),
                  body: '',
                ),
              ]);
            }
            final (tone, icon) = _statusLook(b.status);
            Widget row(String k, String v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      k,
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      v,
                      style: AQTypography.of(context, AQText.bodyMedium),
                    ),
                  ),
                ],
              ),
            );
            Widget? bottom;
            if (b.status == MaintenanceStatus.requested) {
              bottom = AQBottomActionBar(
                primary: AQPrimaryButton(
                  label: f.t('prv.d.confirm'),
                  trailingChevron: false,
                  loading: _busy,
                  onPressed: _busy
                      ? null
                      : () => _run(
                          a,
                          (r) =>
                              r.respond(a.providerId, widget.id, confirm: true),
                          'prv.d.done.confirm',
                        ),
                ),
                secondary: AQBarSecondaryButton(
                  label: f.t('prv.d.decline'),
                  onPressed: _busy ? null : () => _decline(a),
                ),
              );
            } else if (b.status == MaintenanceStatus.confirmed) {
              bottom = AQBottomActionBar(
                primary: AQPrimaryButton(
                  label: f.t('prv.d.complete'),
                  trailingChevron: false,
                  loading: _busy,
                  onPressed: _busy
                      ? null
                      : () => _run(
                          a,
                          (r) => r.complete(a.providerId, widget.id),
                          'prv.d.done.complete',
                        ),
                ),
              );
            }
            return shell([
              if (_doneKey != null)
                AQErrorBanner(tone: AQBannerTone.success, text: f.t(_doneKey!)),
              if (_errorKey != null)
                AQErrorBanner(
                  text: f.t(_errorKey!),
                  action: _retry == null
                      ? null
                      : AQTextButton(
                          label: f.t('common.retry'),
                          color: AQColors.of(context).accent,
                          onPressed: _busy ? null : _retry,
                        ),
                ),
              const SizedBox(height: AQSpacing.x2),
              AQNoticeCard(
                icon: icon,
                title: f.t('mnt.st.${b.status.name}'),
                body: f.t('prv.d.note'),
                tone: tone,
              ),
              AQViewingSectionTitle(f.t('prv.d.title')),
              AQSurface(
                padding: const EdgeInsets.all(AQSpacing.x4),
                child: Column(
                  children: [
                    row(f.t('prv.d.service'), f.t('mnt.svc.${b.service.name}')),
                    row(f.t('prv.d.day'), VFmt.fullDate(context, b.date)),
                    row(f.t('prv.d.window'), f.t('mnt.win.${b.window.name}')),
                    row(
                      f.t('prv.d.received'),
                      VFmt.shortDate(context, b.createdAt),
                    ),
                    row(
                      f.t('prv.d.notes'),
                      b.notes.isEmpty ? f.t('prv.d.noNotes') : b.notes,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AQSpacing.x4),
              const AQDemoNotice(),
            ], bottom: bottom);
          },
        );
  }
}

/// QA only (`REVIEW_TOOLS`): stands in for the administrator's verification and for a customer, so
/// every provider state can be reached. Never in a production build.
class _QaProvider extends ConsumerWidget {
  final ProviderAccount a;
  const _QaProvider(this.a);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.read(providerInviteRepositoryProvider);
    final store = ref.read(maintenanceRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x3),
      child: Wrap(
        spacing: AQSpacing.x2,
        children: [
          if (invites is DemoProviderInviteRepository &&
              a.grant != ProviderGrant.approved)
            AQTextButton(
              label: 'QA: administrator verifies',
              onPressed: () {
                invites.debugGrant(ProviderGrant.approved);
                ref.invalidate(providerAccountProvider);
              },
            ),
          if (invites is DemoProviderInviteRepository &&
              a.grant == ProviderGrant.pendingVerification)
            AQTextButton(
              label: 'QA: administrator asks for changes',
              onPressed: () {
                invites.debugGrant(ProviderGrant.resubmissionRequired);
                ref.invalidate(providerAccountProvider);
              },
            ),
          if (store is DemoMaintenanceRepository && a.canWork)
            AQTextButton(
              label: 'QA: add a sample customer request',
              onPressed: () async {
                try {
                  await store.request(
                    providerId: a.providerId,
                    providerName: a.businessName,
                    service: MaintenanceService.ac,
                    date: DateTime.now().add(const Duration(days: 2)),
                    window: MaintenanceWindow.morning,
                    notes: 'Sample request. The unit is not cooling.',
                  );
                } catch (_) {}
                ref.invalidate(providerRequestsProvider(a.providerId));
              },
            ),
        ],
      ),
    );
  }
}
