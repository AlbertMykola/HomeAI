# OpenAI production migration

Режим: **Full**  
Погоджено: 2026-09-17

## Цілі

- Старі версії застосунку продовжують використовувати чинний Gemini Worker без змін.
- Нова версія використовує окремий `homeai-openai-images` Worker через власний versioned API.
- Remote config дає kill switch назад на Gemini без нового App Store build.
- API keys ніколи не потрапляють в iOS binary.

## Архітектура

```text
OldApp -> ExistingWorker -> Gemini
NewApp -> RemoteConfig
NewApp -> ExistingWorker -> Gemini
NewApp -> OpenAIWorkerV1 -> OpenAI
```

Автоматичного fallback після timeout немає: невідомо, чи OpenAI вже створив платне
зображення. Rollback виконується remote config для наступної спроби.

## Етапи

- [x] Створити окремий `cloudflare-worker-openai/` з `/health` і `/v1/images/generate`.
- [x] Додати provider-neutral request/response/error contract v1.
- [x] Реалізувати OpenAI multipart, Flare/Sunburst routing, alpha-mask, limits і typed errors.
- [x] Додати Cloudflare secrets, Worker tests та deployment README.
- [x] Додати Supabase provider kill switch; production HTTPS URL зафіксувати в binary.
- [x] Додати iOS service для нового contract без OpenAI key.
- [x] DEBUG може вмикати deployed Worker через `HOMEAI_IMAGE_PROVIDER=openai`; Release — лише compile-time HTTPS URL + Supabase kill switch.
- [x] Записувати фактичні provider/model у history та analytics.
- [x] Зібрати Debug/Release, прогнати iOS і Worker tests.
- [x] Оновити системну документацію та rollout checklist.

## Rollout

1. Deploy нового Worker без зміни Supabase config.
2. Smoke test `/health` і test build.
3. Випустити нову версію з default `gemini`.
4. Після проходження review поставити `image_generation_provider=openai` у Supabase.
5. Моніторити success rate, latency, `429/5xx`, cost та accepted-result rate.
6. При деградації повернути provider у `gemini`; старі версії не зачіпаються.

## Privacy / Review

- Перед rollout оновити Privacy Policy та App Privacy щодо передачі фото й prompt в OpenAI.
- Додати explicit consent перед першим OpenAI upload, якщо поточний consent цього не покриває.
- Не вмикати OpenAI для production до завершення цих кроків.

## Перевірка

- Старий app contract і старий Worker не змінені новою міграцією.
- Missing/invalid remote config безпечно використовує Gemini.
- OpenAI Worker не повертає upstream secrets або нестабільний upstream JSON.
- Timeout/cancellation не запускає другу платну генерацію.

## Лог

- [x] Архітектуру окремого Worker погоджено.
- [x] Старий Gemini Worker повернуто до незмінного routing.
- [x] Старий Worker: 6/6 tests; новий OpenAI Worker: 6/6 tests.
- [x] Усі `HomeAITests` пройшли, включно з 4 OpenAI contract/mask/routing tests.
- [x] Debug build-for-testing і Release simulator build успішні.
- [x] Production URL: `https://fragrant-fog-a5e3.dirty-truth-app.workers.dev/v1/images/generate`.
- [ ] Cloudflare secret `OPENAI_API_KEY` ще не доданий (`/health` показує `openai_configured: false`).
- [ ] Supabase migration ще не виконана; default/fallback залишається Gemini.
- [x] Локальні `local-dev.js` сервери видалено; застосунок ходить на deployed Cloudflare Worker.
