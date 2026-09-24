# Впровадження змін після аудиту конверсії

Дата: 24 вересня 2026. Обсяг: пункти 1, 2, 3, 5, 7, 8, 12 і 21 з [аудиту](conversion-audit-2026-09-24.md).

## Події пейволу

Нові події Amplitude мають `event_schema_version=2`, `app_version`, `build_number`, `paywall_session_id`, `placement`, `origin`, `paywall_variant` і `storefront`. Для вибраного продукту додаються `product_id` (SKU), `product_index`, `variation_id`, `paywall_name`, `ab_test_name`, `price`, `currency` та `trial_offer_presented`.

| Етап | Події | Додаткові поля |
|---|---|---|
| Показ і завантаження | `paywall_shown`, `paywall_products_load_started`, `paywall_products_loaded`, `paywall_products_load_failed` | `requested_placement`, `is_fallback`, `product_count`, `load_latency_ms`, `error_domain`, `error_code` |
| Вибір і покупка | `paywall_product_selected`, `purchase_requested`, `purchase_succeeded`, `purchase_cancelled`, `purchase_pending`, `purchase_failed`, `paywall_closed` | `purchase_attempt_id`, `purchase_latency_ms`, `transaction_verified`, `started_free_trial`, `error_domain`, `error_code` |
| Пробний період | `trial_started` | Лише після підтвердженої транзакції з безкоштовним introductory offer |

`purchase_succeeded` означає відкритий доступ і **не дорівнює першому платному списанню**. Старі події збережені для сумісності існуючих дашбордів. Для нового аналізу воронки слід використовувати нові події та групувати результати за `purchase_attempt_id`.

Клієнт передає Amplitude device ID в Adapty, щоб серверні події можна було з'єднати з клієнтськими. Показ flow в Adapty відправляється один раз після успішного завантаження поточного flow.

## Генерація

`generation_started`, `generation_succeeded`, `generation_failed`, `generation_cancelled`, `generation_blocked` містять `attempt_id`; успіх/помилка/скасування містять тривалість. Додано `generation_stage` для підготовки, генерації та збереження, а також `generation_retry` з причиною та номером повтору. На екрані показано поточний етап, повідомлення після 25 секунд і зрозумілий стан помилки. Після закриття пейволу через ліміт генерація не запускається нескінченно повторно; після успішної покупки спроба відновлюється.

## UI та перевірка

На пейволі CTA й юридичні посилання закріплені над safe area, верхній вміст прокручується, ширина на iPad обмежена до 560 pt. Зменшено hero, вирівняно картки тарифів і додано заголовки для звичайного показу, ліміту генерацій, збереження/поширення та редагування. Шрифти тарифів масштабуються через Dynamic Type; у режимах доступності декоративний hero зменшується, а повна вартість залишається в тексті картки. Тексти локалізовані в 15 мовах.

Debug-перегляд `--paywall-layout-preview` відкриває пейвол із синтетичними продуктами без запуску production SDK. Додаткові аргументи `--paywall-select-annual`, `--paywall-placement-save`, `--paywall-placement-edit`, `--paywall-placement-default` дозволяють перевіряти кнопку вибору та контекстні заголовки. Ці аргументи не входять до Release-поведінки.

Перевірено на 17 доступних симуляторах: iPhone SE 2/3, iPhone 16e/16/16 Plus/16 Pro/16 Pro Max, iPad mini A17 Pro, iPad A16, iPad Air 11/13, iPad Pro 11/13, iPhone 17 Pro/17 Pro Max на iOS 26.4, iPhone 17 Pro Max та iPhone 18 Pro Max на iOS 27.0. Окремо перевірено вибір річного тарифу через обробник кнопки, заголовки для збереження й редагування, темну тему та `accessibility-medium` на iPhone SE. За великого шрифту на SE видно повну першу картку, початок другої й закріплений CTA; решта тарифів доступна прокручуванням. Три наявні тести `PaywallPricingTests` пройшли.

Debug і Release збірки для iOS Simulator пройшли. Перевірки локалізацій (`plutil` для 15 мов), синтаксису Swift і `git diff --check` для змінених файлів пройшли. Реальний App Store trial, перше списання та серверні події не відтворювалися на симуляторі.

## Потрібен доступ до правильного Adapty-застосунку

Пункт 3 **частково завершений**: trial відокремлений від успішної покупки на клієнті, але `first_paid_transaction` має надходити із серверного джерела Adapty/App Store після фактичного списання, включно з переходом trial → paid без відкриття застосунку. Для завершення потрібні налаштування інтеграції Adapty → Amplitude саме для ReHomely, перевірка ідентифікатора профілю та транзакційних подій, а потім sandbox-покупка і звірка з Amplitude. Доступний зараз Adapty-кабінет відкрив інший застосунок, тому production-конфігурацію не змінено.
