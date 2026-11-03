# AQARATI final gap audit (second pass)

Date 2026-10-28. Branch `main`, HEAD `e0a6bc3`. Nothing is committed, pushed or deployed. Backend, database and `aqarati/` untouched.
This replaces the first audit. Where the client's latest instruction differs from older notes, the latest instruction wins.

States: **CV** Complete and verified · **IV** Implemented but not fully verified · **P** Partial · **M** Missing · **BA** Blocked by a missing API · **BD** Blocked by a specific unresolved product decision.
"Verified" means walked in headless Chromium (Playwright, accessibility tree) and/or covered by tests. Nothing is connected to a real service; everything not marked otherwise is demo-only and labelled.

## Master implementation pass (2026-10-31) — current state

Local only. Not committed, pushed or deployed. This section is the latest state; later sections below it are earlier passes. Companion files: `ROUTE_MATRIX.md`, `SCREENSHOT_INDEX.md`, `VIEWPORT_MATRIX.md`, `KNOWN_LIMITATIONS.md`, `NAVIGATION_AUDIT.md`, `ADMIN_ACCESS.md`.

| Gate | Result |
|---|---|
| `flutter test` (demo off, the default) | 981 passed, 17 skipped (they need demo mode), 0 failed |
| `flutter test --dart-define=AQARATI_DEMO_MODE=true` | 996 passed, 2 skipped (they only apply to a normal build), 0 failed |
| `flutter analyze` | no errors; 2 existing warnings in `test/devbuild_stabilisation_test.dart` (unused optional parameters); 52 infos |
| Builds | `build/web` (demo off), `build/web_demo` (demo on + review tools), `build/web_admin`, all with `--no-web-resources-cdn` |
| Browser (`j80` 81, `j82` 29, `j90` 42, `j42` 70, `j44` 8) | 230 checks, 0 failures |

| Area | State | Where | Evidence |
|---|---|---|---|
| Typography | CV | Fraunces, Plus Jakarta Sans, IBM Plex Sans Arabic bundled; `google_fonts` removed; `--no-web-resources-cdn` bundles CanvasKit and the fallback font | `j82`: no request leaves localhost; font files listed in `VIEWPORT_MATRIX.md` |
| Minimal customer Home | CV | `aq_home.dart`, `aq_home_services.dart` | `j80`, `home_banner_test`, 4 widths |
| Properties landing and Buy / Rent / Sell / Favorites journeys | CV | `aq_properties_hub.dart`, router | `j80`, `properties_flow_test` |
| Explore marketplace (4 markets, all types, people) | CV | `aq_explore.dart` | `j80`, `explore_marketplace_test` (7) |
| Customer settings (8 pages) with local persistence | CV | `lib/features/settings/` | `j80`, `j82` reload run, `settings_test` (45) |
| Business settings separate from customer settings, shared language and appearance | CV | `business_settings_screen.dart` | `j80`, `j82`, `settings_test` |
| Role Analytics and KPI strips, five roles | CV (sample data) | `lib/features/analytics/` | `j80`, `analytics_test` (15): same input gives the same series |
| One business account: primary role plus additional services | P | Business settings | Settings model only; not wired into public discovery |
| English and Arabic across all new screens, RTL | CV (copy is draft) | `*_strings.dart` | `j90` 42 checks from a genuine User to Shop demo session |
| Sponsored campaign copy in Arabic | CV | `kSampleCampaignsAr` | `j90` |
| Light and dark themes on the new screens | CV | | `j82` |
| Eight viewport widths | CV | | `VIEWPORT_MATRIX.md` |
| Admin Console | CV, English only | `lib/admin/` | `j42` 70 checks |
| Demo-mode tests in both configurations | CV | `devbuild_workspace_test.dart` | demo off 50/50, demo on 50/50 |

Not done, said plainly: additional services in public discovery; the brief's six-label professional navigation (Analytics and Business settings are under More); email and push channels; real password change; real measurements behind the charts; native-speaker review of the Arabic; Admin Console translation; screen-reader and non-Chromium testing. See `KNOWN_LIMITATIONS.md`.


## Results of this pass

| Gate | Result |
|---|---|
| `flutter test` | 782 passed, 0 failed |
| `flutter analyze` | 57 items, no errors. The earlier baseline was 41. The extra 16 are `curly_braces` lints created when I ran `dart format` over all of `lib/core` by mistake (22 untouched files re-wrapped). Reverting them was blocked, so see "Cleanup you should run" |
| Builds | `build/web` (customer), `build/web_review` (QA), `build/web_admin` (admin): each has `AssetManifest.bin`, `FontManifest.json`, `main.dart.js`; no admin or QA sample code in `build/web` or `build/web_admin` |
| Browser checks | Playwright against the QA bundles; result files `docs/readiness/evidence/browser/j*_results.json`, screenshots beside them |

## Priority 1: sponsored banner (corrected)

