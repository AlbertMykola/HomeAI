# GPT Image 2.5 — локальний тест

Режим: **Full**  
Погоджено: 2026-09-17  
Статус: реалізовано, live API smoke test очікує локальний key

## Цілі

- Запустити локальний Cloudflare Worker для безпечного тесту GPT Image 2.5 у HomeAI.
- Не змінювати production endpoint і Gemini-поведінку в Release.
- Дати DEBUG-перемикач між Gemini, `gpt-image-2.5-flare` і `gpt-image-2.5-sunburst`.
- Коректно підтримати base image, reference image та alpha-mask для replace/delete.
- Зберігати фактичний provider/model у локальній історії та аналітиці.

## Рішення

Після першого live test підхід спрощено за уточненням користувача: iOS лишає
чинний Gemini contract, а локальний Worker адаптує request/response до OpenAI.

```text
GemeniPromptManager
  → ImageGenerationInput
      → GeminiRESTService
          → production Gemini Worker (Release)
          → local Gemini→OpenAI adapter (DEBUG)
  → ImageGenerationResult(image, provider, model, prompt)
```

Локальний flow:

```text
iOS DEBUG
  → POST http://<mac-lan-ip>:8787/ (Gemini JSON)
  → local Worker adapter
  → multipart /v1/images/edits
  → https://api.openai.com/v1/images/edits
  → Gemini-compatible JSON назад у GeminiRESTService
```

Release URL і production Gemini не змінюються.

## Моделі

- Default для тесту: `gpt-image-2.5-flare`, `quality=medium`.
- Перемикач: `gpt-image-2.5-sunburst` для `.reference`, `.replace`, `.delete` і складних порівнянь.
- Model IDs не хардкодити по call sites — один namespace у `Constants`.
- API key лише в `cloudflare-worker/.dev.vars`, файл у `.gitignore`.

## Контекст проєкту

- Активний flow: `ProcessingViewController` → `GeminiRESTService`.
- `GemeniPromptManager.generatePromptParts()` зараз повертає Google `ModelContent.Part`.
- `ImageGenService` містить стару невикористану OpenAI-реалізацію (`gpt-image-1` / `dall-e-2`) і не створюється.
- Worker уже має raw route `/openai/v1/*`, але deployed `/health` показує `openai:false`.
- Input image нормалізується до long edge 2048 px.
- Поточна mask: opaque PNG, white=edit / black=preserve; GPT Image mask потребує alpha channel.

## Етапи

### 1. Локальний Worker

- [x] Додати `.dev.vars` у `.gitignore`; secret ніколи не комітити.
- [x] Документувати `OPENAI_API_KEY` і запуск `npx wrangler dev --local --port 8787`.
- [x] `/health` показує readiness OpenAI без виводу secret.
- [x] CORS не додавати — native URLSession його не потребує.
- [x] Додати тести passthrough `/openai/v1/images/edits`: Authorization підставляється Worker, mobile headers прибираються.

### 2. Provider-neutral моделі

- [x] `ImageGenerationInput`: prompt, base image, optional reference/mask, `DesignOption`.
- [x] `ImageGenerationResult`: `UIImage`, prompt, provider, model.
- [x] `ImageGenerationService` protocol.
- [x] `GemeniPromptManager` формує input без дублювання існуючих prompt builders.

### 3. Gemini adapter

- [x] Загорнути чинний `GeminiRESTService` за protocol без зміни request/response та retry.
- [x] Production/Release завжди лишається Gemini.
- [x] Існуючі `GeminiRESTServiceTests` пройшли без зміни поведінки.

### 4. GPT Image 2.5 Worker adapter

- [x] Видалити старий невикористаний `ImageGenService`.
- [x] Worker приймає Gemini JSON та формує `POST /v1/images/edits` multipart:
  - `model`;
  - `prompt`;
  - base image як перший `image[]`;
  - reference image як другий `image[]`;
  - додаткові reference/mask images як наступні `image[]`;
  - `quality=medium`, `size=auto`, `output_format=jpeg`.
