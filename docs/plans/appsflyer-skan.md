# AppsFlyer SKAN

Режим: **Lite**

## Цілі

Щоб Conversion Studio міг ставити SKAN 4 conversion value, апка має слати in-app івенти **з девайса**. Adapty S2S у кабінет цього не робить.

Не викликаємо `SKAdNetwork.updatePostbackConversionValue` самі — це робить AppsFlyer SDK з мапінгу в Conversion Studio.

## Контекст

- Postback copy SKAN уже є: `NSAdvertisingAttributionReportEndpoint` = `https://appsflyer-skadnetwork.com/`
- `disableSKAdNetwork` не ставимо (має лишатись false)
- Facebook SDK за замовчуванням теж пише SKAN CV → конфлікт
- Документація AF: `logEvent` → `updateConversionValue`; AdAttributionKit — окремий postback copy URL

## Етапи

- [x] Після успішної покупки: `AFEventStartTrial` якщо trial, інакше `AFEventSubscribe` (revenue, currency, product id)
- [x] `FacebookSKAdNetworkReportEnabled = false`
- [x] `AdAttributionKit` / `AttributionCopyEndpoint` → той самий AppsFlyer URL
- [x] Збірка

## Поза скоупом

Мапінг CV у Conversion Studio (кабінет). Restore. Ручні SKAN API. ROI360 purchase connector.

## Ризики

Adapty S2S і клієнтський `af_subscribe` можуть обидва з’явитись у дашборді, якщо в кабінеті Adapty той самий event name. SKAN CV оновлює лише клієнтський `logEvent`.

## Перевірка

- Збірка
- Debug лог AppsFlyer після покупки (`logEvent`)
- Кабінет Conversion Studio: SKAN measurement On, події `af_start_trial` / `af_subscribe`

# Лог

- [x] `logEvent` після успішної покупки
- [x] Facebook SKAN off, AdAttributionKit postback copy
- [x] Debug simulator build
- [ ] Живу покупку / SKAN postback не перевіряли
- [ ] Conversion Studio в кабінеті не перевіряли

