# Apphud → Adapt (новий API key)

Режим: **Lite**

## Цілі

Підключити Apphud SDK до кабінету Adapt замість старого ключа `app_P8d6XG2…`.

## Контекст

- Старт: `AppDelegate` → `ApphudService.shared.start(id: Constants.Keys.apphud)`
- Ключ: `HomeAI/Entities/Constants.swift` → `Constants.Keys.apphud`
- Placement IDs не змінюємо (`ob-placement-com`, `app_launch_placement`, `option_ai_placement`, `limit_reached_ai_placement`, `save_image_placement`, `share_image_placement`, `details_edit_placement`, `default_placement`) — мають існувати в новому кабінеті з тими ж ідентифікаторами.

## Етапи

- [x] Замінити `Constants.Keys.apphud` на `public_live_IwMFkQu9.T9yq1wYc8VltAWFTXzdZ`
- [x] Збірка

## Ризики

- Paywall порожній, якщо в Adapt не заведені ті самі placement ID + продукти.
- Існуючі юзери отримають новий Apphud user id (інший app) — restore має підхопити покупки по Apple ID, якщо продукти ті самі.

## Питання

- Placement IDs у Adapt уже збігаються зі старими? Так (припущення) / ні — тоді треба мапінг.

## Перевірка

- Старт апки: в логах `[Apphud] Started` / `User successfully registered`
- Paywall після онбордингу вантажить 2 тарифи
- Restore на девайсі з підпискою

# Лог

- [x] `Constants.Keys.apphud` → Adapt `public_live_IwMFkQu9…`
- [x] Debug simulator build (`CODE_SIGNING_ALLOWED=NO`)
- [x] Прибрав 2 зайві `}` у `PaywallViewController` — інакше збірка не проходила (не частина ключа)
- [ ] Живий флоу paywall / restore на девайсі не ганяли
- [ ] Placement IDs у кабінеті Adapt не перевіряли
- [ ] AppsFlyer S2S token у новому кабінеті не перевіряли
