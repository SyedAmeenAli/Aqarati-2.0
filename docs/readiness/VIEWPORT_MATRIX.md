# Final viewport verification matrix

Date 2026-11-01 (gap-closure pass; rows marked **new** or changed). Headless Chromium, local demo bundle built from the final working tree (`--no-web-resources-cdn`). The check at every width is “no horizontal overflow” (`document.scrollWidth <= innerWidth`) plus the content assertions of the named script. Screenshots are listed in `SCREENSHOT_INDEX.md`.

Widths: 320, 360, 390, 412, 430, 768, 1024, 1280 px.

| Surface | 320 | 360 | 390 | 412 | 430 | 768 | 1024 | 1280 | Script |
|---|---|---|---|---|---|---|---|---|---|
| Customer: 15 routes (Home, Properties, Buy categories, Explore, Explore professionals, Activity, Account, eight settings pages), English, light | ok | ok | ok | ok | ok | ok | ok | ok | `j82` |
| Customer Home content (greeting, sub line, six services, one banner, four-tab bar) | ok | | ok | | | ok | | ok | `j80` |
| Role workspace Home, Analytics, Settings and More (one role per width, rotating: agent 320 and 768, developer 360 and 1024, construction 390 and 1280, architecture 412, interior 430) | ok | ok | ok | ok | ok | ok | ok | ok | `j82` |
| **New.** All five roles: six tabs in the bar (phone) or six items in the side rail (900 px and up), inside the screen, no overflow | ok | ok | ok | ok | ok | ok | ok (rail) | ok (rail) | `j95_nav` (320, 390, 1280), `j95_widths` (the other five) |
| **New.** All five roles: tab-by-tab walk, every tab lands on its route, content shown, no overflow | | | ok | | | | | ok (rail) | `j95_nav` |
| **New.** Three roles in Arabic: six tab names, tabs run right to left, no overflow | | | ok | | | | | | `j95_nav` |
| All five roles: Home KPI strip, Analytics, Business settings | | | ok | | | | | ok (Home only) | `j80` |
| Arabic customer Home, six services, RTL tab order | ok | | ok | | | ok | | ok | `j90` |
| Arabic: Properties, Buy, Commercial, Rent, results, Explore, professionals, Activity, Account, eight settings pages, two forms | | | ok | | | | | | `j90` |
| Dark theme: Home, Properties, Explore, Account, Notifications, Support; professional Analytics | | | ok | | | | | ok | `j82` |
| Admin Console, English (17 screens) | drawer | drawer | ok | drawer | drawer | ok | | ok | `j42`, `adm_after_*` |
| **New.** Admin Console in Arabic: sign-in, 18 screens (1280), narrow overview, drawer from the right and accounts as cards | drawer, cards | | drawer, cards | | | drawer, cards | | sidebar on the right, 18 screens | `j95_admin`, `m95_admin_ar_*` |
| **New.** Admin Arabic in widget tests: sidebar right, headings right, columns right to left, menu and language buttons, no overflow | ok | | ok | | | ok | | ok (1300) | `admin_arabic_test` |
| **New.** Explore: interior directory, profile with service categories, enquiry naming the service (English, Arabic) | | | ok | | | | | | `j95_disc` |
| **New.** Password prototype: rules, errors, simulated confirmation, return (English, Arabic) | | | ok | | | | | | `j95_disc` |
| **New.** Offline walk (every request leaving localhost aborted): customer, business and admin, English and Arabic | | | ok | | | | | | `j95_fonts` |
| Reload persistence (Arabic, dark, text size 130 %, reduced motion, notification choice, preferred location) | | | ok | | | | | | `j82` |

Blank cells were not run at that width; they are not claimed.

## Result
- Earlier suites against the final bundle: `j80` 81 of 81, `j82` 29 of 29, `j90` 42 of 42, `j42` 70 of 70, `j44` 8 of 8: **230 checks, 0 failures**. (`j80` and `j90` were adjusted to the new structure: Analytics is a tab, Business settings is under the Company/Profile/More hub, and the password form lives on its own page. No assertion was removed.)
- This pass: `j95_nav` 135, `j95_widths` 50, `j95_disc` 38, `j95_admin` 35, `j95_fonts` 11: **269 checks, 0 failures**.
- **Total 499 browser checks, 0 failures.**
- Network: with every request that leaves localhost aborted (`j95_fonts`), English and Arabic customer, business and admin screens render, no request fails, and only these font files load: Fraunces, Plus Jakarta Sans, IBM Plex Sans Arabic weights, Material and Cupertino icons, plus the engine's own Roboto file. CanvasKit is in `build/web/canvaskit/`. No request left `localhost` in the sign-in, discovery or Arabic admin runs either.
- **Not run:** the Arabic admin at 360, 412, 430 and 1024 px (the English admin and the Arabic admin at 320, 390, 768 and 1280 were); the eight widths for the Explore, password and offline checks (390 only); dark theme for the new screens; Safari, Firefox and real phones.


## Visual pass (2026-11-01)
Screenshots at 320, 343, 390, 430, 768 and 1280 px for 33 screens before and after (`VISUAL_QA_INDEX.md`); Arabic and dark at 343 and 390 for a subset.

| Check | 320 | 343 | 360 | 390 | 412 | 430 | 768 | 900 | 1024 | 1280 | Script |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Five roles: four tabs plus More in the bar, each tab at least 54 px, inside the screen, no overflow | ok | ok | ok | ok | ok | ok | | | | | `j95_nav`, `j95_widths` |
| Five roles: side rail with all six destinations, no overflow | | | | | | | ok | ok | ok | ok | `j95_nav` |
| Tab-by-tab walk and More > Analytics | | | | ok | | | | | | | `j95_nav` |
| Rail walk (every destination reached) | | | | | | | ok | | | ok | `j95_nav` |
| Three roles in Arabic: tabs right to left | | | | ok | | | | | | | `j95_nav` |
| Motion frames (tabs, gallery, bar, Home, Analytics, reduced motion) | | | | ok | | | | | | | `j96_motion` |
