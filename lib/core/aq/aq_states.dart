import 'package:flutter/material.dart';

import 'aq_primitives.dart';
import 'aq_tokens.dart';
import 'aq_typography.dart';

/// The three states every list or rail can be in besides "has content". One look for all of them:
/// a quiet icon disc, a line of title, a line of explanation and at most one action.
class AQEmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  const AQEmptyState({
    super.key,
    this.icon = 'search',
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AQSpacing.x8, horizontal: AQSpacing.x4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle),
            child: Center(child: AQIcon(icon, size: 24, color: c.accent)),
          ),
          const SizedBox(height: AQSpacing.x4),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.headlineSmall)),
          ),
          if (body != null) ...[
            const SizedBox(height: AQSpacing.x1),
            Text(body!, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AQSpacing.x3),
            AQTextButton(label: actionLabel!, color: c.accentDeep, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// A failed load with a retry. Same shape as [AQEmptyState] so the page does not jump.
class AQErrorState extends StatelessWidget {
  final String title;
  final String? body;
  final String retryLabel;
  final VoidCallback onRetry;
  const AQErrorState({super.key, required this.title, this.body, required this.retryLabel, required this.onRetry});

  @override
  Widget build(BuildContext context) => AQEmptyState(
    icon: 'alert',
    title: title,
    body: body,
    actionLabel: retryLabel,
    onAction: onRetry,
  );
}

/// A placeholder block while content loads. It breathes slowly; with reduced motion it is still.
class AQLoadingBlock extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const AQLoadingBlock({super.key, this.width, required this.height, this.radius = AQRadius.medium});

  @override
  State<AQLoadingBlock> createState() => _AQLoadingBlockState();
}

class _AQLoadingBlockState extends State<AQLoadingBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AQMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: c.ink.withValues(alpha: (c.isDark ? 0.07 : 0.045) + 0.035 * _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}