The app-wide `AQBannerFrame` is **removed**. The banner is now mounted in exactly one place: the User to Shop Home, passed to `AQHero(belowHeader:)` so it sits under the header row (logo, location, account) and above the greeting and hero. A test scans `lib/` and fails if anything else mounts `SponsoredBannerSlot`, and the admin console never mounts the live slot.

- Size: a compact card, fixed **92 px** (thumbnail, `SPONSORED · name`, one-line title, one-line body, "Learn more"), text capped at 120 %, one line each so a rotating ad never moves the page; on screens under 350 px wide the sponsor name and the button word give way to the title.
- Empty state: no banner and **no space** (the slot owns its own padding). Verified: with no ads the customer Home differs from the deployed approved build only where the new `?` sits (0.8 % of pixels).
- Admin preview: `SponsoredBannerView`, the same widget, shown only inside the console form.
- Browser (widths 320, 360, 390, 412, 430): exactly one banner, 92 px tall, below the header; rotation keeps banner and hero still; **24 other screens show none** (Explore, Activity, Account, categories, results, map, property details, viewing booking, Development & Building, maintenance, notifications, login, entry, delete account, agent and company workspaces, all five other role homes). The position relative to the hero is confirmed by screenshot (`j10_home_*.png`) and by `test/home_banner_test.dart`, not by a DOM measurement.

## What was built in this pass

| Item | State | Routes and components | Evidence | Still needs |
|---|---|---|---|---|
| Contextual `?` explainer | CV | `AQHelpButton` / `showAQHelp` (`lib/core/aq/aq_help.dart`) on the Home "Browse Properties" header and the property types screen | 5 widget tests (open, close, selection kept, label, Arabic RTL, 200 % text); browser: opens, closes to the same Home. Found and fixed: the sheet's button sat under the bottom nav, now on the root navigator | Arabic copy is draft |
| Buyer profile | IV | `/app/account/profile`, `/edit`; one new row on Account | 8 tests; browser: empty, validation, failed save keeps typing, retry, cancel asks first. Editable: first and last name only; phone and email are verified identity, shown read-only | Profile API. Saves are kept on the device and labelled |
| Maintenance provider invitation and workspace | IV | `/provider/invite`, `/provider`, `/provider/requests/:id`; `provider_repository.dart` | 18 tests; browser: invalid, expired, used, valid invitation; setup; under review; QA verify; request detail; failed confirm never shows confirmed. **Open issue**: in the browser the Try again after that failed confirm did not bring the request back, while the same flow passes in `provider_workspace_test` | Invitation, verification and request APIs. No public provider signup. No calendar or timing promise |
| AqaratiBroker | IV | `/broker`, `/broker/list`, `/broker/:id`; Home card and Explore banner now open it | 9 tests; browser: intro (badge meaning, "not Aqary e-Broker"), directory, profile, Call opens `tel:` and claims no outcome, listing → existing viewing request, no phone / not found. Public demo has **no brokers** (none invented); QA build adds two labelled samples | Broker directory and approval API; the extra vetting is open (decision list) |
| Engagements (client side) | IV | `/business/:id/engage`, `/engagements`, `/engagements/:id`; request button on professional profiles | 20 tests; browser: rules shown, request, waiting, professional confirms, review offered. Edge states: duplicate, related account, unavailable, error with retry, expired (14 days), declined, cancelled | Engagement API. Kept apart from viewings and maintenance |
| Reviews | IV | `/review/:kind/:id`, `/reviews`, report sheet; the old explainer screen is no longer used | Browser: refusals, 10 character rule, preview, failed send keeps text, pending moderation (never "published"), publish, edit locked until allowed, edit re-enters moderation. Report sheet: reason required, failure, sent, already reported (tests; a Report review action is on each review of a professional, but the demo roster has no reviews, so the sheet was not opened in the browser) | Review and moderation API; report reason codes are a front-end proposal |
| Customer Aqary e-Broker | IV | `/sell`, `/sell/new`, `/sell/:id`, `/sell/:id/edit`; entries on the property types screen and the profile | 15 tests (rules, duplicate deed, fee acceptance required, resubmission only when changes were requested, foreign submission denied, failures change nothing). Browser: intro with the approved sentence and "nothing is charged or paid in the app", empty-form errors. **The filled form, failed send and resubmission were not driven in the browser** (long form defeated the script); tests cover them | Listing API. **Decision 26** (`aqarati/docs/decisions/open-decisions.md`): proposed "one disclosed rate up to 2 %, fixed per listing at approval; offline invoice", owner Founder, with brokerage licensing on hold. The app shows only "Aqary Real Estate fees will apply up to 2%", records acceptance, calculates nothing, takes no payment. Only the rate, invoice and approval-time fixing are undecided; they need no screen here |

## The seven confirmed features (unchanged routes; re-checked)

