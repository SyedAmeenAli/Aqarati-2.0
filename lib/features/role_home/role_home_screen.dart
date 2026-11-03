import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_tokens.dart';
import '../../data/api/account_api.dart' show meProvider;
import '../devbuild/db_widgets.dart' show DbSkeleton;
import '../workspace/aq_home.dart' show AQHomeScreen;
import 'mode_switch.dart';
import 'role_home_model.dart';
import 'role_home_widgets.dart';

/// The Home tab. Resolves the signed-in session into one of six homes from the real grant.
/// Everything that is not an approved role (guests, buyers, drafts, pending, rejected,
/// suspended) gets the buyer home; a business or agent application that is not approved adds a
/// status banner that links to the real verification screens.
class _GoToWorkspace extends StatefulWidget {
  final String path;
  const _GoToWorkspace(this.path);
  @override
  State<_GoToWorkspace> createState() => _GoToWorkspaceState();
}

class _GoToWorkspaceState extends State<_GoToWorkspace> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.path);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class RoleHomeScreen extends ConsumerWidget {
  const RoleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(homeResolutionProvider);
    // Until the session is known, show a quiet placeholder instead of a buyer page that would
    // flash and then be replaced by a role home. A failed lookup (guest) resolves to the buyer home.
    final me = ref.watch(meProvider);
    if (me.isLoading && !me.hasValue && !me.hasError) {
      return const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x6, AQSpacing.gutter, 0),
          child: Column(children: [DbSkeleton(height: 56), SizedBox(height: AQSpacing.x4), DbSkeleton(height: 220), SizedBox(height: AQSpacing.x4), DbSkeleton(height: 120)]),
        ),
      );
    }
    final Widget home = switch (r.role) {
      HomeRole.buyer => AQHomeScreen(topSlot: _buyerTop(ref, r), modeSwitch: r.canSwitch ? Builder(builder: (context) => RoleWorkspaceSwitcher(selected: HomeWorkspace.buyer, onChanged: (w) => w == HomeWorkspace.agent ? switchToWork(context, ref) : null)) : null),
      // An approved agent works in the agent workspace, which has its own navigation.
      HomeRole.agent => const _GoToWorkspace('/agent'),
      // Business accounts work in their own workspace, which has its own navigation.
      HomeRole.developer ||
      HomeRole.construction ||
      HomeRole.architecture ||
      HomeRole.interiorExterior => const _GoToWorkspace('/pro'),
    };
    // Role changes: a short fade with a small rise, then the new home. Reduced motion removes the rise.
    final reduced = AQMotion.reduced(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : AQMotion.state,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: reduced ? child : AnimatedBuilder(animation: animation, child: child, builder: (context, c) => Transform.translate(offset: Offset(0, 8 * (1 - animation.value)), child: c)),
      ),
      child: KeyedSubtree(key: ValueKey(r.role), child: home),
    );
  }

  Widget? _buyerTop(WidgetRef ref, HomeResolution r) {
    if (r.canSwitch) return null;
    if (r.hasPendingApplication) {
      return Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: RoleReveal(child: RoleStatusBanner(grant: r.pendingGrant!, stage: r.pendingStage)));
    }
    return null;
  }
}
