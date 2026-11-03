# Customer navigation audit (2026-10-29)

## Current state (2026-10-31, master implementation pass) — read this first

Everything below this section is the history of earlier passes. Where it differs, this section describes the working tree now. Full route list: `ROUTE_MATRIX.md`. Screens: `SCREENSHOT_INDEX.md`. Widths: `VIEWPORT_MATRIX.md`. Local only; nothing committed, pushed or deployed.

- **Home** holds only the greeting and sub line, one sponsored banner and six services (Properties, Development, Interior & Exterior Designer, Construction Company, Loan Calculator, Maintenance). The four-card block, search entry, category row, featured listings and the old development, maintenance and broker-loan sections are gone from Home on purpose; their destinations remain reachable (Properties landing, Explore, Maintenance and Loan Calculator tiles).
- **Properties** opens its own landing at `/properties` (no `cat`, `tx` or `types`): Buy, Rent, Sell with Aqary e-Broker, My Favorites. The old redirect from `/properties` to Home is removed. Back from the category step returns to this landing. The contextual `?` explainer sits on this landing.
- **Explore** now lists every property type of all four markets (“Browse by property type”, each type opens `/properties/all?cat=…&types=…`), the development projects and a “Find people” row (agents, trusted brokers) next to the professional directories.
- **Account** is regrouped (Account, Preferences, Help and legal, Session) and each row opens a settings page under `/app/account/settings/<security|notifications|language|appearance|privacy|preferences|support|about>`.
- **Agent and professional workspaces** gained `/agent/analytics`, `/agent/settings` (+ `/p/<name>`), `/pro/analytics`, `/pro/settings` (+ `/p/<name>`). They are reached from More and from the Home KPI link, and the More tab stays selected on them. Business settings are separate from customer settings; language and appearance are shared app-wide.
- Browser walk (`j80`, `j82`, `j90`, `j42`, `j44`): 230 checks, 0 failures. Customer navigation after the change: the bottom bar stays on every audited customer route; selected tab unchanged from the table below, except Properties landing, Buy, Rent and Favorites keep the Home tab.

| Source | Action | Destination | Nav | Tab |
|---|---|---|---|---|
| Home | Properties | Properties landing | yes | Home |
| Home | Development, Interior & Exterior Designer, Construction Company | their directories | yes | Explore |
| Home | Loan Calculator | Property tools | yes | Home |
| Home | Maintenance | Maintenance providers | yes | Home |
| Properties landing | Buy / Rent | categories (tx kept) | yes | Home |
| Properties landing | Sell with Aqary e-Broker | e-Broker intro | yes | Home |
| Properties landing | My Favorites | Saved | yes | Home |
| Categories → Types → Results | Commercial → Offices | results for that market and type | yes | Home |
| Explore | a property type | results for that market and type | yes | Explore |
| Explore | Real estate agents / Trusted brokers | `/broker/list`, `/broker` | yes | Explore |
| Account | any settings row | its settings page | yes | Account |
| Professional More | Analytics / Business settings | `/pro/analytics`, `/pro/settings` | pro bar | More |


Method: every route below was opened in headless Chromium on the QA build (`?session=buyer`), recording whether the four-tab bar is present, which tab is selected and the page's first text (`j27_audit.js`, result `docs/readiness/evidence/browser/j27_route_audit.json`).

## Before (route audit of the previous build)
Navbar present only on the four tab pages and the four Development & Building pages. **Missing** on: Buy and Rent categories, property types, results, property detail, My Favorites, Sell (e-Broker), Maintenance, Loan Calculator, Search, Map, Notifications, Profile, Engagements. Selected tab was wrong or none on every one of those. "Maintenance" opened the generic "Professionals" page.

## Cause
Only `/app/*` and the dev-build routes were children of the single `ShellRoute` (`AQAppShell`, the only host of the glass nav). Everything else was a standalone page that replaced the shell.