- [x] Worker конвертує `data[0].b64_json` назад у Gemini `inlineData`.
- [x] Worker нормалізує OpenAI errors у Gemini error contract.
- [ ] Після базового live test окремо перевірити replace/delete; якщо visual mask недостатня, додати alpha-mask conversion у Worker.
- [x] Timeout лишити в межах поточних 180/240 с.

### 5. DEBUG routing

- [x] DEBUG launch environment:
  - `HOMEAI_IMAGE_PROVIDER=openai|gemini`;
  - `HOMEAI_OPENAI_MODEL=gpt-image-2.5-flare|gpt-image-2.5-sunburst`;
  - `HOMEAI_OPENAI_PROXY_URL=http://127.0.0.1:8787/openai/v1/images/edits`.
- [x] Release ігнорує ці environment overrides.
- [x] Додати вузький localhost ATS allowance лише для Debug; не відкривати arbitrary HTTP у Release.
- [x] Якщо Worker недоступний — показати typed network error; автоматично не запускати другу платну генерацію через fallback.

### 6. Metadata та аналітика

- [x] `ImageHistoryService` отримує фактичні provider/model з `ImageGenerationResult`.
- [x] `generation_started/succeeded/failed` отримують `provider` і `model`, без prompt text.
- [x] Окремий test prompt version для GPT 2.5; production Gemini version не змінювати.

### 7. Валідація

- [x] Worker unit tests: 7/7 пройшли через bundled Node.
- [x] Worker adapter contract test: Gemini JSON → OpenAI multipart → Gemini JSON.
- [x] Debug build-for-testing, усі `HomeAITests`, targeted GPT Image tests і Release simulator build.
- [ ] Локальний live smoke test з API key:
  - interior;
  - exterior/garden;
  - reference з двома images;
  - replace/delete з mask;
  - flooring/walls;
  - portrait + landscape.
- [ ] Порівняти Flare/Sunburst: latency, instruction following, geometry preservation, unwanted edits, output size та приблизну вартість.

## Privacy / App Store

- Локальний DEBUG-тест не деплоїться користувачам і не потребує App Store review.
- Перед production-перемиканням:
  - оновити Privacy Policy та App Privacy;
  - розкрити передачу фото/промптів third-party AI;
  - додати explicit consent перед першим upload;
  - після цієї UI-зміни подати новий build на review.

## Ризики

- `size=auto` може змінювати aspect ratio — перевірити portrait/landscape до фіксації custom size.
- GPT не гарантує pixel-identical preservation поза mask; для строгих edits може знадобитися локальний compositing.
- Flare може бути недостатнім для точних replace/reference; Sunburst матиме більшу latency.
- OpenAI organization/API project може вимагати verification та funded billing; Free tier image API не підтримується.
- `.dev.vars` або API key не повинні потрапити в git, логи чи iOS binary.

## Питання перед імплементацією

- [x] Обрано: Flare для redesign, Sunburst для reference/replace/delete; ручний model override доступний.
- [ ] API key додати локально в `cloudflare-worker/.dev.vars`; у чат ключ не надсилати.

## Лог

- [x] Додано provider-neutral generation contract і DEBUG-only factory.
- [x] Client-side OpenAI multipart видалено; адаптація перенесена в локальний Worker.
- [x] Старий невикористаний `ImageGenService` і його DTO видалено.
- [x] Shared scheme містить вимкнені за замовчуванням local test variables.
- [x] Усі iOS тести пройшли; Debug і Release збираються.
- [x] Worker tests: 7/7 пройшли через bundled Node.
- [x] Локальні `local-dev.js` сервери видалено після deploy Cloudflare Worker.
- [ ] Live OpenAI generation не запускалась без API key, щоб не робити платний зовнішній запит.

