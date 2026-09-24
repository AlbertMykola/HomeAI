# Sentry SPM (HomeAI)

Режим: **Lite**

## Цілі

Підключити Sentry Cocoa через SPM до **окремого** проєкту в org `albertapps`, щоб креші ReHomely не змішувались з ChatBot / Truth or Dare.

## Контекст

- HomeAI зараз шле креші лише в Firebase Crashlytics (`AppDelegate`).
- У Sentry немає `com.albert.apps.design.ai`.
- Патерн: `AppsFlyerService` / `AmplitudeService`, ключі в `Constants.Keys`, старт з `AppDelegate`.
- `IPHONEOS_DEPLOYMENT_TARGET` = 15.6.

## Етапи

- [ ] Окремий Sentry проєкт (platform cocoa) + DSN у `Constants.Keys.sentryDSN`
- [ ] SPM: `https://github.com/getsentry/sentry-cocoa`, product `Sentry` (upToNextMajor 9.26.1)
- [ ] `SentryService` — start якомога раніше, environment debug/production, userId з Apphud
- [ ] `AppDelegate` викликає `SentryService.shared.start()` **до** Firebase (щоб crash handler Sentry був першим)
- [ ] Збірка `HomeAI`

## Поза скоупом

Прибрати Crashlytics, upload dSYM у CI, кастомні breadcrumbs/екрани, Session Replay.

## Ризики

Два crash reporter-и (Sentry + Crashlytics). Sentry стартує першим; Crashlytics лишаємо. Debug теж шле в Sentry (`environment=development`), інакше не перевірити.

## Перевірити

- Збірка simulator.
- Після релізу: івенти в проєкті HomeAI, не в `apple-ios`.