| Feature | State | New this pass |
|---|---|---|
| Agent My Listings | CV (demo) | pause blocked by the contract (service must add a pause operation); not re-driven |
| Agent Leads, development enquiries, service requests | CV (demo) | **failure state walked**: a failed Confirm shows "Its status did not change", status stays Requested, retry confirms |
| Admin verification | CV (demo) | **failure state walked**: a failed decision says nothing was changed; the same decision then goes through |
| Admin moderation and e-Broker | CV (demo) | failure state covered by tests only |
| Admin Ads & Sponsors | CV (demo) | **Resume, Move up, Move down now walked in the browser.** Root cause was in the accessibility tree: the action cell was one merged node with the row's full box, so a click opened the editor. Fixed with a container for the action cell and stable keys; also fixes assistive technology reaching the buttons. Create, validate, preview, submit, approve, pause, resume, reorder, live-edit warning: 16 checks |

## Six public roles (Priority 8)

`j11_signup.js`, 6 roles × 8 checks, all passing: the form opens for that role; an empty first step is refused; going Back keeps what was typed; the path reaches its end state (User to Shop: "Your account is active"; the five business roles: "Application submitted … Under review", not approval); the right screen follows; **approved-only screens stay closed** while under review (agent listings refused); sign out returns to the start; afterwards Home is the guest Home (guests may browse by design) with no workspace and no banner. Limits: documents were marked received with the QA "mark all documents received" control, not uploaded; the OTP is the demo code. Session expiry and real browser Back history were not exercised.

## Network failures, accessibility, responsive (Priority 10)

Walked with a QA-only switch (`localStorage.aq_fail = 1`, read only in `REVIEW_TOOLS` builds, `lib/core/config/qa_faults*.dart`): profile save, review send, provider confirm, lead viewing answer, admin verification decision. Not walked: listing save, pause, moderation, ad create or reorder (tests only). Accessibility fixes found by driving the tree: admin dialogs (Close and code field unreachable), the Ads action buttons, the help sheet hidden under the bottom nav. No screen reader, keyboard-only or device pass was done; the accessibility tree is not an assistive-technology evaluation. New screens are in `test/new_screens_matrix_test.dart` (narrow widths, dark, Arabic RTL, 200 % text) alongside the earlier ones; Home with the banner is included.

## Reference assets (Priority 11)

`REFERENCE_ASSET_INDEX.csv` (76 boards) and the notes below. **Classification used the file names and the pack's own index; I did not review the 76 images panel by panel.** Findings that matter: the "Members & Permissions" and organisation-members boards conflict with the architecture (single-owner business profiles, staff roles removed), so they were not built; 39 engagement and review boards repeat one flow with generated sample ratings and wording, which must not be copied (a rating before a confirmed engagement, or an instantly published review, breaks the rules); mixed boards are not specifications.

## Master brief: remaining state

| Item | State |
|---|---|
| Notification preferences and push | BA (inbox is built) |
| Real authentication, session restore, guards | BA |
| Listing pause and resume | BA (contract has no operation) |
| Admin permission matrix (Ch. 47) | BD (role proposal in the console) |
| e-Broker rate, invoice and fee fixing | BD (decision 26) |
| Members and permissions (organisation) | BD (conflicts with the architecture) |
| Screen-reader, keyboard-only, real device | not done |
| Dark and Arabic of the new screens in a browser | IV (layout matrix only) |

## Cleanup you should run (my mistake)

I ran `dart format` over `lib/core` once and re-wrapped 22 files I had not edited. These files differ from `HEAD` only by formatting; restore them if you want the diff clean:

```bash
git checkout -- $(cat docs/readiness/FORMAT_NOISE_FILES.txt)
```

(The list is in `FORMAT_NOISE_FILES.txt`.) After that `flutter analyze` returns to 41.

## APIs required later

Listings (incl. pause and resume), leads and host-side viewing answers, ads (`/ads`, events, admin), admin auth and queues, e-Broker submission and review, broker directory, maintenance provider invitation and requests, engagements and reviews (confirm, moderation, report), buyer profile, notification preferences, real authentication.

---

# Third pass (2026-10-28): provider retry, e-Broker walk, entry experiences, Properties flow

Nothing is committed, pushed or deployed. Backend and database untouched.

| Gate | Result |
|---|---|
| `flutter test` | 820 passed, 0 failed |
| `flutter analyze` | 55 items, no errors (earlier baseline 41; the extra items are `curly_braces` lints from the format-noise files, not individually recounted after this pass; none are in the new files) |
| Builds | `build/web`, `build/web_review`, `build/web_admin` complete; each has AssetManifest and FontManifest; no QA sample code in `build/web` or `build/web_admin` |
| Browser | `j14` provider retry, `j15` e-Broker walk (all steps pass), `j16` entry + Home grid + Properties flow (43 checks pass), `j10` banner exclusions (36 pass). Results in `docs/readiness/evidence/browser/j14..j16_results.json`, screenshots beside them |

## Provider "Try again" (Complete and verified in browser)

