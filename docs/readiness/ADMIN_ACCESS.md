# Admin Console access and demo mode

## Route
The Admin Web Console is part of the same web build as the customer app. It lives at the hash route **`#/admin`** (for example `https://<site>/#/admin`). It has its own sign-in, its own sidebar navigation and its own routes inside that page; it never shares the customer or agent navigation.

- Opening `#/admin` directly (or refreshing on it) shows the admin sign-in. The inner console router does not write to the browser address, so the address stays `#/admin` (`_QuietRouteInformationProvider` in `lib/admin/admin_app.dart`).
- The console is not a sign-up role and not a tab. The customer and agent log-in screens carry one small text link, **Admin Console →** (`lib/features/entry/admin_link.dart`), which opens `#/admin`. If `AQARATI_ADMIN_URL` was set at build time the link opens that address instead.
- **Back to AQARATI** on the console sign-in returns to the customer entry.
- Entry point for a separately hosted console still exists: `lib/admin_main.dart` (`flutter build web -t lib/admin_main.dart`). It is optional; nothing depends on it.

## What the console contains (`lib/admin/`)
| Area | Route | What it does (prototype) |
| --- | --- | --- |
| Sign-in | `/login`, `/code` | Email + password, then an illustrative one-time code step |
| Overview | `/overview` | Counts that open their queues; recent administrative activity |
| Accounts | `/accounts`, `/accounts/:id` | 14 sample accounts (customers, agents, four professional kinds); search, role and status filters; account detail; set active / under review / suspended with confirmation and an optional note |
| Verification | `/verification…` | Review queue and decisions for professional accounts (existing) |
| Listing moderation | `/moderation…` | Moderation queue and actions (existing) |
| Ads & Sponsors | `/ads…` | Sponsored placements: create, pause, resume, reorder (existing) |
| Reports | `/reports`, `/reports/:id` | Complaints against listings and accounts; filter; resolve or dismiss with a note, reopen |
| Activity log | `/audit` | Everything changed in this session, newest first |

Every change asks for confirmation first and is written to the Activity log. Nothing leaves the browser.

## More modules (all fictional, in memory, every change confirmed and logged)
`/m/listings`, `/m/brokers`, `/m/projects`, `/m/construction`, `/m/design`, `/m/maintenance`, `/m/viewings`, `/m/content`, `/m/announcements`, `/analytics` (counts from the demo records; invented figures are labelled "Sample figure") and `/settings` (profile, session, sign out). Ads & Sponsors adds an audience (which Home shows the banner), search, and a preview that says where the button goes.

## One-tap demo entry
In a demo-enabled build the sign-in shows **Open the demo console**, which signs in as the demo super admin through the same simulated sign-in and code. It does not exist in a normal build.

## What it is not
- Sign-in and the one-time code are **simulated**. They protect nothing. The console says so on its sign-in page ("Prototype only. Sign-in and the one-time code on this page are simulated; they do not protect anything.").
- No backend, no database, no real roles or permissions. State lives in memory and resets on reload.
- Status changes, resolutions, ad changes and moderation decisions affect only the sample data in the console. They do not reach the customer or agent apps, except the sponsored placements the demo store already feeds to the customer feed.
- e-Broker submissions made in the same browser session appear in the moderation queue as e-Broker records; the decision shows in the customer's Activity. State resets on reload.

## Demo accounts only in an explicitly enabled preview build
`kDemoMode = kUseDemoBackend && AQARATI_DEMO_MODE` (default **off**). In a normal build the console sign-in shows **no** demo accounts, password or code ("Demo accounts are shown only in a build made for previews."). In a preview build it lists the sample reviewer accounts, the sample password and the sample code, and shows the "DEMO DATA" marker.

```bash
flutter build web --release --dart-define=AQARATI_DEMO_MODE=true --dart-define=REVIEW_TOOLS=true --output build/web_demo
```

## Vercel (truthful status)
- The console is included in the single web build, so a Vercel deployment of that build serves `#/admin` with no second project.
- **Verified in this repository:** a local production build (`build/web`, default flags) served over HTTP shows the admin sign-in at `#/admin`, keeps it on refresh, and still serves the customer entry (`#/entry`) from the same build.
- **Not verified:** the deployed Vercel URL. No deployment was made in this change and the Vercel project settings (build command, defines) were not inspected or changed. Do not describe the console as live on Vercel until `#/admin` has been opened on the deployed address after the next approved deploy.
- A Vercel build made without `AQARATI_DEMO_MODE=true` shows the sign-in but no demo accounts, so a reviewer cannot sign in to it. To let a reviewer in, deploy a preview build with the define above.

