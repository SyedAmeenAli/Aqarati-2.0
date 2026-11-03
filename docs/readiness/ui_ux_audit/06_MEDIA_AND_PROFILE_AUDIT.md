# 06. Media and profile audit

Read-only. State of the working tree, which already contains the unified media work done in earlier local rounds; the section "Before" explains why images looked and behaved differently.

## 1. Every image-selection implementation

| Use | Widget and file | Picker | Crop / preview | Where it lives afterwards | Shares code with the others? |
|---|---|---|---|---|---|
| Customer profile photo | `ProfilePhotoScreen` (`features/account/profile_photo.dart`) using `AqMediaField` | `documentPickerProvider` (`FilePickerAdapter`, `document_state.dart:67`) through `pickAqMedia` | Editor dialog: drag to reposition, zoom slider, rotate; circular frame | `profilePhotoProvider` (in memory) | Yes: the unified system |
| Agent personal photo | Same screen via the "Profile photo" rows in `agent_screens.dart` (More) and `pro_shell.dart` | same | same | same single provider | Yes (one photo per signed-in person) |
| Company logo | `AqMediaField(kind: logo)` inside `DbProfileEditScreen` (`features/devbuild/db_pro_tools.dart`) | same | square contained frame | `businessLogoProvider` (in memory), written on Save | Yes |
| Cover image | `AqMediaField(kind: cover)` in the same editor | same | 16:9 frame | `businessCoverProvider` (in memory) | Yes |
| Portfolio image | `AqMediaField(kind: portfolio)` in `_PortfolioState._edit` (`db_pro_tools.dart`) or bundled choices | same | 4:3 frame | `PortfolioItem.image` as `memory:N` (registry `aqMemoryMedia`) or a bundled asset path | Yes, plus a bundled-picture grid |
| Agent listing photos | `listing_screens.dart:961` | `documentPickerProvider` direct | none; names only (`photoNames`) | Names in the listing draft; Admin moderation shows asset paths only for demo data | **No** (document-style flow) |
| e-Broker photos / ownership documents | `ebroker_screens.dart:358, :381` | direct | none | `photoNames` list | **No** |
| Maintenance provider photos | `provider_screens.dart:115` | direct | none | draft state | **No** |
| Admin banner creative | `admin_ads_screens.dart:499` | direct | preview via `Image.memory` in the ad form and list | `SponsoredAd.imageBytes` | **No** |
| Verification documents | `DocumentController.chooseAndUpload` (`document_state.dart:110`) | direct | `document_preview.dart` | transient private buffer by design | No (documents are deliberately not a media model) |
| Property gallery | `property_gallery_screen.dart` | none: bundled assets only | pager | `Property.imageUrls` (asset paths) | n/a |
| Development project cover | `DbProject.cover` (`db_models.dart`) | none | `aqImg` | `mediaUrls` or deterministic demo cover | n/a |

## 2. Why they used to differ (cause)

- The only file picker is a document picker that accepts PDF, JPG and PNG. Each flow wrapped it differently: some keep bytes in a transient buffer, some keep only a file name, one keeps bytes on a model (`SponsoredAd.imageBytes`), one had no editor at all (the business profile said "Logo and photo upload is not available yet").
- There was no shared media model: `Business.logoUrl`, `DbProfessional.mediaUrls/logoUrl`, `Property.imageUrls`, `PortfolioItem.image`, `SponsoredAd.imageRef/imageBytes`, `ListingDraft.photoNames` are six unrelated representations.

## 3. What exists now (local, uncommitted)

- `features/media/aq_media.dart`: `AqMediaKind {avatar, logo, cover, portfolio}` with frame ratios, `AqMediaImage` (bytes, zoom, dx, dy, turns), `AqMediaFrame`, `AqMediaView`, `AqMediaField` (the one field), the bottom sheet (`_SheetRow`), the editor dialog, `AQAvatar`, `AQBusinessLogo`, and the `memory:N` registry (`registerAqMedia`, `aqMemoryMedia`) which `aqImg` (`features/workspace/aq_home.dart`) understands.
- Tests: `test/media_glass_test.dart`, `test/refinement_test.dart`.

## 4. Gaps and inconsistencies still present

1. **Persistence:** none. `AQLocalPersistence` (`data/repositories/local_persistence.dart`) stores only `kSavedIdsKey`, `kRecentSearchesKey`, `kReadNotificationsKey`, `kSettingsKey`, `kLocaleKey`, `kThemeKey`. Profile photo, logo, cover, studio styles, review toggles and workspace choice are lost on reload.
2. **Propagation is partial.** `AQAvatar` is used in exactly two places (Home hero, Account header). It does not appear in the agent dashboard, contacts, Admin, or the public professional profile. `AQBusinessLogo` is used only in the construction header and `RoleHeader` (development, architecture, interior).
3. **Public profile does not read the new providers.** `DbProCard`, the profile hero (`db_profile.dart`) and Explore cards read `DbProfessional.cover/logoUrl` from the repository, not `businessLogoProvider` / `businessCoverProvider`; a logo chosen in the editor does not appear on the business's own public card.
4. **Document-style flows are separate** (listings, e-Broker, provider, Admin banners): no frame, no editor, no preview consistency.
5. **Sources:** the sheet offers only "Choose from this device" (web). No camera/gallery split on mobile because only `file_picker` is a dependency.
6. **Memory:** pictures are held as full-resolution bytes; there is no downscale on selection. `AqMediaView` decodes at full size (no `cacheWidth`).
7. **Crop:** reposition is an alignment offset plus zoom on a `cover` fit; no true pixel crop is produced (the original bytes are kept and re-framed at render time).

## 5. Recommended unified architecture

1. One `MediaAsset` model (id, bytes or asset path or URL, kind, framing) and one `MediaStore` provider keyed by owner (person, business, portfolio item) persisted through `AQLocalPersistence` (downscaled to a sensible max edge on selection).
2. `AqMediaField` stays the only UI; replace the document-style photo steps (listings, e-Broker, provider) with it, keeping documents on the document pipeline.
3. Make every identity widget read from the store: `AQAvatar` (person) wherever the same person appears; `AQBusinessLogo` and cover wherever the business appears, including `DbProCard`/profile hero for the signed-in business.
4. Add `cacheWidth` per frame size to bound decode memory.
