# Visual quality pass

Date 2026-11-01. Local working tree on `main` (HEAD `e90590b`); nothing is committed, pushed or deployed. Frontend only. The approved colours, the AQARATI marks, the two editorial and UI typefaces and the existing motion language are unchanged. This pass changes layout, proportion, hierarchy and motion.

Evidence: `VISUAL_QA_INDEX.md` (every screen, route, viewport, before and after file). Images: `evidence/browser/v96_before_*`, `v96_after_*` (plus `_ar_` and `_dark_`), and `m96_*` from the navigation run.

## 1. The two supplied screens

### Construction Company Home (343 x 706)
| Problem in the screenshot | What it is now |
|---|---|
| Brand mark and a large heading used the first third of the screen | Logo 64 px with the workspace label beside it, one 28 px title. The hero now starts at y = 167 px instead of y = 225 px (measured on the 343 px screenshots) |
| Hero too tall | Hero capped at 188 px on phones (it was 257 px; 300 px cap on wide screens); its title is 24 px; text stays readable on the dark gradient |
| "Review Business" card squeezed, with a second notice card hidden behind the bar | One status card that fits the content width: name, one state line with a colour dot, one hint, one action. It is above the fold |
| Two conditions merged | Kept apart: **Awaiting review** (the account, set by the review process, never by this screen; the workspace only opens for approved accounts, so this state is handled but not normally reached) and **Profile incomplete** / **Profile complete** (the public profile). Nothing is marked approved or verified by this screen |
| Six squeezed navigation labels | Four destinations plus More (see 2) |
| Operations buried | KPI strip (requests, waiting, completed) directly under the status card; the one sponsored banner comes after the company's own information, using the shared component, in the construction audience |

Files: `lib/features/role_home/home_construction.dart`, `role_home_widgets.dart`, `role_home_strings.dart`.

### Sahari Contracting profile (322 x 705)
| Problem | Fix |
|---|---|
| Gallery took the first screen | A fixed 16:9 gallery capped at 240 px. Previous and Next photo controls (named for assistive technology, mirrored in Arabic), a photo counter, a swipe, and a fade when each photo is decoded |
| Weak identity hierarchy | Logo (or a monogram tile), the name with the verified mark beside it so it never wraps alone, Construction Company, "Also offers: Interior design" as a tag, Sohar, Oman. At 320 px the name steps down one size so the mark stays on its line |
| Rating and verification in a narrow card wrapped to three lines | One full-width band of equal columns: rating 4.6 and 31 reviews on one side, the shield with "Verified" and "Approved business" on the other. Under 260 px of content, or at large text, the two stack. It is flagged as a **sample record** in demo builds, because the rating, reviews and verification are demo data |
| Pill tabs | A segmented control with a sliding thumb; the content below cross-fades and really changes |
| Many unrelated boxes | Plain sections: About, Service categories (primary marked), Location; bordered boxes only for the rating band |
| Contact bar covered content | The bar is now a separate row under the scroller, 4 px shorter, and the scroller ends with 32 px of padding so the last service, project or detail can be read above it |

Files: `lib/features/devbuild/db_profile.dart`, `db_widgets.dart` (`DbSegmentedTabs`), `viewing_scaffold.dart` (`AQBottomActionBar`), `aq_home.dart` (`aqImg` fade).

## 2. Professional navigation on narrow phones
- **Under 700 px:** four destinations plus More. **700 px and up:** the side rail with every destination. A phone bar is never stretched across a tablet or desktop.
- Agent: Dashboard, Listings, Contacts, Calendar, More. Development: Overview, Projects, Enquiries, Units, More. Construction: Overview, Projects, Requests, Services, More. Architecture: Studio, Portfolio, Projects, Enquiries, More. Interior and exterior: Studio, Portfolio, Services, Engagements, More.
- **More** is a hub that lists Analytics first, then the public profile, Business settings and the destinations not on the bar, reviews, verification status. It stays the selected tab on all of them. Titled "More" on phones, Company or Profile in the rail.
- No label is shrunk to a small size: at 320 px each tab is 62 px wide with a 10.5 px label (11 px on four-tab bars). The longest label, Engagements, fits at 343 px. The bar margin is 4 px under 380 px.
- Tested: tabs in order left to right (right to left in Arabic), each at least 54 px wide, inside the screen, one history write per tap, every destination reachable, no overflow, at 320, 343, 390, 430 (bar) and 768, 900, 1024, 1280 (rail) for all five roles.

