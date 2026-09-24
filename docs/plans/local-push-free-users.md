# Local push for free users

Режим: **Lite**

## Цілі

Локальні пуші з 15 текстами (title + body) для юзерів **без** активної підписки. Тексти локалізувати в усі `*.lproj`.

## Контекст

- Пушів у проєкті немає. Дозвіл — `UNUserNotificationCenter` (без remote / entitlements).
- Преміум: `AdaptyService.shared.hasActiveSubscription`.
- Навігація: `NavigationManager`. Тап → таб Options (зробити фото кімнати).
- Дозвіл лише на home (TabBar) **після закриття paywall**. Не зі старту і не з `sceneDidBecomeActive`.

## Припущення (не питали)

- 1 пуш / день о **20:12** локального часу, найближчі **15 днів** (ротація 15 текстів). Після відкриття аппа розклад оновлюється.
- Преміум → усі pending скасовуються.
- Тап з пуша: Options, **без** launch paywall на цьому відкритті.

## Етапи

- [x] `LocalNotificationService` + старт у `AppDelegate`
- [x] 15×2 ключі в усі `Localizable.strings`
- [x] Гейт преміум / онбординг / paywall; sync після TabBar, paywall close, Adapty profile
- [x] Тап → Options через NavigationManager
- [x] Збірка

## Ризики

- Діалог дозволу поруч з ATT/paywall — тому delayed + skip якщо зверху paywall.
- Симулятор: пуші нестабільні; перевірка на девайсі.

# Лог
- [x] `LocalNotificationService`: 20:12 local, 15 днів, cancel на premium
- [x] Локалізації en/uk/ru/de/fr/es/it/pl/nl/cs/da/nb/pt-BR/ja/ko
- [x] `xcodebuild` Debug simulator **BUILD SUCCEEDED**
- [ ] Дозвіл + доставка пуша на фізичному девайсі не ганяли
