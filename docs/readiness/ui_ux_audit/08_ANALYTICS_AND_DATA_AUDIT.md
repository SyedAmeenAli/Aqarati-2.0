# 08. Analytics and data audit

Read-only. All charts are **custom painters in the repository** (no chart package in `pubspec.yaml`): `features/analytics/analytics_charts.dart`; pages and data in `features/analytics/analytics_screens.dart`. Routes: `/agent/analytics`, `/pro/analytics` (role by session via `ProAnalyticsScreen`).

## 1. Components

| Widget | File | What it draws | Interaction | Animation | Responsive |
|---|---|---|---|---|---|
| `KpiTile` / `KpiGrid` | `analytics_charts.dart` | big number, label, optional icon; 1, 2, 3 (compact) or 2 x 2 / 4 across | optional tap | count-up (`_KpiValue`) | rows of equal height; large text drops three to one column |
| `AQColumnChart` | same | weekly vertical bars from zero, whole-number gridlines | tap or drag reads a week; tooltip kept inside the chart; screen-reader label updates | bars grow once per data change | full width, fixed 190 high |
| `AQLineChart` | same | straight segments, marker per point, no fill | tap or drag reading (same tooltip) | line draws in | full width |
| `AQBarChart` | same | horizontal progress bars, one palette colour per row | none | bars fill in | label column fixed 108 px |
| `AQDonut` | same | ring of parts with legend | none | sweep in | stacks below 360 px |
| `AnalyticsCard` | same | titled container | none | none | n/a |
| `AQPeriodSwitch` | `analytics_screens.dart` | 4 / 8 / 12 weeks capsule | selection redraws every figure | thumb slides | equal thirds |
| `AQChoicePillCompact` | same | metric chips on the hero card | switches series | none | wraps |

## 2. Data per role (where the numbers come from)

| Role | Card | Data source | Real local records or hard-coded? |
|---|---|---|---|
| Agent | KPIs: new leads, viewings ahead, follow-ups due | `agentCrmProvider` contacts and appointments (`agent_crm.dart`, demo seed) | real demo records, computed |
| Agent | Hero weekly leads / listing views | `sampleWeekly('agent-leads'|'agent-views', base, amp, weeks: 24)` | **generated**: deterministic hash-based pseudo-random series, not derived from any record |
| Agent | Contacts by stage, viewings donut, follow-up rate | CRM records | real demo records |
| Development | KPIs published / in review / contact taps | `dbMyProjectsProvider`, `dbMyContactEventsProvider` | real demo records (empty for the demo developer: 0, 0, 4 contact events) |
| Development | Hero enquiries / project interest | `sampleWeekly` | generated |
| Development | Projects by status donut, contact channels | project and contact-event records | real |
| Construction | KPIs requests, awaiting, completed | contact events and engagements | real |
| Construction | Hero requests | `sampleWeekly` | generated |
| Construction | Engagements donut, contact channels | engagement and event records | real |
| Construction | Project progress bars (Planning 3, Building 5, Finishing 2, Handover 4) | literal constants in `analytics_screens.dart` | **hard-coded**, labelled sample |
| Architecture / Interior | KPIs portfolio, engagements, contact taps | portfolio, engagement, event records | real |
| Architecture / Interior | Hero portfolio views, enquiries | `sampleWeekly` | generated |
| Architecture | Pipeline bars (Brief 4, Concept 3, Permits 2, Site 2) | literal constants | **hard-coded** |
| Interior | Service interest bars (Interior 9, Exterior 5) | literal constants | **hard-coded**; "Both" removed locally |

`sampleWeekly` (`analytics_screens.dart:20`) seeds an FNV-style hash from the key and walks a linear congruential generator, adding a gentle upward trend. The same role and key always give the same series, so it is stable but it is **not** a measurement and is unrelated to the KPI records beside it.

## 3. Why the earlier charts looked artificial

1. A smoothed cubic line with an area gradient made every series look like a gentle wave regardless of data (removed locally: straight segments, markers, bars).
2. A "% vs the previous N weeks" badge computed from two invented series (removed locally).
3. The same chart template for every role: one hero series plus two to four cards; the cards mostly show two to five tiny integers.
4. KPI numbers (real, small: 0 to 6) next to a chart whose scale is 20 to 100 (generated). The two never reconcile.
5. Donuts for two or three parts and horizontal bars with palette colours cycling by row rather than by meaning.

## 4. Behaviour checks

- Period selector: changes `_weeks`; hero totals and the chart slice update; the KPI and record-based cards do **not** depend on the period.
- Tooltips: column and line charts only. Donut and bars have none.
- Comparisons: no percentage change is shown now.
- Sample disclosure: a "Sample data" chip in demo builds and one sample note on the hero.
- Animations: once per mounted chart or data change; respect `AQMotion.scaled` (reduced motion gives zero duration).
- Tests: `test/analytics_test.dart`, `test/redesign_test.dart`, `test/refinement_test.dart`.

## 5. Proposed visualisation per role (no new metrics)

| Role | Keep / use | Replace |
|---|---|---|
| Agent | Lead stage funnel (stage counts from CRM), viewings status (scheduled, done, cancelled), follow-up due list; lead sources (`AgentContact.source` exists on every contact, so an enquiry-source bar chart is real data); weekly activity from `AgentContact.lastInteraction` and the dated notes (`ContactNote`) instead of `sampleWeekly`; there is no created-date field, so true weekly lead intake cannot be computed | generated listing-views series (no view events exist) |
| Development | Unit availability segmented bar (units exist as `_sampleUnits` in `pro_tab_screens.dart`), project status bars, contact-channel bars | generated enquiry series (use `ContactEvent.at` counts per week) |
| Construction | Requests by status (engagements), project progress bars from real projects, contact channels | hard-coded stage constants |
| Architecture | Engagements by state, portfolio count, contact channels | hard-coded pipeline constants |
| Interior & Exterior | Interior vs Exterior interest only if customer enquiries carry the category; engagement states; portfolio count | hard-coded 9/5 |

Where no dated records exist (portfolio views, listing views) the honest option is to show the figure as unavailable instead of a generated series.