## 3. Other screens refined
Screen titles are one size (28 px) everywhere; role homes share a compact header and a capped hero; two hero actions share a row; the agent pages put their action under the title on narrow phones (the "Contact / s" break is gone); Units gets a stock bar per project; settings label/value rows stack on narrow phones; the entry logo is smaller; photographs everywhere ease in. Screens were reviewed one by one in screenshots for customer Home, Properties, Explore, results, Account and Settings, Activity, the agent's five pages, the four business roles' home, projects, units, services, portfolio and More pages, and the admin overview on mobile.

## 4. Consistency
- One screen-title size (28 px), one hero cap, one bar (margins, label size, tab width), one segmented control, one band pattern for stats, status dots that use the existing warning and success colours.
- Sample data is labelled where it is shown (Units, Projects, analytics, the demo rating).
- Tokens: spacing, radius, motion durations and type roles already in `aq_tokens.dart` and `aq_typography.dart` are used; no new colour was added.

## 5. Typography
The three bundled families only. Editorial display (Fraunces) is now limited to screen titles, hero titles and the profile name; labels, navigation, tags and values use Plus Jakarta Sans (IBM Plex Sans Arabic in Arabic). The typography audit test (23 cases) still finds no style that would fall back to a system font.

## 6. Motion (verified in the browser, not assumed)
`j96_motion.js` records the frames drawn during each action with a screencast and requires frames that differ from both the first and the last.

| Action | Frames in between | Motion |
|---|---|---|
| Profile Overview to Reviews (thumb slide and content fade) | 8 | about 180 ms |
| Profile back to Overview | 8 | about 150 ms |
| Gallery Next photo | 31 | about 500 ms |
| Gallery Previous photo | 15 | about 230 ms |
| Bar tap (indicator and page) | 2 | about 70 ms, one history write |
| More page | 4 | about 120 ms |
| Home sections ease in on open | 17 | about 700 ms |
| Analytics figures count up and the chart draws | 19 | over 1 s |
| Reduced motion: the same tab switch | none beyond one frame | lands at once |

Existing motion kept: the bar's sliding indicator, press scale, reveal on first entry, page transitions, sheets. Added: segmented thumb, gallery transitions and photo fade (shared by every photograph), KPI count-up (whole numbers only; the final value is the real value), hero actions. KPI values are never random or invented.

## 7. Screenshots and checks
`VISUAL_QA_INDEX.md` lists 33 screens at 320, 343, 390, 430, 768 and 1280 px, each with a before and an after file. Arabic and dark captures (343 and 390) are `v96_after_*_ar_*` and `v96_after_*_dark_*`; the dark ones were taken with the app's dark theme actually set (a first set that only changed the browser colour scheme showed the light theme and was discarded). Entry screens: `v96_after_entry_*`.

## 8. Verification
| Check | Result |
|---|---|
| Full tests, demo OFF | **1043 passed, 17 skipped**, 0 failed |
| Full tests, demo ON | **1058 passed, 2 skipped**, 0 failed |
| `flutter analyze` | 0 errors; the 2 existing warnings (`devbuild_stabilisation_test.dart`); 52 infos |
| Builds | default, demo and admin built with `--no-web-resources-cdn` |
| Browser: earlier suites on the final bundle (`j80` 81, `j82` 29, `j90` 42, `j42` 70, `j44` 8) | 230 of 230 |
| Browser: role navigation, four plus More and rail (`j95_nav`) | 192 of 192 |
| Browser: phone widths 360 and 412 (`j95_widths`) | 20 of 20 |
| Browser: motion frames (`j96_motion`) | 11 of 11 |
| Browser: discovery, profile and password (`j95_disc`) | 38 of 38 |
| Browser: Arabic admin (`j95_admin`) | 35 of 35 |
| Browser: fonts and offline (`j95_fonts`) | 11 of 11 |
| **Browser total** | **537 checks, 0 failures** |

Tests changed with the approved navigation: `pro_workspace_test` (the phone bars are the compact sets; a new test asserts every destination stays reachable), `agent_workspace_test`, `pro_tab_screens_test` (the hub is "More" on phones, role-named on wide screens), `business_services_discovery_test` (the additional service is asserted in its own tag row and once in the identity block). No assertion was removed without a replacement. The browser scripts `j80`, `j82` and `j90` were adjusted for the new paths (Analytics under More, the password form on its own page, a keyboard-focused Muscat chip at large text).

