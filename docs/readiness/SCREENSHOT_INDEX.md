# Screenshot index

Date 2026-10-31. All files are in `docs/readiness/evidence/browser/` (extension `.png`). They were taken by Playwright (headless Chromium) against the local demo bundle `build/web_demo`, built from the code in the working tree with `--no-web-resources-cdn`. Scripts: `j80_master.js` (English journeys), `j82_final.js` (viewport, dark, persistence, fonts), `j90_arabic.js` (Arabic from a genuine User to Shop demo session), `j42_admin2.js` (admin). Result files: `j80_results.json`, `j82_results.json`, `j90_results.json`, `j42_results.json`. A number after the name is the viewport width in px (height 844 at 390).

## Customer, English (`m80_*`)
| File | Screen |
|---|---|
| `m80_home_320`, `m80_home_390`, `m80_home_768`, `m80_home_1280` | Home: greeting, banner, six services |
| `m80_properties_390` | Properties landing (Buy, Rent, Sell with Aqary e-Broker, My Favorites) |
| `m80_explore_390` | Explore with the type browser and “Find people” |
| `m80_account_390` | Account, grouped |
| `m80_settings_Account_and_security`, `…_Notification_settings`, `…_Language_and_region`, `…_Appearance_and_accessibility`, `…_Privacy`, `…_Saved_preferences`, `…_Help_and_support`, `…_Legal_and_about` | The eight customer settings pages (390) |
| `m80_home_ar_390` | Home after switching to Arabic (earlier capture; the Arabic set below supersedes it) |

## Professional roles (`m80_<role>_*`, roles: agent, developer, construction, architecture, interior)
| Files | Screen |
|---|---|
| `m80_<role>_home_390`, `m80_<role>_home_1280` | Role Home with KPI strip (agent: Dashboard) |
| `m80_<role>_analytics_390` | Role Analytics (range chips, KPIs, charts, “Sample data”) |
| `m80_<role>_settings_390` | Business settings (primary role, additional services, profile) |

Examples: `m80_developer_analytics_390`, `m80_architecture_settings_390`, `m80_agent_home_1280`.

## Viewports, dark theme, persistence (`m82_*`)
| File | Screen |
|---|---|
| `m82__app_home_320`, `_390`, `_1280` | Customer Home |
| `m82__properties_320`, `_390`, `_1280` | Properties landing |
| `m82__app_explore_320`, `_390`, `_1280` | Explore |
| `m82__app_account_settings_appearance_320`, `_390`, `_1280` | Appearance and accessibility |
| `m82_construction_analytics_390`, `_1280`; `m82_construction_settings_390`, `_1280` | Role pages at two widths |
| `m82_dark__app_home_390`, `_1280`; `m82_dark__properties_*`; `m82_dark__app_explore_*`; `m82_dark__app_account_*`; `m82_dark__app_account_settings_notifications_*`; `m82_dark__app_account_settings_support_*` | Dark theme, six customer screens at 390 and 1280 |
| `m82_dark_pro_analytics_390`, `m82_dark_pro_analytics_1280` | Dark theme, professional Analytics |
| `m82_after_reload_dark_ar_390` | After reload: Arabic, dark, larger text, reduced motion all retained |
| `m82_arabic_account_390` | Account in Arabic (earlier capture) |

## Arabic, genuine User to Shop demo session (`m90_*`, 390 unless noted)
| File | Screen |
|---|---|
| `m90_explore_purpose` | Purpose screen with the demo “Skip: User to Shop” chips (where the session starts) |
| `m90_en_home_390` | Home in English immediately after the demo skip |
| `m90_ar_language_390` | Language and region, after choosing العربية |
| `m90_ar_home_390`, `m90_ar_home_320`, `m90_ar_home_768`, `m90_ar_home_1280` | Arabic Home: greeting, Arabic sponsored campaign, six services, RTL tab bar |
| `m90_ar_properties_390` | Properties landing |
| `m90_ar_buy_390`, `m90_ar_buy_commercial_390`, `m90_ar_rent_390`, `m90_ar_results_390` | Buy categories, Commercial types, Rent categories, results |
| `m90_ar_explore_390`, `m90_ar_explore_build_390` | Explore, professionals |
| `m90_ar_activity_390`, `m90_ar_account_390` | Activity, Account |
| `m90_ar_settings_security_390`, `…_notifications_`, `…_language_`, `…_appearance_`, `…_privacy_`, `…_preferences_`, `…_support_`, `…_about_` + `390` | The eight settings pages in Arabic |
| `m90_ar_form_security_error_390`, `m90_ar_form_support_error_390` | Form validation messages in Arabic |