The earlier "open issue" had two causes. The old script hard-coded the retry check as a failure and never tapped the button, and the unit test covered a different case (a failed load, not a failed answer). Reproduced for real, two defects found and fixed:
1. `AQButton`, `AQTextButton`, `AQIconButton` declared a button with `excludeSemantics: true` but no tap action, so a screen reader or keyboard activation could not press any of them (an app-wide gap). Added `onTap`. `AQSlideSwitch` had the same gap; fixed.
2. `AQErrorBanner` wrapped message and button in one live-region node, so the retry button was not a separate target. The live region now wraps only the message.
3. A failed confirm no longer blanks the page when the re-read also fails; the request stays as shown, an error with its own Try again repeats the same operation, busy state blocks double taps, a conflict still re-reads.

Tests added in `provider_workspace_test.dart` (5): keep state and retry, second failure shows no confirmed state, whole connection down then back, retry answers a screen-reader tap (this one failed before the fix), repeated taps run once. Browser: failed confirm, retry while still failing, retry after recovery, confirmed.

## Customer Aqary e-Broker walk (Complete and verified in browser, demo only)

Entry from the Properties types screen, type-by-market selection, owner documents, wrong deed number refused, photo add/remove, fee sentence "Aqary Real Estate fees will apply up to 2%" only, submit refused until accepted, failed send (answers kept, "Nothing was submitted"), retry, in review and hidden from buyers with acceptance recorded, QA reviewer asks for changes, edit form pre-filled, fee notice must be accepted again, failed resubmission, resubmitted, no edit while in review. Not walked: duplicate deed (tests only). Open decision 26 unchanged (rate, offline invoice, fixing at approval); no payment, no calculation.

## Entry experiences, Home, Properties (implemented, browser verified)

- Entry: User to Shop / Real Estate Agent switch (existing `AQSlideSwitch`). Create an Account opens `/signup/user` or `/signup/agent`; Login opens `/login?as=...` with a line naming the experience; "Other businesses: create an account" keeps the six-role chooser. The choice is context only: after sign-in `routeForSession` decides from the account's own role and grant (also for Google/Apple, which used to go straight to Home); if the account does not match the chosen door, a message says so. QA stand-ins unchanged (`?session=` only in REVIEW_TOOLS builds).
- Home: 2x3 grid of six cards directly under the search bar (Properties, Development, Interior & Exterior Designer, Construction Company, Loan Calculator, Maintenance); all existing Home sections kept. Verified at 320/360/390/412/430, no overflow.
- Properties: `/properties` is now the hub (Buy, Rent, Sell, My Favorites). Buy/Rent open `/properties/categories?tx=` (four categories); a category opens `/properties/types?tx=&cat=` directly; a type opens `/properties/all?tx=&cat=&types=`. Back keeps transaction and category. Sell opens `/sell`; My Favorites opens `/saved` (not category-filtered). No Buy/Sell chooser after a category.
- Taxonomy: Residential Villa, Apartment, Residential Land; Commercial Shops, Offices, Building, Storage, Commercial Land; Industrial Land to invest, Factory; Agriculture Agricultural Land, Farmhouse. Two enum values added (`commercialLand`, `investmentLand`); the rest reuse existing types (Shops = shop, Building = commercialBuilding, Storage = warehouse, Factory = industrial, Farmhouse = farm). Found by test and fixed: Storage was not matched by the Commercial category filter.
- **Unconfirmed product rule: rent eligibility.** The documents do not say which types can be rented. `lib/features/search/browse_taxonomy.dart` treats the four land types as sale only and everything else as rentable, in one list (`kSaleOnlyTypes`). Needs product confirmation.
- Card images repeat (only a few property photos exist), e.g. Shops/Storage share one.

## Not done in this pass (honest list)

Review report sheet in browser, listing/pause/moderation/ads failure walks, the 76-image panel review, keyboard-only/screen-reader/reduced-motion checks, Arabic and dark browser walks of the new screens (layout matrix only), motion timing audit. Agent entry through a real agent account was verified by routing tests (`routeForSession`), not a signed-in browser walk. Existing agent, lead, admin, ads features were not re-walked; their tests pass.

## Format cleanup

Backup: `docs/readiness/backup/pre_cleanup_working_tree.patch` and `untracked_files.tar`. Verified by formatting both sides: 20 of the 22 files are formatting-only (`FORMAT_NOISE_VERIFIED.txt`); `aq_forms.dart` and `aq_primitives.dart` hold real changes and must stay. Restoring is blocked by the permission rule on `git checkout`, so it was not done. Run:

```bash
git checkout -- $(cat docs/readiness/FORMAT_NOISE_VERIFIED.txt)
```

---

# Fourth pass (2026-10-28): demo mode, admin link, login spacing, preview readiness

## Rental eligibility (prototype-based, pending product confirmation)
`kSaleOnlyTypes` in `lib/features/search/browse_taxonomy.dart`: Residential Land and Commercial Land are sale only; Land to invest and Agricultural Land have rental ranges and are offered for Rent; all other types are rentable. This comes from the earlier prototype's configuration, not from an approved business rule, and the architecture documents do not restate it. Confirm against any newer product rule.

