import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/aq/aq_forms.dart';
import '../core/aq/aq_tokens.dart';
import '../core/aq/aq_typography.dart';
import '../core/config/backend_mode.dart';
import '../core/localization/flow_strings.dart';
import '../data/models/enums.dart';
import '../data/models/money.dart';
import '../features/viewing/widgets/viewing_format.dart';
import '../features/workspace/aq_home.dart' show aqImg;
import 'admin_auth.dart';
import 'admin_directory.dart' show adminLog, decisionVerb;
import 'admin_images.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'admin_review_parts.dart';
import 'admin_widgets.dart';
import 'admin_ui.dart';
import 'admin_l10n.dart';

const _pageSize = 8;

String _typeName(BuildContext context, PropertyType t) =>
    FlowStrings.of(context).t(adminTypeKey(t));

String _missingLabel(String k) => switch (k) {
  'title' => 'title',
  'description' => 'description',
  'location' => 'location',
  'size' => 'size',
  'price' => 'price',
  'photos' => 'photos',
  'deed' => 'title deed document',
  _ => k,
};

/// Disclosure wording the e-Broker flow agreed. The console shows it as recorded; it never adds a
/// fee amount, a payment step or a commission figure of its own.
const kEBrokerDisclosure = 'Aqary Real Estate fees will apply up to 2%';

// ------------------------------------------------------------------ queue

