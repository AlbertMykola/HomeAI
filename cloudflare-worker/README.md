# HomeAI proxy worker

Один Cloudflare Worker, який проксує Gemini (Vertex AI або AI Studio rollback), OpenAI.
iOS не змінюється — той самий URL `/gemini/v1beta/models/...:generateContent`.

**Vertex (рекомендовано):** див. [VERTEX_SETUP.md](./VERTEX_SETUP.md).

## Деплой

1. Завести воркер у Cloudflare (Workers → Create) або з CLI:
   ```bash
   cd cloudflare-worker
   npx wrangler deploy
   ```
2. Додати секрети (Vertex):
   ```bash
   npx wrangler secret put GCP_SERVICE_ACCOUNT_JSON < service-account.json
   # rollback: GEMINI_API_KEY + GEMINI_UPSTREAM=ai_studio
   ```
   Детально: [VERTEX_SETUP.md](./VERTEX_SETUP.md).
3. Перевірити:
   ```
   GET https://<worker>/health
   ```
   Очікується `gemini_upstream: "vertex"`.

## Маршрути

| Метод | Шлях                                       | Куди проксується                                      |
| ----- | ------------------------------------------ | ----------------------------------------------------- |
| GET   | `/health`                                  | health-check (показує, які секрети задані)            |
| GET   | `/app/config`                              | remote config для iOS (JSON) — ліміти генерацій, paywall flags |

Поля `GET /app/config` (редагуються в `APP_CONFIG` у `worker.js`):

| Поле | Опис | Default |
| ---- | ---- | ------- |
| `freeGenerationsLifetime` | Безкоштовних генерацій без підписки (за весь час) | `1` |
| `premiumGenerationsPerDay` | Генерацій на день для підписників | `15` |
| `paywallShowTopCloseButton` | Верхня кнопка закриття на paywall | `false` |
| `lifetimeFreeScanLimit` | legacy alias для `freeGenerationsLifetime` | — |
| POST  | `/` або `/gemini`                          | Vertex AI `generateContent` (або AI Studio при rollback) |
| POST  | `/gemini/v1beta/models/{model}:generateContent` | Та сама модель на Vertex / AI Studio              |
| POST  | `/openai/v1/...`                           | `api.openai.com/v1/...`                               |

Дефолтна Gemini-модель: `gemini-3.1-flash-image-preview` (на `:generateContent`).

## OpenAI Images

Production-міграція винесена в окремий `cloudflare-worker-openai/`. Цей Worker
і його Gemini routes не перемикаються, щоб старі версії застосунку працювали без
змін.

## Як використовувати в HomeAI

У `HomeAI/Entities/Constants.swift`:

```swift
struct API {
    /// Шлях до Gemini generateContent. Залишаємо корінь — worker сам додасть дефолтну модель.
    static let gemini  = "https://<worker>/"
    /// Для OpenAI chat completions.
    static let chatGPT = "https://<worker>/openai/v1/chat/completions"
    ...
}
```

`GeminiRESTService` шле POST на `Constants.API.gemini`, тіло — масив `contents` Gemini-формату. Worker прийме на `/` і прокине на `…/gemini-2.5-flash-image:generateContent`.

Якщо схочеш в майбутньому інакшу модель — поміняй URL у клієнті:

```swift
static let gemini = "https://<worker>/gemini/v1beta/models/gemini-2.5-pro:generateContent"
```

Без змін у воркері.

## Mobile gate (опційно)

Якщо встановиш `MOBILE_GATE_KEY` — додавай у клієнті заголовок:

```
X-HomeAI-Mobile-Key: <значення>
```

Це найпростіший шар захисту від випадкового зовнішнього трафіку. Для жорсткого захисту краще робити app-attest / device-check.
