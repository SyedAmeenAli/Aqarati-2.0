# 09. Admin Console responsive audit

Read-only. The Admin recording itself was not available to me as a file; this audit is from the code and from screenshots of the demo admin build at 390 px (and 320 / 768 / 1280 where noted in `14_SCREENSHOT_INDEX.md`). Files under `lib/admin/`. State of the working tree, which already includes a local mobile pass (compact app bar, bottom bar, rail, wrapped filters); the "before" is described where it explains the recordings.

## 1. Architecture

| Item | Where | Behaviour |
|---|---|---|
| Router | `admin_app.dart: buildAdminRouter` | 21 routes: `/overview`, `/accounts[/:id]`, `/reports[/:id]`, `/m/:key[/:id]` (9 modules via `ModKey`), `/analytics`, `/settings`, `/audit`, `/login`, `/code`, `/verification[/:id]`, `/moderation[/:id]`, `/ads`, `/ads/new`, `/ads/:id/edit` |
| Frame | `AdminFrame` (`admin_widgets.dart:~285`) | ≥ 960 px: permanent `_Sidebar` (244 px) + content (max 1240). 600-959: `_Rail` (80 px) + compact bar. < 600: compact bar + `_BottomNav` + `Drawer` |
| Phone bar (local) | `AdminFrame` narrow branch | menu button, logo, "Admin", language button; 52 px; bottom bar: Overview, Accounts, Listings, More (opens the drawer) |
| Drawer | `Drawer(width: min(320, 0.86 x screen))` containing `_Sidebar(inDrawer: true)` | independent scrolling list, close button, 36 px rows; opens from the start edge (right in Arabic) |
| Tables | `AdminTable` (`admin_widgets.dart:~545`) | ≥ 900 px a real table with a 12 px gutter; < 900 each row becomes a card: first cell as heading, remaining cells in two-column label/value pairs, action cells full width |
| Filters | `adminFilterRow`, `AdminChip` | label above the chips on narrow screens, chips wrap (local; before: one horizontally scrolling line that cut labels such as "Real Estate Agent") |
| Key-value panels | `AdminKeyValues` | **fixed 148 px label column** |
| Language | `AdminLangButton`, `admin_l10n.dart`, `admin_strings_ar.dart` | per-string map `tr()`; RTL via `Directionality` |
| Back | `AdminFrame.onBack` + `AdminTextButton(compact: false)` (44 px, local) | parent list, not history |

## 2. Findings per area

1. **Desktop layouts on phone that remain**
   - `AdminKeyValues` (Settings, every detail page, viewing detail): 148 px label + value leaves ≈ 100 px for the value at 320 px; values such as "Simulated. Nothing protects this console." wrap into a narrow column (seen in `admin_settings_390`).
   - Overview stat tiles (`admin_directory_screens.dart`, `AdminPanel` tiles): two columns of unequal height because heights follow content (visible in `admin_overview_390`: "Accounts" tile shorter than its neighbour).
   - Analytics tiles (`admin_modules.dart` `tile()`): width computed from the screen, two columns on phone; sample tiles flagged in text.
   - Forms (`admin_ads_screens.dart` create/edit banner, `admin_verification_screens.dart` decision form): single column but with desktop-sized dialogs (`AdminDialog` width 420).
2. **Tables → cards** works everywhere `AdminTable` is used (accounts, reports, verification, moderation, ads, activity log, module lists). Cards show the heading cell first then label/value pairs; the heading cell now carries a 52 px thumbnail for modules (`admin_images.dart`).
3. **Persistent focus ring on the menu button** (a brown outline) appears in every scripted phone screenshot. It is the app's keyboard focus ring (`aq-focus-ring` in `web/index.html`) and appears because the test click helper falls back to keyboard focus; **not verified** on a real touch device.
4. **App bar** has no page title: it shows the brand and "Admin" on every page, so the current page is known only from the bottom bar highlight (More for everything else).
5. **Bottom bar "More"** is selected for any page outside the three primary ones, including Verification, Moderation and Ads; the drawer shows the true current item.
6. **Drawer** is solid; no scrim blur; the footer (Profile, language, session, Sign out) takes ~170 px so on 320 × 568 the module list scrolls within ~330 px.
7. **Arabic RTL:** drawer, bottom bar order, back chevron and tables mirror; strings come from one map (`admin_strings_ar.dart`) with an automated test (`test/admin_arabic_test.dart`) that fails on untranslated UI text. Arabic screenshots: see index (`admin_*_390_ar`).
8. **Status labels:** pills (`adminStatusPill`, `AQStatusPill` dense) are 10-11 px text on tinted fills; icon plus text; acceptable but small.
9. **Detail pages** (`AdminModuleDetailScreen`, `AccountDetailScreen`, `ReportDetailScreen`, `VerificationDetailScreen`, `ModerationDetailScreen`): Back link, title, status chip, (local) hero photo 160 px, key-values, actions at the bottom as buttons that wrap.

## 3. Recommended pattern per page

| Page (file) | Phone pattern | Wide pattern |
|---|---|---|
| Overview (`admin_directory_screens.dart: AdminOverviewScreen`) | equal-height stat grid; attention list as compact rows | stat row + two-column attention and activity |
| Accounts, Agents/brokers, Reports, Activity (`admin_directory_screens.dart`, `admin_modules.dart`) | cards with identity first (avatar/icon, name), status pill, two key facts, expandable rest | table |
| Verification, Moderation (`admin_verification_screens.dart`, `admin_moderation_screens.dart`) | card queue with claim state and age; detail as full screen with sticky decision bar | table with side detail |
| Property listings and project/company/design modules (`admin_modules.dart`) | image-led cards (done locally) | table with thumbnail column |
| Ads (`admin_ads_screens.dart`) | creative-led cards, actions in an overflow sheet | table |
| Analytics (`admin_modules.dart: AdminAnalyticsScreen`) | two-up tiles with proper charts | tiles + charts |
| Settings, details (`AdminKeyValues`) | stacked label over value (replace the fixed 148 px column) | two columns |
| Filters | wrap chips, or one "Filters" bottom sheet when more than two groups (Accounts has Role and Status = 13 chips today) | inline |
| Dialogs (`adminConfirm`, `AdminDialog`) | bottom sheets on phone | centred dialogs |
| Navigation | bottom bar + drawer (done), add current page title in the bar | sidebar |

## 4. Open issues
- No Admin screen was inspected on a real device; widths below 320 not tested.
- `/ads/:id/edit` could not be exercised because the demo store starts without banners.
