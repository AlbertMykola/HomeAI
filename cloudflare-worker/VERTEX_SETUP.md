# Vertex AI на worker (міграція з AI Studio)

iOS **не змінюється**. Worker сам перемикає upstream.

## 1. GCP

1. [Google Cloud Console](https://console.cloud.google.com/) — проєкт з увімкненим білінгом ($300 trial).
2. Увімкни **Vertex AI API** (`aiplatform.googleapis.com`).
3. IAM → Service Accounts → Create:
   - ім’я: `homeai-vertex-proxy`
   - роль: **Vertex AI User** (`roles/aiplatform.user`)
4. Keys → Add key → JSON → збережи файл локально (не коміть у git).

## 2. Секрети Cloudflare

```bash
cd cloudflare-worker

# JSON в один рядок (macOS):
wrangler secret put GCP_SERVICE_ACCOUNT_JSON < path/to/key.json

# опційно:
wrangler secret put GCP_REGION
# us-central1

wrangler secret put GCP_PROJECT_ID
# лише якщо в JSON немає project_id
```

Автовибір: якщо є `GCP_SERVICE_ACCOUNT_JSON` → **Vertex**.  
Якщо лише `GEMINI_API_KEY` → **AI Studio** (старий шлях).

Примусовий rollback:

```bash
wrangler secret put GEMINI_UPSTREAM
# введи: ai_studio
```

Повернути Vertex:

```bash
wrangler secret delete GEMINI_UPSTREAM
# або: wrangler secret put GEMINI_UPSTREAM → vertex
```

## 3. Деплой

```bash
npx wrangler deploy
```

## 4. Перевірка

```bash
curl -s https://<your-worker>/health | jq
```

Очікується:

```json
{
  "ok": true,
  "gemini_upstream": "vertex",
  "providers": {
    "vertex": true,
    "gemini_ai_studio": true,
    "openai": false
  }
}
```

Тестовий POST (заміни URL і gate header, якщо є `MOBILE_GATE_KEY`):

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -H "X-HomeAI-Mobile-Key: YOUR_KEY" \
  "https://<worker>/gemini/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -d '{"contents":[{"parts":[{"text":"test"}]}]}'
```

Потім **Billing → Reports** у GCP — має з’явитись використання Vertex AI.

## 5. Моделі

iOS уже шле:

`.../gemini/v1beta/models/gemini-3.1-flash-image-preview:generateContent`

Worker витягує `gemini-3.1-flash-image-preview` і викликає Vertex з тією ж назвою моделі.

Якщо модель недоступна в регіоні — зміни `GCP_REGION` або модель у `Constants.API.gemini` (iOS).

## Troubleshooting

| Помилка | Дія |
|--------|-----|
| `vertex_auth_failed` | Перевір JSON ключа, роль SA, годинник |
| `vertex_config_invalid` | `project_id` у JSON або `GCP_PROJECT_ID` |
| 404 від Vertex | Інший `GCP_REGION`; перевір [доступність моделі](https://cloud.google.com/vertex-ai/generative-ai/docs/learn/locations) |
| Кредит не зменшується | Billing Reports → SKU Vertex; можливо trial не покриває generative SKU |
