import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/aq/aq_glass.dart';
import '../../core/aq/aq_primitives.dart';
import '../../data/datasources/mock_business_data.dart' show mockBusinesses;
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
    void openChat() => aqOpenChat(context, name, subject: subject);

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

  /// When it was sent. Sample lines carry none.
  final DateTime? at;
  const ChatMsg(this.text, this.mine, {this.key, this.at});
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

/// Opens the in-app chat with [name] as a full screen (above the tab bar).
void aqOpenChat(BuildContext context, String name, {String? subject}) {
  AQHaptics.selection();
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    final q = 'name=${Uri.encodeQueryComponent(name)}${subject == null ? '' : '&subject=${Uri.encodeQueryComponent(subject)}'}';
    router.push('/chat?$q');
  } else {
    Navigator.of(context).push(AQRoute.route<void>(AQChatScreen(name: name, subject: subject)));
  }
}

String? _businessIdByName(String name) {
  for (final b in mockBusinesses) {
    if (b.name == name) return b.id;
  }
  return null;
}

String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
  final _scroll = ScrollController();
  Timer? _reply;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reply?.cancel();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    });
  }

  void _add(ChatMsg m) {
    ref.read(chatThreadsProvider.notifier).update((all) {
      final i = all.indexWhere((x) => x.name == widget.name);
      if (i < 0) return [ChatThread(widget.name, widget.subject, [m]), ...all];
      final cur = all[i];
      return [ChatThread(cur.name, cur.subject, [...cur.messages, m]), ...all.where((x) => x.name != widget.name)];
    });
    _toEnd();
  }

  void _send([String? preset]) {
    final t = (preset ?? _ctl.text).trim();
    if (t.isEmpty) return;
    _add(ChatMsg(t, true, at: DateTime.now()));
    _ctl.clear();
    // The demo business "types" for a moment, then answers.
    _reply?.cancel();
    setState(() => _typing = true);
    _toEnd();
    _reply = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _typing = false);
      final n = (ref.read(chatThreadsProvider).where((x) => x.name == widget.name).firstOrNull?.messages ?? const <ChatMsg>[]).where((m) => m.mine).length;
      _add(ChatMsg('', false, key: 'ct.reply.${(n - 1) % 3 + 1}', at: DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final threads = ref.watch(chatThreadsProvider);
    final msgs = threads.where((x) => x.name == widget.name).firstOrNull?.messages ?? const <ChatMsg>[];
    final hello = ChatMsg('', false, key: widget.subject == null ? 'ct.chat.hello' : 'ct.chat.helloAbout');
    final all = [hello, ...msgs];
    final bid = _businessIdByName(widget.name);
    final typed = _ctl.text.trim().isNotEmpty;
    final router = GoRouter.maybeOf(context);

    Widget bubble(ChatMsg m, int i) {
      final mine = m.mine;
      final text = m.key == 'ct.chat.helloAbout' ? f.t('ct.chat.helloAbout', {'s': widget.subject ?? ''}) : m.show(f);
      final r = const Radius.circular(22);
      final tail = const Radius.circular(6);
      final body = Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: mine ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent, c.accentDeep]) : null,
          color: mine ? null : c.surfaceRaised.withValues(alpha: 0.94),
          borderRadius: BorderRadiusDirectional.only(topStart: r, topEnd: r, bottomStart: mine ? r : tail, bottomEnd: mine ? tail : r),
          border: mine ? null : Border.all(color: c.hairline),
          boxShadow: [BoxShadow(color: (mine ? c.accent : c.accentDeep).withValues(alpha: mine ? 0.28 : 0.07), blurRadius: mine ? 14 : 10, offset: const Offset(0, 4))],
        ),
        child: Text(text, style: AQTypography.of(context, AQText.bodyMedium, color: mine ? c.onAccent : c.ink)),
      );
      final animate = !MediaQuery.disableAnimationsOf(context);
      final item = Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            body,
            if (m.at != null) Padding(padding: const EdgeInsets.only(top: 4, left: 6, right: 6), child: Text(_clock(m.at!), style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint).copyWith(letterSpacing: 0.2))),
          ],
        ),
      );
      return Align(
        alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        // Each new bubble rises and settles into place.
        child: animate
            ? TweenAnimationBuilder<double>(
                key: ValueKey('msg$i'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 22 * (1 - v)), child: Transform.scale(scale: 0.94 + 0.06 * v, alignment: mine ? AlignmentDirectional.bottomEnd : AlignmentDirectional.bottomStart, child: child))),
                child: item,
              )
            : item,
      );
    }

    final showQuick = !msgs.any((m) => m.mine) && !_typing;
    final quick = ['ct.q.1', 'ct.q.2', 'ct.q.3'];

    return Scaffold(
      backgroundColor: c.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.background, Color.alphaBlend(c.accent.withValues(alpha: 0.10), c.background)]),
        ),
        child: SafeArea(
          child: Column(children: [
            // Header: back, who you are talking to, and a way to see their profile.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: AQGlass(
                radius: 28,
                blur: 14,
                fill: 0.7,
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                child: Row(children: [
                  AQIconButton(icon: 'chevron-left', semanticsLabel: f.t('common.back'), onPressed: () => Navigator.of(context).maybePop()),
                  Semantics(
                    button: bid != null,
                    label: f.t('ct.profile.view'),
                    excludeSemantics: bid != null,
                    onTap: bid == null || router == null ? null : () => router.push('/business/$bid'),
                    child: AQPressable(
                      onTap: bid == null || router == null ? null : () => router.push('/business/$bid'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Stack(clipBehavior: Clip.none, children: [
                          AQThumb(monogramOf: widget.name, size: 46),
                          PositionedDirectional(end: -1, bottom: -1, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle, border: Border.all(color: c.surfaceRaised, width: 2)))),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                      Text(_typing ? f.t('ct.typing') : f.t('ct.online'), maxLines: 1, style: AQTypography.of(context, AQText.bodySmall, color: _typing ? c.accentDeep : c.success)),
                    ]),
                  ),
                  if (bid != null && router != null)
                    Semantics(
                      button: true,
                      label: f.t('ct.profile.view'),
                      excludeSemantics: true,
                      onTap: () => router.push('/business/$bid'),
                      child: AQPressable(
                        onTap: () => router.push('/business/$bid'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                          child: Text(f.t('ct.profile.view'), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep).copyWith(letterSpacing: 0.1)),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            if (widget.subject != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    AQIcon('listings', size: 18, color: c.accentDeep),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.subject!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep).copyWith(letterSpacing: 0.1))),
                  ]),
                ),
              ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: c.surfaceRaised.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.hairline)),
                        child: Text(f.t('ct.demo.pill'), style: AQTypography.of(context, AQText.labelMedium, color: c.inkSoft).copyWith(letterSpacing: 0.1)),
                      ),
                    ),
                  ),
                  for (final (i, m) in all.indexed) bubble(m, i),
                  if (_typing) const _TypingDots(),
                ],
              ),
            ),
            if (showQuick)
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: quick.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Center(
                    child: Semantics(
                      button: true,
                      label: f.t(quick[i]),
                      excludeSemantics: true,
                      onTap: () => _send(f.t(quick[i])),
                      child: AQPressable(
                        onTap: () => _send(f.t(quick[i])),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.accent.withValues(alpha: 0.4))),
                          child: Text(f.t(quick[i]), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep).copyWith(letterSpacing: 0.1)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              // Sits above the tab bar when the chat opens inside the app shell.
              padding: EdgeInsets.fromLTRB(12, 6, 12, 10 + AQShellInset.of(context)),
              child: AQGlass(
                radius: 30,
                blur: 16,
                fill: 0.75,
                padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      cursorColor: c.accent,
                      style: AQTypography.of(context, AQText.bodyMedium),
                      decoration: InputDecoration.collapsed(hintText: f.t('ct.chat.hint'), hintStyle: AQTypography.of(context, AQText.bodyMedium, color: c.inkFaint)).copyWith(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    enabled: typed,
                    label: f.t('ct.chat.send'),
                    excludeSemantics: true,
                    onTap: typed ? _send : null,
                    child: AQPressable(
                      onTap: typed ? _send : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: typed ? [c.accent, c.accentDeep] : [c.accentDisabled, c.accentDisabled]),
                          boxShadow: typed ? [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))] : const [],
                        ),
                        child: Center(child: AQIcon('send', size: 20, color: c.onAccent)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Three dots that pulse one after another while the demo business is "typing".
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(count: 12);
  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surfaceRaised.withValues(alpha: 0.94),
          borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(22), topEnd: Radius.circular(22), bottomEnd: Radius.circular(22), bottomStart: Radius.circular(6)),
          border: Border.all(color: c.hairline),
        ),
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(left: i == 0 ? 0 : 5, bottom: 3 * (0.5 + 0.5 * (1 - ((_ctl.value * 3 - i) % 3 - 0.5).abs().clamp(0.0, 1.0)))),
                decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.35 + 0.5 * (1 - ((_ctl.value * 3 - i) % 3 - 0.5).abs().clamp(0.0, 1.0))), shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, 128),
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
    if (threads.isEmpty) return AQEmptyState(icon: 'chat', title: f.t('ct.chats.empty.t'), body: f.t('ct.chats.empty.b'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, t) in threads.indexed)
        _Rise(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: Builder(builder: (context) {
              final last = t.messages.isEmpty ? null : t.messages.last;
              final unread = last != null && !last.mine && last.at == null;
              final preview = last == null ? (t.subject ?? '') : (last.mine ? '${f.t('ct.you')}: ${last.show(f)}' : last.show(f));
              void open() => aqOpenChat(context, t.name, subject: t.subject);
              return Semantics(
                button: true,
                focusable: true,
                onFocus: () {},
                label: '${t.name}. $preview',
                excludeSemantics: true,
                onTap: open,
                child: AQPressable(
                  onTap: open,
                  child: AQGlass(
                    radius: 26,
                    blur: 10,
                    fill: 0.72,
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Stack(clipBehavior: Clip.none, children: [
                        AQThumb(monogramOf: t.name, size: 54),
                        PositionedDirectional(end: -1, bottom: -1, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle, border: Border.all(color: c.surfaceRaised, width: 2.5)))),
                      ]),
                      const SizedBox(width: AQSpacing.x3),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall))),
                            Text(last?.at == null ? f.t('ct.now') : _clock(last!.at!), style: AQTypography.of(context, AQText.labelSmall, color: unread ? c.accentDeep : c.inkFaint).copyWith(letterSpacing: 0.2)),
                          ]),
                          const SizedBox(height: 3),
                          Row(children: [
                            Expanded(child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, color: unread ? c.ink : c.inkSoft))),
                            if (unread)
                              Container(
                                margin: const EdgeInsetsDirectional.only(start: 8),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c.accent, c.accentDeep])),
                                alignment: Alignment.center,
                                child: Text('1', style: AQTypography.of(context, AQText.labelSmall, color: c.onAccent).copyWith(letterSpacing: 0)),
                              ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
    ]);
  }
}

/// A row that fades and rises into place, one after another.
class _Rise extends StatelessWidget {
  final int index;
  final Widget child;
  const _Rise({required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delay = (index.clamp(0, 6)) * 70;
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
    );
  }
}
