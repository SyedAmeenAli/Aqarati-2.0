# Home, Explore, Analytics and registration redesign (round 7)

All local. Not committed, pushed or deployed. Evidence: `evidence/redesign/` (after, scroll-captured at 320, 390, 768, 1280 and 390 dark where the run finished); before: `evidence/asset_audit/shots/crawl_*_390.png`.

## What changed
| Area | Change |
|---|---|
| Explore | Property categories, professional categories and Services are now photo tiles (`AQPhotoTile`, `AQTileGrid`): 2 columns on every phone, 3 at tablet, 4 wide; description line, icon, arrow. Agriculture and Industrial are the same size as Residential. Property types are grouped into one card per market with wrapping chips. |
| Shop / Work | `RoleWorkspaceSwitcher` is a compact capsule with icons and a sliding thumb. It sits in the Home hero header (customer Home, approved agents) and at the top of the agent dashboard. It changes the real workspace state and route; same account, nothing reset. Not shown to customers without an approved agent grant. |
| Construction Home | Compact header, a short photo card with one action, a profile-status card, three balanced KPI cards in one row, and four large essentials cards (2 x 2, icon, number, heading, description, Complete / Add details status where the profile data supports it). |
| KPI cards (all roles) | `KpiGrid`: three across, four as 2 x 2, never a stranded card; icons; equal heights. Agent dashboard uses the same cards. |
| Other homes | Agent: icon KPI cards in 2 x 2. Developer: shorter hero. Architecture and Interior: portfolio photo strip from the portfolio service. |
| Analytics | Sliding 4 / 8 / 12 week switch, date range, Sample data chip (demo), icon KPIs, one hero chart card per role with metric chips, total, change against the previous period (computed from the series, not decorative), and a chart you can tap or drag to read a week (tooltip, marker, screen-reader label). Whole-number gridlines. Secondary cards (donut, bars) kept where data supports them. |
| Registration | Four picture cards, 2 x 2, whole card selects, check indicator, no logo above the title, no Skip on each card; one "Skip for now" under Continue (demo builds only). |
| Backgrounds | Agent and professional workspaces and customer Activity / Account sit on a clean warm surface. Home and Explore keep the restrained architectural wash. |

## Verification
- Tests: demo OFF 1100 pass (17 skipped); demo ON 1115 pass (2 skipped). New `test/redesign_test.dart` (21): grid columns and 2 x 2 at 320/343/390/430, 200% text, Arabic, dark; Shop / Work capsule; balanced KPI rows; essentials card size; period switch; chart tap reading; registration cards at 320 and 390. `test/role_home_test.dart` updated for the new labels (Work, Identity ...).
- `flutter analyze`: 0 errors.
- Builds: default, demo, admin succeeded.
- Browser (`j104_redesign.js`, final demo build): no horizontal overflow on all 12 redesigned screens at 390, 320, 768, 1280; Shop opens customer Home, Work returns to the agent workspace; period switch redraws; registration shows four types with no per-card Skip; Continue opens the Architecture sign-up form (confirmed in a screenshot; the script's text check for it is unreliable, so that one line shows FAIL in the log).

## Not done or not verified
- Dark: 390 dark run did not finish before this report; dark covered by widget tests only.
- Arabic RTL, reduced motion and large text: widget tests only, no browser screenshots.
- 343 and 430 widths: widget tests only.
- Screenshots opened at full size: construction home (390, 320), agent home, developer home, architecture and interior home, analytics (agent, construction, developer 768), explore (390, 1280), registration (390, 320), Shop mode. Not opened: the other analytics roles, all 1280 homes, remaining scroll frames.
- Shop / Work is not on professional-company homes: they have no switch-back route (their home resolves to /pro), so a switch there would be one-way. They keep the existing "Customer view" row under More.
- Developer "My projects" and Agent listings remain empty for the demo accounts.
- Analytics secondary cards were not redesigned beyond the shared card style; Agent and Developer have no new charts beyond what the data supported.
- Architecture login / entry flow was not separately audited or changed (only the registration cards and the architecture picture on them).
- KPI cards show no sparklines: counts have no trend series.