## Fix
- 11 router routes and 10 module routes moved into the shell (`app_router.dart`, `extra_routes.dart` `extraShellRoutes()`): `/properties*`, `/saved`, `/property/:id`, `/professionals`, `/business/:id`, `/calculators*`, `/notifications`, `/engagements*`, `/reviews`, `/app/account/profile*`, `/broker*`, `/sell`, `/sell/:id`.
- `customerTabFor()` selects the right tab for any location (Home flows stay under Home; profile, notifications, engagements, reviews under Account; viewings under Activity).
- `AQShellInset`: pages inside the shell leave room for the nav and sticky action bars (Enquire / Book viewing, Save, Continue) sit above it.
- Focused wizards and forms stay outside on purpose: signup, login, onboarding, viewing booking, `/sell/new`, `/sell/:id/edit`, engage and review forms, listing forms, delete account.
- Maintenance now opens a page titled "Maintenance" with its own description (it was the generic professionals list).

## After
24 routes checked: navbar present on 22, correct tab selected on every one that has it. Still without the bar: Search start and Map (own full-screen layouts).

| Source | Action | Destination | Nav | Tab |
|---|---|---|---|---|
| Home | Buy a property | Buy categories | yes | Home |
| Home | Rent a property | Rent categories | yes | Home |
| Home | Sell with Aqary e-Broker | e-Broker intro | yes | Home |
| Home | My Favorites | Saved | yes | Home |
| Home | Development / Architecture / Interior & Exterior / Construction | four different directories | yes | Explore |
| Home | Maintenance | Maintenance providers | yes | Home |
| Home | Loan Calculator | Property tools | yes | Home |
| Categories | Residential / Commercial | types of that category (tx kept) | yes | Home |
| Types | Villa / Offices | results with tx, category and type | yes | Home |
| Results | a card | that property's detail | yes | Home |
| Account | Profile, Notifications, Engagements | their pages | yes | Account |
| Tab bar | Home / Explore / Activity / Account | four different pages | yes | selected |

## Not done in this pass (and said plainly)
Search start and Map still outside the shell. Explore is already a separate page but was not redesigned. Activity, Account and the agent workspace were not restructured: the agent has no separate navigation or CRM yet, there is no contacts/leads/appointments module, the four professional workspaces are unchanged, the admin console is not part of the Vercel deployment, and the Aqary e-Broker form is still the single-page form. Category and type images repeat in places because few property photos exist.

---

## Update (2026-10-29): Search and Map, the four tabs, the agent workspace

- Search start, search results and Map now live inside the customer shell (Explore selected). The map's bottom sheet and strip sit above the nav. All 24 audited customer routes now show the nav; focused wizards and forms stay outside on purpose.
- Home, Explore, Activity and Account are four different pages: Home = four image action cards, sponsored banner, services; Explore = editorial discovery with search, categories and development; Activity = Viewings / Maintenance / Selling (e-Broker submission status) / Requests (professional engagements), each record opens its own detail; Account = profile header and grouped settings rows (Your account, Preferences, Session), no card grid.
- The agent has a separate shell (`AgentShell`): Dashboard, Contacts, Listings, Calendar, More. A side rail on screens 900 px and wider, a bottom bar below. A shopper opening an agent route sees only the access explanation, with no agent navigation. `routeForSession`, the demo Skip and the Home resolver all send an approved agent to `/agent`. "View as a customer" (More) opens the shopper app and the switcher there leads back.
- Route table additions: `/agent`, `/agent/contacts`, `/agent/contacts/new`, `/agent/contacts/:id`, `/agent/contacts/:id/edit`, `/agent/calendar`, `/agent/more`; `/agent/listings*`, `/agent/leads*`, `/workspace/enquiries*`, `/workspace/requests*` moved into the agent shell.

---

## Update (2026-10-28): admin console, four professional workspaces, e-Broker wizard

Browser evidence: `j30` (admin), `j32` (professional workspaces), `j33` (e-Broker) in the QA scratch folder; screenshots copied to `docs/readiness/evidence/browser/` when the final report is made.

- **Admin Console** is hosted at `#/admin` in the same build. Own sign-in (`/login`, `/code`), own sidebar (Overview, Accounts, Verification, Listing moderation, Ads & Sponsors, Reports, Activity log). Customer, agent and professional navigation never appear inside it. Refreshing on `#/admin` stays on the console. Full route list: `ADMIN_ACCESS.md`.
- **Professional shell** (`ProShell`, `lib/features/pro/pro_shell.dart`) for approved Development, Construction, Architecture and Interior & Exterior accounts. Bottom bar below 900 px, side rail at 900 px and wider. Each role has its own five destinations:

