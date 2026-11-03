# Known limitations

Date 2026-11-01. Local working tree after the gap-closure pass (`GAP_CLOSURE.md`). Nothing is committed, pushed or deployed. This list says what is not done or not proven, so a reviewer does not have to find it.

## Behaviour (frontend only, by design)
- There is no backend. Sign-in, the one-time code, password change, verification, e-Broker submission, enquiries, support messages and account deletion are simulated. The screens say so; nothing is sent to a person or a service.
- **Password change** is a frontend prototype: a dedicated screen checks every rule and, when the entries are acceptable, shows a *simulated* confirmation that says no password was changed. It changes nothing and sends nothing.
- **Email and push notification channels** are not connected. Notification settings choose in-app categories only, and say so.
- **Analytics and KPIs** (customer-facing none; agent and four professional roles) come from deterministic local sample series: the same role and range always draw the same 4, 8 or 12 weeks. They are labelled “Sample data”. They are not measurements.
- Persisted locally in the browser (localStorage): language, theme, text size, reduced motion, notification choices, privacy choices, preferred locations and interests. Data records (listings, leads, submissions) reset on reload.
- Demo mode defaults **off**. “Skip” chips, sample contact activity, engagements and portfolio images exist only in a build made with `AQARATI_DEMO_MODE=true`.

## Product scope
- **Additional business services** are connected to discovery with local fixtures: a business that offers an additional service appears once under each category in Explore, shows its categories on its public profile, and an enquiry names the service. The **signed-in business is not inserted into the public directory**: nothing is published or synced, and the Services screen says so.
- **Units, Projects and analytics** screens of the business workspaces show deterministic sample data and are labelled "Sample data". There is no unit, project or request store behind them. (Development projects keep their own existing wizard and store.)
- The professional navigation follows the approved structure for every role (`ROUTE_MATRIX.md`): four destinations plus More on phones, all six in a rail from 700 px. The **Enquiries** tab of an architecture studio opens the same contact-activity list as the other roles' Requests and Enquiries tabs; there is no separate brief model.
- Search start and Map keep their own full-screen layouts (inside the shell).
- Property-type and professional **Explore** entries link to the existing results screens; they do not add new filtering capability beyond the service-category filter above.

## Language
- All Arabic copy is **draft** and needs review by a native speaker: the customer and business screens, the settings, analytics and password text, the Arabic sample campaigns, and the whole **Admin Console** (about 650 strings and 60 patterns in `lib/admin/admin_strings_ar.dart`).
- The separately built console (`lib/admin_main.dart`) keeps the chosen language for the session only; hosted at `#/admin` inside the app it shares the app's stored language and persists across reloads.
- The **Admin Console is bilingual** (English and Arabic, same language switch as the app). Sample records inside it (people, businesses, places, listing titles) keep their original wording; the words around them are translated. Its Arabic was checked with widget tests and a Chromium run, not by a native reviewer.
- Genuine proper names stay as written: sample business names (for example Wadi Architecture, Namaa Construction), the sample sponsor names (Arabic transliterations are used for the six sample campaigns), the location chips (Muscat, Sohar, Salalah and so on) and “Aqary e-Broker”. The interface around them is translated.
- The language page lists “English” in English on purpose.
- The browser's `html` element keeps `dir="ltr"`; Flutter mirrors the layout itself. This was verified by geometry (tab order, right-edge alignment, mirrored back chevrons), not by the attribute.

## Visual and accessibility
- Browser verification used **headless Chromium only**. Safari, Firefox and real phones were not tested.
- On screens 900 px and wider the side rail of the business workspaces was missing from the accessibility tree; this pass fixes it (`GAP_CLOSURE.md` section 1) and a test guards it. The customer shell was not affected.
- Flutter web builds its accessibility tree on demand (the “Enable accessibility” control). Rows below the fold appear in that tree only once scrolled or focused. A screen reader (NVDA, VoiceOver, TalkBack) was **not** run against the app; the checks read the same semantics tree, with keyboard focus. Colour contrast was judged by eye on screenshots in light and dark; it was not measured with a tool.
- Reduced motion and text size 130 % are honoured and survive a reload. Larger system text than that was not exercised.
- The glass tab bar floats over the lower part of long pages; content scrolls beneath it with bottom padding, as in the approved design.
- Glyphs outside the three bundled families fall back to the bundled Roboto file. A test walks 10 business and settings screens, dialogs and fields in English and Arabic and finds no style that would draw in a system font, and the offline browser run loads only bundled fonts. Screens outside that list, and rare characters typed by a person, can still reach the fallback for those glyphs.
- The engine's default `Roboto-Regular.ttf` is always served from the app itself (no CDN); it is not used for text drawn with the bundled families.
- The intro film plays on first load; the checks click its Skip control.

## Tooling
- `flutter analyze`: no errors. Two existing warnings remain in `test/devbuild_stabilisation_test.dart` (unused optional parameters `failFirst` and `gate`), a file this pass did not touch, plus 52 `info` lints.
- `vercel.json` has a local edit (`--no-web-resources-cdn`); the deployed project still runs its previous build command until you deploy.
- 17 tests are skipped in a normal run because they need demo mode; they all run (and pass) with `--dart-define=AQARATI_DEMO_MODE=true`. With demo mode on, 2 tests are skipped because they only apply to a normal build.
- `google_fonts` was removed from `pubspec.yaml`; the three families are bundled under `assets/fonts`.

## Visual pass (2026-11-01)
See `VISUAL_QA.md` section 9 for the full list. In short: the entry and sign-up forms, property details, Explore result variants, Activity states and Settings rows were reviewed at 343 and 390 and received only the shared title, logo and bar changes; Arabic and dark captures cover a subset of screens at two widths; motion was measured in headless Chromium, not on a real phone.


## Round 3 (v98) open items
- Viewing steps 1 and 2 are near-duplicates.
- Property details at 1280 is a ~520 px column on a large canvas.
- Action bars stack vertically at 320.
- Brokers list shows "QA sample broker A/B" (kept: `test/broker_test.dart` depends on the name).
- Compare columns are cut at the right edge (horizontal scroll pattern).
- Admin ads and ad detail at 343/1280 and reports/report detail at 390 not captured in the verified set; admin sheets reviewed at thumbnail scale only.
- Unauthenticated visit to `/onboarding/documents` shows an error frame, not a redirect.
- Map tile can render as a blue block while loading.
- Headless Chromium crashed intermittently on some runs; not traced to a code defect.


## Round 4 (v99) open items
- `j97_motion` is intermittent in the full chain: the filter-sheet check and the password-confirmation check each fail some runs (different one each time) when the browser screencast captures too few frames while the machine is busy. In isolation the sheet showed intermediate frames 8 of 8 runs and the password swap 6 of 6; `test/sheet_motion_test.dart` proves the sheet's motion deterministically. The assertions were not weakened and the check is not marked passed in the runs where it failed.
- `j26_theme_rtl.js` is a legacy script (October) whose setup no longer applies the dark theme or Arabic; 6 of its 11 checks fail. Dark and Arabic are covered by `j80_master`, `j82_final`, `j90_arabic` and `j99_variants`. It was not fixed.
- The live map is a keyless Google embed. `load` does not prove tiles painted, so a plain blue map background can appear briefly after the loaded state.
- Contact sheets were inspected only at layout level; 86 of 310 v99 screenshots were not opened.
