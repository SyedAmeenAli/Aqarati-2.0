# AQARATI redesign: final handoff (local, uncommitted, not deployed)

Scope kept: frontend presentation only. No route, provider, validation, permission, data-model, backend or flow change.

## Phases
| Phase | State |
|---|---|
| 1 Design system + Home | Done, reviewed (see PHASE1_HOME_HANDOFF.md) |
| 2 Discovery (Explore, results, search, detail, gallery, compare, saved, map strip) | Done, screenshots reviewed (see PHASE2_DISCOVERY_HANDOFF.md) |
| 3 Professional directory + public profile | Done: image-led card, profile cover with logo overlap, portfolio grid (lead photo full width) |
| 4 Five workspaces | Done for the screens below: agent contacts (52 px avatars, readable follow-up), appointments (date block first), agent listing card (4:3 photo, price first, status over the photo; not visible in screenshots because the demo agent has no listings, covered by agent_listings tests), project and unit cards for Construction, Architecture and Development (16:9 photo, stage tag, large progress, unit stock bar), project card with cover in the shared DbProjectCard. NOT redone: Interior/Exterior project screens (no separate project list screen found beyond portfolio), lead detail and listing forms |
| 5 Admin | Partial: activity table no longer truncates (wraps to 3 lines), taller table rows (56 px), role labels in full, responsive label column. NOT done: numeric alignment, pagination styling, per-screen recomposition of accounts, verification, moderation, ads |
| 6 Remaining customer/account screens | Partial: notifications rebuilt (type icon, unread dot, larger title, date as secondary line). Login/signup/OTP/account reviewed by screenshot only, not recomposed |
| 7 Global consistency | Partial, high impact: AQGlass fill root-cause fix (warm fill never painted), nav fill and selected pill, one property card family used by every property list, radius 18 for cards/banners/tiles, inkFaint contrast raised to about 4.8:1, Arabic-safe facts line |
| 8 QA | One consolidated pass (below) |

## Main visible changes
Home rebuilt (header, search pill, hero, rails). One property card (4:3 photo, price first, save/tag over photo, facts) in results, saved, search, broker, business lists; compact horizontal variant for the map strip; 2/3-column results on tablet/desktop. Detail: 4:3 hero, photo tags, amenities as icon grid, editorial description, divided specification rows, lister thumbnail, 760 px tablet column. Professionals: image-led cards with logo, rating, place, description. Profile: cover + overlapping logo, larger portfolio.

## Files modified in this run (beyond Phase 1/2 files)
`aq_cards.dart`, `aq_business_profile.dart`, `aq_professionals.dart`, `property_detail_screen.dart`, `property_gallery_screen.dart`, `db_widgets.dart` (card radius), `aq_glass.dart`, `aq_scene.dart`, `aq_tokens.dart` (inkFaint), `aq_home.dart`, `aq_tiles.dart`, `aq_filter_sheet.dart`, `analytics_charts.dart`, `admin_widgets.dart`, `admin_directory_screens.dart`, `agent_screens.dart`, `compare_screen.dart`.
Reused: AQPropertyCard, AQProfessionalCard, AQResultGrid, AQThumb, AQPhotoTag, AQGlass, tokens.

## QA actually run
- `flutter analyze`: 0 errors, 60 infos/warnings (59 before this run; the extra one is an existing-style info in a file I touched, not an error).
- Full suite (demo off) run after the Phase 3 and detail/profile edits: 1165 passed, 17 skipped, 0 failed. Demo-on run was last done at the end of Phase 2 (1180 passed, 2 skipped). After the final one-line amenities-grid fix, only search_filters, properties_flow and home_premium tests were re-run (passed).
- Builds: customer and admin web release builds succeeded.
- Browser overflow checks (headless Chromium): no horizontal overflow on every captured screen listed in evidence folders.
- Journeys: an earlier browser script could not confirm navigations. Replaced by a widget test through a real GoRouter (`home_premium_test.dart`): Home search entry opens /search/start, a property card opens /property/:id, a professional card opens /business/:id. It passes, so the earlier failure was the script, not a regression. Results to detail to gallery to viewing, enquiry and Admin navigation are covered only by the existing tests (properties_flow, admin_console), not re-verified in a browser.
- Phase 4–6 pass: analyze 0 errors (60 infos/warnings); 219 targeted tests passed (home, pro, agent, listings, admin, settings, product flows); admin and customer release builds succeeded.