## Admin Console (`adm_after_*`, earlier polish pass; unchanged code, re-walked by `j42_admin2.js`)
`adm_after_1280_01_login` … `adm_after_1280_17_announcements` (17 screens at 1280), the same 17 at `adm_after_390_*` and `adm_after_768_*`, and drawers at 320, 360, 390, 412, 430 and 768 (`adm_after_<w>_drawer`). `adm_before_*` shows the console before that polish.

## Earlier evidence kept for the record
`j*_*.png` files from the earlier passes (agent, e-Broker, professional workspaces, sponsorship, integration) are unchanged.

## Gap-closure pass (2026-11-01, `m95_*`)
Taken by `j95_nav.js`, `j95_disc.js`, `j95_admin.js` and `j95_fonts.js` against the final demo bundle (`build/web_demo`), headless Chromium. Result files: `j95_nav_results.json`, `j95_disc_results.json`, `j95_admin_results.json`, `j95_fonts_results.json`. `<role>` is agent, developer, construction, architecture or interior.

| File | Screen |
|---|---|
| `m95_<role>_home_320`, `m95_<role>_home_1280` | Role Home with the six-tab bar at 320 px and the side rail at 1280 px |
| `m95_<role>_analytics_390` | Analytics as a tab |
| `m95_<role>_hub_390` | The last tab: Company (development, construction), Profile (architecture, interior) or More (agent) |
| `m95_agent_ar_390`, `m95_developer_ar_390`, `m95_interior_ar_390` | Arabic bars: the six tabs run right to left |
| `m95_services_390` | Services tab (construction): primary role, additional services, Explore categories preview, "nothing is published" note |
| `m95_explore_interior_390`, `m95_ar_explore_interior_390` | Interior-design directory listing a construction company that also designs interiors (English, Arabic) |
| `m95_profile_services_390`, `m95_ar_profile_services_390` | That company's profile: service categories, primary marked, one-business note |
| `m95_enquiry_interior_390` | The contact sheet naming "Enquiry about: Interior design" |
| `m95_password_390`, `m95_password_simulated_390`, `m95_ar_password_390` | Password prototype: requirements and fields, simulated confirmation, Arabic |
| `m95_admin_login_en`, `m95_admin_login_ar`, `m95_admin_login_ar_errors` | Admin sign-in with the language button, in Arabic, and Arabic field errors |
| `m95_admin_ar_01_1280` … `m95_admin_ar_18_1280` | The 18 console screens in Arabic at 1280 px (Overview, Accounts, Verification, Agents and brokers, Listing moderation, Property listings, Development projects, Construction, Architecture and design, Maintenance, Viewings and requests, Ads & Sponsors, Announcements, Categories and content, Reports, Analytics, Activity log, Profile and settings) |
| `m95_admin_ar_account_detail_1280`, `m95_admin_ar_ad_form_1280` | Account detail; banner form with Arabic validation |
| `m95_admin_ar_overview_320/390/768`, `m95_admin_ar_drawer_320/390/768`, `m95_admin_ar_accounts_320/390/768` | Narrow Arabic console: overview, the drawer from the right, accounts as cards |
| `m95_fonts_ar_profile_390`, `m95_fonts_ar_admin_390` | Arabic profile and Arabic admin rendered with every request that leaves localhost blocked |

## Visual pass (2026-11-01)
`VISUAL_QA_INDEX.md` lists every before and after screenshot (`v96_before_*`, `v96_after_*`, with `_ar_` and `_dark_` variants and the entry screens `v96_after_entry_*`). `m96_<role>_bar_<320|343>`, `m96_<role>_rail_<768|900|1024|1280>`, `m96_<role>_ar_bar_390` and `m96_<role>_analytics_from_more_390` come from `j95_nav.js`. Scripts: `j96_shots.js` (matrix), `j96_motion.js` (frame capture), `j95_nav.js`.
