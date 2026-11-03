# Final product gap closure

Date 2026-11-01. Local working tree on `main` (HEAD `e90590b`); nothing is committed, pushed or deployed. Frontend only: no backend, no real authentication, no real publishing.

This pass closes the five gaps the last review left open. It starts from the earlier master pass (minimal Home, Properties landing, Explore, settings, role analytics, bilingual RTL, bundled fonts) and does not redesign any working screen.

> **Superseded in part (2026-11-01):** on phones the bar now shows four destinations plus More, and the rail from 700 px shows all six. See `VISUAL_QA.md`. The route and tab tables below describe the full set.

## 1. Professional navigation: closed

Each of the five roles now has six destinations of its own, in the approved order, with Analytics as its own tab. The tables are in `ROUTE_MATRIX.md` sections 3 and 4.

| Role | Tabs |
|---|---|
| Real Estate Agent | Dashboard, Listings, Contacts, Calendar, Analytics, More |
| Development company | Overview, Projects, Units, Enquiries, Analytics, Company |
| Construction company | Overview, Projects, Requests, Services, Analytics, Company |
| Architecture | Studio, Portfolio, Projects, Briefs, Analytics, Profile |
| Interior & exterior design | Studio, Portfolio, Services, Engagements, Analytics, Profile |

- The five sets are all different; a test asserts it.
- **Narrow screens.** All six tabs stay in the bar at every width: the bar grows to 500 px on wider phones and the labels scale down at 320 px (each tab 48 px wide). Nothing moves behind a menu. The last tab (Company, Profile or More) is a hub that holds Business settings, reviews, verification status and the role's destinations that are not tabs (Construction: Portfolio and Engagements; Architecture: Engagements; Interior: Enquiries and Projects; Development: Engagements).
- **New screens** (`lib/features/pro/pro_tab_screens.dart`): `/pro/units` (development), `/pro/projects` (construction, architecture), `/pro/services` (construction, interior). Their figures are local deterministic samples and say so on screen.
- **Wide screens.** The side rail now lists the same six destinations.
- **A defect found and fixed on the way.** On screens 900 px and wider, the side rail of every business workspace (agent included) was **missing from the accessibility tree**: the page's own navigator blocks the semantics of anything painted before it, and the rail came first in a `Row`. Screen readers and keyboard users could not reach it. The rail is now painted after the content and placed at the start edge (`PositionedDirectional`), and its separator is `BorderDirectional`, so it also mirrors in Arabic. Covered by `test/workspace_rail_semantics_test.dart`.

Files: `lib/features/pro/pro_shell.dart`, `lib/features/pro/pro_tab_screens.dart`, `lib/features/agent/agent_shell.dart`, `lib/features/agent/agent_routes.dart`, `lib/core/router/app_router.dart`, `lib/core/aq/aq_scene.dart` (bar width), `lib/features/analytics/analytics_screens.dart` (Analytics is a tab, no Back), `lib/core/localization/hub_strings.dart`.

Tests that changed with the approved structure (assertions replaced, not dropped): `test/pro_workspace_test.dart` (14 index and count expectations of the old five-tab bar replaced by 26 for the six-tab bars, including the label sets of all four roles) and `test/agent_workspace_test.dart` (tab indices, the destination list).

## 2. Additional business services and Explore discovery: closed (local fixtures)

- **One business, one record.** `DbProfessional` gains `extraTypes` and `extraServiceType`. The primary role stays in `type`; `allTypes` lists the primary first. Nothing is duplicated.
- **Fixtures.** Sahari Contracting (construction, also interior design), Zahra Developments (developer, also construction), and Namaa Construction (the mock record that already carries construction and development, now read as one business with an additional service).
- **Explore.** A business appears once under every category it offers. The interior/exterior filter reaches an additional interior or exterior service and only the side it offers. A category it does not offer does not list it. The developer rule (only with an approved project) stays under Developers.
- **Result cards** name the primary role and the extra ("Construction Company · also Interior design").
- **Public profile.** A "Service categories" block marks the primary one, and a line says it is one business listed in each category. Profile links from a category carry `?svc=<category>`.
- **Enquiry context.** The contact sheet names the service the visitor browsed from ("Enquiry about: Interior design"); from the primary category no such line is invented.
- **The signed-in business.** The additional services chosen in Business settings (or the new Services tab) reach `myOrganisation()`, so the same record shows the same categories in the Services preview. The business is **not** inserted into the public directory: nothing is published or synced, and the screen says so.