class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});
  @override
  ConsumerState<ModerationQueueScreen> createState() =>
      _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen> {
  final _search = TextEditingController();
  ListingSource? _source;
  ModerationStatus? _status;
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
    final async = ref.watch(moderationListProvider);
    final store = ref.watch(adminStoreProvider);
    return AdminFrame(
      section: '/moderation',
      title: tr('Listing moderation'),
      subtitle: tr('Listings from agents and Aqary e-Broker submissions waiting for review.'),
      actions: [
        AdminSecondaryButton(
          label: tr('Refresh'),
          leadingIcon: 'refresh',
          trailingChevron: false,
          compact: true,
          onPressed: () => ref.invalidate(moderationListProvider),
        ),
      ],
      children: [
        AdminAsyncView<List<ListingSubmission>>(
          value: async,
          onRetry: () => ref.invalidate(moderationListProvider),
          builder: (all) {
            if (all.isEmpty) {
              return AdminNotice(
                icon: 'home',
                title: tr('No listings are waiting'),
                body: tr('Submissions from agents and e-Broker appear here.'),
                action: kUseDemoBackend && store != null
                    ? AdminSecondaryButton(
                        label: tr('Add demo records'),
                        trailingChevron: false,
                        onPressed: () {
                          store.seedDemoRecords();
                          ref.invalidate(moderationListProvider);
                          ref.invalidate(verificationListProvider);
                        },
                      )
                    : null,
              );
            }
            final q = _search.text.trim().toLowerCase();
            final shown = all
                .where(
                  (l) =>
                      (_source == null || l.source == _source) &&
                      (_status == null || l.status == _status) &&
                      (q.isEmpty ||
                          l.title.toLowerCase().contains(q) ||
                          l.ownerName.toLowerCase().contains(q) ||
                          l.id.toLowerCase().contains(q)),
                )
                .toList();
            final pages = (shown.length / _pageSize).ceil().clamp(1, 9999);
            final page = _page.clamp(0, pages - 1);
            final slice = shown.skip(page * _pageSize).take(_pageSize).toList();
            final c = AQColors.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSearchField(
                  controller: _search,
                  hint: tr('Search by title, owner or ID'),
                  onChanged: (_) => _filter(() {}),
                ),
                const SizedBox(height: AQSpacing.x3),
                adminFilterRow(context, 'Source', [
                  ('All', _source == null, () => _filter(() => _source = null)),
                  for (final s in ListingSource.values)
                    (
                      sourceLabel(s),
                      _source == s,
                      () => _filter(() => _source = s),
                    ),
                ]),
                adminFilterRow(context, 'Status', [
                  ('All', _status == null, () => _filter(() => _status = null)),
                  for (final s in ModerationStatus.values)
                    (
                      moderationStatusLabel(s),
                      _status == s,
                      () => _filter(() => _status = s),
                    ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Showing ${shown.length} of ${all.length} submissions',
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
                      'Listing',
                      'Source',
                      'Submitted',
                      'Owner',
                      'Status',
                    ],
                    flex: const [4, 3, 3, 3, 3],
                    rows: [
                      for (final l in slice)
                        AdminTableRow(
                          key: l.id,
                          semantics: tr('${l.title}, ${sourceLabel(l.source)}, ${moderationStatusLabel(l.status)}'),
                          onTap: () => context.go('/moderation/${l.id}'),
                          cells: [
                            AdminThumbCell(
                              thumb: AdminThumb(
                                asset: l.photos.isNotEmpty && l.photos.first.startsWith('assets/') ? l.photos.first : null,
                                icon: 'home',
                                size: 52,
                              ),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  VFmt.iso(l.title),
                                  style: AQTypography.of(
                                    context,
                                    AQText.titleSmall,
                                  ),
                                ),
                                Text(
                                  '${_typeName(context, l.type)}${l.location.isEmpty ? '' : ' · ${l.location}'}${l.missing.isEmpty ? '' : ' · incomplete'}',
                                  style: AQTypography.of(
                                    context,
                                    AQText.bodySmall,
                                    color: l.missing.isEmpty
                                        ? c.inkSoft
                                        : c.danger,
                                  ),
                                ),
                              ],
                            ),
                            ),
                            Text(
                              sourceLabel(l.source),
                              style: AQTypography.of(
                                context,
                                AQText.bodyMedium,
                              ),
                            ),
                            Text(
                              shortDate(context, l.submittedAt),
                              style: AQTypography.of(context, AQText.bodySmall),
                            ),
                            Text(
                              VFmt.iso(l.ownerName),
                              style: AQTypography.of(
                                context,
                                AQText.bodyMedium,
                              ),
                            ),
                            adminStatusPill(
                              moderationStatusLabel(l.status),
                              moderationStatusLook(l.status),
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

class ModerationDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ModerationDetailScreen({super.key, required this.id});
  @override
  ConsumerState<ModerationDetailScreen> createState() =>
      _ModerationDetailScreenState();
}

class _ModerationDetailScreenState
    extends ConsumerState<ModerationDetailScreen> {
  String? _lockedBy;
  bool _claimed = false;
  late final ModerationRepository _repo = ref.read(
    moderationRepositoryProvider,
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
      ref.invalidate(moderationItemProvider(widget.id));
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
    final c = AQColors.of(context);
    final async = ref.watch(moderationItemProvider(widget.id));
    final session = ref.watch(adminAuthProvider).session;
    return AdminFrame(
      section: '/moderation',
      title: async.valueOrNull?.title ?? 'Submission',
      subtitle: async.valueOrNull == null
          ? null
          : '${sourceLabel(async.value!.source)} · ID ${async.value!.id}',
      onBack: () => context.go('/moderation'),
      backLabel: tr('Back to moderation'),
      children: [
        AdminAsyncView<ListingSubmission?>(
          value: async,
          onRetry: () => ref.invalidate(moderationItemProvider(widget.id)),
          builder: (l) {
            if (l == null) {
              return AdminNotice(
                icon: 'info',
                title: tr('We could not find this submission'),
                body: tr('It may have been removed. Go back to the list.'),
              );
            }
            final role = session?.role ?? AdminRole.auditor;
            final missing = l.missing;
            final locked =
                _lockedBy ??
                (l.claimedByOther(session?.id ?? '', DateTime.now())
                    ? l.claimedByName
                    : null);
            final (tone, icon) = moderationStatusLook(l.status);
            return LayoutBuilder(
              builder: (context, box) {
                final twoCol = box.maxWidth >= 860;
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClaimBanner(lockedBy: locked),
                    Row(
                      children: [
                        adminStatusPill(moderationStatusLabel(l.status), (
                          tone,
                          icon,
                        )),
                        const SizedBox(width: AQSpacing.x2),
                        adminStatusPill(sourceLabel(l.source), (
                          l.source == ListingSource.eBroker ? tone : tone,
                          'home',
                        )),
                      ],
                    ),
                    if (missing.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AQSpacing.x4),
                        child: AQErrorBanner(
                          text: tr('Missing mandatory information: ${missing.map(_missingLabel).join(", ")}.'),
                        ),
                      ),
                    adminSection(context, 'Property'),
                    AdminKeyValues([
                      ('Title', l.title.isEmpty ? 'Not provided' : l.title),
                      (
                        'Category',
                        FlowStrings.of(context).t('ls.market.${l.market.name}'),
                      ),
                      ('Type', _typeName(context, l.type)),
                      (
                        'Transaction',
                        FlowStrings.of(context)
                            .t('ls.tx.${l.transaction.name}'),
                      ),
                      (
                        'Location',
                        l.location.isEmpty ? 'Not provided' : l.location,
                      ),
                      (
                        'Size',
                        l.sizeSqm == null
                            ? 'Not provided'
                            : '${VFmt.n(context, l.sizeSqm!.round())} m²',
                      ),
                      (
                        'Price',
                        l.priceOmr == null
                            ? 'Not provided'
                            : Money(l.priceOmr!).formatted,
                      ),
                      ('Submitted by', l.ownerName),
                      ('Submitted', shortDate(context, l.submittedAt)),
                    ]),
                    adminSection(context, 'Description'),
                    Text(
                      l.description.isEmpty
                          ? 'No description was provided.'
                          : l.description,
                      style: AQTypography.of(
                        context,
                        AQText.bodyMedium,
                        color: l.description.isEmpty ? c.danger : null,
                      ),
                    ),
                    adminSection(context, 'Photos'),
                    if (l.photos.isEmpty)
                      AdminNotice(
                        icon: 'alert',
                        title: tr('No photos were submitted'),
                      )
                    else
                      Wrap(
                        spacing: AQSpacing.x2,
                        runSpacing: AQSpacing.x2,
                        children: [
                          for (final p in l.photos)
                            Container(
                              width: 150,
                              height: 100,
                              alignment: Alignment.center,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: c.surfaceSelected,
                                borderRadius: BorderRadius.circular(
                                  AQRadius.medium,
                                ),
                              ),
                              child: p.startsWith('assets/')
                                  ? ExcludeSemantics(child: SizedBox.expand(child: aqImg(p, cacheWidth: 480)))
                                  : Text(
                                p,
                                style: AQTypography.of(
                                  context,
                                  AQText.bodySmall,
                                  soft: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    adminSection(context, 'Documents'),
                    AdminDocumentList(documents: l.documents),
                    if (l.source == ListingSource.eBroker) ...[
                      adminSection(context, 'e-Broker fee disclosure'),
                      AdminKeyValues([
                        ('Disclosure shown', kEBrokerDisclosure),
                        (
                          'Accepted by the owner',
                          l.feeDisclosureAccepted == null
                              ? 'Not recorded'
                              : (l.feeDisclosureAccepted! ? 'Yes' : 'No'),
                        ),
                      ]),
                    ],
                    adminSection(context, 'Earlier decisions'),
                    AdminHistoryList(history: l.history),
                  ],
                );
                final right = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    adminSection(context, 'Review'),
                    DecisionPanel(
                      reasons: kListingReasons,
                      approveBlockedReason: missing.isEmpty ? null : 'Approval is not possible while mandatory information is missing. Request corrections instead.',
                      canDecide: role.canDecide && locked == null,
                      open: l.open,
                      onDecide: (d, reason, note) async {
                        await ref
                            .read(moderationRepositoryProvider)
                            .decide(l.id, d, reason: reason, note: note);
                        adminLog(ref, '${decisionVerb(d)} listing${l.source == ListingSource.eBroker ? ' (e-Broker)' : ''}', l.title);
                        ref.invalidate(moderationItemProvider(l.id));
                        ref.invalidate(moderationListProvider);
                      },
                    ),
                    if (l.open)
                      Padding(
                        padding: const EdgeInsets.only(top: AQSpacing.x3),
                        child: Text(
                          'A listing becomes visible to buyers only after it is approved here.',
                          style: AQTypography.of(
                            context,
                            AQText.bodySmall,
                            soft: true,
                          ),
                        ),
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
