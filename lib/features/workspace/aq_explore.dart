import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../search/aq_unified_search.dart';

/// Explore is the one search page of AQARATI: a search field, a category row, one Filters sheet and the
/// results on the same page. Every search bar in the app opens this page; result cards still open their
/// original detail screens. (The old banner-and-tile discovery layout was removed on purpose.)
class AQExploreScreen extends ConsumerWidget {
  final String? initialQuery;
  final bool focus;
  const AQExploreScreen({super.key, this.initialQuery, this.focus = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AQUnifiedSearch(initialQuery: initialQuery, focus: focus);
}
