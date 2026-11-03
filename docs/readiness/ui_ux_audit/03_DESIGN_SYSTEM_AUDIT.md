# 03. Design system audit

Read-only. Question asked: is there a central design system, who uses it, and can it carry a premium Liquid Glass direction?

## 1. Files that define a system (three overlapping layers)

| Layer | Files | Role today |
|---|---|---|
| **AQ Experience System (the live one)** | `lib/core/aq/aq_tokens.dart` (colours, spacing, radii, elevation, icon sizes, control sizes, motion, layout), `aq_typography.dart` (`AQText` roles, `AQTypography.of`), `aq_primitives.dart` (buttons, icon, pressable, surface, icon button, text button), `aq_scene.dart` (backdrop, top bar, choice tile, glass nav, route transitions, step switcher, sheet rows), `aq_forms.dart` (fields, segmented, banners), `aq_status.dart` (status pill), `aq_documents.dart`, `aq_help.dart`, `aq_demo.dart`, `aq_auth_scaffold.dart`, **new** `aq_glass.dart` | Every customer and business screen reads `AQColors.of(context)`, `AQSpacing`, `AQRadius`, `AQMotion`, `AQTypography.of(context, AQText.x)` |
| Brand tokens | `lib/core/brand/brand_tokens.dart` (`BrandColors` mocha `#825C3F`, deep mocha `#674830`, ivory `#ECE3D7`, ink `#2D2823`...; `BrandSpace`, `BrandRadius`, `BrandSize`, a brand `ThemeData` with button themes) | imported by 2 files (the theme builder and a startup file); duplicates the AQ values |
| Legacy theme | `lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_theme.dart`, `app_typography.dart` | `main.dart:37` still sets `theme: AppTheme.light` and an inline `darkTheme: ThemeData(...)`; `app_typography.dart` is imported by **0** files; `AppColors/AppSpacing/AppTypography` have 75 references |

So: one real system (`core/aq`) and two vestigial ones. Admin has its own sizing/buttons (`lib/admin/admin_ui.dart`: `AdminSize`, `AdminButton*`, `AdminChip`, `AdminIconButton`) on top of the AQ tokens.

## 2. Tokens in detail

