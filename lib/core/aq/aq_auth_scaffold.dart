import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/entry/widgets/entry_common.dart' show MasterLogo;
import 'aq_scene.dart';
import 'aq_tokens.dart';
import 'aq_typography.dart';

/// Shared frame for sign-up / OTP / login-style screens: quiet photographic
/// backdrop, back + quiet action, a small logo anchor, editorial title,
/// scrolling body and a pinned action area that stays above the keyboard.
class AQAuthScaffold extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;
  final Widget? progress;
  final VoidCallback? onBack;
  final String? backLabel;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String backdrop;
  final bool showLogo;
  final double logoWidth;
  final bool centered;

  /// False on roots of the authenticated area, where Back would only lead to Welcome.
  final bool showBack;
  const AQAuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.bottom,
    this.progress,
    this.onBack,
    this.backLabel,
    this.actionLabel,
    this.onAction,
    this.backdrop = 'assets/entry/oman_terrace_2k.jpg',
    this.showLogo = true,
    this.logoWidth = 84,
    this.centered = false,
    this.showBack = true,
  });

  @override
  State<AQAuthScaffold> createState() => _AQAuthScaffoldState();
}

class _AQAuthScaffoldState extends State<AQAuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: AQMotion.reveal,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AQMotion.reduced(context) ? _enter.value = 1 : _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final compact = AQLayout.compact(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AQBackdrop(asset: widget.backdrop, quiet: true),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AQSpacing.x4,
                        ),
                        child: AQTopBar(
                          onBack: widget.showBack
                              ? (widget.onBack ??
                                    () => aqBack(context, '/entry'))
                              : null,
                          backLabel: widget.backLabel,
                          actionLabel: widget.actionLabel,
                          onAction: widget.onAction,
                        ),
                      ),
                      Expanded(
                        // Soft fade where content scrolls under the pinned action, instead of a hard cut.
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (r) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: [0, 0.94, 1],
                          ).createShader(r),
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(
                              AQSpacing.gutter,
                              0,
                              AQSpacing.gutter,
                              AQSpacing.x6,
                            ),
                            child: Column(
                              crossAxisAlignment: widget.centered
                                  ? CrossAxisAlignment.center
                                  : CrossAxisAlignment.start,
                              children: [
                                if (widget.showLogo && !keyboard) ...[
                                  Center(
                                    child: AQReveal(
                                      animation: _enter,
                                      begin: 0,
                                      end: 0.45,
                                      dy: 8,
                                      child: MasterLogo(
                                        width: widget.logoWidth,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: compact
                                        ? AQSpacing.x4
                                        : AQSpacing.x6,
                                  ),
                                ],
                                if (widget.progress != null) ...[
                                  AQReveal(
                                    animation: _enter,
                                    begin: 0.04,
                                    end: 0.5,
                                    dy: 0,
                                    child: widget.progress!,
                                  ),
                                  const SizedBox(height: AQSpacing.x4),
                                ],
                                AQReveal(
                                  animation: _enter,
                                  begin: 0.08,
                                  end: 0.55,
                                  dy: 8,
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      widget.title,
                                      textAlign: widget.centered
                                          ? TextAlign.center
                                          : null,
                                      style: AQTypography.of(
                                        context,
                                        AQText.headlineLarge,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: AQSpacing.x3),
                                  AQReveal(
                                    animation: _enter,
                                    begin: 0.16,
                                    end: 0.65,
                                    dy: 6,
                                    child: Text(
                                      widget.subtitle!,
                                      textAlign: widget.centered
                                          ? TextAlign.center
                                          : null,
                                      style: AQTypography.of(
                                        context,
                                        AQText.bodyMedium,
                                        soft: true,
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(
                                  height: compact ? AQSpacing.x5 : AQSpacing.x6,
                                ),
                                AQReveal(
                                  animation: _enter,
                                  begin: 0.24,
                                  end: 0.8,
                                  dy: 8,
                                  child: Column(
                                    crossAxisAlignment: widget.centered
                                        ? CrossAxisAlignment.center
                                        : CrossAxisAlignment.start,
                                    children: widget.children,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.bottom != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AQSpacing.gutter,
                            AQSpacing.x2,
                            AQSpacing.gutter,
                            AQSpacing.x4,
                          ),
                          child: AQReveal(
                            animation: _enter,
                            begin: 0.5,
                            end: 1,
                            dy: 6,
                            child: widget.bottom!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
