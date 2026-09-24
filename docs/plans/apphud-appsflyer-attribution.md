# Apphud ← AppsFlyer attribution

Режим: **Lite**

## Цілі

Передати в Apphud `appsflyer_id` (+ conversion data), щоб S2S-події покупок не лишались Pending.

## Контекст

- Apphud уже шле ASA і Meta через `Apphud.setAttribution(..., identifer:)`.
- AppsFlyer стартує в `AppsFlyerService`; UID: `getAppsFlyerUID()`.
- Документація Apphud: `from: .appsFlyer`, `identifer` = UID; conversion у `rawData`; перед purchase — ще раз UID.

## Етапи

- [x] `AppsFlyerLibDelegate` → success/fail conversion → Apphud
- [x] Перед `buyProduct` — UID, якщо conversion ще не прийшов
- [x] Після ATT — IDFA в `Apphud.setDeviceIdentifiers` (IDFV уже є)
- [x] Збірка

# Лог
- [x] Conversion delegate + UID перед purchase
- [x] IDFA після ATT
- [ ] Кабінет Apphud/AppsFlyer (S2S token) не перевіряли

## Поза скоупом

AppsFlyer S2S token у кабінеті Apphud, customer user ID, deep links.

## Ризики

Покупка до conversion callback — закриваємо UID перед `purchase`. Не слати UID одразу після `initialize`: Apphud 2 с `isSendingAppsFlyer` може зжерти conversion.
