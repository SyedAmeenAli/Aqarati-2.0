import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/aq/aq_forms.dart';
import '../core/aq/aq_primitives.dart';
import '../core/aq/aq_status.dart';
import '../core/aq/aq_tokens.dart';
import '../core/aq/aq_typography.dart';
import '../features/viewing/domain/viewing_presentation.dart' show AQTone;
import 'admin_models.dart';
import 'admin_widgets.dart';
import 'admin_ui.dart';
import 'admin_l10n.dart';

/// The documents of one item. Opening one shows the streamed file in a watermarked viewer; a
/// document the service cannot stream is flagged here so the reviewer knows before opening it.
class AdminDocumentList extends ConsumerWidget {
  final List<AdminDocument> documents;
  const AdminDocumentList({super.key, required this.documents});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    if (documents.isEmpty) {
      return AdminNotice(
        icon: 'alert',
        title: tr('No documents were submitted'),
        body: tr('Request a resubmission if documents are required for this item.'),
      );
    }
    return AdminPanel(
      padding: const EdgeInsets.symmetric(vertical: AQSpacing.x2),
      child: Column(
        children: [
          for (var i = 0; i < documents.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AQSpacing.x4,
                vertical: AQSpacing.x2,
              ),
              child: Row(
                children: [
                  AQIcon(
                    documents[i].available ? 'shield' : 'alert',
                    size: 20,
                    color: documents[i].available ? c.accent : c.danger,
                  ),
                  const SizedBox(width: AQSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          documents[i].label,
                          style: AQTypography.of(context, AQText.titleSmall),
                        ),
                        Text(
                          documents[i].available
                              ? documents[i].fileName
                              : 'Not available to view',
                          style: AQTypography.of(
                            context,
                            AQText.bodySmall,
                            color: documents[i].available
                                ? c.inkSoft
                                : c.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AdminTextButton(
                    label: tr('View'),
                    color: c.accent,
                    onPressed: () =>
                        showDocumentViewer(context, ref, documents[i]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Earlier decisions on the item, newest last: who, when, what, and the reason given.
class AdminHistoryList extends StatelessWidget {
  final List<DecisionRecord> history;
  const AdminHistoryList({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    if (history.isEmpty) {
      return Text(
        'No decisions have been recorded yet.',
        style: AQTypography.of(context, AQText.bodyMedium, soft: true),
      );
    }
    return AdminPanel(
      padding: const EdgeInsets.all(AQSpacing.x4),
      child: Column(
        children: [
          for (final r in history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AQSpacing.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AQStatusPill(
                    label: decisionLabel(r.decision),
                    tone: r.decision == Decision.approve
                        ? AQTone.success
                        : (r.decision == Decision.reject
                              ? AQTone.danger
                              : AQTone.warning),
                    icon: r.decision == Decision.approve
                        ? 'check'
                        : (r.decision == Decision.reject ? 'close' : 'refresh'),
                    dense: true,
                  ),
                  const SizedBox(width: AQSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.byName} · ${shortDate(context, r.at)}',
                          style: AQTypography.of(context, AQText.bodyMedium),
                        ),
                        if (r.reason != null)
                          Text(
                            reasonLabel(r.reason!),
                            style: AQTypography.of(
                              context,
                              AQText.bodySmall,
                              color: c.inkSoft,
                            ),
                          ),
                        if (r.note.isNotEmpty)
                          Text(
                            r.note,
                            style: AQTypography.of(
                              context,
                              AQText.bodySmall,
                              soft: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A checklist the reviewer ticks before approving. State lives in the page; the decision panel
/// only needs to know whether it is complete.
class AdminChecklist extends StatelessWidget {
  final List<(String id, String label)> items;
  final Set<String> done;
  final bool enabled;
  final void Function(String id, bool value) onChanged;
  const AdminChecklist({
    super.key,
    required this.items,
    required this.done,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AQSpacing.x4,
        vertical: AQSpacing.x2,
      ),
      child: Column(
        children: [
          for (final i in items)
            AQCheckRow(
              value: done.contains(i.$1),
              label: tr(i.$2),
              onChanged: enabled ? (v) => onChanged(i.$1, v) : (_) {},
            ),
        ],
      ),
    );
  }
}
