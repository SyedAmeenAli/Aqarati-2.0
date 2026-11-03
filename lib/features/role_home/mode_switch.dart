import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/localization/flow_strings.dart';
import '../../core/domain/account_models.dart' show MeSession;
import '../../data/api/account_api.dart' show meProvider;
import '../viewing/screens/viewing_kit.dart' show AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'role_home_model.dart';

/// The one way to move between Shop (the customer app) and Work (the agent or business workspace).
/// The capsule, the "View as a customer" rows, `/shop` and `/work` all call these, so the choice is
/// kept the same way everywhere and nothing is created or reset: it is the same signed-in account.
Future<HomeResolution> _resolution(WidgetRef ref) async {
  // Wait for the session so the choice is made on what the account really is, not on a half-loaded read.
  final me = await ref.read(meProvider.future).then<MeSession?>((m) => m).catchError((_) => null);
  return resolveHome(me, chosen: ref.read(homeWorkspaceProvider));
}

Future<void> switchToShop(BuildContext context, WidgetRef ref) async {
  final res = await _resolution(ref);
  if (!context.mounted) return;
  if (res.canSwitch) {
    ref.read(homeWorkspaceProvider.notifier).state = HomeWorkspace.buyer;
    context.go('/app/home');
  } else if (res.isProfessionalCompany) {
    // A business account browses the marketplace from Explore; its Home tab leads back to its workspace.
    context.go('/app/explore');
  } else {
    context.go('/app/home');
  }
}

Future<void> switchToWork(BuildContext context, WidgetRef ref) async {
  final res = await _resolution(ref);
  if (!context.mounted) return;
  if (res.canSwitch) {
    ref.read(homeWorkspaceProvider.notifier).state = HomeWorkspace.agent;
    context.go('/agent');
  } else if (res.isProfessionalCompany) {
    context.go('/pro');
  } else {
    context.go('/work');
  }
}

/// Whether the signed-in account has a Work side at all (an approved agent or business).
bool hasWorkSide(HomeResolution r) => r.canSwitch || r.isProfessionalCompany;

/// What a person without access sees instead of a dead end: the reason, and the next real step.
/// A guest is sent to sign in with the destination remembered; a shopper is offered professional
/// registration; an application still in review shows its real status.
class WorkspaceAccessNotice extends ConsumerWidget {
  final String title;

  /// The path to return to after signing in (for example `/work`).
  final String next;
  final bool agent;
  const WorkspaceAccessNotice({super.key, required this.title, required this.next, this.agent = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    if (me.isLoading && !me.hasValue) {
      return AQViewingScaffold(title: title, backLabel: f.t('common.back'), onBack: () => context.go('/app/home'), children: const [AQViewingSkeleton(height: 96)]);
    }
    final res = resolveHome(me.valueOrNull);
    final guest = me.valueOrNull == null;
    final pending = res.hasPendingApplication;
    final (t, b) = guest
        ? (f.t('wa.guest.t'), f.t('wa.guest.b'))
        : pending
            ? (f.t('rh.banner.title'), f.t('rh.banner.body'))
            : (f.t('pn.noAccess.t'), f.t('pn.noAccess.b'));
    final primary = guest
        ? AQPrimaryButton(label: f.t('wa.signin'), trailingChevron: false, onPressed: () => context.go('/login?as=${agent ? 'agent' : 'user'}&next=${Uri.encodeComponent(next)}'))
        : pending
            ? AQPrimaryButton(label: f.t('home.viewStatus'), trailingChevron: false, onPressed: () => context.go('/verification'))
            : AQPrimaryButton(label: f.t('biz.cta'), trailingChevron: false, onPressed: () => context.push('/signup/business'));
    return AQViewingScaffold(
      title: title,
      backLabel: f.t('common.back'),
      onBack: () => context.go('/app/home'),
      bottom: AQBottomActionBar(
        primary: primary,
        secondary: AQSecondaryButton(label: f.t('wa.shop'), trailingChevron: false, onPressed: () => context.go('/app/home')),
      ),
      children: [
        AQNoticeCard(icon: pending ? 'clock' : 'lock', title: t, body: b),
        // A signed-out person may not have a business account yet: registering is one tap away.
        if (guest) Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: AQTextButton(label: f.t('biz.cta'), color: AQColors.of(context).accentDeep, onPressed: () => context.push('/signup/business'))),
      ],
    );
  }
}

/// `/shop`: the customer app. Signed in goes straight to it; signed out signs in first, then arrives here.
class ShopGate extends ConsumerStatefulWidget {
  const ShopGate({super.key});
  @override
  ConsumerState<ShopGate> createState() => _ShopGateState();
}

class _ShopGateState extends ConsumerState<ShopGate> {
  bool _sent = false;
  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    if (!_sent && !(me.isLoading && !me.hasValue)) {
      _sent = true;
      final guest = me.valueOrNull == null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (guest) {
          context.go('/login?as=user&next=${Uri.encodeComponent('/app/home')}');
        } else {
          switchToShop(context, ref);
        }
      });
    }
    return const SizedBox.shrink();
  }
}

/// `/work`: the agent or business workspace. Eligible accounts open it; everyone else gets a real next step.
class WorkGate extends ConsumerStatefulWidget {
  const WorkGate({super.key});
  @override
  ConsumerState<WorkGate> createState() => _WorkGateState();
}

class _WorkGateState extends ConsumerState<WorkGate> {
  bool _sent = false;
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    if (me.isLoading && !me.hasValue) return const SizedBox.shrink();
    final res = resolveHome(me.valueOrNull);
    final guest = me.valueOrNull == null;
    if (guest) {
      if (!_sent) {
        _sent = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/login?as=agent&next=${Uri.encodeComponent('/work')}');
        });
      }
      return const SizedBox.shrink();
    }
    if (hasWorkSide(res)) {
      if (!_sent) {
        _sent = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) switchToWork(context, ref);
        });
      }
      return const SizedBox.shrink();
    }
    return WorkspaceAccessNotice(title: f.t('wa.work.t'), next: '/work', agent: true);
  }
}
