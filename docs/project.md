# HomeAI / ReHomely — карта проєкту

iOS UIKit-ап: AI-редизайн інтер’єру, екстер’єру, саду + smart tools.  
Display name: **ReHomely**. Bundle: `com.albert.apps.design.ai`. SwiftUI немає.

## Запуск

```
AppDelegate (Sentry → Facebook → Adapty; Firebase/AppsFlyer/Amplitude на наступному runloop)
  → SceneDelegate → NavigationManager.setupWindow
      → LaunchViewController (Onboarding.storyboard, 0.8 с)
          → proceedToApp()
              → didShowOnboarding != true (або явний DEBUG -showOnboarding)
                    → OBPageViewController
              → інакше TabBarController, Home починається з Interior
```

Ключ онбордингу: `did_show_onboarding_8`.  
Debug і Release поважають completion flag. Для примусового повтору у Debug потрібен `-showOnboarding`; `-skipOnboarding` вимикає це примусове повторення. Одразу після завершення O4 Home показує вибраний напрям у першому сеансі; з наступного запуску процесу — Interior. Оригінальний `onboarding_goal` зберігається.

## Таби

| Таб | Storyboard ID | Файл |
|---|---|---|
| Create | `HomeViewController` | `Storyboards/Home.storyboard` |
| Inspiration | `InspirationFeedViewController` | `Storyboards/Inspiration.storyboard` |
| Projects | `ProjectsViewController` | `Storyboards/Projects.storyboard` |
| Profile | `ProfileTabViewController` | `Storyboards/Profile.storyboard` |

Кожен таб у `PortraitNavigationController`. Роутинг — `NavigationManager`, не coordinator.

З 20.10.2026 навігація використовує системні `UITabBarController` / `UITabBar`. Чотири кореневі сцени задають `tabBarItem` у storyboard; `TabBarController` підставляє локалізовані назви. UIKit керує розміром, матеріалом, safe area й розташуванням панелі, зокрема може показувати її вгорі на iPad. Кастомний `DSTabBarView`, його overlay-сцена, масштабування та додатковий нижній safe-area inset прибрані. Push-екрани й режим вибору Projects приховують панель через системний `setTabBarHidden`; власної анімації таббара немає.

## Онбординг

Pager: `OBPageViewController` (paging `UIScrollView`). Новий Figma A стек:

1. `OnboardingPageViewController(.room)` — before/after, ручка з drag.
2. `.tools` — карусель п’яти інструментів зі сканером.
3. `.words` — демонстрація текстової правки.
4. `OnboardingGoalViewController` — персоналізація (interior/exterior/garden/surfaces).

Сцени `Onboarding.storyboard`, `OnboardingHeroView`, `OnboardingLayout` (bounds вікна, база 393×852). Зображення у `Assets.xcassets/Onboarding`. Старі OB-класи збережені, але pager їх не використовує.

Кнопки Skip немає; на O4 потрібно вибрати ціль. Вибір пишеться в `onboarding_goal` та `redesign_home_focus` і персоналізує перший Home та стартовий інструмент. Завершення: ATT → Adapty → TabBar → paywall `ob-placement-com`. Повторний запуск — Home з інтер’єром першим, без онбордингу й launch-paywall.

UI QA: схема `HomeAIOnboardingQA`, `HomeAIUITests`; DEBUG `--onboarding-preview`, `--onboarding-page 0…3`, `--onboarding-still`, `--onboarding-splash`. Деталі: `docs/onboarding.md`.

Повний каталог: схема `HomeAIFullQA`, DEBUG `--app-qa`, 72 стани / 15 мов. Відтворення й результати завершених прогонів — [full-app QA](qa/full-app-qa.md).

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
| Remote flags | `SupabaseAppConfigService` | `obSwRateAlert` — для legacy-маршруту; поточний `RatePrompt` запитує системний рейтинг один раз після першої успішної генерації |
| Історія | `ImageHistoryService` | локально + upload |
| Локальні пуші | `LocalNotificationService` | 15 re-engagement пушів для юзерів без преміума, 20:12 локального часу |

Глобальні кольори/ключі/URL — лише `Entities/Constants.swift`.  
Локальні тексти/лейаут файлу — `private struct Defaults`.

Пейвол завжди пропонує лише тижневу підписку з продуктів Adapty. Якщо тижневого продукту немає, показується помилка доступності; автоматичного переходу на інший період немає. Profile та Pro feature sheet використовують кешовану ціну цього самого тижневого продукту.

## UI-конвенції

- Увесь поточний UI: `HomeAI/Storyboards/*.storyboard`; `AppStoryboard` створює сцени. Клітинки — storyboard prototypes. Старі невикористовувані XIB legacy-екранів не є джерелом поточного дизайну.
- Кнопки CTA: `LiquidGlassButton`.
- Констрейнти з IB: `constraintsCollection` + `scaleConstant()` (база висоти 852).
- Ієрархії, шрифти Geologica, зображення, констрейнти та outlets задаються у storyboard. Swift містить стан, локалізацію, анімації й адаптивну зміну існуючих констрейнтів. `tools/xibgen` — архівний інструмент; поточний UI ним не генерується.
- Локалізація: 15 мов, `Resources/<lang>.lproj/Localizable.strings`, `"key".localized`.

## Cloudflare worker

`cloudflare-worker/` — чинний Gemini proxy і `GET /app/config`; його routes лишаються backward-compatible.  
`cloudflare-worker-openai/` — окремий GPT Image 2.5 Worker з contract `/v1/images/generate`; setup і rollout описані в його `README.md`.

## Відомі дірки (не чіпати, поки немає задачі)

- `EnterPromptViewController` у storyboard без Swift-класу
- `logs.swift` — не апп-код
- Firebase Auth у processing заглушений
- опечатка ключа `optionPlacememt`

## Адаптивна розмітка storyboard

Статичні сцени використовують `DSAdaptiveRootView`, а клітинки — `DSAdaptiveCollectionViewCell` / `DSAdaptiveTableViewCell`. `DSReferenceLayout` зберігає авторські константи й застосовує наявний `scaledByHeight` від розміру поточного viewport, включно зі шрифтами, відступами, іконками та сітками. Повторні layout і resize не накопичують масштаб; обмеження 1.35 прибране. Онбординг, Result/Compare/Share та пейволи з власним reference layout не отримують другого масштабу. Системний таббар не входить у reference layout; його safe area надає UIKit. `ds.dynamic` позначає констрейнти, які контролер обчислює з поточного стану, наприклад ручку before/after. Ієрархії залишаються в storyboard.

Поради отримують `DesignOption` із поточного wizard; локалізований legacy-каталог використовується для фасаду, саду, маскування й планів. Три векторні приклади планів у `Assets.xcassets/PhotoGuidance` доступні офлайн через стандартні demo-картки. Перша успішна генерація записує pending review; Result запитує системний рейтинг один раз при показі саме цього результату.

Adaptive thumbnails request the rendered card resolution; wide Projects cards load the saved original instead of stretching the compact preview. Photo-guidance rows use storyboard minimum heights measured after each label receives its final scaled bounds.
