# AQARATI route matrix

Date 2026-11-01 (updated by the gap-closure pass). Describes the local working tree (nothing committed, pushed or deployed). Routes are hash URLs (`#/…`). Source of truth: `lib/core/router/app_router.dart`, `lib/core/router/extra_routes.dart`, `lib/features/agent/agent_routes.dart`, `lib/features/devbuild/db_routes.dart`, `lib/admin/admin_app.dart`.

Shells: **Customer** = `AQAppShell` (tabs Home, Explore, Activity, Account). **Agent** = `AgentShell`. **Pro** = `ProShell` (role-specific tabs). **Admin** = the console at `#/admin` with its own router and sidebar. **Focused** = full-screen wizard or form outside any shell, on purpose.

Verification key: **B** walked in headless Chromium (`j80`, `j82`, `j90`, `j42` etc., see `SCREENSHOT_INDEX.md`). **T** covered by widget or unit tests. Both are against local sample data; nothing is connected to a real service.

## 1. Customer (User to Shop)

| Route | Screen | Shell | Verified |
|---|---|---|---|
| `/app/home` | Home: greeting, sub line, one sponsored banner, six services (Properties, Development, Interior & Exterior Designer, Construction Company, Loan Calculator, Maintenance) | Customer, Home tab | B T |
| `/properties` | Properties landing: Buy, Rent, Sell with Aqary e-Broker, My Favorites (opens the landing only when no `cat`, `tx` or `types` is given) | Customer, Home tab | B T |
| `/properties/categories?tx=buy\|rent` | Four categories (Residential, Commercial, Industrial, Agriculture) | Customer | B T |
| `/properties/types?tx=…&cat=…` | Property types of the chosen category | Customer | B T |
| `/properties/all?cat=…&types=…` | Results with filters and sort | Customer | B T |
| `/saved` | My Favorites | Customer | B T |
| `/property/:id` | Property detail | Customer | T |
| `/property/:id/viewing`, `/slot`, `/review`, `/conflict` | Viewing booking steps | Focused | T |
| `/viewings`, `/viewings/:id` and `/requested /confirmed /declined /reschedule /cancel /cancelled /completed /review` | Viewings list, detail and states | Customer, Activity tab | T |
| `/app/explore` | Explore: search, four markets, “Browse by property type” (every type of all four markets), development projects, “Find people” (agents, trusted brokers), professional directories | Customer, Explore tab | B T |
| `/app/explore/build`, `/categories`, `/results` | Development & Building directories (development, construction, architecture, interior and exterior) | Customer | B T |
| `/build/pro/:id`, `/reviews`, `/projects`; `/build/project/:id`, `/gallery` | Professional profile, reviews, projects, project detail | Customer | T |
| `/professionals`, `/business/:id` | Professional list (Maintenance) and profile | Customer | B T |
| `/business/:id/engage`, `/business/:id/book`, `/bookings/:id` | Engagement request, booking | Focused | T |
| `/search/start`, `/search`, `/map` | Search, results, map | Customer, Explore tab | T |
| `/compare` | Compare properties | Customer | T |
| `/calculators`, `/calculators/:id` | Loan Calculator and property tools | Customer | B T |
| `/app/activity` | Activity: viewings, maintenance, selling, requests | Customer, Activity tab | B T |
| `/app/account` | Account, regrouped: Account, Preferences, Help and legal, Session | Customer, Account tab | B T |
| `/app/account/settings/security` | Account and security (password check, devices, sign-in methods) | Customer | B T |
| `/app/account/settings/notifications` | Notification settings (five categories, in-app only) | Customer | B T |
| `/app/account/settings/language` | Language and region (English, Arabic, rial) | Customer | B T |
| `/app/account/settings/appearance` | Appearance and accessibility (theme, text size, reduced motion) | Customer | B T |
| `/app/account/settings/privacy` | Privacy | Customer | B T |
| `/app/account/settings/preferences` | Saved preferences (interests, locations) | Customer | B T |
| `/app/account/settings/support` | Help and support (FAQ, saved message form) | Customer | B T |
| `/app/account/settings/about` | Legal and about | Customer | B T |
| `/app/account/profile`, `/edit` | Buyer profile | Customer | T |
| `/notifications` | Notification inbox | Customer | T |
| `/engagements`, `/engagements/:id`, `/reviews`, `/review/:kind/:id` | Customer engagements and reviews | Customer, Account tab | T |
| `/broker`, `/broker/list`, `/broker/:id` | AqaratiBroker intro, directory, profile | Customer | T |
| `/sell`, `/sell/:id`; `/sell/new`, `/sell/:id/edit` | Aqary e-Broker submissions; the six-step wizard | Customer; wizard Focused | T |
| `/provider`, `/provider/invite`, `/provider/requests/:id` | Maintenance provider invitation and workspace | Focused | T |
| `/account/delete` | Delete account (confirmation only, nothing is deleted) | Focused | T |

## 2. Entry, sign-up and verification (all roles)

`/entry`, `/onboarding/purpose` (demo builds show a “Skip: <role>” chip per purpose), `/signup/business`, `/onboarding/interests`, `/legal/terms`, `/legal/privacy`, `/login`, `/forgot-password`, `/reset-password`, `/otp`, `/verify-email`, `/account/active`, `/onboarding/documents`, `/onboarding/verification-intro`, `/onboarding/review`, `/onboarding/submitted`, `/verification`, `/verification/details`, `/verification/resubmit`, `/verification/resubmit/review`, `/verification/resubmitted`, `/verification/approved`, `/verification/summary`, `/workspace/activation`. Focused, simulated, verified by T (`phase1_entry_test`, `signup_paths_test`) and B (`j11`, `j24`, `j90` starts here).