## 9. Remaining visual limitations
- The entry and sign-up forms, property details, the Explore result variants, Activity states and the Settings rows were reviewed in screenshots at 343 and 390 only; apart from the shared title, logo and bar changes they were not redesigned in this pass.
- Property details and the viewing steps were not captured at all six widths.
- Dark mode and Arabic were captured at 343 and 390 for a subset of screens (customer, agent, developer, construction, and architecture and design in dark); the rest were not.
- Motion was measured in headless Chromium frames, not on a real phone. Frame cost on a low-powered device was not measured.
- Admin tables on narrow screens were already record cards; the desktop and tablet admin screens were captured but not changed.
- Sample images are the project's own placeholders; some are darker than others, so hero text relies on the gradient.

---

# Final visual completion pass (2026-11-01, second round)

Index: `VISUAL_QA_INDEX.md`, section "Final visual pass" (60 screens, 6 widths, before and after: `v97_before_*`, `v97_after_*`; Arabic `v97_after_*_ar_*` at 343 and 390; dark `v97_after_*_dark_*` at 343 and 390). Captured routes are listed there with their actual viewport; where a cell is blank the file does not exist. Scripts (kept outside the repo): `j97_shots.js`, `j97_act.js`, `j97_motion.js`, `j97_keys.js`.

## What was done, by area
| Area | Result |
|---|---|
| **Entry, login, signup** | Captured at six widths and reviewed at 343 and 390: welcome, login, forgot password, account type, professional category, interests, documents, verification intro, one-time code, application review and submitted. **Not captured:** the user and business detail forms, password creation and the final success screen. One coordinated look: every title is 28 px (Welcome keeps its display headline, which now steps down on screens under 740 px tall so the account buttons are above the fold), logo marks are one smaller size, validation messages ease in under their fields while the logo, title and fields above do not move (0.00 % of the top 190 px changed in the frame capture). The documents screen shows its error state in the local build because there is no document service |
| **Property details** | The page is now full screen: the tab bar no longer stacks under the pinned Enquire / Book viewing bar (it used about 170 px of a 706 px screen). Gallery, thumbnails, title, price, attributes and the verified line are visible above the bar. Captured for all six sample properties at six widths (sale, rent, plot and commercial examples among them). Whether industrial and agricultural listings use a different layout was not separately verified: the sample data has no such property |
| **Explore** | Maintenance providers: the category chips are one scrolling line (was a four-row cloud). Property results, development, professional and profile layouts were reviewed at 343 and already use different compositions (property card with price, professional card with photo, rating and project count); they were not changed |
| **Activity** | Maintenance, Selling and Professional engagements have their own empty states: a role icon medallion, a title and a three-step "what happens next" list, instead of one shared arch illustration. Populated viewings were reviewed (status pills for completed, declined, upcoming) and not changed. Rejected, in-review and approved selling and engagement states were not driven to each state in the browser |
| **Settings** | Customer: label/value rows stack on narrow phones (security, privacy, about). Business settings reviewed for all five roles at 343; no layout change. The two systems stay distinct |
| **Admin** | Phone and tablet up to 900 px: record cards put fields two to a row, label over value, with a full-width action row; Role/Status/About filters are one scrolling line each (an Accounts toolbar was seven lines); analytics tiles two to a row; the desktop table now starts at 900 px (at 768 its Status column broke "Suspended" into fragments). Reviewed at 320, 343, 390, 430, 768, 900 and 1280 |
| **Navigation** | Re-verified for all five roles (bar, More, rail, Arabic order) |
| **Animation** | Verified in the browser: login and password errors, confirmation swap, filter and sort sheets, gallery, preference switch, viewing filter, project progress bars, admin drawer, record transitions, sidebar page changes, reduced motion |
| **Loading skeletons** | Not added. The existing skeletons (professional lists, profiles, activity rows, role homes) appear only while a real request is pending; the local fixtures answer at once, so no skeleton flashes. Not exercised in the browser |

## Checks that did not fully pass, or were not run
- The headless renderer intermittently crashed ("Target crashed") during long screenshot runs, most often at 768 px and in the dark-mode set. The captures were repeated until every screen in the index existed; widget tests of the same admin screens at 768 px raise no exception. It is an environment instability that was not traced to a code defect, and it was not reproduced on a real device.
- Rejected, in-review and approved activity states, the viewing flow's own steps, the property comparison and map screens, and the admin dialogs (moderation confirmation) were not captured at all six widths.
- Dark mode and Arabic cover 343 and 390 only.
- Not run on real phones or non-Chromium browsers.

