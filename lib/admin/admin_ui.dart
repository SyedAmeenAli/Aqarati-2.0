import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/aq/aq_primitives.dart';
import '../core/aq/aq_tokens.dart';
import '../core/aq/aq_typography.dart';
import 'admin_l10n.dart';

/// The Admin Console's own control kit. The customer app keeps its large, soft controls; an
/// administration tool needs compact, content-sized ones, so the sizes live here and nowhere else.
///
/// Heights: button 40 (compact 34), field 44, icon button 38. Radius: 8 for controls, 12 for panels.
class AdminSize {
  AdminSize._();
  static const double button = 40, buttonCompact = 34, field = 44, icon = 38;
  static const double control = 8, panel = 12;
  static const double sidebar = 244, content = 1240;
}

enum AdminButtonKind { primary, secondary, danger, text }

/// One button for every variant. It is as wide as its label needs, never as wide as its parent;
/// put it in an `Expanded` or `SizedBox` only where a full-width button is the right design.
class AdminButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AdminButtonKind kind;
  final bool loading, compact;
  final String? leadingIcon, trailingIcon, semanticsLabel;
  final Color? color;

  /// Fill the parent's width. Only for a form's single main action; everywhere else a button hugs its label.
  final bool expand;
  const AdminButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AdminButtonKind.secondary,
    this.loading = false,
    this.compact = false,
    this.leadingIcon,
    this.trailingIcon,
    this.semanticsLabel,
    this.color,
    this.expand = false,
  });

  @override
  State<AdminButton> createState() => _AdminButtonState();
}

class _AdminButtonState extends State<AdminButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final k = widget.kind;
    // A full-size text button (the Back control) is a 44 px target.
    final h = widget.compact ? AdminSize.buttonCompact : (widget.kind == AdminButtonKind.text ? 44.0 : AdminSize.button);
    Color bg, fg, border;
    switch (k) {
      case AdminButtonKind.primary:
        bg = _hover && enabled ? c.accentDeep : c.accent;
        fg = c.onAccent;
        border = Colors.transparent;
      case AdminButtonKind.secondary:
        bg = _hover && enabled ? c.surfaceSelected : c.surfaceRaised;
        fg = c.ink;
        border = c.hairline;
      case AdminButtonKind.danger:
        bg = _hover && enabled ? c.danger.withValues(alpha: 0.1) : Colors.transparent;
        fg = c.danger;
        border = c.danger.withValues(alpha: 0.55);
      case AdminButtonKind.text:
        bg = _hover && enabled ? c.ink.withValues(alpha: 0.05) : Colors.transparent;
        fg = widget.color ?? c.accentDeep;
        border = Colors.transparent;
    }
    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AQTypography.of(context, AQText.titleSmall, color: fg),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (widget.leadingIcon != null) ...[
          AQIcon(widget.leadingIcon!, size: 16, color: fg),
          const SizedBox(width: 8),
        ],
        if (!widget.loading) Flexible(child: label),
        if (!widget.loading && widget.trailingIcon != null) ...[
          const SizedBox(width: 6),
          AQIcon(widget.trailingIcon!, size: 16, color: fg),
        ],
      ],
    );
    final button = Semantics(
      button: true,
      focusable: true,
      enabled: enabled,
      onFocus: () {},
      label: tr(widget.semanticsLabel ?? widget.label),
      excludeSemantics: true,
      onTap: enabled ? widget.onPressed : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AQPressable(
          onTap: enabled ? widget.onPressed : null,
          pressedScale: 0.98,
          child: Opacity(
            opacity: widget.onPressed == null ? 0.45 : 1,
            child: AnimatedContainer(
              duration: AQMotion.scaled(context, AQMotion.fast),
              constraints: BoxConstraints(minHeight: h, minWidth: k == AdminButtonKind.text ? 0 : (widget.compact ? 56 : 84)),
              padding: EdgeInsets.symmetric(horizontal: k == AdminButtonKind.text ? 8 : (widget.compact ? 12 : 16)),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AdminSize.control),
                border: Border.all(color: border),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
    return widget.expand
        ? button
        : Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, heightFactor: 1, child: button);
  }
}

/// Same constructor names as the customer buttons, so screens read the same; only the look differs.
class AdminPrimaryButton extends AdminButton {
  const AdminPrimaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.loading,
    super.compact,
    super.leadingIcon,
    super.semanticsLabel,
    super.expand,
    bool trailingChevron = false,
  }) : super(kind: AdminButtonKind.primary);
}

class AdminSecondaryButton extends AdminButton {
  const AdminSecondaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.loading,
    super.compact,
    super.leadingIcon,
    super.semanticsLabel,
    super.expand,
    bool trailingChevron = false,
  }) : super(kind: AdminButtonKind.secondary);
}

class AdminDangerButton extends AdminButton {
  const AdminDangerButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.loading,
    super.compact,
    super.leadingIcon,
    super.semanticsLabel,
  }) : super(kind: AdminButtonKind.danger);
}

class AdminTextButton extends AdminButton {
  const AdminTextButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.color,
    super.trailingIcon,
    super.leadingIcon,
    super.semanticsLabel,
    super.compact = true,
  }) : super(kind: AdminButtonKind.text);
}

