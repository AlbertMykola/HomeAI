# AppsFlyer SPM

Режим: **Lite**

## Цілі

Підключити AppsFlyer iOS SDK через SPM і стартувати його з `Constants.Keys.appsFlyer` + `Constants.Keys.appleId`.

## Контекст

- Ключ уже є: `Constants.Keys.appsFlyer`.
- Apple App ID: `Constants.Keys.appleId` (`6752722494`).
- Патерн сервісів: `AmplitudeService` / `ApphudService`, старт з `AppDelegate`.
- ATT уже в `SceneDelegate` → `TrackingManager.requestPermission`. SDK v7: `initialize` + `registerSessionReadyListener`, `start()` після ATT у listener (старий `waitForATT` deprecated).

## Етапи

- [x] SPM: `https://github.com/AppsFlyerSDK/AppsFlyerFramework-Static`, product `AppsFlyerLib-Static` (7.0.2)
- [x] `AppsFlyerService` — `initialize` + session-ready listener + `start` після ATT
- [x] `AppDelegate` викликає `AppsFlyerService.shared.start()`
- [x] SKAN postback copy URL в `Info.plist` (рекомендація AppsFlyer)
- [x] Збірка `HomeAI` (simulator Debug)

# Лог
- [x] SPM AppsFlyerLib-Static 7.0.2
- [x] API v7: `initialize(devKey:appId:)`, не settable `appsFlyerDevKey`
- [x] `start()` всередині `registerSessionReadyListener` після `TrackingManager.requestPermission`
- [x] Збірка simulator Debug OK
- [x] Прибрано зайву `}` у `PaywallViewController` — блокувала компіляцію target (не частина AppsFlyer)
- [ ] Тестовий інсталл у AppsFlyer dashboard не ганяли

## Поза скоупом

Deep links, кастомні in-app events, customer user ID з Apphud.

## Ризики

Перший `start` без ATT — якщо не поставити timeout, IDFA на першому запуску може не піти. Timeout 60 с покриває delay 1 с + діалог.

## Перевірити

- Debug-збірка компілюється з `import AppsFlyerLib`.
- У Xcode: Package Dependencies → AppsFlyerFramework-Static.
- Руками в AppsFlyer dashboard: тестовий інсталл (не ганяємо тут).