| Role | Tab 1 | Tab 2 | Tab 3 | Tab 4 | Tab 5 |
|---|---|---|---|---|---|
| Development | Home | Projects | Enquiries | Company | More |
| Construction | Home | Portfolio | Requests | Company | More |
| Architecture | Studio | Portfolio | Engagements | Profile | More |
| Interior & Exterior | Gallery | Portfolio | Engagements | Profile | More |

  None of them carries Explore, Activity or Account. A shopper, an agent or a business that is not approved who opens `/pro` sees only the access explanation. `routeForSession`, the demo Skip chips and the Home resolver send an approved business to `/pro`. More leads to reviews, verification status, a workspace summary, "Browse as a customer" and Sign out.
- **e-Broker** form is a six-step wizard (property type, property information, location, price and photos, owner and documents, review and send). `/sell/new` is a focused page outside the shell. A routing defect found in the browser walk is fixed: the shell's `/sell/:id` route used to read `new` as a submission id ("We could not find this submission"); it now redirects `new` to the form (`/sell-new`).
- **Activity > Selling** lists the submission with status "In review" right after sending. The confirmation says "Prototype submission saved. No listing has been sent to a real service and nothing is live."

### Still not done
- Search start and Map remain inside the shell; nothing else changed there.
- e-Broker submissions are not in the admin moderation queue (the console has its own sample queue).
- The professional "Add portfolio work" and project editing for Construction, Architecture and Interior & Exterior remain unavailable (the service is not confirmed). Development has project creation. Contact activity, engagements (confirm locally) and portfolio images are sample data in a preview build only.
- Nothing has been deployed. The console on the Vercel address is not verified.

## Current state, gap-closure pass (2026-11-01)

This section supersedes any earlier statement here about the professional bars and the Admin Console language. The route-by-route tables are in `ROUTE_MATRIX.md`.

- **Every business role has six destinations of its own**, with Analytics a tab (the fifth). Agent: Dashboard, Listings, Contacts, Calendar, Analytics, More. Development: Overview, Projects, Units, Enquiries, Analytics, Company. Construction: Overview, Projects, Requests, Services, Analytics, Company. Architecture: Studio, Portfolio, Projects, Briefs, Analytics, Profile. Interior and exterior: Studio, Portfolio, Services, Engagements, Analytics, Profile. The five sets differ (tested).
- **Phones.** One floating bar with six equal tabs; at 320 px each is 48 px wide and its label scales down. Nothing is behind a menu. At 1280 px the bar becomes a side rail with the same six destinations.
- **The last tab is a hub** (`/pro/more`, titled Company or Profile): public profile, Business settings, reviews, verification status, workspace summary, the role's destinations that are not tabs, the way into the shopper app, and Sign out.
- **Side rail accessibility fixed.** At 900 px and wider the rail of every business workspace was not exposed to screen readers or the keyboard (the page's navigator blocked its semantics). It is now painted after the content, so it is exposed, and it mirrors in Arabic (rail on the right, separator on its left edge). Browser: all six rail items are findable and in order at 1280 for all five roles.
- **Back behaviour.** Analytics is a tab, so it has no Back control; the password page returns to Account and security; a profile opened from a service category returns to that category's results.
- **Admin Console.** The sidebar sits at the start edge: left in English, right in Arabic. On screens under 960 px a menu button opens a drawer (right edge in Arabic). The language button is on sign-in, the code step, the sidebar and the narrow top bar.
- **Customer shell** is unchanged: Home, Explore, Activity, Account.

## Visual pass (2026-11-01): phone bars are four destinations plus More

This supersedes the "six equal tabs on phones" statements above and in `GAP_CLOSURE.md`.

- Under 700 px every business workspace shows **four day-to-day destinations plus More**; from 700 px a **side rail lists all six**. Details and routes: `ROUTE_MATRIX.md` sections 3 and 4, reasons and evidence: `VISUAL_QA.md`.
- Analytics and the company or profile hub are reached from **More**, which stays selected on them. Nothing was removed.
- Tab labels are never scaled to a tiny size: a tab is 62 px wide at 320 px with a 10.5 px label on five-item bars.
- The Architecture tab previously named Briefs is now **Enquiries** everywhere (bar and rail).
