# Phase 2: customer property discovery, visual redesign (local, uncommitted)

Rule followed: UI/UX only. No route, provider, validation, permission, data-model or flow change. No new feature, filter, step or screen.

## Screens redesigned (all existing)
Explore, property results (`/properties`, `/properties/all`), Search start and Search results, Property details, Gallery, Compare, Saved, Map bottom strip, plus every list that shows properties (broker, business profile).

## Files modified
- `lib/core/aq/aq_glass.dart` (root-cause fix: the warm fill was never painted because a BoxDecoration with a gradient ignores its colour; fill and highlight are now two layers)
- `lib/core/aq/aq_scene.dart` (nav fill 0.88, selected pill alpha)
- `lib/features/workspace/aq_cards.dart` (AQPropertyCard gained `saveAtStart`/`tagAtBottom`; new AQCompactPropertyCard, AQResultGrid, `aqListMaxWidth`; Arabic-safe facts line)
- `lib/features/workspace/aq_home.dart` (AQResultCard now delegates to the Phase 1 card, same constructor plus `compact`; results screen uses AQResultGrid and wider column on tablet/desktop; AQBanner radius 18; `aqPage` column 760 px at tablet, 960 px at desktop)
- `lib/features/workspace/aq_tiles.dart` (tile radius 18)
- `lib/features/search/aq_filter_sheet.dart` (filter button uses the sliders icon, raised-surface pills, editorial results count)
- `lib/features/search/aq_search.dart`, `aq_map.dart` (grid and compact card wiring only)
- `lib/features/property/property_detail_screen.dart` (gallery ratio and photo tags, title/price hierarchy, detail rows with dividers, lister thumbnail, 760 px tablet column)
- `lib/features/property/property_gallery_screen.dart` (image fade-in)
- `lib/features/compare/compare_screen.dart` (RTL-correct table header alignment)

## Phase 1 components reused
AQPropertyCard, AQSaveButton, AQPhotoTag, AQGlass, AQThumb, tokens, AQPressable, AQIcon, AQTextButton, AQSecondaryButton, AQBottomActionBar.

## Behaviour preserved
Card tap opens `/property/:id`; Save toggles the same provider; compare marks, sort, filters, search, gallery, enquiry, viewing and offer controls were not edited beyond appearance. Existing tests were not changed in Phase 2.

## Not changed on purpose (documented, not implemented)
- Saved still uses a single column (compare marks overlay each card).
- Compare's wide layout does not letter its columns like the phone layout does. Functional/visual-parity idea, not implemented.
- The Explore/Results page header still uses the older photo hero (AQHero) with logo, location and avatar; a unified header would be a layout decision.

## Limits
Arabic strings from Phase 1 remain draft. Screens were checked in a headless Chromium build, not on a device. Dark and Arabic were captured at 390 px only.

Evidence: `docs/readiness/evidence/phase2/`.
