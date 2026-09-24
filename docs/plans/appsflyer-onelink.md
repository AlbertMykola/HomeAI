# AppsFlyer OneLink / Associated Domains

Режим: **Lite**

## Цілі

Підключити OneLink `https://rehomelyai.onelink.me/W3xt/r2wpnkyu` для SKAN/Google Ads без ATT (`gbraid`/`wbraid`).

## Контекст

- Scene-based апка: основний шлях — `SceneDelegate`.
- AppsFlyer 7.0.2: `continue(_:restorationHandler:)`, `handleOpen(_:options:)`.
- Навігацію з OneLink не робимо — лише attribution.

## Етапи

- [x] `HomeAI.entitlements`: `applinks:rehomelyai.onelink.me` + `CODE_SIGN_ENTITLEMENTS`
- [x] `AppsFlyerService` — `continueUserActivity` / `handleOpenURL`
- [x] `SceneDelegate` (cold start + continue + openURLContexts) і `AppDelegate` fallback
- [x] `docs/project.md` + збірка

## Ризики

- AASA на `rehomelyai.onelink.me` має вказувати на `com.albert.apps.design.ai` (кабінет AppsFlyer, не код).
- Associated Domains на симуляторі без девайсу/профілю можуть не резолвитись.

# Лог

- [x] Entitlements `applinks:rehomelyai.onelink.me`
- [x] Cold start: `configure()` до Scene `continue`; pending URL якщо SDK ще не готовий
- [x] `xcodebuild` Debug simulator **BUILD SUCCEEDED**
- [ ] Клік OneLink на девайсі / gbraid у AppsFlyer не ганяли
