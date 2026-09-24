# System review на детальці

Режим: **Lite**

## Цілі

Перенести `SKStoreReviewController.requestReview` з онбордингу на перший успішний згенерований результат (`InspirationDetailViewController`). Кастомний LikeAlert не показувати одночасно.

## Контекст

- Зараз: `RateOBViewController.requestReviewIfNeeded()` + гейт `ob_sw_rate_alert`.
- Кастомний LikeAlert: `InspirationDetailFeedbackManager.showRateAlertIfNeeded` на `currentCount == 1` (не спрацьовує для premium).
- Флаг показа: `Constants.Keys.didShowRateAlert`.
- Івент: уже є `detail_review_request`.

## Етапи

- [x] Прибрати `requestReview` з `RateOBViewController` (екран OB лишається)
- [x] Авто: системний review на детальці згенерованого фото, гейт лише `obSwRateAlert` (без нашого ліміту)
- [x] Like: кастомний LikeAlert один раз (`didShowRateAlert`); повторний like — знову пробуємо системний
- [x] Оновити коментар `obSwRateAlert` + `docs/project.md`
- [x] Збірка

## Ризики

- Apple може не показати діалог (квота) — це єдиний ліміт для системного.
- `didShowRateAlert` тепер лише для кастомного LikeAlert.

## Питання

- Нове поле в Supabase не заводимо: крутимо тим самим `ob_sw_rate_alert`.

## Що перевірити

- Онбординг: Rate-екран без системного діалогу.
- Кожна згенерована деталька: пробуємо системний prompt.
- Like: кастомний лише якщо ще не бачили; інакше системний.

# Лог

- [x] OB більше не кличе `requestReview`
- [x] Деталька з `canRegenerate`: системний prompt ~0.55s після appear
- [x] Like fallback, якщо ще не просили
- [x] `xcodebuild` Debug simulator **BUILD SUCCEEDED**
- [x] Системний більше не пише `didShowRateAlert`; кастомний лишається once
- [ ] Флоу на девайсі / симуляторі з `ob_sw_rate_alert=true` не ганяли руками
