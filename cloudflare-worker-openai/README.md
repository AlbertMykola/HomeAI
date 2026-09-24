# HomeAI OpenAI Images Worker

Окремий Worker для нових версій HomeAI. Він не замінює і не змінює старий
`cloudflare-worker/`: старі версії застосунку продовжують працювати через Gemini.

## Routes

- `GET /health`
- `POST /v1/images/generate`

## Deploy

```bash
npx wrangler secret put OPENAI_API_KEY
npx wrangler deploy
```

Після deploy перевір:

```text
GET https://<worker>.workers.dev/health
```

Production Worker URL вже прописаний у
`Constants.Generation.OpenAI.productionWorkerURL`:
`https://fragrant-fog-a5e3.dirty-truth-app.workers.dev/v1/images/generate`. Supabase зберігає лише
kill switch `image_generation_provider`; URL навмисно зафіксований у binary,
щоб скомпрометований remote config не міг перенаправити фото користувачів.
Не перемикай provider на `openai`, доки новий build не пройшов App Store review
і privacy disclosure не оновлено.

## API v1

Request:

```json
{
  "version": 1,
  "operation": "interior",
  "prompt": "Redesign this room...",
  "images": [
    {
      "role": "base",
      "mimeType": "image/jpeg",
      "data": "<base64>"
    }
  ]
}
```

Roles: `base`, `reference`, `mask`. Mask must be PNG with fully transparent
pixels in the edit area.

Success:

```json
{
  "version": 1,
  "requestId": "uuid",
  "provider": "openai",
  "model": "gpt-image-2.5-flare",
  "image": {
    "mimeType": "image/jpeg",
    "data": "<base64>"
  },
  "usage": {
    "totalTokens": 0,
    "inputTokens": 0,
    "outputTokens": 0
  }
}
```

Error:

```json
{
  "version": 1,
  "requestId": "uuid",
  "error": {
    "code": "rate_limited",
    "message": "The image service is busy",
    "retryable": true
  }
}
```

## Model routing

- `reference`, `replace`, `delete`: `gpt-image-2.5-sunburst`.
- Other operations: `gpt-image-2.5-flare`.
- `OPENAI_IMAGE_MODEL` can pin either supported model.
- Default quality is `medium`; override server-side with `OPENAI_IMAGE_QUALITY`.

## Production safety

- The OpenAI key exists only as a Worker secret.
- `MOBILE_GATE_KEY` is available for local/internal builds only; it is not strong attestation.
- Configure Cloudflare rate limiting before public rollout.
- Add App Attest/App Check before relying on the endpoint as abuse-proof.
- Do not automatically retry/fallback after an ambiguous client timeout.
