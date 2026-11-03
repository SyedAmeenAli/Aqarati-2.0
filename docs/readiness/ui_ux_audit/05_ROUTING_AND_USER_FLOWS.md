# 05. Routing and user flows

Read-only audit of the working tree as it stands today (it contains the earlier local fixes; where a defect was already fixed locally, both the cause and the current state are stated). Router files: `core/router/app_router.dart` (shells, entry, auth, customer), `core/router/extra_routes.dart`, `features/agent/agent_routes.dart`, `features/devbuild/db_routes.dart`, `admin/admin_app.dart`. Session and mode state: `data/api/account_api.dart (meProvider)`, `features/role_home/role_home_model.dart (resolveHome, homeWorkspaceProvider, homeResolutionProvider)`, `features/role_home/mode_switch.dart`.

## 1. How the app decides where a person belongs

```mermaid
flowchart TD
  A[App start: initialLocation /entry] --> B{Choose}
  B -- Create account --> C[/signup/user or /signup/agent by chooser/]
  B -- Login --> D[/login?as=user|agent/]
  B -- Register as Business --> E[/signup/business -> 4 role cards/]
  D --> F[routeForSession(me)]
  F -- otpPending --> G[/otp/]
  F -- no role docs needed --> H[/app/home/]
  F -- approved agent --> I[/agent/]
  F -- approved business --> J[/pro/]
  F -- not approved --> K[/verification/]
  F -- draft --> L[/onboarding/verification-intro/]
  H --> M{homeResolutionProvider}
  M -- buyer --> N[AQHomeScreen]
  M -- agent chose Work --> O[_GoToWorkspace -> /agent]
  M -- business --> P[_GoToWorkspace -> /pro]
```

- The entry chooser (`_ExperienceChooser` in `features/entry/screens/onboarding_entry_screen.dart`) only sets `entryExperienceProvider`. It selects which sign-up and login route the two buttons open (`/signup/user|agent`, `/login?as=user|agent`). It grants nothing: "The account decides where it belongs, not the door that was chosen" (comment in the same file).
- `routeForSession` (`features/flow/screens/auth_screens.dart:22`) is the single post-login destination function. `LoginScreen` honours a `next` query only when it is a local path.
- `/app/home` is shared: `RoleHomeScreen` (`features/role_home/role_home_screen.dart`) resolves the session and either shows the customer Home or runs `_GoToWorkspace`, a stateful widget that calls `context.go('/agent' | '/pro')` in a post-frame callback and returns an empty box. The result is a two-step transition (paint `/app/home`, then redirect) wrapped in an `AnimatedSwitcher`.

## 2. The unexpected screens: traced causes

| Symptom in the recordings | Cause in code | Status in the working tree |
|---|---|---|
| "Business workspace only" page | `ProShell` guard (`features/pro/pro_shell.dart`, `allowed = me.hasValue && isProRole(res.role)`) rendered an `AQViewingScaffold` whose only exit was Back (`aqBack(context, '/app/home')`). Any signed-out visitor, plain customer, or person whose application was in review hit the same page. The same pattern existed in `AgentGuard` (`features/listings/agent_guard.dart`) with copy "Agent workspace only" and a primary button that went to `/app/home`. | Replaced locally by `WorkspaceAccessNotice` (`features/role_home/mode_switch.dart`): guest gets Sign in (destination kept) and Register, customer gets Register as a Business, pending gets the status link. |
| The welcome screen coming back | Back fallbacks and sign-out paths target `/entry`: `agent_shell.dart:87` (`AgentGuard.backFallback: '/entry'`), `auth_screens.dart:122`, `legal_screens.dart:23`, `aq_auth_scaffold.dart:106`, `purpose_selection_screen.dart:185`, plus explicit `context.go('/entry')` after sign-out in `aq_app_shell.dart:235`, `pro_shell.dart:330`, `agent_screens.dart:1290`, `business_settings_screen.dart:151`, `delete_account_screen.dart:150`, `admin_host.dart:20`. `aqBack` pops when it can and otherwise goes to the fallback, so a deep-linked or redirected page with no stack sends Back to the welcome screen. | Guards no longer use `/entry` as a fallback; the other uses are intentional (sign-out, delete account). |
| Shop and Work feeling like two products | They are not separate navigators. Both are branches of the same `GoRouter`; moving between them is `context.go(...)`, which replaces the stack. The "mode" is `homeWorkspaceProvider` (`StateProvider<HomeWorkspace?>`), in memory only. | Unified entry points `switchToShop` / `switchToWork` (`mode_switch.dart`) plus `/shop` and `/work` gates now exist locally. |