## 3. Real Estate Agent (`AgentShell`: Dashboard, Listings, Contacts, Calendar, Analytics, More)

Six destinations. **Phones (under 700 px):** a bottom bar with Dashboard, Listings, Contacts, Calendar and More; Analytics is in More. **700 px and up:** a side rail with all six.

| Route | Screen | Verified |
|---|---|---|
| `/agent` | Dashboard with KPI strip | B T |
| `/agent/listings`, `/new`, `/:id`, `/:id/edit` | Listings | B T |
| `/agent/contacts`, `/new`, `/:id`, `/:id/edit` | Contacts | B T |
| `/agent/calendar` | Calendar | B T |
| `/agent/analytics` | **Analytics tab** (4, 8 or 12 weeks; deterministic sample data) | B T |
| `/agent/more` | More: Analytics link, Business settings and the rest | B T |
| `/agent/leads`, `/agent/leads/:id` | Leads (selected tab: More) | T |
| `/agent/settings`, `/agent/settings/p/<security\|notifications\|language\|appearance\|privacy\|preferences\|support\|about>` and `/agent/settings/p/password` | Business settings; the password prototype sits under Security | B T |
| `/workspace/enquiries`, `/:id`; `/workspace/requests`, `/:id` | Enquiries and requests | T |

## 4. Professional roles (`ProShell`)

Each role has **six** destinations of its own, in this order, shown in full in the **side rail from 700 px**. **On phones (under 700 px)** the bar shows four day-to-day destinations plus More (the fifth), and Analytics and the company or profile hub are reached from More (`/pro/more`, titled More on phones, Company or Profile in the rail). More stays the selected tab on Analytics, settings, reviews and the other secondary pages.

| Role | Rail (700 px and up) | Phone bar (under 700 px) |
|---|---|---|
| Development company | Overview, Projects, Units, Enquiries, Analytics, Company | Overview, Projects, Enquiries, Units, **More** |
| Construction company | Overview, Projects, Requests, Services, Analytics, Company | Overview, Projects, Requests, Services, **More** |
| Architecture | Studio, Portfolio, Projects, Enquiries, Analytics, Profile | Studio, Portfolio, Projects, Enquiries, **More** |
| Interior & exterior design | Studio, Portfolio, Services, Engagements, Analytics, Profile | Studio, Portfolio, Services, Engagements, **More** |

Routes: Overview/Studio `/pro`; Projects `/app/account/workspace/projects` (development) or `/pro/projects` (construction, architecture); Units `/pro/units`; Enquiries and Requests `/app/account/workspace/leads`; Services `/pro/services`; Portfolio `/app/account/workspace/portfolio`; Engagements `/app/account/workspace/engagements`; Analytics `/pro/analytics`; Company, Profile and More `/pro/more`. The More hub lists Analytics first, then the public profile, Business settings, the role's destinations that are not on the bar, reviews, verification status and the workspace summary.

| Route | Screen | Verified |
|---|---|---|
| `/pro` | Role Home with role-specific KPI strip | B T |
| `/pro/units` | Development: units by project and type (sample data, labelled) | B T |
| `/pro/projects` | Construction and Architecture: active or design projects with stage and progress (sample data, labelled) | B T |
| `/pro/services` | Construction and Interior: primary service, additional services on the same account, and the Explore categories they produce (local preview) | B T |
| `/pro/analytics` | Role-specific Analytics, now a tab | B T |
| `/pro/settings`, `/pro/settings/p/<eight pages>` and `/pro/settings/p/password` | Business settings: primary role, additional services, profile, team, shared pages | B T |
| `/pro/more` | Company or Profile hub | B T |
| `/app/account/workspace`, `/profile`, `/profile/status`, `/projects`, `/leads`, `/reviews`, `/engagements`, `/portfolio` | Workspace pages | T B |
| `/workspace/projects/new`, `/:id`, `/:id/edit`, `/:id/submitted` | Development project wizard and detail | T |
| `/workspace/leads/:id`, `/workspace/engagements/:id` | Contact activity and engagement detail | T |

A shopper, an agent or an unapproved business opening `/pro` sees only the access explanation.

### Customer routes added or changed in this pass
| Route | Change |
|---|---|
| `/app/account/settings/password` | The password prototype (current, new, confirm, requirements, simulated confirmation). Back goes to `/app/account/settings/security`. |
| `/build/pro/:id?svc=<interiorExterior\|construction\|…>` | Public business profile in the context of the service category the visitor browsed from. Lists every service category and marks the primary one. |
| `/app/explore/build/results?cat=…` | A business that offers the category as an additional service is listed here too, once. |

## 5. Admin console (`#/admin`, own router)

Sign-in then the sidebar (right side in Arabic). A language button (English / العربية) is on sign-in, the code step, the sidebar and the narrow top bar, and drives the same locale as the rest of the app. Screens: `/login`, `/code`, `/overview`, `/accounts`, `/accounts/:id`, `/verification`, `/verification/:id`, `/moderation`, `/moderation/:id`, `/m/:key`, `/m/:key/:id` (listings, projects and other moderated modules), `/ads`, `/ads/new`, `/ads/:id/edit`, `/reports`, `/reports/:id`, `/audit`, `/analytics`, `/settings`. Responsive: sidebar at 960 px and wider, drawer below (the 768 px screenshots show the drawer). Sign-in is a demo, only in preview builds (see `ADMIN_ACCESS.md`). Verified by B (`j30`, `j42`, `adm_before_*` and `adm_after_*` screenshots at 320, 360, 390, 412, 430, 768, 1280) and T (`admin_*` tests).
