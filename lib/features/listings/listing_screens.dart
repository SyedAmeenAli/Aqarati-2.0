import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/config/backend_mode.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_status.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/money.dart';
import '../devbuild/db_models.dart'
    show PermissionDeniedException, omanGovernorates;
import '../devbuild/db_widgets.dart'
    show
        DbErrorCard,
        DbFieldFrame,
        DbNotice,
        DbPillRow,
        DbSelectField,
        showDbChoiceSheet;
import '../flow/state/document_state.dart'
    show documentPickerProvider, kMaxDocumentBytes;
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/screens/viewing_kit.dart'
    show AQViewingSectionTitle, AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show aqImg;
import 'agent_guard.dart';
import 'listing_models.dart';
import 'listing_repository.dart';

// ------------------------------------------------------------------ shared pieces

(AQTone, String) _statusLook(ListingStatus s) => switch (s) {
  ListingStatus.approved => (AQTone.success, 'check'),
  ListingStatus.pendingVerification => (AQTone.pending, 'clock'),
  ListingStatus.draft => (AQTone.neutral, 'edit'),
  ListingStatus.resubmissionRequired => (AQTone.warning, 'alert'),
  ListingStatus.rejected => (AQTone.danger, 'close'),
  ListingStatus.hidden => (AQTone.neutral, 'eye-off'),
  ListingStatus.expired => (AQTone.warning, 'clock'),
  ListingStatus.paused => (AQTone.neutral, 'clock'),
  ListingStatus.withdrawn => (AQTone.neutral, 'close'),
  ListingStatus.sold => (AQTone.success, 'check'),
  ListingStatus.rented => (AQTone.success, 'check'),
};

class ListingStatusPill extends StatelessWidget {
  final ListingStatus status;
  final bool dense;
  const ListingStatusPill(this.status, {super.key, this.dense = true});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final (tone, icon) = _statusLook(status);
    return AQStatusPill(
      label: f.t('ls.st.${status.name}'),
      tone: tone,
      icon: icon,
      dense: dense,
    );
  }
}

String _typeLabel(FlowStrings f, PropertyType t) => f.t('ptype.${t.name}');
String _txLabel(FlowStrings f, TransactionType t) => f.t('ls.tx.${t.name}');

String _priceLabel(AgentListing l) {
  final suffix = l.transaction.pricePeriodSuffix;
  return suffix == null
      ? Money(l.priceOmr).formatted
      : '${Money(l.priceOmr).formatted} $suffix';
}

Widget _photo(ListingPhoto p, {BoxFit fit = BoxFit.cover}) {
  final bytes = p.bytes;
  if (bytes != null && bytes.isNotEmpty) {
    return Image.memory(
      Uint8List.fromList(bytes),
      fit: fit,
      gaplessPlayback: true,
    );
  }
  return aqImg(p.name, cacheWidth: 400);
}

