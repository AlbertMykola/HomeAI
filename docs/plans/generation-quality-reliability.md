# Generation quality and reliability

Mode: Full  
Approved: 2026-08-27

## Goals

- Make generation quotas and outcome analytics reflect actual successful results.
- Make Gemini failures actionable and retries bounded.
- Keep generation prompts stable across app locales.
- Normalize input images and verify mask alignment before upload.
- Add regression coverage for prompts, image handling, REST behavior, and the worker.

## Scope

- Production Gemini flow, prompt builders, image/mask normalization, quotas, analytics, retry/timeout, iOS tests, and worker regression tests.
- Worker authentication, App Attest/Firebase validation, live Gemini CI tests, and legacy-code removal are excluded.

## Implementation

- [x] Separate generation success, failure, cancellation, and blocked outcomes.
- [x] Charge free and premium counters only after a result is saved.
- [x] Add stable analytics properties without sending user prompt text.
- [x] Add typed Gemini errors, request limits, timeout, and bounded retries.
- [x] Normalize generation images and reject mismatched masks.
- [x] Add canonical English prompt descriptors and prompt versioning.
- [x] Honor design mode in interior, exterior, and furnish prompts.
- [x] Add conservative generation presets by task type.
- [x] Add `HomeAITests` and worker regression tests.
- [x] Build, test available automated flows, and update project documentation.

## Risks

- Resizing to a 2048 px long edge can reduce fine detail in very large source images.
- Retrying an ambiguous transport failure can create an unused upstream result.
- Historical `finish generation` data remains semantically mixed before this release.
- Prompt and sampling changes require visual comparison against real inputs.

## Validation

- Run worker unit tests.
- Build the app and run all `HomeAITests`.
- Exercise structural/renovation prompts and replace/delete mask paths.
- Confirm failed/cancelled attempts do not consume quota.
- Confirm each generation attempt emits one terminal analytics outcome.

## Log

- [x] Plan approved and copied into the repository.
- [x] App build and `HomeAITests` build-for-testing succeeded.
- [x] All 20 `HomeAITests` passed on iPhone 16 Pro / iOS 18.6 simulator.
- [ ] Worker tests were not executed locally because Node/npm is not installed; test files and command are present.
- [ ] Live Gemini generation, device mask drawing, quota persistence, and post-release Amplitude ingestion were not exercised to avoid paid/external side effects.
