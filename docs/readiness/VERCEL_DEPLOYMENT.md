# Vercel deployment and demo access

## How the site is built
`vercel.json` (committed) holds the install and build commands, so the build is reviewable:

| Setting | Value |
| --- | --- |
| Install | clone Flutter 3.47.4, `precache --web`, `pub get` |
| Build | `flutter build web --release --pwa-strategy=none --no-web-resources-cdn --dart-define=AQARATI_DEMO_MODE=${AQARATI_DEMO_MODE:-false}` |
| Output | `build/web` |

`AQARATI_DEMO_MODE` is a compile-time flag. Its source default is **false** (`lib/core/config/demo_mode.dart`). A Vercel environment variable alone does nothing; the build command forwards it into `--dart-define`.

## Two deployments from one project
| Deployment | Git branch | Vercel target | `AQARATI_DEMO_MODE` | What a visitor gets |
| --- | --- | --- | --- | --- |
| Production | `main` | production | not set, so `false` | The normal app. No Skip for Demo, no admin demo shortcut, no demo accounts on the admin sign-in. |
| Client preview | `client-preview` | preview | `true` (Preview-scoped env var `AQARATI_DEMO_MODE`) | The same app with Skip for Demo on sign-up and the purpose screen for all six roles, and "Open the demo console" on the admin sign-in. |

The preview address is the branch alias, `https://aqarati-final-ui-ux-git-client-preview-amelio123ali-2093s-projects.vercel.app`. Project protection (SSO, password) is off, so it is public.

To update the preview after a change: merge or reset `client-preview` to `main` and push it.

## What demo mode exposes
Fictional records only: sample accounts, contacts, listings, sponsored campaigns and portfolio entries, each labelled as sample or demo. Skip for Demo replaces the simulated session and creates nothing. The admin sign-in, one-time code and demo accounts are simulated and protect nothing, and every admin screen says so. Anyone with the preview link can enter every role. Do not put real data in the preview and share its link only with people who should see a prototype.

## Not covered
No real authentication, backend, payments or advertising agreements exist. Opening `#/admin` on production shows the admin sign-in, but nobody can sign in there because the production build has no demo accounts.

> 2026-10-31: `--no-web-resources-cdn` bundles CanvasKit and the fallback font so the page makes no request to Google hosts. This is a local edit of `vercel.json`; the deployed project keeps its previous build command until you deploy.
