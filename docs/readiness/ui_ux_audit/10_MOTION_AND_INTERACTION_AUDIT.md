# 10. Motion and interaction audit

Read-only. Motion tokens: `AQMotion` in `core/aq/aq_tokens.dart:141-181`. Route transitions: `AQRoute` in `core/aq/aq_scene.dart:470-620`. Reduced motion: `AQMotion.reduced(context)` and `AQMotion.scaled(context, d)` (returns `Duration.zero` when reduced).

## 1. What exists

| Area | Implementation | Duration / curve | Notes |
|---|---|---|---|
| Tokens | `micro 110, fast 180, standard 260, slow 380, page 300, tapDown 100, tapUp 160, icon 180, sheet 320 (reverse 240), dialog 200, formStep 240, theme 340, state 220, hero 700, reveal 640` ms; curves `standardCurve (easeOutCubic)`, `emphasized`, `spring (0.22,1,0.36,1)` | single source | A rule in the file: "Never hard-code a Duration or Curve in a screen." |
| Push / pop | `AQRoute.forward` | `page` 300 ms, slide travel 20 px + fade | used by most pushed screens |
| Tab change | `AQRoute.tab` | short fade | `/app/home`, `/pro`, `/agent` tabs |
| Sheet | `AQRoute.sheet` | `sheet` 320 / 240 ms | legal pages |
| Hero route | `AQRoute.hero` | slow reveal | used for approval / confirmation outcome screens (`app_router.dart:201-212, 532, 547`) |
| Hero widget | `Hero(tag: 'vw-img-<propertyId>')` | Flutter default | only inside the viewing flow (`viewing_components.dart:62`, `viewing_schedule_screens.dart:317`) |
| Fade | `AQRoute.fade` | | `/admin`, `/shop`, `/work` |
| Press feedback | `AQPressable` (`aq_primitives.dart`) scale on tap | 100 down / 160 up | used by cards, buttons, nav |
| Floating nav | `AQGlassNav` sliding indicator (`AnimatedPositionedDirectional`), icon scale and colour tween, compact-on-scroll | 180 ms / spring | reads well |
| Shop/Work capsule | `AnimatedAlign` thumb + `AnimatedDefaultTextStyle` | 220 / 200 ms | the content change itself is a route replace (no coordinated transition) |
| Period switch | `AnimatedPositionedDirectional` | 220 ms | |
| Charts | `TweenAnimationBuilder` grow/draw-in | 700 ms scaled | once per data change |
| KPI numbers | count-up | `slow` | |
| Role homes | `RoleReveal` stagger (45 ms x index, max 5) | 240+ | |
| Home content switch | `AnimatedSwitcher` fade + 8 px rise in `RoleHomeScreen` | `state` 220 | |
| Images | `aqImg` fade-in with `frameBuilder` | `slow` | skipped when `sync` or reduced |
| Theme change | `AQThemeTransition` cross-fades all tokens | 340 ms | |
| Glass | one `BackdropFilter` implementation (`AQGlass`, `core/aq/aq_glass.dart`) | n/a | nav (blur 20), capsule (16), search (18), location (14), media sheet and editor (20-22); photo-tile chips use blur 0 |

Counts (static): 106 animated-widget uses (`AnimatedContainer`, `AnimatedSwitcher`, `AnimatedAlign`, `TweenAnimationBuilder` and similar), 25 explicit reduced-motion checks, 64 literal `Duration(milliseconds: ...)` outside the token file.

## 2. Gaps and inconsistencies

1. **Literal durations (64 sites)** contradict the "never hard-code" rule; examples: `Duration(milliseconds: 200)` in `role_home_widgets.dart` capsule, `220` in the period switch, `180` in `_FilterChip`.
2. **Reduced motion:** 106 animated uses vs 25 checks. Most go through `AQMotion.scaled`; the exceptions are places that pass a literal `Duration` straight to `AnimatedAlign` / `AnimatedContainer` (the capsule uses `AQMotion.scaled(context, const Duration(...))`, which is correct, but several older widgets do not).
3. **Shop/Work and role changes** are route replaces, not transitions between two views of one shell: the avatar, capsule and header are rebuilt, nothing travels.
4. **No shared element** from property or professional cards to their details: `Hero` tags exist only inside the viewing flow, so a property card opening Property Details and a professional card opening a profile cross-fade instead of expanding the photo.
5. **Dialogs and sheets** use Flutter defaults for most of the app (`showDialog`, `showModalBottomSheet` in about 30 places) so their motion and surface differ from `AQRoute.sheet`; only the new media sheet and editor use the glass surface.
6. **Charts** animate on mount only; switching the period replays the whole draw-in (the key is the value list), not a tween from old to new values.
7. **Drawer** (Admin): Flutter's default `Drawer` slide, no scrim blur.
8. **Performance risks:** every `AQGlass` is a `BackdropFilter` (an off-screen layer). A screen with nav + search + location + capsule has four to five; each is wrapped in `RepaintBoundary`, but cost on low-end phones has not been measured (only desktop Chrome in headless runs). The Explore and Home hero use a full-bleed photo plus two gradients behind a blur.
9. **Image decoding:** `aqImg` passes `cacheWidth` (400 to 1000) for bundled assets; the new `AqMediaView` for user pictures does not.
10. **Unnecessary motion:** staggered `RoleReveal` on every dashboard section plus count-up on KPIs plus chart draw-in all play together on a role home's first paint.

## 3. Proposed single motion system (for the redesign, not implemented)

| Interaction | Target | Token |
|---|---|---|
| Press | 100-150 ms, scale 0.985 (current `AQPressable.pressedScale`) | `tapDown/tapUp` (exists) |
| Selection change (tabs, chips, switches) | 200-260 ms, easeInOutCubic | `fast` / `standard` |
| Mode switch (Shop/Work) | 320-440 ms: shared capsule and avatar stay, content cross-fades and shifts 12 px, bar morphs | new `mode` token |
| Page push / pop | 260-360 ms; forward slide 20 px, reverse mirrors | `page` (exists) |
| Modal and sheet | 300-400 ms with blurred scrim | `sheet` (exists); add a shared `AQSheet` route using `AQGlass` |
| Image reveal | 350-550 ms fade, no layout jump | `slow` (exists) |
| Dashboard entrance | hero first, then KPI group, then sections, once | `reveal` (exists) but limit to three beats |
| Chart update | tween old to new 200-320 ms, not replay | new |

Rules: all durations from tokens (lint the 64 literals), every animation through `scaled`, at most three blurs on a phone screen, and `BackdropFilter` skipped (opaque fallback) under high contrast (already in `AQGlass`).
