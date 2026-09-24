# Dark Cinematic Paywall Redesign

Mode: Full

## Goal
- Replace the existing paywall for all placements with Figma frame `5904:20002`.
- Preserve Apphud loading, purchase, restore, analytics, placement fallback, legal links, remote close behavior, and purchase callbacks.
- Select a plan on card tap and purchase only from Continue.
- Build the screen with UIKit, Auto Layout, and XIB.

## Implementation
- [x] Replace the storyboard paywall with `PaywallViewController.xib`.
- [x] Add exact before/after and slider assets; reuse matching premium benefit icons.
- [x] Recreate the cinematic comparison motion and one-time content entrance.
- [x] Adapt live StoreKit prices, billing subtitles, trial, and savings badges.
- [x] Remove paywall-only carousel code and assets after reference checks.
- [x] Add pricing/presentation regression tests.
- [x] Build, test, and exercise the paywall flow in Simulator.

## Decisions
- The native status bar replaces the Figma mock status bar.
- Content scrolls on compact devices rather than shrinking typography.
- Live StoreKit metadata overrides inconsistent sample prices in Figma.
- The hero comparison loops; purchasing controls animate in once and remain stable.
- Reduce Motion shows the final comparison state without decorative animation.

## Risks
- The 402×944 reference requires adaptive constraints on shorter devices.
- Product order and subscription periods can vary by Apphud placement.
- The repository has extensive unrelated uncommitted work; changes remain scoped to paywall files.

## Validation
- Loading, fallback, plan selection, purchase cancellation/error/success, restore, legal links, and both remote close variants.
- 402×944-class and compact-device layouts.
- Dynamic yearly/weekly prices, trial badge, savings badge, and selected state.

## Log
- [x] Retrieved Figma layout, exact assets, and 3.5-second motion timeline.
- [x] Audited existing paywall UI, Apphud integration, analytics, localization, and navigation.
- [x] Migrated the paywall from Main.storyboard to a dedicated XIB and removed the obsolete scene.
- [x] Preserved live Apphud products, placement fallback, purchase/restore callbacks, analytics, legal links, and remote close variants.
- [x] Verified dynamic yearly savings against the live weekly product; sample Figma prices were not hardcoded.
- [x] Fixed an outlet-collection launch crash and a horizontal Auto Layout conflict found in the real simulator flow.
- [x] Captured iPhone 16 Pro and iPhone SE validation screenshots in `docs/validation`.
- [x] Final `xcodebuild` simulator build and the complete `HomeAITests` suite passed.
- [ ] Live purchase success and restore were not completed against the App Store sandbox account; loading, live product rendering, selection, and the purchase controls were exercised.
