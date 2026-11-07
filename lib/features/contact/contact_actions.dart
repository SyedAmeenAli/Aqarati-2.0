import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../devbuild/db_widgets.dart' show DbIcon;
import '../../core/aq/aq_states.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_thumb.dart' show AQThumb;

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
    void openChat() {
      AQHaptics.selection();
      Navigator.of(context).push(AQRoute.route<void>(AQChatScreen(name: name, subject: subject)));
    }

    // The in-app chat is its own, main action: it never leaves AQARATI.
    final chat = Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '${f.t('ct.chat.primary')} $name',
      excludeSemantics: true,
      onTap: openChat,
      child: AQPressable(
        onTap: openChat,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent, c.accentDeep]),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AQIcon('chat', size: 20, color: c.onAccent),
            const SizedBox(width: 10),
            Flexible(child: Text(f.t('ct.chat.primary'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall, color: c.onAccent))),
          ]),
        ),
      ),
    );
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 18.5 || MediaQuery.sizeOf(context).width < 340;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      chat,
      const SizedBox(height: AQSpacing.x2),
      if (stacked) ...[call, const SizedBox(height: AQSpacing.x2), wa]
      else Row(children: [Expanded(child: call), const SizedBox(width: AQSpacing.x2), Expanded(child: wa)]),
      if ((phone ?? '').isNotEmpty) ...[
        const SizedBox(height: AQSpacing.x1),
        Text('${phone!}  ·  ${f.t('ct.sample')}', style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
      ],
    ]);
  }
}

class ChatMsg {
  final String text;
  final bool mine;

  /// A built-in line (the greeting and the demo reply) is stored by key so it follows the language.
  final String? key;
  const ChatMsg(this.text, this.mine, {this.key});
  String show(FlowStrings f) => key == null ? text : f.t(key!);
}

/// One conversation: who it is with, what it is about, and what was typed. Kept for the app session.
class ChatThread {
  final String name;
  final String? subject;
  final List<ChatMsg> messages;
  const ChatThread(this.name, this.subject, this.messages);
}

/// Two sample conversations are there to start with, so the inbox shows how chatting looks.
final chatThreadsProvider = StateProvider<List<ChatThread>>((ref) => const [
  ChatThread('Rawaq Maintenance Services', null, [ChatMsg('', false, key: 'ct.seed.1')]),
  ChatThread('Wadi Architecture', null, [ChatMsg('', false, key: 'ct.seed.2')]),
]);

/// A demo in-app conversation. There is no chat service: your messages stay on this device and are not sent.
class AQChatScreen extends ConsumerStatefulWidget {
  final String name;
  final String? subject;
  const AQChatScreen({super.key, required this.name, this.subject});
  @override
  ConsumerState<AQChatScreen> createState() => _AQChatScreenState();
}

class _AQChatScreenState extends ConsumerState<AQChatScreen> {
  final _ctl = TextEditingController();
  Timer? _reply;

  @override
  void dispose() {
    _reply?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    ref.read(chatThreadsProvider.notifier).update((all) {
      final i = all.indexWhere((x) => x.name == widget.name);
      if (i < 0) return [ChatThread(widget.name, widget.subject, [ChatMsg(t, true)]), ...all];
      final cur = all[i];
      return [ChatThread(cur.name, cur.subject, [...cur.messages, ChatMsg(t, true)]), ...all.where((x) => x.name != widget.name)];
    });
    _ctl.clear();
    // A short, clearly demo reply, so a conversation has two sides.
    _reply?.cancel();
    _reply = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      ref.read(chatThreadsProvider.notifier).update((all) {
        final i = all.indexWhere((x) => x.name == widget.name);
        if (i < 0) return all;
        final cur = all[i];
        return [ChatThread(cur.name, cur.subject, [...cur.messages, const ChatMsg('', false, key: 'ct.reply')]), ...all.where((x) => x.name != widget.name)];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final threads = ref.watch(chatThreadsProvider);
    final msgs = threads.where((x) => x.name == widget.name).firstOrNull?.messages ?? const <ChatMsg>[];
    Widget bubble(ChatMsg m) => Align(
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
            child: Text(m.show(f), style: AQTypography.of(context, AQText.bodyMedium, color: m.mine ? c.onAccent : c.ink)),
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
        bubble(ChatMsg(hello, false)),
        for (final m in msgs) bubble(m),
      ],
    );
  }
}

/// The Chats inbox as its own full screen (from the chat icon on Home).
class AQChatsScreen extends StatelessWidget {
  const AQChatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return AQViewingScaffold(
      title: f.t('act.chats'),
      subtitle: f.t('ct.chat.demo'),
      backLabel: f.t('common.back'),
      onBack: () => Navigator.of(context).maybePop(),
      children: const [ChatsList()],
    );
  }
}

/// The Chats tab of Activity: every conversation you have started, newest first.
class ChatsView extends StatelessWidget {
  const ChatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x4, AQSpacing.gutter, 128),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(header: true, child: Text(f.t('act.chats'), style: AQTypography.of(context, AQText.displaySmall))),
        const SizedBox(height: AQSpacing.x1),
        Text(f.t('ct.chat.demo'), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
        const SizedBox(height: AQSpacing.x4),
        const ChatsList(),
      ]),
    );
  }
}

/// The conversations themselves.
class ChatsList extends ConsumerWidget {
  const ChatsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final threads = ref.watch(chatThreadsProvider);
    void open(ChatThread t) => Navigator.of(context).push(AQRoute.route<void>(AQChatScreen(name: t.name, subject: t.subject)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (threads.isEmpty)
          AQEmptyState(icon: 'send', title: f.t('ct.chats.empty.t'), body: f.t('ct.chats.empty.b'))
        else
          for (final t in threads)
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: Semantics(
                button: true,
                focusable: true,
                onFocus: () {},
                label: '${t.name}. ${t.messages.isEmpty ? '' : t.messages.last.show(f)}',
                excludeSemantics: true,
                onTap: () => open(t),
                child: AQPressable(
                  onTap: () => open(t),
                  child: Container(
                    padding: const EdgeInsets.all(AQSpacing.x3),
                    decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
                    child: Row(children: [
                      AQThumb(monogramOf: t.name, size: 48),
                      const SizedBox(width: AQSpacing.x3),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                          Text(t.messages.isEmpty ? (t.subject ?? '') : t.messages.last.show(f), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                        ]),
                      ),
                      AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
                    ]),
                  ),
                ),
              ),
            ),
      ]);
  }
}