Files: `lib/features/devbuild/db_models.dart`, `db_repository.dart`, `db_profile.dart`, `db_widgets.dart`, `db_discovery.dart`, `db_routes.dart`, `db_strings.dart`. Tests: `test/business_services_discovery_test.dart` (15), `test/pro_tab_screens_test.dart` (7).

## 3. Admin Console in Arabic with right-to-left layout: closed

- **How.** The console stays written in English. `lib/admin/admin_l10n.dart` looks every string up in `lib/admin/admin_strings_ar.dart` (about 650 exact strings and about 60 patterns for text built from parts) when the app language is Arabic. Admin files use a `Text` that translates, and the shared admin widgets translate the strings they pass to shared components (status pills, fields, checklists, banners, semantics). A runtime collector (`AdminLang.missing`) records any string with no translation, and a test fails if one appears.
- **Same language switch as the app.** The console reads and writes the app's `localeProvider`. A language button (English / العربية) is on sign-in, the one-time code step, the sidebar and the narrow top bar. The choice persists across reloads through the app's own storage, and switching rebuilds the whole console.
- **Covered:** sign-in, the illustrative one-time code, sidebar and drawer, Overview, metrics and the accounts-by-role bars, Accounts and detail, Verification and detail, Moderation and detail, Property listings, Agents and brokers, Development projects, Construction, Architecture and design, Maintenance, Viewings and requests, Ads and sponsors (list, form, validation, preview), Announcements, Categories and content, Reports and detail, Activity log, Analytics, Profile and settings, dialogs, validation, empty and error states.
- **RTL geometry** (not right-aligned English): the sidebar is on the right; the page heading, tables and columns run right to left; forms, the Back control and chevrons mirror; the narrow menu button is at the right edge and the language button at the far end; mobile records are cards. Verified in widget tests and in the browser at 320, 390, 768 and 1280 px.
- **Numbers.** Counts and amounts use Arabic-Indic digits like the rest of the Arabic app; identifiers (R3, U1), e-mail addresses and money written as "OMR 185,000" keep theirs. Dates and times use the app's Arabic formatter.
- **Names.** Genuine proper names (people, businesses, places) stay as written; the descriptive words around them ("(demo)", "(sample)", roles, statuses, notes) are translated. The fictional sample campaigns use the Arabic the customer app already shows for them.
- **Fonts.** IBM Plex Sans Arabic (bundled), through the same typography the rest of the app uses.
- Arabic copy is **draft** and needs a native review.

Files: `lib/admin/admin_l10n.dart`, `admin_strings_ar.dart`, `admin_app.dart`, `admin_widgets.dart` (language button, sidebar, directional padding), `admin_auth_screens.dart`, `admin_ui.dart`, and the other admin screens (imports and wrapped labels). Tests: `test/admin_arabic_test.dart` (6: every screen translated, interactive states, language switch, right-to-left geometry at four widths, digits). The English console tests (`admin_console_test`, `admin_directory_test`, `admin_modules_test`, `demo_admin_test`, `admin_demo_entry_test`, `ebroker_admin_link_test`) pass unchanged.

## 4. Password change flow: closed (frontend prototype)

`/app/account/settings/password` (and the same page under business settings, `/pro/settings/p/password`, `/agent/settings/p/password`):

- Current, new and confirm fields, each with its own show/hide control.
- A live requirements list (8 characters, a number, different from the current one, matches the confirmation), with a text state per rule, not colour alone.
- Clear error states (missing current password, too short, no number, same as current, mismatch).
- On acceptable entries the page shows **"Simulated confirmation"** and says no password was changed and nothing was sent; it never shows a server success. A button returns to Account and security.
- The Security page links to it. The page also says up front that there is no sign-in service behind this prototype.

