# Adapty → AppsFlyer: appsflyer_id

Режим: **Lite**

## Цілі

Щоб Adapty S2S (trial / subscribe / renew) доходив у AppsFlyer, на профіль треба покласти `appsflyer_id` **після** `Adapty.activate`. Клієнтський `logEvent(af_subscribe)` не додаємо — подвоїть івенти з кабінету.

## Контекст

- Кабінети вже з’єднані (юзер).
- Зараз UID + conversion йдуть у `onConversionDataSuccess` через `try?` **без очікування activate** → `#2002 notActivated`, ідентифікатор не сідає.
- Перед покупкою шлемо UID знову, але з порожнім attribution.

## Етапи

- [x] Після успішного `activate` — `setIntegrationIdentifier(.appsflyerId)`, якщо UID уже є
- [x] Після `AppsFlyer.start()` — той самий bind
- [x] Conversion: UID + `updateExternalAttribution` лише якщо rawData не порожній; чекати activate
- [x] Збірка

## Ризики

Покупка до conversion — UID усе одно піде після start/activate. Attribution-кампанія може прийти пізніше другим викликом.

## Перевірка

- Логи: немає `#2002` на `setIntegrationIdentifier`
- У Adapty профіль: поле `appsflyer_id`
- Після sandbox-покупки — івент у AppsFlyer з кабінету Adapty (не з клієнта)

# Лог

- [x] UID після activate + після AppsFlyer.start
- [x] Conversion чекає activate; порожній rawData не йде в attribution
- [x] Debug simulator build
- [ ] Живу покупку / AppsFlyer dashboard не перевіряли

