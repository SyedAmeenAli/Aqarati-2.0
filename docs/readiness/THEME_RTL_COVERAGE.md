# `j26_theme_rtl` reconciliation

The old script (`j26_theme_rtl_legacy.js`, 11 checks, 5 passing and 6 failing) was written when the app followed the browser: it set the browser's colour scheme and locale and expected dark mode and Arabic. The product has since changed on purpose: it **always opens in light mode and in English** (`themeModeProvider`, `localeProvider`); dark mode and Arabic are explicit choices in Account > Appearance and Language and region, and "System" follows the browser's colour scheme. So the six failures were obsolete setup, not regressions, and the failing checks were never exercising the behaviour they named.

## Mapping of every legacy assertion

| # | Legacy assertion | Legacy result | Why it failed (or passed) | Replacement now (all pass) |
|---|---|---|---|---|
| 1 | dark: entry renders | pass | n/a | `j26` "dark: entry renders its content" and "... is really dark (mean luminance < 0.35) and does not overflow" (the old check could not tell dark from light) |
| 2 | dark: business renders | fail | browser emulation does not switch the app; the route also landed on a different screen in that setup | `j26` dark business (content + measured luminance) |
| 3 | dark: home renders | fail | expected the old home copy "What would you like to do" (copy is now "What are you looking for today?") | `j26` dark home (content + luminance); also `j82_final` dark theme at each width, `j99_variants` dark |
| 4 | Arabic: entry shows Arabic and the business button | fail | locale emulation no longer switches the app | `j26` "Arabic: entry shows Arabic text and no untranslated UI text" (stronger: also fails on leftover Latin UI strings) |
| 5 | Arabic: entry no overflow | pass | n/a | `j26` Arabic entry no overflow |
| 6 | Arabic: business selector in Arabic, four roles | fail | same | `j26` Arabic business |
| 7 | Arabic: business no overflow | pass | n/a | `j26` Arabic business no overflow |
| 8 | Arabic: interests in Arabic | fail | same | `j26` Arabic interests |
| 9 | Arabic: interests no overflow | pass | n/a | `j26` Arabic interests no overflow |
| 10 | Arabic: Home shows the four primary actions in Arabic | fail | same | `j26` Arabic home, plus `j90_arabic` (Home greeting, six services and sub-lines, four tabs, no Latin UI text, Properties, Buy/Rent, settings pages, forms, RTL tab order and geometry) |
| 11 | Arabic: Home no overflow | pass | n/a | `j26` Arabic home no overflow, `j90_arabic` Home at several widths |

## Coverage that did not exist before and is now in `j26` (23 checks)

- Light baseline, so "dark" is measured against something.
- The browser preferring dark does **not** change the app (product default), and Appearance "System" **does** follow it. This is the surviving, correct form of what the legacy test was trying to test.
- Dark theme survives a reload.
- The map failure panel follows the theme. This was a real defect found while reviewing dark screenshots: the panel stayed a pale sand colour with faint text and a low-contrast "Try again". The new check measured 0.866 luminance before the fix and passes after it.
- Arabic: page language switches to `ar`, tab order is right-to-left.

## Coverage lost

None. Every legacy assertion has a passing replacement above. The only behaviour dropped is "the app picks Arabic/dark by itself from the browser", which is no longer a product requirement. If it should be, that is a product decision, not a test fix.
