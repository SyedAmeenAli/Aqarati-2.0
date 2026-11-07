import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../devbuild/db_widgets.dart' show DbIcon;
import '../viewing/widgets/viewing_scaffold.dart';

/// A sample phone number for a record that has none of its own (the same scheme the demo professionals use).
/// It is a stand-in for demo data, never a real person's number.
String aqDemoPhoneFor(String id) {
  final n = id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) % 10000000);
  final d = n.toString().padLeft(7, '0');
  return '+968 9${d.substring(0, 3)} ${d.substring(3)}';
}

Future<bool> _open(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Call, WhatsApp and in-app chat for one person or business, in one row. Call opens the phone dialler and
/// WhatsApp opens a chat with the number; the in-app chat is a demo conversation (nothing is sent anywhere).
class AQContactButtons extends StatelessWidget {
  final String name;
  final String? phone;

  /// What the conversation is about (a property or a service), shown in the chat.
  final String? subject;
  const AQContactButtons({super.key, required this.name, this.phone, this.subject});

  Future<void> _go(BuildContext context, Uri uri) async {
    final f = FlowStrings.of(context);
    final ok = await _open(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t('ct.open.fail'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final tel = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    Widget pill(String icon, String label, VoidCallback? onTap) => Semantics(
          button: true,
          focusable: true,
          onFocus: () {},
          label: '$label $name',
          enabled: onTap != null,
          excludeSemantics: true,
          onTap: onTap,
          child: AQPressable(
            onTap: onTap == null
                ? null
                : () {
                    AQHaptics.selection();
                    onTap();
                  },
            child: Container(
              constraints: const BoxConstraints(minHeight: AQControl.tap),
              padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x2),
              decoration: BoxDecoration(
                color: onTap == null ? c.surface : c.surfaceRaised,
                borderRadius: BorderRadius.circular(AQControl.tap),
                border: Border.all(color: c.hairline),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                DbIcon(icon, size: 18, color: onTap == null ? c.inkFaint : c.accentDeep),
                const SizedBox(width: 6),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelMedium, color: onTap == null ? c.inkFaint : c.ink))),
              ]),
            ),
          ),
        );
    final call = pill('phone', f.t('ct.call'), tel.isEmpty ? null : () => _go(context, Uri(scheme: 'tel', path: tel)));
    final wa = pill('whatsapp', f.t('ct.whatsapp'), digits.isEmpty ? null : () => _go(context, Uri.https('wa.me', '/$digits')));
    final chat = pill('send', f.t('ct.chat'), () => Navigator.of(context).push(AQRoute.route<void>(AQChatScreen(name: name, subject: subject))));
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 18.5 || MediaQuery.sizeOf(context).width < 340;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (stacked) ...[call, const SizedBox(height: AQSpacing.x2), wa, const SizedBox(height: AQSpacing.x2), chat]
      else Row(children: [Expanded(child: call), const SizedBox(width: AQSpacing.x2), Expanded(child: wa), const SizedBox(width: AQSpacing.x2), Expanded(child: chat)]),
      if ((phone ?? '').isNotEmpty) ...[
        const SizedBox(height: AQSpacing.x1),
        Text('${phone!}  ·  ${f.t('ct.sample')}', style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
      ],
    ]);
  }
}

class _Msg {
  final String text;
  final bool mine;
  const _Msg(this.text, this.mine);
}

/// A demo in-app conversation. There is no chat service: your messages stay on this screen and are not sent.
class AQChatScreen extends StatefulWidget {
  final String name;
  final String? subject;
  const AQChatScreen({super.key, required this.name, this.subject});
  @override
  State<AQChatScreen> createState() => _AQChatScreenState();
}

class _AQChatScreenState extends State<AQChatScreen> {
  final _ctl = TextEditingController();
  final _msgs = <_Msg>[];

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    setState(() => _msgs.add(_Msg(t, true)));
    _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    Widget bubble(_Msg m) => Align(
          alignment: m.mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: Container(
            margin: const EdgeInsets.only(bottom: AQSpacing.x2),
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x3),
            decoration: BoxDecoration(
              color: m.mine ? c.accent : c.surfaceRaised,
              borderRadius: BorderRadius.circular(AQRadius.medium),
              border: m.mine ? null : Border.all(color: c.hairline),
            ),
            child: Text(m.text, style: AQTypography.of(context, AQText.bodyMedium, color: m.mine ? c.onAccent : c.ink)),
          ),
        );
    final hello = f.t(widget.subject == null ? 'ct.chat.hello' : 'ct.chat.helloAbout', {'s': widget.subject ?? ''});
    return AQViewingScaffold(
      title: f.t('ct.chat.title', {'n': widget.name}),
      subtitle: f.t('ct.chat.demo'),
      backLabel: f.t('common.back'),
      onBack: () => Navigator.of(context).maybePop(),
      bottom: Container(
        color: c.surfaceRaised,
        padding: EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x3, AQSpacing.x3, AQSpacing.x3 + MediaQuery.paddingOf(context).bottom),
        child: Row(children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: AQControl.field),
              padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AQControl.field), border: Border.all(color: c.hairline)),
              alignment: Alignment.center,
              child: TextField(
                controller: _ctl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                cursorColor: c.accent,
                style: AQTypography.of(context, AQText.bodyMedium),
                decoration: InputDecoration.collapsed(hintText: f.t('ct.chat.hint'), hintStyle: AQTypography.of(context, AQText.bodyMedium, color: c.inkFaint)).copyWith(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AQSpacing.x2),
          AQIconButton(icon: 'send', directional: false, semanticsLabel: f.t('ct.chat.send'), onPressed: _send),
        ]),
      ),
      children: [
        bubble(_Msg(hello, false)),
        for (final m in _msgs) bubble(m),
      ],
    );
  }
}