Files: `lib/features/settings/settings_screens.dart`, `lib/core/localization/settings_strings.dart`, routes in `app_router.dart`, `extra_routes.dart`, `agent_routes.dart`. Tests: `test/settings_test.dart` (the earlier password assertions moved to the new page, plus rules, toggles and same-password cases). The old inline "Check password" control is replaced by this flow.

## 5. Typography fallback: audited, none found on the screens checked

- **Method.** `test/typography_audit_test.dart` walks every paragraph and editable text on 10 screens in English and Arabic (settings and password, business settings, the pro hub, Units, Projects, Services), dialogs and their buttons, and typed text in fields. A paragraph fails if its primary family is not one of the three bundled families, or if Arabic text is not followed by the Arabic family. A negative control proves the check flags a `Roboto` style and an Arabic string with no Arabic fallback.
- **Result.** No screen audited draws a style with a system or default font. Headings use Fraunces; body, buttons, inputs, navigation, tables and analytics use Plus Jakarta Sans (Latin) or IBM Plex Sans Arabic; Arabic text reaches IBM Plex Sans Arabic in every style.
- **One real gap closed:** `ThemeData` now carries `fontFamilyFallback: IBMPlexSansArabic`, so Material defaults that bypass the text theme (dialogs, tooltips, menus) also reach the Arabic family before any system font. The logo's accessible name is Arabic in Arabic.
- **Browser and offline** (`j95_fonts.js`): with every request that leaves localhost aborted, English and Arabic customer, business and admin screens render, no request fails, and only the bundled font files and the local CanvasKit load. The engine's own default fallback file (`Roboto-Regular.ttf`, served locally) is always present; it is used only for a glyph none of the three bundled families has.
- **Not proven:** the check covers the screens listed. Screens added later, or user-entered text with rare characters, can still fall back to the system font for those glyphs.

## 6. Verification (this pass)

| Check | Result |
|---|---|
| Full tests, demo OFF (default) | **1041 passed, 17 skipped** (the skips need demo mode) |
| Full tests, demo explicitly ON | **1056 passed, 2 skipped** (the skips apply only to a normal build) |
| `flutter analyze` | **0 errors**, the 2 existing warnings in `test/devbuild_stabilisation_test.dart` (unused `failFirst`, `gate`), 52 infos |
| Builds | default (`build/web`), demo (`build/web_demo`, demo and review tools on), admin (`build/web_admin`): all succeeded with `--no-web-resources-cdn` |
| Earlier browser suites on the final bundle (`j80`, `j82`, `j90`, `j42`, `j44`) | **230 of 230** (81 + 29 + 42 + 70 + 8) |
| Role navigation, browser (`j95_nav`, `j95_widths`) | **185 of 185**: five roles, every tab opens its route, six tabs inside the screen at 320, 360, 390, 412, 430, 768, 1024 and 1280, side rail at 1024 and 1280, three roles in Arabic |
| Service discovery, enquiry context and the password prototype, browser (`j95_disc`) | **38 of 38**, English and Arabic |
| Admin Console in Arabic, browser (`j95_admin`) | **35 of 35**: sign-in, one-time code, 18 screens with no English interface text, sidebar on the right, reload keeps Arabic, switching back, 320 / 390 / 768 drawer and cards |
| Fonts and offline, browser (`j95_fonts`) | **11 of 11** |
| **Browser total** | **499 checks, 0 failures** |

New tests this pass: 6 (admin Arabic) + 15 (discovery) + 7 (pro tab screens) + 6 (rail semantics) + 23 (typography audit) + 3 (password) = 60, plus the changed navigation tests above. No existing test was removed or weakened; the only replaced assertions are those of the old five-tab bars, listed in section 1.

## 7. Remaining limitations

See `KNOWN_LIMITATIONS.md`. In short: the Arabic copy (customer, business and admin) is draft; Units, Projects and analytics are labelled sample data; the signed-in business is not inserted into the public directory; there is no real authentication, password change, publishing or syncing; a real screen reader and non-Chromium browsers were not run.