## Demo mode (Complete, verified in browser)
`AQARATI_DEMO_MODE` defaults to **false** (`lib/core/config/demo_mode.dart`). Default build: no Skip for Demo on either signup screen, no Skip chips on the purpose screen (browser-checked on a default build). Demo build (`--dart-define=AQARATI_DEMO_MODE=true`): Skip for Demo on User to Shop and Real Estate Agent signup opens that role's home on the simulated session with "Demo mode: no account was created, registered or verified." (browser-checked). The Vercel project was not reconfigured; the link serves whatever the project's own build command produces, which has no demo flag, so the hosted link has no skips. See `ADMIN_ACCESS.md`.

## Admin Console link (Complete, verified in browser)
Under Login on both login variants. On localhost it opened `http://localhost:8081/#/login`, the admin sign-in with its one-time-code step intact. On a hosted build with no `AQARATI_ADMIN_URL` it shows an explanatory sheet. No admin site is deployed; none is claimed.

## Login role pill spacing (Complete, verified in browser and by 20 tests)
Gap 2 px before, 16 px after, at 320, 360, 390, 412, 430 px, both variants. The left-edge leak from the adjacent screen was not reproduced.

## Listing status message (Complete, tested)
The one-time "Sent for review" message now shows only while the listing is still in review. Regression tests: pending to approved, to changes requested, to rejected.

## Browser verification state of the outstanding list
- Verified in browser this pass: listing save, pause, resume, edit failures and retry (`j17`); moderation failure and retry (`j20`); Ads create, submit and review failures (`j21`, first three checks and the retry that follows each).
- Not completed in browser: Ads pause, resume and reorder failures (the `j21` walk stopped after approval; the earlier `j7` walk covers the working path), review-report sheet, duplicate deed number, dark mode and Arabic walks, keyboard-only and reduced-motion checks, the 76-image review.
- Signed-in agent journey: demo-build Skip for Demo opens the agent workspace (browser); the deeper agent flows (listings, leads) were walked in earlier passes and re-run by tests.

## Gates
`flutter test`: 836 passed, 17 skipped (demo-only tests, which run with the define and pass; run `flutter test --dart-define=AQARATI_DEMO_MODE=true test/demo_admin_test.dart test/demo_skip_test.dart`). `flutter analyze`: 55, no errors. Builds `build/web` (default), `build/web_demo`, `build/web_admin` complete with manifests.

## Format cleanup
Still not restored: the permission rule blocks `git checkout`. The 20 files in `FORMAT_NOISE_VERIFIED.txt` are formatting-only (verified earlier) and are committed as they are; they can be restored later with `git checkout <last commit before> -- <files>`.

---

# Phase 1 (2026-10-29): entry, registration, first-time onboarding

Not pushed, not deployed. Backend untouched.

## Release check
Commit `217db2d` deployment `dpl_8Kmq4HPqi18MgeKHgCmoTxJrH2xp`: state READY on production; the live `main.dart.js` contains the new Home strings ("Explore more with AQARATI", "Sell with Aqary e-Broker"). Verified by deployment API and by fetching the live bundle; the page itself was not opened in a browser.

## Test-count reconciliation
836 passed (+17 skipped) at `7912a0a` became 830 (+17) at `217db2d`: six fewer. Cause: the Properties hub was retired, which removed one test ("on the properties hub nothing is lost when help closes") and the hub entry in the screen matrix (about five variants). Nothing else was deleted; the hub-offers test and the six-module tests were rewritten for the new Home (stronger: equal-size cards, above search, photos). Now 846 passed, 17 skipped, with 16 new Phase 1 tests.

## What Phase 1 added
- Entry: a prominent **Register as a Business or Professional** button under Login; it opens `/signup/business` with the four professional cards (Development, Construction, Architecture, Interior & Exterior), selected state, Continue. The full six-role chooser stays at `/onboarding/purpose`.
- Interests: new `/onboarding/interests` "What are you looking for?" (nine options, multi-select, Continue disabled until one is chosen, Skip for now). A new User to Shop account reaches it from "Your account is active"; businesses still go to documents. Saved locally (`aq.interests`), restored on the next start. It re-orders the services under Explore more; Buy, Rent, Sell and My Favorites never move.
- Accessibility (found while testing): 92 tiles and cards declared a button with no tap action, so keyboard and screen-reader activation could not press them. About 80 were fixed in one pass (the tap action now mirrors the pointer action); 10 odd cases remain.
- Agent: approved agent session lands on the agent workspace; a shopper session on customer Home (browser-checked). A new agent account still goes through documents and review before the workspace, as designed.

## Browser evidence (`j24`, 17 checks pass)
Entry at 320/360/390/412/430/1280: no overflow, both modes and the business button visible. Business selector, Interior & Exterior selection to its signup. User signup to "Your account is active" to interests to Home with the four primary actions; choice stored and survives a reload; Skip stores nothing. Agent Create an Account opens the agent signup.