## Evidence
`evidence/phase1`, `evidence/phase2`, `evidence/final`. Reviewed by opening (including detail amenities grid, agent contacts and calendar, construction projects, developer units, notifications, Admin overview 1280): Home 375/320/768/dark-AR, results, saved, detail 375/1280/dark, explore 375/768, compare 320, professionals directory and profile 375, construction/architecture/interior/agent 375, admin overview 375/1280, login 375. Not opened: the remaining frames.

## Known defects / incomplete
Items marked Partial above. Also: Admin menu focus ring in scripted shots; Interior/Exterior workspace got no new card redesign beyond Home. Arabic strings added are draft. Admin menu button shows a focus ring in scripted shots (likely an artefact). Admin activity table still truncates long cell text. Explore keeps its banner-and-tile structure; no featured/development/professional rails were added to it because that would add content.

## Functional ideas, not implemented
Compare columns lettered on wide layout; unify the Explore/Results page header; Saved grid with compare marks; persist media and mode.

No intentional product-flow or functionality change was made.


---
## Final update (completion pass)
Added since the table above: Admin accounts rows now lead with an identity avatar and bold name; portfolio pieces (Architecture, Interior/Exterior) are photograph-led 16:10 cards; lead cards have a larger property photo and stronger title; card radius unified to 18 px across detail info cards, calculators, saved, explore type cards, reviews and onboarding business cards; demo skip overlay no longer breaks equal tile heights. Notifications, agent contacts/calendar/listing card, project and unit cards, Admin activity table fix are described above.

Final QA (this pass): `flutter analyze` 0 errors (60 infos/warnings, unchanged style); full suite demo off 1166 passed, 17 skipped, 0 failed (the demo-on run was last done at the end of Phase 2); release builds of the customer app and the Admin app both succeeded.
Screenshots opened and reviewed in this pass: onboarding purpose, business signup, login 1280, lead inbox, units, construction projects, notifications, agent contacts and calendar, Admin overview and activity table. Not re-captured after the last two small edits (Admin accounts avatar, portfolio card, lead card photo, radius unification): those are covered by passing tests only.

Completion pass 2 (items previously listed as not done):
- Admin pagination: shared `AdminPager` bar (Previous / Page X of Y / Next, same two actions) in verification and moderation.
- Admin numeric alignment: `AdminTable.endColumns`; the verification Documents count aligns to the end edge.
- Admin verification rows lead with an identity avatar; accounts rows already do.
- Lead detail: the related property or project is a 16:9 photograph card with a large title and the same open action; lead cards use a larger photo.
- Listing form: already grouped into titled sections (property, details, location, facts, price, deed, photos); no recomposition needed beyond the shared section title style, left as is.
- Account: the signed-in profile header is now a card with a 64 px avatar and larger role title. The guest view is unchanged.
- Interior & Exterior: no project-list screen exists apart from the portfolio (now photograph-led cards), so nothing further to redesign; reported, not invented.

QA for pass 2: analyze 0 errors (60 infos/warnings); 164 targeted admin, leads, shell, settings and ad tests passed; customer and Admin builds succeeded. Screenshots opened: Admin accounts 1280 (avatar rows), Admin verification 1280 (queue is empty in the demo, so the populated table and the pager were NOT seen on screen), account 375 (guest view; the new signed-in header was NOT seen on screen), lead detail NOT captured. Those four changes are verified by compile and tests only.