- **Colour (`AQColors`, light and dark, 16 roles):** `background #EDE1D4` / `#1A1613`, `surface` (72% translucent) and `surfaceRaised #FBF7F1` / `#2A231D`, `surfaceSelected`, `ink`, `inkSoft`, `inkFaint`, `hairline`, `accent #825C3F` / `#B98A64`, `accentDeep`, `onAccent`, `accentDisabled`, `danger`, `success`, `warning`. Interpolated by `AQThemeTransition`. **No tokens** for champagne/metallic highlight, olive (the brief's selected state) or glass fill: olive appears only as a per-role accent (`roleAccent`, `role_home_widgets.dart`), glass tint is hard-coded in `aq_glass.dart` (`0xFFF7EFE4` / `0xFF2A231D`).
- **Typography:** families bundled locally: Fraunces (display/headline, `editorial` roles), PlusJakartaSans (interface), IBMPlexSansArabic (Arabic, with PlusJakartaSans fallback). 15 roles from `displayLarge 46` to `labelSmall 11`; Arabic uses its own family and a 0.92 scale on editorial roles. `labelSmall` is 11 px with 1.4 letter-spacing (used for eyebrows and KPI labels; small and low contrast on tinted cards).
- **Spacing:** `AQSpacing` x1 = 4 up to x10, `gutter 24`, `maxContent 520`. **Radius:** small 10, medium 18, large 28. **Elevation:** `none/subtle/floating/modal`. **Icon sizes:** 18/22/26/28. **Controls:** tap 48, button 56 (compact 50), field 56.
- **Motion:** `AQMotion` (see doc 10), the most complete part of the system.
- **Breakpoints:** none centralised. Literals found: `kWorkspaceRailFrom = 700` (`agent_shell.dart:152`), `aqTileColumns` 640 / 1000 (`aq_tiles.dart`), Admin 960 (frame), 900 (table), 600 (rail, new), phone checks at 340 / 350 / 360 / 380 / 400 scattered through ~20 widgets, `AQLayout.compact`.
- **Arabic / RTL:** `Directionality`-aware widgets (`EdgeInsetsDirectional`, `PositionedDirectional`, `directional: true` icons); separate family and line-height. Strings: `FlowStrings` with per-feature maps (`flow_strings.dart`, `hub_strings.dart`, `role_home_strings.dart`, `db_strings.dart`, `analytics_strings.dart`, `admin_strings_ar.dart`); Arabic marked "draft copy" in several files.

## 3. Who follows the system and who does not

Static counts (lib only): `Color(0x` literals: core 97, features 58, admin 2; `Colors.white/black`: core 12, features 37; literal `BorderRadius.circular(<number>)` 51 against 164 uses of `AQRadius`; literal `EdgeInsets` with numeric values and no `AQSpacing` 105; literal `Duration(milliseconds)` 64; `BoxShadow(` 14 versus 12 uses of `AQElevation`.

Highest concentrations of off-system styling:

| File | Literal colours | Note |
|---|---|---|
| `features/workspace/aq_home.dart` | 15 | hero gradients, scrims (`bg.withValues`, black overlays) |
| `features/role_home/role_home_widgets.dart` | 12 | photo-panel scrim and ivory button (`0xFFFBF7F1`, `0xFF2D2823`), kicker `0xFFF0DCC0` |
| `features/property/property_gallery_screen.dart` | 9 | dark viewer chrome |
| `features/property/property_detail_screen.dart` | 4 | |
| `features/analytics/analytics_charts.dart` | 3 | palette extras (`0xFFB59A7C`, `0xFF7C8B6F`, `0xFFC08A6B`) |
| `core/aq/aq_scene.dart`, `aq_primitives.dart`, `aq_documents.dart` | many (97 in core) | mostly inside the system itself (shadows, scrims) |
| `features/workspace/aq_tiles.dart`, `aq_home_services.dart` | 1 each | photo scrim stops |

Inconsistent patterns observed:
- Three "photo overlay card" implementations with different scrims and radii: `_PhotoTile` (`aq_home_services.dart`, Home), `AQPhotoTile` (`aq_tiles.dart`, Explore), `RolePhotoPanel` (`role_home_widgets.dart`, business homes), plus `AQBanner` and `AQActionCard` in `aq_home.dart` / `aq_action_card.dart`.
- KPI cards: `KpiTile` (analytics), agent dashboard `AQSurface` tiles (now `KpiTile`), `RoleNumberCell` (unused after the redesign), admin stat tiles (`AdminPanel` in `admin_modules.dart`).
- Two pill/chip systems for customers (`AQChoicePill` in `aq_filter_sheet.dart`, `DbPillRow`/`DbSegmentedTabs` in `db_widgets.dart`) and a third for Admin (`AdminChip`).
- Switch visuals: `DbSwitch` (new), `SwitchRow` (`settings_screens.dart`), `SwitchRowLike` (`business_settings_screen.dart`), `AQSlideSwitch` (`aq_home.dart`), `AQCheckToggle`.

## 4. Can it support a premium Liquid Glass direction?

Mostly yes, with additions:
- **Already there:** `AQColors` with a translucent `surface`, a real `BackdropFilter` navigation bar, `AQElevation`, token-driven motion with reduced-motion handling, theme cross-fade, and (new) `AQGlass` with high-contrast fallback and per-blur control.
- **Missing foundations (do these before screens):**
  1. Glass tokens in `AQColors` (fill, edge, highlight, shadow) instead of constants in `aq_glass.dart`; a champagne highlight and an olive selected-state token.
  2. A small set of semantic surfaces (page, card, raised card, glass, glass-on-photo) so screens stop hand-composing `Container + BoxDecoration`.
  3. A single photo-overlay card family replacing the three above.
  4. Central breakpoints (`AQBreakpoints`) and a `Responsive` helper.
  5. Delete or fold the legacy theme (`core/theme/*`) and the duplicate brand tokens into `core/aq`.
  6. Contrast review (computed WCAG ratios): `inkFaint #766B60` on page `#EDE1D4` = **4.04:1** (below the 4.5:1 needed for small text; 4.87:1 on `#FBF7F1` cards); `inkSoft` 5.09:1; `accent #825C3F` on page 4.60:1; white on accent 5.91:1; dark theme `inkFaint` 5.13:1, `accent` 5.89:1. The small 11 px `labelSmall` role and the faint hints sit in the failing band on the page background.
- **Cost risk:** every glass surface is a backdrop layer. A budget of at most three per phone screen and an opaque fallback on low-power/high-contrast needs to be part of the system, not decided per screen.