## Not verified
Keyboard-only navigation: in headless Chromium Tab did not reach the buttons and Enter did not activate tiles; not resolved, so keyboard access is unverified. Interest cards low in the grid were unreliable to click because the semantics geometry lags, so the browser picked Buy and Loan only; ordering is covered by a widget test. Demo sessions were exercised in earlier checks, not re-walked after the accessibility pass.

---

# Fifth pass (2026-10-29): customer shell completion, tab differentiation, agent workspace

Not pushed, not deployed. Backend untouched. Demo mode still off by default.

## Gates
`flutter test` 865 passed, 17 skipped. With `--dart-define=AQARATI_DEMO_MODE=true`, the demo, Phase 1, shell and agent test files pass (66, 2 skipped). `flutter analyze` 55 items, no errors. Builds: `build/web` (default), `build/web_review`, `build/web_demo`, `build/web_admin`, each with manifests.

## Customer
- Navbar on all 24 audited routes including Search and Map (browser, `j27`/`j29`). Sticky bars sit above it (`AQShellInset`).
- Tabs differ (Activity now has Selling and Requests records; Account is grouped settings). Browser `j29`: four tabs give four different pages; Activity Selling and Requests open; dark mode persists from Account to Home; the Account Language row switches to Arabic and Home renders RTL with no overflow.
- Distinct imagery per property type (12 different photos, previously several repeated).
- The earlier "Arabic did not switch" was the entry-screen language sheet, whose rows are not exposed to the accessibility tree; the Account language row works and is how Arabic was verified.

## Keyboard
Tab order, focus ring, Enter and Space verified in the browser on Entry, business selector, signup, interests, Home, results, Search, Favorites and the login form (22 checks, `j25`). Reviewed the script: it only acts on focused accessibility nodes with a button-like role, stops the key from reaching Flutter's own handlers (one press, one activation), prevents Space scrolling, and never touches native browser controls. The login keyboard trap (Tab cycling Email and Password only) is fixed with an app-side hook that releases text focus first. Not verified: native screen reader, and a real (headed) browser; only headless Chromium was used. Two stale text checks in `j24` and `j25` look for the old agent heading and fail by wording only (the agent dashboard itself passes in `j28`).

## Agent workspace (frontend demo, fictional data, on-device only)
Browser `j28`, 48 checks: dashboard (counts computed from records), contacts (search, status filter, sort, 8 records), contact detail (notes timeline, status change, call, email, related listings, appointments), add contact (validation then saved), edit, calendar (Upcoming / Overdue / Done, appointment sheet with reschedule, mark done, cancel), More (profile, requests, enquiries, service requests, customer view, sign out), listings (the existing module inside the agent shell), role isolation (a shopper sees no agent navigation), no overflow at 320 to 1280 px.
Not verified in the browser: the date and time pickers used by Schedule follow-up and Reschedule (the underlying rules are unit-tested), Arabic and dark walks of the agent pages (widget tests cover layout), and the agent Listings add and edit forms inside the new shell.
Existing tests changed because the architecture changed (none removed): the agent no longer renders inside the customer Home, so the role-home tests now assert the redirect to `/agent` and the way back, and the agent rendering matrix moved to `agent_workspace_test.dart`.

## Still missing
Admin Console on the Vercel build; the four other professional workspaces beyond their existing homes; multi-step Aqary e-Broker form; results sort controls beyond what exists; Explore redesign beyond its existing structure; format-noise restore (blocked by the permission rule, list in `FORMAT_NOISE_VERIFIED.txt`).

---

# Sixth pass (2026-10-29): admin console, professional workspaces, e-Broker wizard, Explore

Local only. Not committed, not pushed, not deployed. Backend untouched. Demo mode still off by default.

## Gates
`flutter test`: 898 passed, 17 skipped (demo-only). The demo-gated files (`demo_admin_test`, `demo_skip_test`, `pro_demo_data_test`) pass with `--dart-define=AQARATI_DEMO_MODE=true`; `admin_directory_test`, `admin_console_test`, `phase1_entry_test`, `flow_logic_test` also pass with it. `flutter analyze`: 56 items, all info, no errors. Builds `build/web` (default), `build/web_demo`, `build/web_admin` complete with manifests.

## What this pass delivered
- **Admin Console** at `#/admin` in the same build: sign-in with illustrative one-time code, Overview, Accounts (search, filters, detail, status change with confirmation), Verification, Listing moderation, Ads & Sponsors, Reports (resolve with note), Activity log. Demo accounts appear only in a preview build. See `ADMIN_ACCESS.md`.
- **Four professional workspaces** inside `ProShell`: Development, Construction, Architecture, Interior & Exterior, each with its own five tabs and home; contact activity, engagements (confirm locally) and portfolio carry sample data in a preview build only.
- **Aqary e-Broker** as a six-step wizard; the submission appears in Activity > Selling as "In review"; confirmation says "Prototype submission saved. No listing has been sent to a real service."
- **Explore** reviewed and walked (search, results, filters, sort, category and professional directories, empty states); no new Explore build was needed.