/// The listing card extends the existing result card: photograph on the leading edge, then the
/// type line, title, place, facts and price. Status sits on its own line so it is easy to scan.
class AgentListingCard extends StatelessWidget {
  final AgentListing listing;
  final VoidCallback onOpen;
  final Widget? actions;
  const AgentListingCard({
    super.key,
    required this.listing,
    required this.onOpen,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final l = listing;
    final facts = [
      if (l.bedrooms != null)
        '${VFmt.n(context, l.bedrooms!)} ${f.t('disc.beds')}',
      if (l.bathrooms != null)
        '${VFmt.n(context, l.bathrooms!)} ${f.t('home.baths')}',
      '${VFmt.n(context, l.sizeSqm.round())} m²',
    ].join(' · ');
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          border: Border.all(color: c.hairline),
          borderRadius: BorderRadius.circular(AQRadius.medium),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.medium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                focusable: true,
                onFocus: () {},
                label:
                    '${l.title}, ${l.locationLabel}, ${f.t('ls.st.${l.status.name}')}, ${_priceLabel(l)}',
                excludeSemantics: true,
      onTap: onOpen,
                child: AQPressable(
                  onTap: onOpen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            l.photos.isEmpty
                                ? ColoredBox(color: c.surfaceSelected, child: Center(child: AQIcon('home', size: 32, color: c.inkFaint)))
                                : _photo(l.photos.first),
                            PositionedDirectional(start: AQSpacing.x3, bottom: AQSpacing.x3, end: AQSpacing.x3, child: Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x1, children: [
                              ListingStatusPill(l.status),
                              if (l.pendingChanges) AQStatusPill(label: f.t('ls.card.changes'), tone: AQTone.pending, icon: 'clock', dense: true),
                            ])),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AQSpacing.x4, AQSpacing.x3, AQSpacing.x4, AQSpacing.x3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_priceLabel(l), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.headlineSmall, color: c.accentDeep)),
                            const SizedBox(height: 2),
                            Text(VFmt.iso(l.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                            const SizedBox(height: AQSpacing.x1),
                            Row(children: [
                              AQIcon('pin', size: 14, color: c.accent),
                              const SizedBox(width: 4),
                              Flexible(child: Text(VFmt.iso(l.locationLabel), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                            ]),
                            const SizedBox(height: AQSpacing.x2),
                            Text('${_typeLabel(f, l.type)} · ${_txLabel(f, l.transaction)}  ·  $facts', maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (actions != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AQSpacing.x3,
                    0,
                    AQSpacing.x3,
                    AQSpacing.x2,
                  ),
                  child: actions!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ My listings

enum _Filter { all, live, review, changes, paused, closed }

bool _matches(_Filter f, ListingStatus s) => switch (f) {
  _Filter.all => true,
  _Filter.live => s == ListingStatus.approved,
  _Filter.review =>
    s == ListingStatus.pendingVerification || s == ListingStatus.draft,
  _Filter.changes => s == ListingStatus.resubmissionRequired,
  _Filter.paused => s == ListingStatus.paused,
  _Filter.closed => const {
    ListingStatus.rejected,
    ListingStatus.hidden,
    ListingStatus.expired,
    ListingStatus.withdrawn,
    ListingStatus.sold,
    ListingStatus.rented,
  }.contains(s),
};

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});
  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return AgentGuard(
      title: f.t('ls.title'),
      builder: (context) {
        final async = ref.watch(myListingsProvider);
        final all = async.valueOrNull ?? const <AgentListing>[];
        final shown = all.where((l) => _matches(_filter, l.status)).toList();
        Widget body;
        if (async.isLoading && !async.hasValue) {
          body = const Column(
            key: ValueKey('load'),
            children: [
              AQViewingSkeleton(height: 132),
              AQViewingSkeleton(height: 132),
            ],
          );
        } else if (async.hasError && !async.hasValue) {
          body = DbErrorCard(
            key: const ValueKey('err'),
            error: async.error,
            onRetry: () => ref.invalidate(myListingsProvider),
          );
        } else if (all.isEmpty) {
          body = AQEmptyViewingState(
            key: const ValueKey('empty'),
            title: f.t('ls.empty.t'),
            body: f.t('ls.empty.b'),
            action: AQPrimaryButton(
              label: f.t('ls.add'),
              leadingIcon: 'plus',
              trailingChevron: false,
              onPressed: () => context.push('/agent/listings/new'),
            ),
          );
        } else if (shown.isEmpty) {
          body = AQEmptyViewingState(
            key: const ValueKey('none'),
            title: f.t('ls.empty.filter.t'),
            body: f.t('ls.empty.filter.b'),
          );
        } else {
          body = Column(
            key: ValueKey('list-${_filter.name}-${shown.length}'),
            children: [
              for (final l in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  child: AgentListingCard(
                    listing: l,
                    onOpen: () => context.push('/agent/listings/${l.id}'),
                    actions: _rowActions(context, l),
                  ),
                ),
            ],
          );
        }
        return AQViewingScaffold(
          title: f.t('ls.title'),
          subtitle: f.t('ls.sub'),
          backLabel: f.t('common.back'),
          onBack: () => aqBack(context, '/app/home'),
          bottom: all.isEmpty && async.hasValue
              ? null
              : AQBottomActionBar(
                  primary: AQPrimaryButton(
                    label: f.t('ls.add'),
                    leadingIcon: 'plus',
                    trailingChevron: false,
                    onPressed: () => context.push('/agent/listings/new'),
                  ),
                ),
          children: [
            if (all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x4),
                child: DbPillRow(
                  scroll: true,
                  pills: [
                    for (final x in _Filter.values)
                      (
                        f.t('ls.f.${x.name}'),
                        _filter == x,
                        () => setState(() => _filter = x),
                      ),
                  ],
                ),
              ),
            AnimatedSwitcher(
              duration: AQMotion.scaled(context, AQMotion.fast),
              child: body,
            ),
          ],
        );
      },
    );
  }

  Widget? _rowActions(BuildContext context, AgentListing l) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final items = <Widget>[
      if (l.canEdit)
        AQTextButton(
          label: f.t('ls.d.edit'),
          color: c.accent,
          onPressed: () => context.push('/agent/listings/${l.id}/edit'),
        ),
      if (l.canPause)
        AQTextButton(
          label: f.t('ls.d.pause'),
          color: c.inkSoft,
          onPressed: () => context.push('/agent/listings/${l.id}'),
        ),
    ];
    if (items.isEmpty) return null;
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: items);
  }
}

