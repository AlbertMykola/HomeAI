# HomeAI / ReHomely — карта проєкту

iOS UIKit-ап: AI-редизайн інтер’єру, екстер’єру, саду + smart tools.  
Display name: **ReHomely**. Bundle: `com.albert.apps.design.ai`. SwiftUI немає.

## Запуск

```
AppDelegate (Sentry → Facebook → Adapty; Firebase/AppsFlyer/Amplitude на наступному runloop)
  → SceneDelegate → NavigationManager.setupWindow
      → LaunchViewController (5 с)
          → proceedToApp()
              → немає didShowOnboarding (або DEBUG alwaysShowOnboarding)
                    → OBPageViewController
              → інакше TabBarController + launch paywall
```

Ключ онбордингу: `did_show_onboarding_8`.  
DEBUG: `Constants.Debug.alwaysShowOnboarding == true` (Release = false).

## Таби

| Таб | Storyboard ID | Файл |
|---|---|---|
| Options | `OptionsViewController` | `Controllers/OptionsViewController.swift` |
| Inspiration | `InspirationViewController` | `Controllers/InspirationViewController.swift` |
| Profile | `ProfileViewController` | `Controllers/ProfileViewController.swift` |

Кожен таб у `PortraitNavigationController`. Роутинг — `NavigationManager`, не coordinator.

## Онбординг

Pager: `OBPageViewController` (paging `UIScrollView`, не storyboard). XIBs:

1. `WelcomeOBViewController` — interior before/after
2. `OBExteriorViewController`
3. `GardenOBViewController`
4. `RateOBViewController` — Lottie `iphone ob 4.json`, CTA Get Started. Системний `requestReview` тут більше не викликається.

Останній екран: Adapty → `completeOnboarding()` → TabBar → paywall `ob-placement-com`, якщо немає підписки.

Деталі / лог: `docs/onboarding.md`.

## Генерація дизайну

```
Options
  → interior/exterior/garden/reference/flooring → PageViewController
  → replace/delete → ReplaceObjectPageViewController
      → кроки (фото, кімната/тип, стиль, колір, маска)
      → GenerationAccess
      → ProcessingViewController
          → GemeniPromptManager + ImageGenerationService
              → GeminiRESTService (production)
              → OpenAIWorkerImageGenerationService + separate Worker
          → ImageHistoryService (+ upload у Supabase)
          → InspirationDetailViewController
```

Кроки `PageViewController` залежать від `DesignOption` (`Entities/Enums/DesignOptionType.swift`). Анімований `setViewControllers` лише через `setPageSafely` (не під час свайпа/модалки — HOMEAI-1).  
Ім’я `GemeniPromptManager` — історична опечатка, не перейменовувати без потреби.

Production image model: `Constants.Generation.modelID` (`gemini-3.1-flash-image-preview`).  
Prompt contract is versioned by `Constants.Generation.promptVersion`; UI display names stay localized, while prompts use canonical English `promptDescriptor` values.

GPT Image 2.5 migration:

- `HOMEAI_IMAGE_PROVIDER=openai` у DEBUG ходить на deployed Worker `https://fragrant-fog-a5e3.dirty-truth-app.workers.dev/v1/images/generate`;
- Release reads the provider kill switch from Supabase; the HTTPS Worker URL is pinned in `Constants`;
- missing/invalid config always falls back to Gemini;
- Flare is selected for normal redesign, Sunburst for reference/replace/delete;
- old app versions and the existing Worker remain on Gemini.

Перед API:

- base/reference images normalize EXIF orientation, use scale 1, and cap the long edge at 2048 px;
- replace/delete masks must have the same pixel dimensions as the normalized base image;
- JSON body is rejected locally above the configured budget;
- transient timeout/429/502/503/504 failures receive at most two retries.

Quota is recorded only after the generated image is saved. Generation history and analytics store the actual provider/model. Analytics use one attempt id and separate `generation_started`, `generation_succeeded`, `generation_failed`, `generation_cancelled`, and `generation_blocked` outcomes. User prompt text is not sent to analytics.

Regression checks:

```sh
xcodebuild -project HomeAI.xcodeproj -scheme HomeAI -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -project HomeAI.xcodeproj -scheme HomeAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' test
cd cloudflare-worker && npm test
```

## Сервіси

| Що | Файл | Навіщо |
|---|---|---|
| Креші | `SentryService` | Sentry Cocoa. Кабінет: проєкт **homeai** (org `albertapps`, DE). Старт до Firebase. |
| Підписки | `AdaptyService` | paywall, статус; кабінет Adapty; AppsFlyer UID + conversion. SKAN CV: клієнтський `af_start_trial` / `af_subscribe` через `AppsFlyerService` |
| AppsFlyer OneLink | `AppsFlyerService` + `HomeAI.entitlements` | `applinks:rehomelyai.onelink.me`; SceneDelegate/AppDelegate прокидують `continue` / `openURL` |
| Аналітика | `AmplitudeService` | Amplitude + Firebase. Кабінет: проєкт **HomeDesignAI** (US, appId `745093`). Івенти в `AmpitudeEvent`. MCP: `https://mcp.amplitude.com/mcp`. Дашборд: [ReHomely — product overview](https://app.amplitude.com/analytics/albertappstruthordare/dashboard/djh22ked). |
| Генерація | `ImageGenerationService`, `GeminiRESTService`, `OpenAIWorkerImageGenerationService` | Existing Worker/Gemini for old versions; separate versioned OpenAI Worker for the new version |
| Чат | `AssistantChatService` | текст через worker |
| Ліміти | `WorkerConfigService`, `GenerationAccess` | free / daily premium |
| Remote flags | `SupabaseAppConfigService` | `obSwRateAlert` — системний Store review на згенерованій детальці (Apple лімітить частоту), не на онбордингу |
| Історія | `ImageHistoryService` | локально + upload |
| Локальні пуші | `LocalNotificationService` | 15 re-engagement пушів для юзерів без преміума, 20:12 локального часу |

Глобальні кольори/ключі/URL — лише `Entities/Constants.swift`.  
Локальні тексти/лейаут файлу — `private struct Defaults`.

## UI-конвенції

- Екрани: storyboard (шел) або XIB (онбординг, клітини).
- Кнопки CTA: `LiquidGlassButton`.
- Констрейнти з IB: `constraintsCollection` + `scaleConstant()` (база висоти 852).
- Шрифти в storyboard/XIB (Geologica). Картинки в XIB, якщо можна.
- Локалізація: 15 мов, `Resources/<lang>.lproj/Localizable.strings`, `"key".localized`.

## Cloudflare worker

`cloudflare-worker/` — чинний Gemini proxy і `GET /app/config`; його routes лишаються backward-compatible.  
`cloudflare-worker-openai/` — окремий GPT Image 2.5 Worker з contract `/v1/images/generate`; setup і rollout описані в його `README.md`.

## Відомі дірки (не чіпати, поки немає задачі)

- `EnterPromptViewController` у storyboard без Swift-класу
- `logs.swift` — не апп-код
- Firebase Auth у processing заглушений
- опечатка ключа `optionPlacememt`
