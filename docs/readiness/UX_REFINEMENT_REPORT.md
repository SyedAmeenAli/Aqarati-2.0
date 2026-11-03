# UX refinement (round 8): routing, services, photo, reviews, charts, Admin on a phone

Local only. Not committed, pushed or deployed. The two recordings were not available to me as files, so the work follows the brief's timestamp list and the code, not frame-by-frame review. Evidence: `evidence/refine/`.

## Entry, Shop and Work: the cause
Two guards were dead ends. `ProShell` ("Business workspace only") and `AgentGuard` ("Agent workspace only") showed a notice whose only exits were Back, and Back fell back to `/entry` (the welcome screen) or `/app/home`. A signed-out person, a plain customer and a person whose application was in review all saw the same page and had to find their own way. That is the "unexpected screen" and the welcome screen coming back. There was no `/shop` or `/work` route, and "View as a customer" was a separate code path in each More menu.

## Changes
| Area | Change | Status |
|---|---|---|
| Routing | `WorkspaceAccessNotice` replaces both dead ends: a guest gets Sign in (destination remembered) and Register; a customer gets Register as a Business or Professional; an application in review gets its status link; all can Continue shopping. `/shop` and `/work` gates; one `switchToShop` / `switchToWork` used by the capsule, both More menus and both gates. Same account, nothing reset. | Fixed and functionally verified (browser + 9 widget tests) |
| Shop / Work capsule | On customer Home and Explore (eligible accounts), agent dashboard, and every business home. | Fixed and visually verified (390) |
| Interior / Exterior | Two independent switches (editor, sign-up, Studio card); "Both" only a derived description; both off blocks Save; Public-now versus Pending-review preview; contract value unchanged (`both` stays the stored value). | Fixed and visually verified (editor 390) |
| Studio | Services card, Studio styles (8 real multi-select chips with Save / Cancel / saved state), named demo portfolio projects, portfolio strip. | Fixed and visually verified (home 390) |
| Profile photo | `ProfilePhotoScreen` (add, change, zoom, remove, preview, Save / Cancel, JPG / PNG only), `AQAvatar` in Home header and Account; rows in Account, agent More and business More. Kept in the running app only; nothing uploaded, and the screen says so. | Automated verification only (picker faked); not exercised in a browser |
| Reviews | Summary (average, count, bars computed from the listed reviews), visibility and notification switches that change real state (and the own-profile preview), clearly marked sample reviews in the preview. | Fixed and functionally verified (widget); Not verified in browser |
| Analytics | Weekly counts are vertical bars from zero (tap or drag to read a week, tooltip kept inside the chart); the line chart is straight segments with a marker per point and no area fill; the invented "% vs previous" badge is removed; Service interest shows Interior and Exterior only. | Fixed and visually verified (agent 390) |
| Sell with Aqary e-Broker | Full-width Sell card with image, text and "Start selling" on Properties, separate from the broker programme; Buy and Rent side by side; Favorites below. | Fixed and visually verified (390) |
| Admin on a phone | Compact app bar, bottom bar (Overview, Accounts, Listings, More), tablet rail, drawer at most 86% of the screen with a close button, wrapping filters (nothing clipped), record cards. | Fixed and visually verified (390); widget tests at 320, 390, 768 |
| Misc | Operational pages on a clean warm surface, distinct icons per destination, 44 px Admin Back, Admin table column gutters. | See earlier reports |

## Verification
- Source fingerprint of the final gate: see the final message (computed after the last edit).
- Tests demo OFF and ON, analyze, default / demo / admin builds: see the final message.
- New tests: `test/refinement_test.dart` (23), plus updates to `agent_listings_test`, `properties_flow_test`, `devbuild_workspace_test`, `role_home_test`, `admin_arabic_test`, `image_icon_mapping_test` for the new behaviour (assertions replaced by equivalents, none removed).

## Not done or not verified
- Contacts and contact detail polish, the role-specific More grouping, Property details, and Activity item variety were not changed in this round.
- Business logo and cover images: not added (media upload remains off in the product).
- Per-role analytics sets were not redesigned beyond the shared hero chart; Development, Construction and Architecture keep their earlier cards.
- Arabic RTL Admin drawer and other-width screenshots were captured by script (`evidence/refine/*_320`, `*_1280`) but I opened only the 390 shots listed above at full size. Arabic Admin is covered by the existing Arabic test suite.
- Browser upload of a real photo file was not exercised.
- Admin detail screens (viewing detail etc.) were captured, not redesigned.
