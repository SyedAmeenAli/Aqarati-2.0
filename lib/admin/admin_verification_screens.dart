import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/aq/aq_status.dart';
import '../core/aq/aq_tokens.dart';
import '../core/aq/aq_typography.dart';
import '../core/config/backend_mode.dart';
import '../features/viewing/domain/viewing_presentation.dart' show AQTone;
import '../features/viewing/widgets/viewing_format.dart';
import 'admin_auth.dart';
import 'admin_directory.dart' show adminLog, decisionVerb;
import 'admin_models.dart';
import 'admin_repository.dart';
import 'admin_review_parts.dart';
import 'admin_images.dart';
import 'admin_widgets.dart';
import 'admin_ui.dart';
import 'admin_l10n.dart';

const _pageSize = 8;

// ------------------------------------------------------------------ queue

class VerificationQueueScreen extends ConsumerStatefulWidget {
  const VerificationQueueScreen({super.key});
  @override
  ConsumerState<VerificationQueueScreen> createState() =>
      _VerificationQueueScreenState();
}

class _VerificationQueueScreenState
    extends ConsumerState<VerificationQueueScreen> {
  final _search = TextEditingController();
  ApplicantKind? _kind;
  QueueStatus? _status;
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(VoidCallback f) => setState(() {
    f();
    _page = 0;
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final async = ref.watch(verificationListProvider);
    final store = ref.watch(adminStoreProvider);
    return AdminFrame(
      section: '/verification',
      stats: [(tr('In the queue'), async.valueOrNull?.length ?? 0)],
      title: tr('Verification queue'),
      subtitle: tr('Agents and companies waiting for review. Resubmissions come first, then the oldest.'),
      actions: [
        AdminSecondaryButton(
          label: tr('Refresh'),
          leadingIcon: 'refresh',
          trailingChevron: false,
          compact: true,
          onPressed: () => ref.invalidate(verificationListProvider),
        ),
      ],
      children: [
        AdminAsyncView<List<VerificationItem>>(
          value: async,
          onRetry: () => ref.invalidate(verificationListProvider),
          builder: (all) {
            if (all.isEmpty) {
              return AdminNotice(
                icon: 'verified',
                title: tr('The queue is empty'),
                body: tr('New applications from agents and companies appear here.'),
                action: kUseDemoBackend && store != null
                    ? AdminSecondaryButton(
                        label: tr('Add demo records'),
                        trailingChevron: false,
                        onPressed: () {
                          store.seedDemoRecords();
                          ref.invalidate(verificationListProvider);
                          ref.invalidate(moderationListProvider);
                        },
                      )
                    : null,
              );
            }
            final q = _search.text.trim().toLowerCase();
            final shown = all
                .where(
                  (v) =>
                      (_kind == null || v.kind == _kind) &&
                      (_status == null || v.status == _status) &&
                      (q.isEmpty ||
                          v.applicantName.toLowerCase().contains(q) ||
                          v.id.toLowerCase().contains(q)),
                )
                .toList();
            final pages = (shown.length / _pageSize).ceil().clamp(1, 9999);
            final page = _page.clamp(0, pages - 1);
            final slice = shown.skip(page * _pageSize).take(_pageSize).toList();
            final session = ref.watch(adminAuthProvider).session;
            final now = DateTime.now();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSearchField(
                  controller: _search,
                  hint: tr('Search by name or application ID'),
                  onChanged: (_) => _filter(() {}),
                ),
                const SizedBox(height: AQSpacing.x3),
                adminFilterRow(context, 'Account type', [
                  ('All', _kind == null, () => _filter(() => _kind = null)),
                  for (final k in ApplicantKind.values)
                    (kindLabel(k), _kind == k, () => _filter(() => _kind = k)),
                ]),
                adminFilterRow(context, 'Status', [
                  ('All', _status == null, () => _filter(() => _status = null)),
                  for (final s in QueueStatus.values)
                    (
                      queueStatusLabel(s),
                      _status == s,
                      () => _filter(() => _status = s),
                    ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Showing ${shown.length} of ${all.length} applications',
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  AdminNotice(
                    icon: 'search',
                    title: tr('Nothing matches these filters'),
                    body: tr('Clear a filter or change the search to see more.'),
                  )
                else
                  AdminTable(
                    headers: const [
                      'Applicant',
                      'Account type',
                      'Submitted',
                      'Status',
                      'Documents',
                    ],
                    flex: const [4, 3, 3, 3, 2],
                    endColumns: const {4},
                    rows: [
                      for (final v in slice)
                        AdminTableRow(
                          key: v.id,
                          semantics: tr('${v.applicantName}, ${kindLabel(v.kind)}, ${queueStatusLabel(v.status)}'),
                          onTap: () => context.go('/verification/${v.id}'),
                          cells: [
                            AdminThumbCell(
                              thumb: const AdminThumb(icon: 'user', size: 44),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  VFmt.iso(v.applicantName),
                                  style: AQTypography.of(
                                    context,
                                    AQText.titleSmall,
                                  ),
                                ),
                                Text(
                                  'ID ${v.id}${v.isResubmission ? ' · resubmission' : ''}${v.claimedByOther(session?.id ?? '', now) ? ' · being reviewed' : ''}',
                                  style: AQTypography.of(
                                    context,
                                    AQText.bodySmall,
                                    color: c.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                            ),
                            Text(
                              kindLabel(v.kind),
                              style: AQTypography.of(
                                context,
                                AQText.bodyMedium,
                              ),
                            ),
                            Text(
                              shortDate(context, v.submittedAt),
                              style: AQTypography.of(context, AQText.bodySmall),
                            ),
                            adminStatusPill(
                              queueStatusLabel(v.status),
                              queueStatusLook(v.status),
                            ),
                            Text(
                              v.documents.isEmpty
                                  ? 'None'
                                  : '${v.documents.length}${v.documents.any((d) => !d.available) ? ' · issue' : ''}',
                              style: AQTypography.of(
                                context,
                                AQText.bodyMedium,
                                color:
                                    v.documents.isEmpty ||
                                        v.documents.any((d) => !d.available)
                                    ? c.danger
                                    : null,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                if (pages > 1)
                  AdminPager(page: page, pages: pages, onPrevious: page == 0 ? null : () => setState(() => _page = page - 1), onNext: page >= pages - 1 ? null : () => setState(() => _page = page + 1)),
              ],
            );
          },
        ),
        adminDemoNotice(),
      ],
    );
  }
}

// ------------------------------------------------------------------ detail

class VerificationDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const VerificationDetailScreen({super.key, required this.id});
  @override
  ConsumerState<VerificationDetailScreen> createState() =>
      _VerificationDetailScreenState();
}

class _VerificationDetailScreenState
    extends ConsumerState<VerificationDetailScreen> {
  final Set<String> _checks = {};
  String? _lockedBy;
  bool _claimed = false;
  late final VerificationRepository _repo = ref.read(
    verificationRepositoryProvider,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
  }

  Future<void> _claim() async {
    try {
      await _repo.claim(widget.id);
      _claimed = true;
      ref.invalidate(verificationItemProvider(widget.id));
    } on AdminLockedException catch (e) {
      if (mounted) {
        setState(() => _lockedBy = e.by.isEmpty ? 'Another reviewer' : e.by);
      }
    } catch (e) {
      endSessionIfExpired(ref, e);
    }
  }

  @override
  void dispose() {
    if (_claimed) _repo.release(widget.id).catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(verificationItemProvider(widget.id));
    final session = ref.watch(adminAuthProvider).session;
    return AdminFrame(
      section: '/verification',
      title: async.valueOrNull?.applicantName ?? 'Application',
      subtitle: async.valueOrNull == null
          ? null
          : '${kindLabel(async.value!.kind)} · ID ${async.value!.id}',
      onBack: () => context.go('/verification'),
      backLabel: tr('Back to the queue'),
      children: [
        AdminAsyncView<VerificationItem?>(
          value: async,
          onRetry: () => ref.invalidate(verificationItemProvider(widget.id)),
          builder: (v) {
            if (v == null) {
              return AdminNotice(
                icon: 'info',
                title: tr('We could not find this application'),
                body: tr('It may have been removed. Go back to the queue.'),
              );
            }
            final role = session?.role ?? AdminRole.auditor;
            final allChecked = kApplicantChecklist.every(_checks.contains);
            String? blocked;
            if (!allChecked) {
              blocked = 'Tick every check in the checklist before approving.';
            } else if (v.isDeveloper &&
                v.status == QueueStatus.awaitingSecondApproval) {
              if (v.firstApproverId == session?.id) {
                blocked = 'You gave the first approval. A different senior reviewer must give the second.';
              } else if (!role.canSecondApprove) {
                blocked = 'Only a senior reviewer or super admin can give the second approval.';
              }
            }
            final locked =
                _lockedBy ??
                (v.claimedByOther(session?.id ?? '', DateTime.now())
                    ? v.claimedByName
                    : null);
            final (tone, icon) = queueStatusLook(v.status);
            return LayoutBuilder(
              builder: (context, box) {
                final twoCol = box.maxWidth >= 860;
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClaimBanner(lockedBy: locked),
                    Row(
                      children: [
                        AQStatusPill(
                          label: queueStatusLabel(v.status),
                          tone: tone,
                          icon: icon,
                        ),
                        if (v.isResubmission) ...[
                          const SizedBox(width: AQSpacing.x2),
                          AQStatusPill(
                            label: tr('Resubmission'),
                            tone: AQTone.warning,
                            icon: 'refresh',
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    if (v.isDeveloper)
                      Padding(
                        padding: const EdgeInsets.only(top: AQSpacing.x3),
                        child: Text(
                          'Development companies need two approvals from two different people.',
                          style: AQTypography.of(
                            context,
                            AQText.bodySmall,
                            soft: true,
                          ),
                        ),
                      ),
                    adminSection(context, 'Applicant'),
                    AdminKeyValues([
                      ('Account type', kindLabel(v.kind)),
                      ('Submitted', shortDate(context, v.submittedAt)),
                      for (final e in v.details.entries) (e.key, e.value),
                    ]),
                    adminSection(context, 'Documents'),
                    AdminDocumentList(documents: v.documents),
                    adminSection(context, 'Earlier decisions'),
                    AdminHistoryList(history: v.history),
                  ],
                );
                final right = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    adminSection(context, 'Checklist'),
                    AdminProgressCard(label: tr('Checks completed'), done: _checks.length, total: kApplicantChecklist.length),
                    const SizedBox(height: AQSpacing.x3),
                    AdminChecklist(
                      items: const [
                        ('registry', 'Registry lookup done'),
                        ('name', 'Name matches the documents'),
                        ('call', 'Call-back made'),
                        ('duplicates', 'No duplicate account'),
                      ],
                      done: _checks,
                      enabled: v.open && role.canDecide && locked == null,
                      onChanged: (id, on) => setState(
                        () => on ? _checks.add(id) : _checks.remove(id),
                      ),
                    ),
                    const SizedBox(height: AQSpacing.x5),
                    DecisionPanel(
                      reasons: kApplicantReasons,
                      approveBlockedReason: blocked,
                      canDecide: role.canDecide && locked == null,
                      open: v.open,
                      onDecide: (d, reason, note) async {
                        await ref
                            .read(verificationRepositoryProvider)
                            .decide(v.id, d, reason: reason, note: note);
                        adminLog(ref, '${decisionVerb(d)} verification', v.applicantName);
                        ref.invalidate(verificationItemProvider(v.id));
                        ref.invalidate(verificationListProvider);
                      },
                    ),
                  ],
                );
                if (!twoCol) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [left, right],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: left),
                    const SizedBox(width: AQSpacing.x6),
                    Expanded(flex: 5, child: right),
                  ],
                );
              },
            );
          },
        ),
        adminDemoNotice(),
      ],
    );
  }
}