// ------------------------------------------------------------------ Listing detail

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String id;

  /// `sent` after adding, `saved` after editing: a quiet confirmation of what actually happened.
  final String? flash;
  const ListingDetailScreen({super.key, required this.id, this.flash});
  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _busy = false;
  String? _doneKey, _errorKey;

  Future<void> _run(
    Future<AgentListing> Function(ListingRepository) op, {
    required String done,
    required String err,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _doneKey = null;
      _errorKey = null;
    });
    try {
      await op(ref.read(listingRepositoryProvider));
      ref.invalidate(myListingProvider(widget.id));
      ref.invalidate(myListingsProvider);
      if (mounted) setState(() => _doneKey = done);
    } on ListingStatusConflictException {
      ref.invalidate(myListingProvider(widget.id));
      if (mounted) setState(() => _errorKey = 'ls.conflict');
    } catch (_) {
      if (mounted) setState(() => _errorKey = err);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// True when the service has no pause / resume operation: nothing is attempted and nothing changes.
  bool _pauseUnsupported() {
    if (ref.read(listingRepositoryProvider).supportsPause) return false;
    setState(() {
      _doneKey = null;
      _errorKey = 'ls.pause.unsupported';
    });
    return true;
  }

  Future<void> _pause() async {
    if (_pauseUnsupported()) return;
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
                f.t('ls.pause.t'),
                style: AQTypography.of(s, AQText.headlineSmall),
              ),
            ),
            const SizedBox(height: AQSpacing.x2),
            Text(
              f.t('ls.pause.b'),
              style: AQTypography.of(s, AQText.bodyMedium, soft: true),
            ),
            const SizedBox(height: AQSpacing.x4),
            AQPrimaryButton(
              label: f.t('ls.pause.keep'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(false),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: f.t('ls.pause.yes'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(true),
            ),
          ],
        ),
      ),
    );
    if (yes == true) {
      await _run(
        (r) => r.pause(widget.id),
        done: 'ls.pause.done',
        err: 'ls.pause.err',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    void back() => aqBack(context, '/agent/listings');
    return AgentGuard(
      title: f.t('ls.d.title'),
      backFallback: '/agent/listings',
      builder: (context) {
        final async = ref.watch(myListingProvider(widget.id));
        return async.when(
          loading: () => AQViewingScaffold(
            title: f.t('ls.d.title'),
            backLabel: f.t('common.back'),
            onBack: back,
            children: const [
              AQViewingSkeleton(height: 200),
              AQViewingSkeleton(height: 160),
            ],
          ),
          error: (e, _) => AQViewingScaffold(
            title: f.t('ls.d.title'),
            backLabel: f.t('common.back'),
            onBack: back,
            bottom: e is PermissionDeniedException
                ? AQBottomActionBar(
                    primary: AQPrimaryButton(
                      label: f.t('ls.back'),
                      trailingChevron: false,
                      onPressed: back,
                    ),
                  )
                : null,
            children: [
              if (e is PermissionDeniedException)
                AQNoticeCard(
                  icon: 'lock',
                  title: f.t('ls.denied.t'),
                  body: f.t('ls.denied.b'),
                )
              else
                DbErrorCard(
                  error: e,
                  onRetry: () => ref.invalidate(myListingProvider(widget.id)),
                ),
            ],
          ),
          data: (l) {
            if (l == null) {
              return AQViewingScaffold(
                title: f.t('ls.d.title'),
                backLabel: f.t('common.back'),
                onBack: back,
                bottom: AQBottomActionBar(
                  primary: AQPrimaryButton(
                    label: f.t('ls.back'),
                    trailingChevron: false,
                    onPressed: back,
                  ),
                ),
                children: [
                  AQNoticeCard(
                    icon: 'info',
                    title: f.t('ls.notFound'),
                    body: '',
                  ),
                ],
              );
            }
            final (tone, icon) = _statusLook(l.status);
            Widget? primary, secondary;
            if (l.canEdit) {
              primary = AQPrimaryButton(
                label: l.status == ListingStatus.resubmissionRequired
                    ? f.t('ls.form.submitReturned')
                    : f.t('ls.d.edit'),
                leadingIcon: 'edit',
                trailingChevron: false,
                onPressed: () => context.push('/agent/listings/${l.id}/edit'),
              );
            } else if (l.canRenew) {
              primary = AQPrimaryButton(
                label: f.t('ls.d.renew'),
                leadingIcon: 'refresh',
                trailingChevron: false,
                loading: _busy,
                onPressed: _busy
                    ? null
                    : () => _run(
                        (r) => r.renew(l.id),
                        done: 'ls.renew.done',
                        err: 'ls.renew.err',
                      ),
              );
            }
            if (l.canPause) {
              final b = AQBarSecondaryButton(
                label: f.t('ls.d.pause'),
                onPressed: _busy ? null : _pause,
              );
              if (primary == null) {
                primary = b;
              } else {
                secondary = b;
              }
            } else if (l.canResume) {
              final b = AQBarSecondaryButton(
                label: f.t('ls.d.resume'),
                leadingIcon: 'refresh',
                onPressed: _busy
                    ? null
                    : () => _pauseUnsupported()
                          ? null
                          : _run(
                              (r) => r.resume(l.id),
                              done: 'ls.resume.done',
                              err: 'ls.resume.err',
                            ),
              );
              if (primary == null) {
                primary = b;
              } else {
                secondary = b;
              }
            }
            final attrs = attributesFor(l.type);
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
            return AQViewingScaffold(
              title: VFmt.iso(l.title),
              subtitle: _priceLabel(l),
              backLabel: f.t('common.back'),
              onBack: back,
              bottom: primary == null
                  ? null
                  : AQBottomActionBar(primary: primary, secondary: secondary),
              children: [
                // A one-time message from the page that sent you here. It only shows while the listing
                // is still in the state it describes, so it never contradicts the status below.
                if (widget.flash == 'sent' &&
                    _doneKey == null &&
                    l.status == ListingStatus.pendingVerification)
                  AQErrorBanner(
                    tone: AQBannerTone.success,
                    text: '${f.t('ls.sent.t')}. ${f.t('ls.sent.b')}',
                  ),
                if (widget.flash == 'saved-live' &&
                    _doneKey == null &&
                    l.status == ListingStatus.approved)
                  AQErrorBanner(
                    tone: AQBannerTone.success,
                    text: '${f.t('ls.saved.t')}. ${f.t('ls.saved.live')}',
                  ),
                if (widget.flash == 'saved-review' &&
                    _doneKey == null &&
                    (l.status == ListingStatus.pendingVerification ||
                        l.status == ListingStatus.approved))
                  AQErrorBanner(
                    tone: AQBannerTone.success,
                    text: '${f.t('ls.saved.t')}. ${f.t('ls.saved.review')}',
                  ),
                if (_doneKey != null)
                  AQErrorBanner(
                    tone: AQBannerTone.success,
                    text: f.t(_doneKey!),
                  ),
                if (_errorKey != null) AQErrorBanner(text: f.t(_errorKey!)),
                const SizedBox(height: AQSpacing.x2),
                AQNoticeCard(
                  icon: icon,
                  title: f.t('ls.st.${l.status.name}'),
                  body: f.t('ls.exp.${l.status.name}'),
                  tone: tone,
                ),
                if (l.pendingChanges) ...[
                  const SizedBox(height: AQSpacing.x3),
                  DbNotice(f.t('ls.exp.pending'), icon: 'clock'),
                ],
                if (l.feedback != null && l.feedback!.isNotEmpty) ...[
                  AQViewingSectionTitle(f.t('ls.d.feedback')),
                  AQSurface(
                    padding: const EdgeInsets.all(AQSpacing.x4),
                    child: Text(
                      l.feedback!,
                      style: AQTypography.of(context, AQText.bodyMedium),
                    ),
                  ),
                ],
                AQViewingSectionTitle(f.t('ls.d.photos')),
                if (l.photos.isEmpty)
                  DbNotice(f.t('ls.d.noPhotos'), icon: 'info')
                else
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: l.photos.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AQSpacing.x2),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(AQRadius.medium),
                        child: SizedBox(width: 160, child: _photo(l.photos[i])),
                      ),
                    ),
                  ),
                AQViewingSectionTitle(f.t('ls.d.facts')),
                AQSurface(
                  padding: const EdgeInsets.all(AQSpacing.x4),
                  child: Column(
                    children: [
                      row(
                        f.t('ls.d.type'),
                        '${_typeLabel(f, l.type)} · ${_txLabel(f, l.transaction)}',
                      ),
                      row(
                        f.t('ls.d.market'),
                        f.t('ls.market.${l.market.name}'),
                      ),
                      row(f.t('ls.d.location'), VFmt.iso(l.locationLabel)),
                      row(
                        f.t('ls.d.size'),
                        '${VFmt.n(context, l.sizeSqm.round())} m²',
                      ),
                      if (attrs.bedrooms && l.bedrooms != null)
                        row(f.t('ls.d.beds'), VFmt.n(context, l.bedrooms!)),
                      if (attrs.bathrooms && l.bathrooms != null)
                        row(f.t('ls.d.baths'), VFmt.n(context, l.bathrooms!)),
                      if (attrs.parking && l.parking != null)
                        row(f.t('ls.d.parking'), VFmt.n(context, l.parking!)),
                      row(f.t('ls.d.deed'), VFmt.iso(l.titleDeed)),
                    ],
                  ),
                ),
                if (l.description.isNotEmpty) ...[
                  AQViewingSectionTitle(f.t('ls.d.desc')),
                  Text(
                    l.description,
                    style: AQTypography.of(
                      context,
                      AQText.bodyMedium,
                      color: c.ink,
                    ),
                  ),
                ],
                if (kShowReviewTools) _QaReview(id: l.id),
                const SizedBox(height: AQSpacing.x4),
                const AQDemoNotice(),
              ],
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Add / edit form

class ListingFormScreen extends ConsumerStatefulWidget {
  /// Null when adding a listing.
  final String? editId;
  const ListingFormScreen({super.key, this.editId});
  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _area = TextEditingController();
  final _size = TextEditingController();
  final _beds = TextEditingController();
  final _baths = TextEditingController();
  final _parking = TextEditingController();
  final _price = TextEditingController();
  final _deed = TextEditingController();
  PropertyMarket? _market;
  PropertyType? _type;
  TransactionType? _tx;
  String? _gov, _wilayat;
  final List<ListingPhoto> _kept = [];
  final List<ListingPhoto> _added = [];
  bool _tried = false,
      _saving = false,
      _dirty = false,
      _loaded = false,
      _addingPhoto = false;
  String? _errorKey, _photoErrorKey;
  AgentListing? _existing;

  bool get _editing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _title,
      _desc,
      _area,
      _size,
      _beds,
      _baths,
      _parking,
      _price,
      _deed,
    ]) {
      c.addListener(() => _dirty = true);
    }
    if (!_editing) _loaded = true;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _desc,
      _area,
      _size,
      _beds,
      _baths,
      _parking,
      _price,
      _deed,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(AgentListing l) {
    _existing = l;
    _market = l.market;
    _type = l.type;
    _tx = l.transaction;
    _gov = l.governorate;
    _wilayat = l.wilayat;
    _title.text = l.title;
    _desc.text = l.description;
    _area.text = l.area;
    _size.text = l.sizeSqm == l.sizeSqm.roundToDouble()
        ? l.sizeSqm.toInt().toString()
        : l.sizeSqm.toString();
    _beds.text = l.bedrooms?.toString() ?? '';
    _baths.text = l.bathrooms?.toString() ?? '';
    _parking.text = l.parking?.toString() ?? '';
    _price.text = l.priceOmr == l.priceOmr.roundToDouble()
        ? l.priceOmr.toInt().toString()
        : l.priceOmr.toString();
    _deed.text = l.titleDeed;
    _kept
      ..clear()
      ..addAll(l.photos);
    _loaded = true;
    _dirty = false;
  }

  // ---- validation
  double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
  int? _count(String s) =>
      RegExp(r'^\d{1,3}$').hasMatch(s.trim()) ? int.parse(s.trim()) : null;

  String? get _eTitle => _title.text.trim().isEmpty ? 'ls.err.title' : null;
  String? get _eDesc => _desc.text.trim().isEmpty ? 'ls.err.desc' : null;
  String? get _eType => _type == null ? 'ls.err.type' : null;
  String? get _eTx => _tx == null ? 'ls.err.tx' : null;
  String? get _eGov => _gov == null ? 'ls.err.gov' : null;
  String? get _eWilayat => _wilayat == null ? 'ls.err.wilayat' : null;
  String? get _eSize => (_num(_size.text) ?? 0) > 0 ? null : 'ls.err.size';
  String? get _ePrice {
    final raw = _price.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null || v <= 0) return 'ls.err.price';
    final dot = raw.indexOf('.');
    if (dot >= 0 && raw.length - dot - 1 > 3) return 'ls.err.price';
    return null;
  }

  String? get _eDeed => deedValid(_deed.text) ? null : 'ls.err.deed';
  String? _eCount(TextEditingController c) =>
      c.text.trim().isEmpty || _count(c.text) != null ? null : 'ls.err.count';

  bool get _valid {
    final a = _type == null ? const ListingAttributes() : attributesFor(_type!);
    return _eTitle == null &&
        _eDesc == null &&
        _eType == null &&
        _eTx == null &&
        _eGov == null &&
        _eWilayat == null &&
        _eSize == null &&
        _ePrice == null &&
        _eDeed == null &&
        (!a.bedrooms || _eCount(_beds) == null) &&
        (!a.bathrooms || _eCount(_baths) == null) &&
        (!a.parking || _eCount(_parking) == null);
  }

  // ---- photos
  Future<void> _addPhoto() async {
    if (_addingPhoto) return;
    setState(() {
      _addingPhoto = true;
      _photoErrorKey = null;
    });
    try {
      final file = await ref.read(documentPickerProvider).pick();
      if (file == null) return;
      final b = file.bytes;
      final isImage =
          b.length >= 3 &&
          ((b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) ||
              (b.length >= 4 &&
                  b[0] == 0x89 &&
                  b[1] == 0x50 &&
                  b[2] == 0x4E &&
                  b[3] == 0x47));
      if (file.sizeBytes > kMaxDocumentBytes) {
        setState(() => _photoErrorKey = 'ls.ph.err.size');
      } else if (!isImage) {
        setState(() => _photoErrorKey = 'ls.ph.err.type');
      } else {
        setState(() {
          _added.add(
            ListingPhoto(
              id: 'new${_added.length}-${file.name}',
              name: file.name,
              bytes: b,
            ),
          );
          _dirty = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _photoErrorKey = 'ls.ph.err.pick');
    } finally {
      if (mounted) setState(() => _addingPhoto = false);
    }
  }

  // ---- pickers
  Future<void> _pickMarket(FlowStrings f) async {
    final r = await showDbChoiceSheet<PropertyMarket>(
      context,
      title: f.t('ls.fl.market'),
      options: [
        for (final m in PropertyMarket.values) (m, f.t('ls.market.${m.name}')),
      ],
      selected: _market,
    );
    if (r == null) return;
    setState(() {
      if (_market != r) _type = null;
      _market = r;
      _dirty = true;
    });
  }

  Future<void> _pickType(FlowStrings f) async {
    final m = _market;
    if (m == null) return;
    final r = await showDbChoiceSheet<PropertyType>(
      context,
      title: f.t('ls.fl.type'),
      options: [for (final t in kMarketTypes[m]!) (t, _typeLabel(f, t))],
      selected: _type,
    );
    if (r != null) {
      setState(() {
        _type = r;
        _dirty = true;
      });
    }
  }

  Future<void> _pickGov(FlowStrings f) async {
    final r = await showDbChoiceSheet<String>(
      context,
      title: f.t('ls.fl.gov'),
      options: [for (final g in omanGovernorates.keys) (g, g)],
      selected: _gov,
    );
    if (r != null) {
      setState(() {
        if (_gov != r) _wilayat = null;
        _gov = r;
        _dirty = true;
      });
    }
  }

  Future<void> _pickWilayat(FlowStrings f) async {
    final g = _gov;
    if (g == null) return;
    final r = await showDbChoiceSheet<String>(
      context,
      title: f.t('ls.fl.wilayat'),
      options: [for (final w in omanGovernorates[g]!) (w, w)],
      selected: _wilayat,
    );
    if (r != null) {
      setState(() {
        _wilayat = r;
        _dirty = true;
      });
    }
  }

  // ---- submit
  Future<void> _submit() async {
    setState(() => _tried = true);
    if (!_valid || _saving) return;
    FocusScope.of(context).unfocus();
    final a = attributesFor(_type!);
    final input = ListingInput(
      title: _title.text,
      description: _desc.text,
      type: _type!,
      transaction: _tx!,
      priceOmr: _num(_price.text)!,
      governorate: _gov!,
      wilayat: _wilayat!,
      area: _area.text,
      sizeSqm: _num(_size.text)!,
      bedrooms: a.bedrooms ? _count(_beds.text) : null,
      bathrooms: a.bathrooms ? _count(_baths.text) : null,
      parking: a.parking ? _count(_parking.text) : null,
      titleDeed: _deed.text,
      keepPhotoIds: [for (final p in _kept) p.id],
      newPhotos: _added,
    );
    setState(() {
      _saving = true;
      _errorKey = null;
    });
    try {
      final repo = ref.read(listingRepositoryProvider);
      final saved = _editing
          ? await repo.update(widget.editId!, input)
          : await repo.create(input);
      ref.invalidate(myListingsProvider);
      if (_editing) ref.invalidate(myListingProvider(widget.editId!));
      AQHaptics.success();
      _dirty = false;
      if (!mounted) return;
      final flash = !_editing
          ? 'sent'
          : (saved.pendingChanges ? 'saved-live' : 'saved-review');
      if (_editing) {
        final router = GoRouter.of(context);
        router.pop();
        router.pushReplacement('/agent/listings/${saved.id}?flash=$flash');
      } else {
        context.pushReplacement('/agent/listings/${saved.id}?flash=$flash');
      }
    } on DuplicateListingException {
      if (mounted) setState(() => _errorKey = 'ls.form.dup');
    } on ListingPhotoUploadException {
      if (mounted) setState(() => _errorKey = 'ls.form.photoFail');
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'ls.form.error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmLeave(FlowStrings f) async {
    if (!_dirty || _saving) return true;
    final leave = await showAQSheet<bool>(
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
                f.t('ls.leave.t'),
                style: AQTypography.of(s, AQText.headlineSmall),
              ),
            ),
            const SizedBox(height: AQSpacing.x2),
            Text(
              f.t('ls.leave.b'),
              style: AQTypography.of(s, AQText.bodyMedium, soft: true),
            ),
            const SizedBox(height: AQSpacing.x4),
            AQPrimaryButton(
              label: f.t('ls.leave.stay'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(false),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: f.t('ls.leave.yes'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(true),
            ),
          ],
        ),
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final fallback = _editing
        ? '/agent/listings/${widget.editId}'
        : '/agent/listings';
    Future<void> back() async {
      final leave = await _confirmLeave(f);
      if (!leave || !context.mounted) return;
      aqBack(context, fallback);
    }

    return AgentGuard(
      title: _editing ? f.t('ls.form.edit') : f.t('ls.form.add'),
      backFallback: fallback,
      builder: (context) {
        if (_editing && !_loaded) {
          final async = ref.watch(myListingProvider(widget.editId!));
          return async.when(
            loading: () => AQViewingScaffold(
              title: f.t('ls.form.edit'),
              backLabel: f.t('common.back'),
              onBack: back,
              children: const [
                AQViewingSkeleton(height: 120),
                AQViewingSkeleton(height: 200),
              ],
            ),
            error: (e, _) => AQViewingScaffold(
              title: f.t('ls.form.edit'),
              backLabel: f.t('common.back'),
              onBack: back,
              children: [
                if (e is PermissionDeniedException)
                  AQNoticeCard(
                    icon: 'lock',
                    title: f.t('ls.denied.t'),
                    body: f.t('ls.denied.b'),
                  )
                else
                  DbErrorCard(
                    error: e,
                    onRetry: () =>
                        ref.invalidate(myListingProvider(widget.editId!)),
                  ),
              ],
            ),
            data: (l) {
              if (l == null || !l.canEdit) {
                return AQViewingScaffold(
                  title: f.t('ls.form.edit'),
                  backLabel: f.t('common.back'),
                  onBack: back,
                  children: [
                    AQNoticeCard(
                      icon: 'info',
                      title: l == null
                          ? f.t('ls.notFound')
                          : f.t('ls.conflict'),
                      body: '',
                    ),
                  ],
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_loaded) setState(() => _prefill(l));
              });
              return AQViewingScaffold(
                title: f.t('ls.form.edit'),
                backLabel: f.t('common.back'),
                onBack: back,
                children: const [
                  AQViewingSkeleton(height: 120),
                  AQViewingSkeleton(height: 200),
                ],
              );
            },
          );
        }

        final a = _type == null
            ? const ListingAttributes()
            : attributesFor(_type!);
        final anyFacts = a.bedrooms || a.bathrooms || a.parking;
        String? err(String? k) => _tried ? k : null;
        final returned =
            _existing?.status == ListingStatus.resubmissionRequired;
        final live =
            _existing != null &&
            (_existing!.status == ListingStatus.approved ||
                _existing!.status == ListingStatus.paused);

        Widget gap() => const SizedBox(height: AQSpacing.x4);
        Widget numberField(
          TextEditingController ctl,
          String label, {
          bool decimal = false,
        }) => AQTextField(
          label: label,
          controller: ctl,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          formatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
            LengthLimitingTextInputFormatter(decimal ? 14 : 3),
          ],
          error: err(decimal ? null : _eCount(ctl)) == null
              ? null
              : f.t(_eCount(ctl)!),
          onChanged: (_) => setState(() {}),
        );

        return PopScope(
          canPop: !_dirty || _saving,
          onPopInvokedWithResult: (didPop, _) async {
            if (!didPop) await back();
          },
          child: AQViewingScaffold(
            title: _editing ? f.t('ls.form.edit') : f.t('ls.form.add'),
            subtitle: _editing ? f.t('ls.form.editSub') : f.t('ls.form.addSub'),
            backLabel: f.t('common.back'),
            onBack: back,
            bottom: AQBottomActionBar(
              primary: AQPrimaryButton(
                label: !_editing
                    ? f.t('ls.form.submitAdd')
                    : (returned
                          ? f.t('ls.form.submitReturned')
                          : f.t('ls.form.submitEdit')),
                trailingChevron: false,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ),
            children: [
              if (live) DbNotice(f.t('ls.saved.live'), icon: 'info'),
              AQViewingSectionTitle(f.t('ls.fs.property')),
              DbSelectField<PropertyMarket>(
                label: f.t('ls.fl.market'),
                valueLabel: _market == null
                    ? null
                    : f.t('ls.market.${_market!.name}'),
                hint: f.t('ls.fl.market'),
                required: true,
                error: err(_market == null ? 'ls.err.market' : null),
                onTap: () => _pickMarket(f),
              ),
              gap(),
              DbSelectField<PropertyType>(
                label: f.t('ls.fl.type'),
                valueLabel: _type == null ? null : _typeLabel(f, _type!),
                hint: f.t('ls.fl.type'),
                required: true,
                error: err(_eType),
                onTap: _market == null ? null : () => _pickType(f),
              ),
              gap(),
              DbFieldFrame(
                label: f.t('ls.fl.tx'),
                required: true,
                error: err(_eTx),
                child: DbPillRow(
                  pills: [
                    for (final t in TransactionType.values)
                      (
                        _txLabel(f, t),
                        _tx == t,
                        () => setState(() {
                          _tx = t;
                          _dirty = true;
                        }),
                      ),
                  ],
                ),
              ),
              AQViewingSectionTitle(f.t('ls.fs.details')),
              AQTextField(
                label: f.t('ls.fl.title'),
                controller: _title,
                hint: f.t('ls.fl.title.hint'),
                error: err(_eTitle) == null ? null : f.t(_eTitle!),
                formatters: [LengthLimitingTextInputFormatter(120)],
                onChanged: (_) => setState(() {}),
              ),
              gap(),
              AQTextField(
                label: f.t('ls.fl.desc'),
                controller: _desc,
                hint: f.t('ls.fl.desc.hint'),
                minLines: 3,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                action: TextInputAction.newline,
                error: err(_eDesc) == null ? null : f.t(_eDesc!),
                formatters: [LengthLimitingTextInputFormatter(2000)],
                onChanged: (_) => setState(() {}),
              ),
              AQViewingSectionTitle(f.t('ls.fs.location')),
              DbSelectField<String>(
                label: f.t('ls.fl.gov'),
                valueLabel: _gov,
                hint: f.t('ls.fl.gov'),
                required: true,
                error: err(_eGov),
                onTap: () => _pickGov(f),
              ),
              gap(),
              DbSelectField<String>(
                label: f.t('ls.fl.wilayat'),
                valueLabel: _wilayat,
                hint: f.t('ls.fl.wilayat'),
                required: true,
                error: err(_eWilayat),
                onTap: _gov == null ? null : () => _pickWilayat(f),
              ),
              gap(),
              AQTextField(
                label: f.t('ls.fl.area'),
                controller: _area,
                formatters: [LengthLimitingTextInputFormatter(80)],
              ),
              AQViewingSectionTitle(f.t('ls.fs.facts')),
              AQTextField(
                label: f.t('ls.fl.size'),
                controller: _size,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                error: err(_eSize) == null ? null : f.t(_eSize!),
                onChanged: (_) => setState(() {}),
              ),
              AnimatedSize(
                duration: AQMotion.scaled(context, AQMotion.fast),
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_type != null && !anyFacts)
                      Padding(
                        padding: const EdgeInsets.only(top: AQSpacing.x3),
                        child: DbNotice(f.t('ls.fl.noFacts'), icon: 'info'),
                      ),
                    if (a.bedrooms) ...[
                      gap(),
                      numberField(_beds, f.t('ls.fl.beds')),
                    ],
                    if (a.bathrooms) ...[
                      gap(),
                      numberField(_baths, f.t('ls.fl.baths')),
                    ],
                    if (a.parking) ...[
                      gap(),
                      numberField(_parking, f.t('ls.fl.parking')),
                    ],
                  ],
                ),
              ),
              AQViewingSectionTitle(f.t('ls.fs.price')),
              AQTextField(
                label: f.t('ls.fl.price'),
                controller: _price,
                hint: f.t('ls.fl.price.hint'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(14),
                ],
                error: err(_ePrice) == null ? null : f.t(_ePrice!),
                onChanged: (_) => setState(() {}),
              ),
              AQViewingSectionTitle(f.t('ls.fs.deed')),
              AQTextField(
                label: f.t('ls.fl.deed'),
                controller: _deed,
                hint: f.t('ls.fl.deed.hint'),
                helper: f.t('ls.fl.deed.note'),
                formatters: [LengthLimitingTextInputFormatter(24)],
                error: err(_eDeed) == null ? null : f.t(_eDeed!),
                onChanged: (_) => setState(() {}),
              ),
              AQViewingSectionTitle(f.t('ls.fs.photos')),
              if (_kept.isEmpty && _added.isEmpty)
                Text(
                  f.t('ls.ph.none'),
                  style: AQTypography.of(context, AQText.bodySmall, soft: true),
                )
              else
                Wrap(
                  spacing: AQSpacing.x2,
                  runSpacing: AQSpacing.x2,
                  children: [
                    for (var i = 0; i < _kept.length + _added.length; i++)
                      _PhotoTile(
                        photo: i < _kept.length
                            ? _kept[i]
                            : _added[i - _kept.length],
                        label: f.t('ls.ph.remove', {
                          'n': VFmt.n(context, i + 1),
                        }),
                        onRemove: () => setState(() {
                          _dirty = true;
                          if (i < _kept.length) {
                            _kept.removeAt(i);
                          } else {
                            _added.removeAt(i - _kept.length);
                          }
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: AQSpacing.x3),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AQSecondaryButton(
                  label: f.t('ls.ph.add'),
                  leadingIcon: 'plus',
                  trailingChevron: false,
                  loading: _addingPhoto,
                  onPressed: _addingPhoto ? null : _addPhoto,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AQSpacing.x2),
                child: Text(
                  f.t('ls.ph.hint'),
                  style: AQTypography.of(
                    context,
                    AQText.bodySmall,
                    color: c.inkFaint,
                  ),
                ),
              ),
              if (_photoErrorKey != null)
                Padding(
                  padding: const EdgeInsets.only(top: AQSpacing.x2),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      f.t(_photoErrorKey!),
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        color: c.danger,
                      ),
                    ),
                  ),
                ),
              if (_errorKey != null)
                Padding(
                  padding: const EdgeInsets.only(top: AQSpacing.x4),
                  child: AQErrorBanner(text: f.t(_errorKey!)),
                ),
              const SizedBox(height: AQSpacing.x4),
              const AQDemoNotice(),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final ListingPhoto photo;
  final String label;
  final VoidCallback onRemove;
  const _PhotoTile({
    required this.photo,
    required this.label,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AQRadius.medium),
              child: _photo(photo),
            ),
          ),
          PositionedDirectional(
            top: 2,
            end: 2,
            child: Semantics(
              button: true,
              focusable: true,
              onFocus: () {},
              label: label,
              excludeSemantics: true,
      onTap: onRemove,
              child: AQPressable(
                onTap: onRemove,
                child: SizedBox(
                  width: AQControl.tap,
                  height: AQControl.tap,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c.surfaceRaised.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AQIcon('close', size: 14, color: c.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// QA only (`--dart-define=REVIEW_TOOLS=true`): stands in for the reviewer, whose decision the
/// service owns, so every listing state can be reached and looked at. Never in a production build.
class _QaReview extends ConsumerWidget {
  final String id;
  const _QaReview({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(listingRepositoryProvider);
    if (repo is! DemoListingRepository) return const SizedBox.shrink();
    void decide(ListingStatus s, {String? feedback}) {
      repo.debugSet(id, s, feedback: feedback);
      ref.invalidate(myListingProvider(id));
      ref.invalidate(myListingsProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x4),
      child: AQSurface(
        padding: const EdgeInsets.all(AQSpacing.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'QA only: simulate the reviewer',
              style: AQTypography.of(context, AQText.labelMedium, soft: true),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: 'Reviewer approves',
              trailingChevron: false,
              onPressed: () => decide(ListingStatus.approved),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: 'Reviewer asks for changes',
              trailingChevron: false,
              onPressed: () => decide(
                ListingStatus.resubmissionRequired,
                feedback: 'Sample feedback: the photos are too dark.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
