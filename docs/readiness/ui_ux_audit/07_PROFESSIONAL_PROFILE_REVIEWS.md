# 07. Professional profile, specialisations, reviews, portfolio and design language

Read-only. Existing functionality is separated from what would have to be introduced. State: working tree including earlier local rounds (marked **(local)**).

## 1. Interior / Exterior specialisation

**Storage.** Two models coexist:
1. *Primary service type* for Interior & Exterior accounts: the enum `InteriorExteriorServiceType { interior, exterior, both }` (`core/domain/account_models.dart:39`), carried by `MeSession.serviceType` (API contract field `service_type`), by the demo session `DemoBackendState.serviceType` (`data/demo/demo_backend.dart:31`), and by `DbProfessional.serviceType` / `extraServiceType` / `designService` (`features/devbuild/db_models.dart:104-154`).
2. *Additional services* for other roles: a set of service keys (`BusinessProfile.services`, `features/settings/business_settings_screen.dart`) turned into categories by `proTypesOfServices` (`db_models.dart:33-47`), which **already derives** `both` when `interior` and `exterior` are both present. So the "derive Both from two independent flags" rule already exists for secondary services; only the primary enum models it as three values.

**UI (before local work).** A three-way selector in the Company Profile editor (`DbPillRow` over `InteriorExteriorServiceType.values`, `db_pro_tools.dart`), a three-way `AQSegmented` in the Interior sign-up step (`signup_form_screen.dart`), and read-only chips on the Studio Home (`home_studio.dart`, `segment()`), the last tapping through to the editor.

**Now (local):** `DbServiceToggles` (`features/devbuild/db_service_toggles.dart`) gives two independent switches, `serviceFromFlags`/`serviceFlags` derive the enum, the editor shows "Public profile now" versus "Pending review", Save is blocked when none is on, the Studio shows a services card. The stored contract value is unchanged (`both` remains the wire value).

**Still three-valued, customer facing:** Explore discovery filter for Interior & Exterior (`features/devbuild/db_discovery.dart:470` quick pills and `:553` filter sheet) iterates `InteriorExteriorServiceType.values`, so customers can filter "Both". Under the two-toggle rule the customer filter should be two independent chips with "Both" removed or turned into the intersection.

**Does selection affect the public profile and Explore?** The demo repository applies the change under the material-field rule (`DemoDevBuildRepository.updateMyProfile`, `db_repository.dart:754`, comment: "Bio, service type and location are material fields: they go to re-review before they are public"); the status screen is `DbProfileStatusScreen` (`/app/account/workspace/profile/status`). Pending review is therefore supported by the model. Whether the public listing keeps showing the previously approved value until approval is demo-repository behaviour and is not asserted by a widget test.

## 2. Reviews

| Aspect | Existing | Source |
|---|---|---|
| Model | `DbReview { id, rating, body, author, at }` | `db_models.dart:497` |
| Repository | `publishedReviews(orgId)`; demo data only for business `b2` plus, **(local)**, three clearly marked sample reviews for the signed-in demo business (`'me'`) | `db_repository.dart` |
| Public display | Reviews tab on the profile: rating header from `DbProfessional.rating/reviewCount`, two review cards, "All reviews" (`DbReviewsScreen`, `/build/pro/:id/reviews`) | `db_profile.dart:882-1010` |
| Rating calculation | **Two sources of truth:** the header uses the stored aggregate (`rating`, `reviewCount`), the list is the published items. For the signed-in business **(local)** `DbRatingSummary` computes average, count and star bars from the listed reviews so they agree | `db_review_widgets.dart` |
| Management | `DbBizReviewsScreen` (`/app/account/workspace/reviews`): star filter chips, cards, empty state, no reply control (`caps.reviewReplies` false) | `db_pro_tools.dart` |
| Eligibility | Customer side: `AQReviewEligibilityCard` and `review_flow_screens.dart` (reviews tied to a confirmed viewing or engagement, edit window, report); professional side: none (cannot create reviews) | `viewing_components.dart`, `features/reviews/` |
| Visibility preferences | **(local)** two switches in `DbBizReviewsScreen` (`reviewsPublicProvider`, `reviewsNotifyProvider`), in memory; "show" affects the own-profile preview only | `db_review_widgets.dart` |
| States modelled | Published only. Pending, eligible-to-request, hidden/disputed are not in the model | — |

Not existing: persisted visibility, per-review context (service/project), reply, request-a-review.

## 3. Portfolio

- Model `PortfolioItem { id, title, note, image }` (`db_models.dart:491`); repository `myPortfolio / savePortfolioItem / removePortfolioItem` (`db_repository.dart:105-108`), demo-seeded from bundled pictures with fictional named projects (`_portfolioInfo`, **(local)**); previously "Sample work N / Sample entry".
- Screen `DbPortfolioScreen` (`/app/account/workspace/portfolio`, `db_pro_tools.dart`): add, edit (dialog with title, note, bundled pictures or device picture **(local)**), remove, local-only notice.
- Consistency: Studio strip `RolePortfolioStrip` (**local**, `role_home_widgets.dart`), the portfolio page, and the public profile all read `myPortfolio()` / `mediaUrls`; a `memory:N` picture shows in all three through `aqImg`. The public profile's gallery (`DbProfessional.mediaUrls`) is seeded from the same demo list but is not updated when an item is added, so a new portfolio item does not appear in the public gallery (separate list).
- Missing: project type field (it is embedded in the note text), detail page, ordering.

## 4. Design language / moodboard

- Before: six hard-coded swatches (`palette` in `home_studio.dart`) with the text "A visual direction only. It is not a saved client moodboard." Nothing was selectable or saved.
- **(local)** replaced by eight multi-select style chips with Save/Cancel (`_StudioStyles`, `studioStylesProvider`, in memory). Not used anywhere else (not on the public profile, not in Explore filters).
- No moodboard feature exists in the product and none should be implied.

## 5. What would need to be introduced vs what exists

| Capability | Exists | Needs introducing |
|---|---|---|
| Two independent services | derived-both logic for secondary services; local toggles | customer filter without a third "Both" option; persisted pending/approved split visible on the public card |
| Review summary and visibility | local | persisted visibility, per-review context, pending/eligible states |
| Portfolio with type and detail | basic CRUD | project-type field, detail screen, ordering |
| Studio styles | local chips | storing/displaying them publicly, optional filter |
| Business logo / cover on public card | local pickers | read by `DbProCard` and the profile hero |
