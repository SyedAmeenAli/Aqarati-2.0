# 12. Image and icon coverage

Read-only. Combines this round's screenshots with the earlier rendered-pixel probes (`docs/readiness/evidence/asset_audit/IMAGE_RENDER_AUDIT.md`, `imageprobe_*.json`, `ICON_AUDIT.md`). "Rendered" below means the photo was seen in a screenshot or measured by the pixel probe, not merely referenced in source.

## 1. Asset library (what exists)

| Folder | Files | Used for |
|---|---:|---|
| `assets/properties/p1` | 37 jpg + 7 mp4 | flagship waterfront villa gallery, Home/Explore heroes, admin listings |
| `assets/properties/p2..p6` | 8 / 5 / 22 / 18 / 5 | apartment, plot, family villa, second apartment, commercial |
| `assets/businesses/b1..b4` | 14 / 9 / 6 / 6 | architecture, construction, interior, maintenance portfolios and covers |
| `assets/location` | 15 | Muscat, Nizwa, Sohar, Sur, desert: Home/Explore heroes, ads |
| `assets/entry` | 2 | entry background `oman_terrace_2k.jpg` (also the backdrop of 6 screens), `entry_bg_01.jpg` |
| `assets/unassigned`, `assets/raw_media` | 13 / 158 | spare stock and originals (not referenced; raw_media is a source archive inside the bundle folder) |
| `assets/icons/aq` | 52 svg (43 original + 9 added locally) | the whole icon set |
| `assets/logo`, `assets/branding` | 2 / 2 | master logo, mark, intro poster/video |

Missing categories: portraits or neutral avatars for people (agents, owners, reviewers), business logos for the fictional businesses (only `Business.logoUrl` fields, unused), floor plans, empty-state illustrations (only the three-arch drawing in `AQEmptyViewingState`), Arabic calligraphic marks, map placeholders, and distinct industrial and agricultural photography (Industrial and Agriculture tiles reuse landscape/plot photos).

## 2. Repetition (how often a path is referenced in `lib`)

`b2/05_Construction_site_with_tower_crane` 14 times, `b1/05_Contemporary_architectural_facad` 11, `b3/06_Styled_bedroom_interior_photography` 10, `p6/04_Modern_commercial_building_exterior` 8, `p1/08_Contemporary_villa_front_facade_` 8, `entry/oman_terrace_2k` 6, `b4/05_Technician_servicing_air_conditi` 6. The same crane photo is the Construction hero, the Development discovery banner, the Admin construction row, a sponsored banner and the registration card; the same facade photo serves Development tile, Developer hero, Architecture hero, a sponsored banner and a portfolio. Per entity the same picture is kept (good); across entities it reads as repetition (weakens the "each role has its own world" goal).

## 3. Per-area rendered coverage

| Area | Images expected | Actually rendered | Notes |
|---|---|---|---|
| Customer Home | hero, sponsor, six service tiles | all rendered | tile labels wrap and overlap the icon chips on two-line titles ("Construction Company", "Interior & Exterior Designer") |
| Explore | hero, banner, 4 + 4 + 4 tiles | rendered | the banner image is washed behind a cream gradient (low contrast) |
| Properties hub | Buy, Rent, Sell banner, Favorites | rendered | Favorites uses a corniche photo, not a saved-property motif |
| Results, saved, compare, viewings | property photo per row | rendered (probe PPP) | |
| Agent dashboard | sponsor only | rendered | no property or person imagery; appointment rows use icon circles |
| Contacts | contact identity | initials only | no avatar, no property thumbnail |
| Agent listings, leads | property thumb | **empty for the demo agent** | listings list is an empty state; leads empty state |
| Developer home | hero, sponsor, project cards | hero and sponsor; project list empty for the demo account | `DbProjectCard` covers are demo-only (`DbProject.demoCoverFor`) |
| Construction home | hero (own cover if set) | rendered | essentials cards are icon-only by design |
| Architecture / Interior homes | hero, portfolio strip | rendered (portfolio from demo list) | portfolio uses named demo projects |
| Reviews | none | none | reviewers have no avatar |
| Account | avatar | person icon until a photo is added | |
| Professional discovery, profile | cover, gallery, portfolio | rendered for the four seeded businesses | logo unused |
| Maintenance, Activity rows | service/property thumb | rendered (local) | |
| Admin | record thumbs | rendered for module lists (local); ads list empty; accounts/verification/reports no imagery | brokers show an icon, not a person |
| Entry / auth | background photo | rendered | auth pages use a pale full-bleed arch photo behind forms (`AQBackdrop`), strongest behind registration and login |

Cropping: tiles use `BoxFit.cover` with centre alignment; portrait-heavy architecture photos lose their tops in 4:3 and 16:9 frames; Home tile images are cropped to roughly 1:1.1.

## 4. Icons

- One family: 52 custom 24 pt SVGs (`AQIcon`) plus Material glyphs through `DbIcon` for `filter`, `sort`, `list`, `work`, `review`, `handshake`, `copy`, `image`, `map`. Meaning problems fixed earlier (bell for notifications, bookmark for saved, chart for analytics, wrench for maintenance, megaphone for ads, flag for reports, key for listings, grid for content). A test (`image_icon_mapping_test.dart`) enforces unique glyphs per navigation bar.
- **Still ambiguous or duplicated:** `user` is used for "Profile photo", "Your profile" (account), "Business settings" and Account tab; `activity` (pulse) for the Activity tab and for status "uploading" in documents; `info` (74 uses) stands for notices, help, and "Enquiries"; `lock` for both locked and read-only; `star` for rating and (still) preferences in a few feature screens; `home` for Home tab, Properties, "View as a customer"; `construction` (hard hat) used for Construction and for "Service requests" in the agent More menu; Admin `account` vs `user`.
- **Dark theme:** icons are tinted at draw time from tokens, so they appear in both themes; the pale-on-photo icons (white in tile chips) are fixed white.
- Icon-only controls with a semantic label: `AQIconButton`, back buttons, Admin `AdminIconButton`; the chart tooltips and capsule icons are decorative inside labelled parents.