## Defects found by the browser walks and fixed
1. A refresh on `#/admin` left the console: the inner admin router overwrote the browser address with `#/login`. It now never writes the address when hosted.
2. `/sell/new` opened "We could not find this submission": the shell's `/sell/:id` captured `new`. It now redirects to the form (`/sell-new`). New test `sell_route_test.dart`.
3. The Construction role's Projects tab opened a developer-only page. Its tab is now Portfolio.
4. Contact activity and engagement pages said "not available" in the preview build because the sample repository returned nothing; sample data now exists (preview build only; normal build still says the service is not available). New test `pro_demo_data_test.dart`.
5. `demo_skip_test.dart` expected business roles at `/app/home`; they now open `/pro` by design. Expectation updated; no assertion removed.

## Browser evidence (headless Chromium, `docs/readiness/evidence/browser/`)
- `j30` admin console: 22 checks pass (hosted route, refresh, login link, demo accounts only in preview, two-step sign-in, Overview, Accounts search/detail/confirm/status, Reports resolve with note, Activity log, moderation, ads, widths 320/390/768/1280).
- `j32` professional workspaces: 38 checks pass (four roles at 390 and 1280: own tabs, no customer tabs, every tab opens, sample contact activity, portfolio, engagement confirmed locally, four different homes).
- `j33` e-Broker: 13 checks pass (six steps, blocked Continue with reasons, Back keeps values, review with Edit, no overflow at 390, truthful confirmation, record in Activity > Selling).
- `j35` Explore: 12 checks pass (sections, search, sort reorders, empty state, category and professional directories, no overflow at 320/390/1280).
- Regression: agent workspace `j28` 48 pass; customer tabs `j29` 14 pass; route audit `j27` re-run.

## Not verified / limits (said plainly)
- Not opened on the deployed Vercel URL; no deployment was made and Vercel settings were not inspected.
- Sign-in, one-time code, roles and approvals are simulated; no backend exists.
- e-Broker submissions are not in the admin moderation queue. Admin status changes do not reach the customer or agent apps.
- Construction, Architecture and Interior & Exterior cannot add portfolio work or projects (service not confirmed). Arabic and dark walks of the new screens are covered by widget tests (320 to 1280 px, RTL, 160-200% text), not by browser walks. Keyboard-only and screen-reader walks of the admin console and professional shell were not done in the browser.
- The 20 formatting-only files in `FORMAT_NOISE_VERIFIED.txt` are not restored (permission rule); run `git checkout -- $(cat docs/readiness/FORMAT_NOISE_VERIFIED.txt)` yourself if wanted.
- Review-report sheet, duplicate-deed, Ads pause/resume/reorder failure walks and the 76-image visual audit from earlier passes remain outstanding.

---

# Seventh pass (2026-10-29): sponsorship on every Home, admin modules, e-Broker to admin, release gate

## Gates
`flutter test`: 913 passed, 17 skipped, exit 0 (the earlier 898 baseline plus 15 new tests; nothing deleted or weakened). The 17 skips are the demo-only tests; with `--dart-define=AQARATI_DEMO_MODE=true` the demo-gated files (`demo_admin_test`, `demo_skip_test`, `pro_demo_data_test`, `admin_demo_entry_test`) and the admin, entry, flow and e-Broker-link files pass. `flutter analyze`: 55 info items, 0 warnings, 0 errors.

## What was added
- One shared sponsorship banner (`SponsoredBannerView` and `SponsoredBannerSlot`) on all six Homes, served by audience from sample campaigns (`kSampleCampaigns`); an unknown destination falls back to `/app/explore`; the whole card is one keyboard-operable button.
- Admin console: Property listings, Agents and brokers, Development projects, Construction, Architecture and design, Maintenance, Viewings and requests, Categories and content, Announcements, Analytics, Profile and settings, plus audience, search and preview on Ads & Sponsors, and one shared Activity log.
- e-Broker submissions appear in the admin moderation queue, a decision writes back to the customer's Activity, and a resubmission updates the same queue record.
- Portfolio add, edit and remove for Construction, Architecture and Interior & Exterior (preview data only, in memory).
- One-tap "Open the demo console" on the admin sign-in (demo builds only).
- `vercel.json`: forwards `AQARATI_DEMO_MODE` from the environment into `--dart-define` (see `VERCEL_DEPLOYMENT.md`).

## Defects found by the browser walks and fixed
1. Signing in after opening `#/admin` directly landed on "Page Not Found" (inner router started at `/admin`).
2. Admin table rows were not keyboard-focusable; the sponsorship banner's focus target was a 16 px chevron.
3. Sorting, hash and `/sell/new` fixes from the previous pass remain in place.