## 3. Shop and Work (agent) flow as implemented now

```mermaid
sequenceDiagram
  participant U as Agent
  participant H as AQHomeScreen (Shop)
  participant C as Capsule (RoleWorkspaceSwitcher)
  participant S as mode_switch.dart
  participant R as GoRouter
  U->>C: tap Shop (on /agent)
  C->>S: switchToShop()
  S->>S: await meProvider.future; resolveHome(me, chosen)
  S->>S: homeWorkspaceProvider = buyer
  S->>R: go(/app/home)
  R->>H: customer shell (bottom bar)
  U->>C: tap Work
  C->>S: switchToWork()
  S->>S: homeWorkspaceProvider = agent
  S->>R: go(/agent)
```

Findings:
- Account and profile state are preserved (same `meProvider`; `profilePhotoProvider` and other in-memory providers are not touched). `homeWorkspaceProvider` is **not persisted**: a browser reload returns an approved agent to the Work side (`chosen ?? HomeWorkspace.agent` in `resolveHome`).
- Switching causes a route replace and therefore a full rebuild of the target shell (Agent shell ↔ customer shell). There is no shared element or coordinated transition; the capsule thumb animates but the content change is the shell's `AQRoute.tab` fade.
- For **business roles** (development, construction, architecture, interior/exterior) `resolveHome` pins the role, so `/app/home` always redirects to `/pro`. Shop for them is `/app/explore` (`switchToShop`), with the capsule in Explore (`aq_explore.dart`) and at the top of each business home (`_ProModeBar` in `role_home_widgets.dart`). Their customer-side Home tab bounces back to `/pro`, which is the way back.

## 4. Role entry flows

| Role | Entry | Post-login route | Workspace shell | Notes |
|---|---|---|---|---|
| Customer (User to Shop) | `/signup/user`, `/login?as=user` | `/app/home` | `AQAppShell` | Guest browsing allowed; guards use `aqRequireSession` (`property_detail_screen.dart`). |
| Real Estate Agent | `/signup/agent`, `/login?as=agent` | `/agent` when approved, `/verification` otherwise | `AgentShell` (`agent_shell.dart`) | Six slots, five on phone (Analytics under More). `AgentGuard` wraps every agent screen. |
| Development | `/signup/business` → `/signup/development` | `/pro` | `ProShell` | Nested workspace pages under `/app/account/workspace/*` and `/workspace/*` (customer-shell routes with `DbGuard`). |
| Construction | `/signup/business` → `/signup/construction` | `/pro` | `ProShell` | Same as above. |
| Architecture | `/signup/business` → `/signup/architecture` | `/pro` | `ProShell` | There is no dedicated Architecture login; `/login?as=` only knows `user` and `agent` (`entry_experience.dart`). Business sign-in goes through the generic login. |
| Interior & Exterior | `/signup/business` → `/signup/interior-exterior` | `/pro` | `ProShell` | Service type collected at sign-up (`signup_form_screen.dart`). |

## 5. Two route families for business pages (a structural inconsistency)

- Role-bar pages under `ProShell`: `/pro`, `/pro/more`, `/pro/analytics`, `/pro/units`, `/pro/projects`, `/pro/services`, `/pro/settings`, `/pro/settings/p/:name`.
- Workspace pages that live in the **customer** shell with a Back bar: `/app/account/workspace/{projects,leads,reviews,portfolio,profile,engagements}`, `/workspace/{projects,enquiries,requests}`, `/build/pro/:id/*` (public profile). Opening them from a business bar shows the customer shell's chrome rules for the duration, which is why back targets (`_wsBack`) differ between pages and why the business bar disappears on some pages.

## 6. Defects and risks recorded

1. Mode state is in memory only (`homeWorkspaceProvider`); reload resets it.
2. `_GoToWorkspace` produces a visible two-step redirect on `/app/home` for approved business and agent accounts.
3. No dedicated Architecture / business login: `entry_experience.dart` has only `user` and `agent`.
4. The Explore Interior/Exterior filter in discovery still lists **Both** as a third choice (`features/devbuild/db_discovery.dart:470` and `:553`, iterating `InteriorExteriorServiceType.values`).
5. Two overlapping route families for business pages (section 5).
6. Back fallbacks to `/entry` remain in auth, legal and purpose screens (benign when launched from the welcome screen, wrong for deep links).
7. Demo-only `demoSkipInto` (`features/entry/demo_entry.dart`) jumps into `/agent` or `/pro`, bypassing `routeForSession`; it is gated by `kDemoMode`.