/// Icon-only action with a 38 px hit area and a required accessible name.
class AdminIconButton extends StatefulWidget {
  final String icon, semanticsLabel;
  final VoidCallback? onPressed;
  const AdminIconButton({super.key, required this.icon, required this.semanticsLabel, required this.onPressed});
  @override
  State<AdminIconButton> createState() => _AdminIconButtonState();
}

class _AdminIconButtonState extends State<AdminIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: tr(widget.semanticsLabel),
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: AQPressable(
          onTap: widget.onPressed,
          pressedScale: 0.94,
          child: Container(
            width: AdminSize.icon,
            height: AdminSize.icon,
            decoration: BoxDecoration(
              color: _hover ? c.ink.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(AdminSize.control),
            ),
            child: Center(child: AQIcon(widget.icon, size: 20, color: c.ink)),
          ),
        ),
      ),
    );
  }
}

/// A 44 px input. The label sits on the top border, so a field is one line high instead of two.
class AdminField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint, helper, error;
  final TextInputType? keyboardType;
  final TextInputAction action;
  final List<TextInputFormatter>? formatters;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscure, enabled, valid;
  final Widget? prefix, suffix;
  final FocusNode? focusNode;
  final int minLines, maxLines;
  const AdminField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.error,
    this.keyboardType,
    this.action = TextInputAction.next,
    this.formatters,
    this.autofill,
    this.onChanged,
    this.onSubmitted,
    this.obscure = false,
    this.enabled = true,
    this.valid = false,
    this.prefix,
    this.suffix,
    this.focusNode,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminSize.control),
      borderSide: BorderSide(color: col, width: w),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: action,
      inputFormatters: formatters,
      autofillHints: autofill,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      minLines: minLines,
      maxLines: obscure ? 1 : maxLines,
      style: AQTypography.of(context, AQText.bodyMedium),
      cursorColor: c.accent,
      decoration: InputDecoration(
        isDense: true,
        labelText: tr(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        floatingLabelStyle: AQTypography.of(context, AQText.labelMedium, color: error != null ? c.danger : c.inkSoft),
        hintText: hint == null ? null : tr(hint!),
        hintStyle: AQTypography.of(context, AQText.bodyMedium, color: c.inkFaint),
        helperText: error == null ? (helper == null ? null : tr(helper!)) : null,
        helperMaxLines: 2,
        errorText: error == null ? null : tr(error!),
        errorMaxLines: 2,
        filled: true,
        fillColor: enabled ? c.surface : c.surface.withValues(alpha: 0.5),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: (AdminSize.field - 20) / 2),
        constraints: const BoxConstraints(minHeight: AdminSize.field),
        prefixIcon: prefix,
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: AdminSize.field),
        suffixIcon: suffix ?? (valid ? Padding(padding: const EdgeInsetsDirectional.only(end: 10), child: AQIcon('check', size: 16, color: c.success)) : null),
        suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: AdminSize.field),
        enabledBorder: b(c.hairline),
        disabledBorder: b(c.hairline.withValues(alpha: 0.6)),
        focusedBorder: b(c.accent, 1.5),
        errorBorder: b(c.danger),
        focusedErrorBorder: b(c.danger, 1.5),
      ),
    );
  }
}

class AdminPasswordField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String showLabel, hideLabel;
  final String? error, helper;
  final TextInputAction action;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const AdminPasswordField({
    super.key,
    required this.label,
    required this.controller,
    required this.showLabel,
    required this.hideLabel,
    this.error,
    this.helper,
    this.action = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
  });
  @override
  State<AdminPasswordField> createState() => _AdminPasswordFieldState();
}

class _AdminPasswordFieldState extends State<AdminPasswordField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) => AdminField(
    label: widget.label,
    controller: widget.controller,
    obscure: !_show,
    error: widget.error,
    helper: widget.helper,
    action: widget.action,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    autofill: const [AutofillHints.password],
    suffix: AdminIconButton(
      icon: _show ? 'eye-off' : 'eye',
      semanticsLabel: tr(_show ? widget.hideLabel : widget.showLabel),
      onPressed: () => setState(() => _show = !_show),
    ),
  );
}

/// A small selectable chip for filters and choices: 30 px high, squared corners, no thick outline.
class AdminChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const AdminChip({super.key, required this.label, required this.selected, required this.onTap});
  @override
  State<AdminChip> createState() => _AdminChipState();
}

class _AdminChipState extends State<AdminChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final sel = widget.selected;
    return Semantics(
      button: true,
      focusable: true,
      selected: sel,
      onFocus: () {},
      label: tr(widget.label),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: AQPressable(
          onTap: widget.onTap,
          pressedScale: 0.97,
          child: AnimatedContainer(
            duration: AQMotion.scaled(context, AQMotion.fast),
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: sel ? c.accent : (_hover ? c.surfaceSelected : c.surfaceRaised),
              borderRadius: BorderRadius.circular(AdminSize.control),
              border: Border.all(color: sel ? c.accent : c.hairline),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                widget.label,
                maxLines: 1,
                style: AQTypography.of(context, AQText.bodySmall, color: sel ? c.onAccent : c.ink).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A calm container: one hairline, a small radius, no shadow. Group related content in one.
class AdminPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AdminPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AdminSize.panel),
        border: Border.all(color: c.hairline),
      ),
      child: child,
    );
  }
}