## Browser evidence (headless Chromium, `docs/readiness/evidence/browser/*_results.json`)
Sponsorship six roles x six widths plus CTA and Back: 73 of 73. Admin walk (ads, modules, activity log, widths): 59 of 59. e-Broker to admin round trip: 8 of 8. Portfolio: 15 of 15. Keyboard-only admin, professional shell and banners: 44 of 44 (one run in three showed intermittent timing failures in the sign-in typing; the rerun passed). Duplicate deed refused with a clear message and one record kept; Ads failed load, Try again, failed save and retry: 5 of 5. Regression: admin hosted 22, professional 38, e-Broker wizard 13, Explore 12, agent 48, customer tabs 14.

## Not done, said plainly
- Review-report sheet: the preview data has no published reviews for a business, so the sheet cannot be opened in the browser; it is covered by `engagement_reviews_test.dart`.
- The 76-image reference visual audit was not performed. It needs a person to compare each reference image with its screen; no automated comparison exists. Screens were checked for overflow, cropping and overlap at 320 to 1280 px only.
- No screen-reader walk. Keyboard and focus-ring checks were made in headless Chromium only.
- Developer "update project status" has no local action; status changes come from the admin decision.
- The 20 formatting-only files are committed as they are (verified formatting-only earlier); nothing was bulk-restored.

---

# Eighth pass (2026-10-29): Admin Console UI polish

Admin-only: the customer and agent design system was not changed. New scoped kit: `lib/admin/admin_ui.dart`.

## Problems found in the "before" screenshots (`evidence/browser/adm_before_*`)
Header actions forced to a 190 px width (stretched buttons); secondary buttons that looked like plain text; 66 px two-line inputs; oversized pill filters with the label on a separate line; one flat list of 18 sidebar items with wrapping labels and the profile block overlapping the last item; the login inside a tall card with a 140 px logo and an edge-to-edge Continue; 18 px-radius cards everywhere; ragged metric cards with 32 px numbers; 56 px table rows; the narrow layout used a row of 18 pills for navigation.

## What changed
- **Controls**: button 40 px (compact 34), content-sized (full width only for the sign-in Continue and the demo shortcut); primary, secondary, destructive and text variants; 38 px icon buttons; 44 px inputs with the label on the border; 30 px chips with 8 px corners; hover, press and focus states; loading and disabled states kept.
- **Sidebar**: 244 px, grouped (People, Listings, Services, Marketing, Insight), 36 px rows with a subtle selected state, settings and profile pinned at the bottom, scrolls independently. Below 960 px it becomes a menu button and drawer.
- **Page**: one compact header (back link, 24 px title, one line of context, content-sized actions), 32 px margins, 1240 px max width.
- **Overview**: six compact metric cards, a "Needs attention" queue, recent activity, a sponsored-placements panel using the shared banner, accounts by role.
- **Tables, filters, dialogs**: 12 px radius, 48 px rows, small header labels, a toolbar of search plus labelled chip rows, a small confirmation dialog with a red variant for destructive actions.
- **Sponsored placements**: compact list with audience and status filters, banner preview at its natural size beside the form.

## Evidence
Before and after screenshots: `docs/readiness/evidence/browser/adm_before_*` and `adm_after_*` (1280 and 390 px, 768 px after). 913 tests pass; analyzer 55 info items, no warnings. Browser: admin 64, keyboard 44, hosted admin 22, professional 38, portfolio 15, Explore 12, agent 48, customer tabs 14, sponsorship 73, failure states 5; admin fits without horizontal scroll at 320, 360, 390, 412, 430, 768, 1024, 1280 and 1920 px.

## Remaining
The sign-in and code pages were checked at 1280 and 390 px only. Dark mode in the admin was not reviewed (the console is light-only). No screen-reader walk.

## Current state, gap-closure pass (2026-11-01)

The five gaps the previous review left open are closed in the local working tree. Details, files and tests: `GAP_CLOSURE.md`.

| Gap | State |
|---|---|
| Professional navigation (Analytics and Business settings hidden under More) | **Closed.** Six destinations per role, Analytics a tab, Business settings in the Company/Profile hub and still on Home; new Units, Projects and Services screens (sample data, labelled). |
| Additional business services not wired into Explore | **Closed with local fixtures.** One record, several categories; listed once per category; filter, public profile categories and enquiry context work. The signed-in business is not inserted into the public directory (nothing is published). |
| Admin Console English only | **Closed.** Complete Arabic with real right-to-left layout, the app's language switch, Arabic-Indic digits, bundled Arabic font. Arabic copy is draft. |
| Password change did nothing | **Closed as a prototype.** Dedicated screen, rules, errors, simulated confirmation, no server claim. |
| Roboto fallback not audited | **Audited.** No audited screen draws a style without a bundled family; Material defaults now reach the Arabic family; offline run loads only bundled fonts. |

Still open, unchanged: real authentication, email and push channels, real publishing, real analytics, native review of the Arabic, a real screen-reader pass, non-Chromium browsers.
