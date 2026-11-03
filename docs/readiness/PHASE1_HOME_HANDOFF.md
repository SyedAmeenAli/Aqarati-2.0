# Phase 1: premium Home pass (local, uncommitted)

**New:** `lib/core/aq/aq_states.dart` (AQEmptyState, AQErrorState, AQLoadingBlock); `lib/features/workspace/aq_cards.dart` (AQPropertyCard, AQProfessionalCard, AQSaveButton, AQPhotoTag); `aq_home_sections.dart` (AQHomeHeader, AQHomeGreeting, AQHomeHero, AQRail, AQHomeFeatured, AQHomePros); `test/home_premium_test.dart` (28 tests).
**Changed:** `aq_home.dart` (Home rebuilt; AQSearchEntry restyled; AQLocationPill public), `aq_home_services.dart` (equal tiles, wide layout), `aq_scene.dart` (nav fill 0.66 to 0.88), `hub_strings.dart` (hm8.* EN + draft AR), `test/home_banner_test.dart` (search now expected on Home).
**Reused:** AQColors/AQSpacing/AQRadius/AQTypography/AQMotion, AQGlass, AQPressable, AQIcon, AQAvatar, AQHeart, AQTextButton, aqImg, savedPropertiesProvider, featuredPropertiesProvider, businessesProvider, aqRequireSession + EnquiryScreen.
**Evidence:** `docs/readiness/evidence/phase1/` (320/375/430/768/1280 light EN; 390 dark EN; 390 light and dark AR).
**Not done:** Phase 2 screens still use AQResultCard; AR strings need native review; media persistence unchanged (in-memory); inactive nav label contrast over bright photos not re-measured.
