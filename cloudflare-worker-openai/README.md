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

## Security (2026-10-20)

- `OPENAI_API_KEY` lives only in Worker secrets; the app never has it.
- `X-HomeAI-Mobile-Key` gate (`MOBILE_GATE_KEY`) on every route.
- **Apple App Attest** (`attest.js`, `guard.js`): the app registers a Secure Enclave key once
  (`GET /attest/challenge` → `POST /attest/register`, chain checked against Apple's root) and signs
  every generation body (`X-HomeAI-Attest-Key` / `X-HomeAI-Attest-Assertion`). Strictly increasing
  counter → no replay; signature covers SHA256(body) → no tampering. Keys live in the `DeviceGuard`
  Durable Object.
- Rate limits (Durable Object counters, `[vars] LIMIT_*`): per device 6/min, 100/day; per IP 20/min,
  400/day; attestation per IP 10/min, 50/day. Over the limit → 429 `rate_limited_minute` /
  `rate_limited_daily` + `retry-after`.
- Debug simulator only: `X-HomeAI-Dev-Token` = secret `DEV_BYPASS_TOKEN` (token file
  `~/.rehomely-dev-token` on the Mac; not in the app bundle, not compiled into Release).
- Emergency switch: `[vars] ATTEST_MODE = "off"` + deploy (IP limits stay on).
- Logs: codes and ids only — no keys, photos or prompts.

Tests: `npm test` (attestation fixtures: a throwaway test CA generated on each run, gitignored).
