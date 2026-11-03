# 04. Component architecture

Read-only. Derived from a scan of every `class` whose name matches a component pattern (172 matches, `docs` appendix list below) and from reading the main ones. Paths are under `lib/`.

## 1. Key components

| Component | Source file | Used by | Current behaviour | Problems | Proposed improvement |
|---|---|---|---|---|---|
| Page header (customer) `AQHero` | `features/workspace/aq_home.dart` | Home, Explore, Properties hub, results | photo that fades into the page, logo row, location pill, avatar, `belowHeader` slot, title, sub | two photos stacked under three gradients; photo repeated across tabs; mode capsule only via `belowHeader` | one `AQHeader` with solid and photo variants and a defined action slot |
| Page header (workspace) `DbShellPage`, `AQViewingScaffold`, `_AgentPage`, `RoleHomePage`, `AdminFrame` | `devbuild/db_workspace.dart`, `viewing/widgets/viewing_scaffold.dart`, `agent/agent_screens.dart`, `role_home/role_home_widgets.dart`, `admin/admin_widgets.dart` | each area | five different page scaffolds with different paddings, back bars, title styles | five ways to place a title and Back; each re-implements scroll padding for the floating bar (`AQShellInset`) | one workspace scaffold with a title, back, actions and bottom inset |
| Customer bottom bar `AQGlassNav` | `core/aq/aq_scene.dart:660` | customer, agent and business shells | `AQGlass` blur 20, sliding capsule indicator, compact-on-scroll | label 10.5-11 px; same widget for 4, 5 and 6 items | keep; make compact mode and items count part of the spec |
| Rail `WorkspaceSideRail` | `features/agent/agent_shell.dart` | agent and business shells ≥ 700 px | vertical rail | separate from the customer layout at wide widths (customer stays a phone column) | one responsive shell |
| Admin navigation `_Sidebar`, `_BottomNav`, `_Rail`, `_NavButton` | `admin/admin_widgets.dart` | Admin | sidebar ≥ 960, rail 600-959, bottom bar + drawer < 600 | breakpoints differ from the product's 700 | align with central breakpoints |
| Shop/Work `RoleWorkspaceSwitcher` | `role_home/role_home_widgets.dart` | customer Home, Explore, agent dashboard, business homes | glass capsule, sliding thumb, real route switch via `mode_switch.dart` | placed by four different callers (`belowHeader`, row, `_ProModeBar`) | one header slot |
| Search `AQSearchEntry` | `workspace/aq_home.dart:325` | Home, Explore, hub | glass pill that opens `/search/start` | not a field; the search screens (`aq_search.dart`) have a second search UI | one search component with two states |
| Filters `AQFilterSheet`, `AQChoicePill`, `DbPillRow`, `AQSegmented` | `search/aq_filter_sheet.dart`, `devbuild/db_widgets.dart`, `core/aq/aq_forms.dart` | property and professional discovery | three pill/segment systems | duplicated visuals and behaviour | consolidate on one chip and one segmented control |
| Photo cards | `_PhotoTile` (`workspace/aq_home_services.dart`), `AQPhotoTile` + `AQTileGrid` (`workspace/aq_tiles.dart`), `AQActionCard` + `AQActionGrid` (`workspace/aq_action_card.dart`), `AQBanner` (`aq_home.dart`), `RolePhotoPanel` (`role_home_widgets.dart`) | Home / Explore / hub / business homes | five implementations of "photo with scrim and text" | different radii, scrims, tap affordances | one `AQPhotoCard` family (tile, banner, hero) |
| Property card `AQResultCard` | `workspace/aq_home.dart` | results, saved, related | photo, price, facts, save | lives inside the 1,500-line `aq_home.dart` with Home/Explore widgets | extract; add saved/sponsored states |
| Professional card `DbProCard` | `devbuild/db_widgets.dart:323` | discovery lists, Explore | photo strip + text, rating, verified | reads repository cover/logo, not the new media store | read from the media store; add avatar/logo variant |
| Project card `DbProjectCard` | `devbuild/db_widgets.dart` | workspace lists, profile | 72 px thumb + text (cover from `DbProject.cover`) | small thumb; no status colour system | larger cover variant |
| Portfolio cards | `_PortfolioState` list (`db_pro_tools.dart`), `RolePortfolioStrip` (`role_home_widgets.dart`) | portfolio page, studio homes | list rows vs horizontal photo strip | two representations | one `AQPortfolioCard` |
| KPI `KpiTile`, `KpiGrid`, `RoleKpiStrip` | `analytics/analytics_charts.dart`, `analytics_screens.dart` | all role homes, analytics, agent dashboard | big number, icon, balanced rows | all identical in look; no context line | per-role variants |
| Essentials `RoleEssentialCard` | `role_home/role_home_widgets.dart` | Construction home only | icon, number, title, description, status | 176 px minimum; only one role uses it | generalise as the "module card" |
| Charts | `AQColumnChart`, `AQLineChart`, `AQBarChart`, `AQDonut`, `AnalyticsCard` | analytics | see doc 08 | donut and bars not interactive | add tooltips, shared legend |
| Media `AqMediaField`, `AqMediaFrame`, `AQAvatar`, `AQBusinessLogo` | `features/media/aq_media.dart` | profile photo, company profile, portfolio, headers | see doc 06 | partial propagation | finish propagation and persistence |
| Dialogs and sheets | `showDialog` / `showModalBottomSheet` in about 30 sites; `AQSheetRow` (`aq_scene.dart`), `showDbChoiceSheet` (`db_widgets.dart`), `adminConfirm` (`admin_directory_screens.dart`) | many | Material defaults mixed with custom rows | no shared sheet surface | one `AQSheet`/`AQDialog` on `AQGlass` |
| Settings rows `_SettingsRow`, `SwitchRow`, `SwitchRowLike`, `DbSettingToggle`, `DbServiceToggles` | `workspace/aq_app_shell.dart`, `settings/settings_screens.dart`, `business_settings_screen.dart`, `devbuild/*` | account and business settings | four switch row designs | inconsistent | one `AQSwitchRow` |
| Status badges `AQStatusPill`, `ListingStatusPill`, `EBrokerStatusPill`, `EngagementPhasePill`, `DbStatusChip`, `RoleChip`, `adminStatusPill` | `core/aq/aq_status.dart` and feature files | lists | seven status pills | colours and shapes differ | one pill with tone enum |
| Empty / notice | `AQNoticeCard`, `AQEmptyViewingState`, `DbNotice`, `AdminNotice`, `AQNoticeLine` (x3) | everywhere | five empty/notice designs | | one `AQNotice` with icon, text, action |
| Loading | `AQSkeleton`, `AQSkeletonBox`, `DbSkeleton`, `DbSkeletonList`, `AQViewingSkeleton` | lists | five skeleton widgets | | one `AQSkeleton` |
| Back | `AQTopBar`, `AQViewingScaffold` back, `AdminFrame.onBack`, `aqBack` | all secondary pages | consistent behaviour (pop else fallback) | three visual styles | one back bar |