## Demo mode ("Skip for Demo")
Off by default. A normal or production build has no skip buttons anywhere (sign-up screens or purpose screen). With `AQARATI_DEMO_MODE=true`, User to Shop and Real Estate Agent sign-up show **Skip for Demo**, and the purpose screen shows per-role Skip chips (agent, and the four professional roles). They only replace the simulated session, then show "Demo mode: no account was created, registered or verified." They never bypass the Admin Console sign-in.

In a preview build the four professional workspaces also show sample contact activity, sample engagements (confirmable locally) and sample portfolio images. In a normal build those pages say plainly that the service is not available.

## Troubleshooting
- Blank page on a static host: stop any server holding the output folder before `flutter build web` and check `assets/AssetManifest.bin` exists.
- Sign-in will not accept the sample credentials: the build was made without `AQARATI_DEMO_MODE=true`.

---

## Update (2026-10-31): master implementation pass

Local only; nothing is committed, pushed or deployed.

- **Preview build command** now also bundles the Flutter engine and fallback font locally, so the page makes no request to `www.gstatic.com` or `fonts.gstatic.com`:

```bash
flutter build web --release --pwa-strategy=none --no-web-resources-cdn --dart-define=AQARATI_DEMO_MODE=true --dart-define=REVIEW_TOOLS=true --output build/web_demo
flutter build web --release --pwa-strategy=none --no-web-resources-cdn -t lib/admin_main.dart --output build/web_admin
```

- The console is unchanged in structure: same sidebar (below 960 px a drawer), same sign-in, same modules. It was walked again at 320, 360, 390, 412, 430, 768 and 1280 px (`adm_after_*` screenshots, `j42_admin2.js`) and its tests pass with demo mode off and on.
- The console's text is **English only**. The customer, agent and professional apps are fully bilingual; translating the console was not part of this pass.
- The console's Analytics page (`/analytics`) counts the console's own sample records. It is separate from the role Analytics inside the agent and professional workspaces (`/agent/analytics`, `/pro/analytics`), which use deterministic local sample series.
- Console data does not reach the apps, except the sponsored placements, as before. The sample sponsored campaigns now carry Arabic copy for Arabic customers; admin-created campaigns show exactly the text typed.
- Demo-mode tests: `devbuild_workspace_test.dart` now builds its gated screens from a repository that has the contract's optional capabilities off, so the same assertions hold in both configurations. A separate assertion states what a demo build switches on (contact activity, engagements, portfolio) and what stays off (media, review replies).


## Arabic and right-to-left (2026-11-01)

The console is bilingual and follows the same language switch as the app.

- **Switch.** A language button (English / العربية) is on the sign-in screen, the one-time code step, the sidebar and the narrow top bar. It sets the app's locale, so a choice made in Account > Language and region applies here and the reverse. It persists across reloads.
- **How the text is translated.** The screens stay written in English. `lib/admin/admin_l10n.dart` looks each string up in `lib/admin/admin_strings_ar.dart` when the language is Arabic. A runtime collector records any string with no translation and a test fails on it.
- **Layout.** The sidebar is on the right, headings and table columns run right to left, forms and dialogs mirror, back and chevron controls point the other way, and mobile records are cards. At 960 px and below a menu button at the right edge opens the drawer.
- **Numbers and names.** Counts use Arabic-Indic digits; identifiers, e-mail addresses and money written as "OMR 185,000" keep theirs. Proper names (people, businesses, places) stay as written; the words around them are translated.
- **Fonts.** IBM Plex Sans Arabic, bundled.
- **Simulation notices are translated too.** Arabic sign-in and the one-time code still say they are simulated and protect nothing.
- **Review status.** The Arabic is draft copy and needs a native review before launch.
- **Tests.** `test/admin_arabic_test.dart` (every screen, interactive states, switch, geometry at 320, 390, 768 and 1280). Browser: `j95_admin.js`.
