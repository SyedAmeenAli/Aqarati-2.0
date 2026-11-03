import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_auth_scaffold.dart';
import '../../../core/aq/aq_forms.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/localization/entry_strings.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../data/api/account_api.dart';
import '../../entry/models/signup_purpose.dart';

/// Role display name from the sign-up taxonomy.
String roleTitle(BuildContext context, SignupPurpose p) => signupPurposeOptions.firstWhere((o) => o.id == p).title(EntryStrings.of(context));

/// Skeleton-style loading frame (no full-screen spinner): quiet bars where content will be.
class AQSkeleton extends StatelessWidget {
  const AQSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    Widget bar(double w, double h) => Container(width: w, height: h, margin: const EdgeInsets.only(bottom: AQSpacing.x3), decoration: BoxDecoration(color: c.hairline, borderRadius: BorderRadius.circular(AQRadius.small)));
    return Semantics(label: FlowStrings.of(context).t('common.loading'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(120, 28), bar(double.infinity, 16), bar(220, 16), const SizedBox(height: AQSpacing.x4), bar(double.infinity, 72), bar(double.infinity, 72)]));
  }
}

/// Loading / error frames shared by verification screens.
Widget aqLoadingFrame(BuildContext context, {String? title}) => AQAuthScaffold(showLogo: false, title: title ?? ' ', showBack: false, children: const [AQSkeleton()]);

Widget aqErrorFrame(BuildContext context, WidgetRef ref, {required String title, required VoidCallback onRetry, Object? error}) {
  // Not being signed in is a normal navigation state, not a failure: send the person to sign in and bring them back here.
  if (error is ApiException && error.code == ApiErrorCode.unauthenticated) {
    final here = GoRouterState.of(context).uri.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/login?next=${Uri.encodeComponent(here)}');
    });
    return aqLoadingFrame(context, title: title);
  }
  final f = FlowStrings.of(context);
  return AQAuthScaffold(
    showLogo: false,
    title: title,
    showBack: false,
    children: [AQErrorBanner(text: f.t('ver.retryLoad'), action: AQTextButton(label: f.t('common.retry'), color: AQColors.of(context).accent, onPressed: onRetry))],
  );
}

String apiErrorKey(Object e) => e is ApiException && e.code != ApiErrorCode.network ? 'common.genericError' : 'common.networkError';