## 2. Duplicates worth consolidating (highest value first)

1. Photo-with-scrim cards (five implementations).
2. Page scaffolds (five).
3. Status pills (seven), notices (five), skeletons (five).
4. Chips/segmented (three customer systems + `AdminChip`) and switch rows (four).
5. Settings rows and list rows (`RoleRow`, `_SettingsRow`, admin rows).

## 3. Components that should stay role-specific

`AdminFrame` and the Admin table-to-card conversion (`AdminTable`), the agent CRM rows (`_ContactRow`, `_AppointmentRow` in `agent_screens.dart`), the viewing flow kit (`AQViewing*`), document upload tiles (`DocumentUploadTile`), the ad banner view (`SponsoredBannerView`), property-specific detail sections.

## 4. Components that need replacing, not patching

- The three-way service selector pattern (`DbPillRow` over `InteriorExteriorServiceType.values`) still in the customer discovery filter.
- `RolePhotoPanel` plus `_PhotoTile` plus `AQPhotoTile` (merge).
- The legacy Material theme in `core/theme`.
- `aq_home.dart` (1,500 lines holding header, search, banner, result card, location sheet, skeletons, properties screen): split.

## Appendix: component classes found
Machine-generated list of 172 classes matching Tile/Card/Kpi/Hero/Banner/Segmented/Pill/Chip/Switch/Toggle/Avatar/Header/TopBar/Empty/Notice/Skeleton/Surface/Section/Chart/Nav/Rail/Sidebar/Drawer/Frame/Button/Sheet/Scaffold/Page is in `docs/readiness/ui_ux_audit/components_index.txt`.