## Verification of the second round
| Check | Result |
|---|---|
| Full tests, demo OFF | 1043 passed, 17 skipped, 0 failed |
| Full tests, demo ON | 1058 passed, 2 skipped, 0 failed |
| `flutter analyze` | 0 errors; the 2 existing warnings; 52 infos |
| Builds (default, demo, admin) | all built with `--no-web-resources-cdn` |
| Earlier browser suites (`j80` 81, `j82` 29, `j90` 42, `j42` 70, `j44` 8) | 230 of 230 |
| Role navigation, bars, More, rail, Arabic (`j95_nav`, `j95_widths`) | 212 of 212 |
| Motion (`j96_motion` 11, `j97_motion` 16, `j97_reduced` 1) | 28 of 28 |
| Keyboard (`j97_keys`: Tab and Enter on login, property Book viewing, rail Analytics, More and its Analytics row) | 9 of 9 |
| Discovery, profile, password (`j95_disc`) | 38 of 38 |
| Arabic admin (`j95_admin`), fonts and offline (`j95_fonts`) | 35 of 35, 11 of 11 |
| **Browser total** | **563 checks, 0 failures** |

Test changes in this round: `customer_shell_test` now asserts that `/property/:id` is a full-screen route outside the tab shell (it previously asserted the opposite; the old assertion was replaced, not dropped). The activity empty states and the admin card layout needed no test changes.
The motion check "Property: tapping the heart gives visible feedback" passes on a small changed area only; the heart's own pop animation was not isolated frame by frame.


## Round 3 (v98)

Scope: signup and business details, documents, populated Activity states, the viewing booking walkthrough, Map/Compare/results/professionals, property details for four categories, Admin at three widths, motion, tests. No redesign.

Changes:
- Fictional industrial warehouse (p7) and agricultural farm (p8) fixtures, labelled "(fictional)" and "DEMO RECORD".
- Review-only `?session=activity` seeds fictional Selling submissions and professional engagements (REVIEW_TOOLS builds only).
- `/property/:id` is now a full-screen route outside the tab shell (`customer_shell_test` assertion updated to match).
- Results category chips scroll horizontally.
- Viewing detail action bar stacks under 400 px (fixes "Back to pro/perty" mid-word break at 343).

Documents screen error: not a code defect. It was captured with no session; an unauthenticated visit shows an error frame instead of redirecting. Recorded as a limitation.

Motion verified with CDP screencast frame diffs: heart pop (add and remove), signup step transition, profile loading placeholder (real 220 ms service wait, no artificial delay), Activity tab swap.

Tests after the final change: `flutter test` demo off 1043 passed; demo on 1058 passed; analyze reports no errors (2 pre-existing unused-parameter warnings in `test/devbuild_stabilisation_test.dart`, plus infos); demo web build rebuilt.


## Round 4 (v99) — final visual defect closure

Local only. Nothing committed, pushed or deployed.

Fixed and verified: desktop Property Details (≥1000 px, 1180 px column, gallery beside facts); compact one-row action bars under 400 px (viewing detail, review, conflict); Compare (equal columns with aligned rows at ≥700 px, lettered cards plus one table on phones); lazy live map (idle, then loading, loaded, failed with retry); broker sample names; booking split into a date step and a time step with a progress bar; signed-out `/onboarding/documents` redirect to `/login?next=…`; "Morning" tab wrap; "Similar" label wrap in the conflict bar; Filters (and every `showAQSheet`) sheets now open above the floating tab bar.

Map lifecycle (`lib/core/widgets/map_embed_lifecycle.dart`): no request and no timer until the map is in view or "Show map" is tapped; the 12 s timeout starts at activation; the iframe `load` event is treated as "the embedded document loaded", not "tiles painted" (the embed can still show its plain blue background for a moment after load); retry starts a new attempt with a full timeout; leaving while loading cancels the timer.

Test totals on the final code: demo OFF 1063 passed (17 skipped); demo ON 1078 passed (2 skipped); analyze 0 errors, 2 warnings (`test/devbuild_stabilisation_test.dart`), 55 infos.

See `VISUAL_QA_INDEX.md` for the captured/inspected status of every v99 screenshot.
