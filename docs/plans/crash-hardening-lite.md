# Crash hardening (HomeAI 1.1.10)

Режим: **Lite**

## Цілі

Знайти реальні креші ReHomely (`com.albert.apps.design.ai` 1.1.10) у Sentry + Amplitude і закрити підтверджені crash-prone місця в коді.

## Контекст

- Sentry MCP (`https://mcp.sentry.dev/mcp`) підключений, org `albertapps`, region DE.
- Проєкти: `homeai`, `rehomely` — **0 issues / 0 events** (SDK ще не в сторі).
- `apple-ios` — **не HomeAI**: hangs/watchdog/502 на `new.truth.or.dare.com` і ChatBot smoke. Стеків HomeAI немає.
- ASC 1.1.10: ~13 opt-in crashes без сигнатур у нас.
- Amplitude (HomeDesignAI): на 1.1.10 юзери доходять до `show Options`; `error` — Apphud/StoreKit («Failed to register User», unknown, SKError 4), не native crash.

## Етапи

- [x] Sentry MCP + issues `homeai` / `rehomely` / `apple-ios`
- [x] Amplitude error messages (7d)
- [x] Прибрати KVC `_feedbackSupportLevel` (NSUnknownKeyException на частині девайсів; haptic на paywall Continue)
- [x] Прибрати private `_AppEventsDeviceInfo` (Scene becomeActive → Meta CAPI)
- [x] Прибрати KVC `orientation` на iOS 15
- [x] `presentSafely` + не present на VC без window / mid-transition (paywall після TabBar, alert після StoreKit)
- [x] Carousel: bounds / empty section / `% 0`
- [x] `UIView.fromNib` без `fatalError`
- [x] AppsFlyer: conversion/ATT на main, `NSNull` у rawData не йде в Apphud
- [x] Не чіпати Crashlytics / не комітити секрети

# Лог
- [x] Sentry MCP ready: `homeai`/`rehomely` порожні; `apple-ios` = ToD/ChatBot
- [x] Amplitude `error` = Apphud/StoreKit, не native crash
- [x] KVC haptic + orientation, Meta private API
- [x] presentSafely / carousel / fromNib / image scale
- [ ] iPad / симулятор не ганяли
- [ ] Стека 1.1.10 у Sentry немає — ASC креші без сигнатури

## Поза скоупом

Вгадувати фікс paywall/AppsFlyer без стека 1.1.10. Upload dSYM / Session Replay.

## Ризики

Без стека HomeAI фіксимо crash-prone API (NSException, present, bounds). Store 1.1.10 креші з’являться в `homeai` лише після релізу з Sentry SDK.
