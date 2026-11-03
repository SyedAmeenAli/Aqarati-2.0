import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../media/aq_media.dart';
import '../viewing/widgets/viewing_scaffold.dart';

export '../media/aq_media.dart' show AQAvatar, AqMediaImage, ProfilePhoto, profilePhotoProvider;

/// `/app/account/photo`: the person's own photo, through the same media field, sheet and editor as every
/// other picture in the app. The change applies everywhere only after Save. Nothing is uploaded in this preview.
class ProfilePhotoScreen extends ConsumerStatefulWidget {
  const ProfilePhotoScreen({super.key});
  @override
  ConsumerState<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends ConsumerState<ProfilePhotoScreen> {
  AqMediaImage? _draft;
  bool _inited = false;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final saved = ref.watch(profilePhotoProvider);
    if (!_inited) {
      _inited = true;
      _draft = saved;
    }
    final changed = _draft != saved;
    return AQViewingScaffold(
      title: f.t('pp.title'),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/app/account'),
      bottom: AQBottomActionBar(
        primary: AQPrimaryButton(
          label: f.t('pp.save'),
          trailingChevron: false,
          onPressed: changed
              ? () {
                  ref.read(profilePhotoProvider.notifier).state = _draft;
                  context.go('/app/account');
                }
              : null,
        ),
        secondary: AQSecondaryButton(label: f.t('common.cancel'), trailingChevron: false, onPressed: () => aqBack(context, '/app/account')),
      ),
      children: [
        Center(child: AqMediaField(kind: AqMediaKind.avatar, value: _draft, onChanged: (v) => setState(() => _draft = v))),
        const SizedBox(height: AQSpacing.x4),
        Text(f.t('pp.note'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      ],
    );
  }
}
