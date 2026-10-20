# Onboarding · Figma A

Джерело: Figma `W5U3Q7e9HY5WCcnpqEu6fd`, секція `23:7252`, базовий canvas **393 × 852**.

## Поточний сценарій

`LaunchViewController` (`Onboarding.storyboard`, анімоване лого, 0.8 с) → `OBPageViewController` → чотири кроки:

1. **Redesign any room** — `OnboardingPageViewController(.room)`: intro 0.6 с, reveal 1.0 с, петля 28–72%, drag ручки; повернення до автоплею через 3 с.
2. **11 tools** — `.tools`: п’ять карток (стіни, підлога, видалення, заміна, стиль), сканер before/after, свайп; ручний свайп призупиняє автоплей на 3 с.
3. **Edit with words** — `.words`: демонстрація друку, Send, сканування результату. Поле не редагується й не викликає API.
4. **What are we redesigning?** — `OnboardingGoalViewController`: вибір однієї з чотирьох плиток. Вибір відображається 0.7 с перед переходом.

Системний `LaunchScreen.storyboard` містить лише білий фон без зображень. Лого, назву й локалізований слоган показує тільки анімований `LaunchViewController`.

Кнопок пропуску на O1–O4 немає: O1–O3 проходяться кнопкою Continue, O4 завершується вибором цілі. Свайп назад збережено. Зображення в `Assets.xcassets/Onboarding` — точні експорти Figma, локальні JPEG; clay-іконки, Geologica, DSPrimaryButton — наявні компоненти проєкту.

Онбординг показується один раз: completion flag `did_show_onboarding_8` зберігає `UserDefaultsManager`. У Debug повторення можливе лише за явним аргументом `-showOnboarding`; звичайний запуск його не примушує. `completeOnboarding()` зберігає вибір O4 як hero першого сеансу Home. На наступному запуску процесу `proceedToApp()` скидає тільки `redesign_home_focus` на `interior` перед створенням Home; `onboarding_goal` лишається початковим вибором. Коротке згортання чи системний вибір фото в першому сеансі не змінюють hero.

Після вибору «Стіни й підлога» карусель альтернатив містить Interior, Exterior, Garden і By reference. Для інших цілей показано три альтернативи, які не повторюють hero; четвертий storyboard-слот прихований без додаткового проміжку.

## Layout та анімації

Панелі, заголовки, hero, п’ять tool-карток, stepper і плитки цілей редагуються в `HomeAI/Storyboards/Onboarding.storyboard`. Для room/tools/words є окремі сцени. Ієрархії не створюються Swift-кодом; Swift керує станом, масками, жестами та значеннями IB-констрейнтів. `OnboardingLayout` рахує масштаб від **поточних bounds вікна**, бази 393 × 852, із верхньою межею 1.35 для планшетів. Тексти та CTA мають ширину колонки макета; на широкому вікні вона центрується. Safe area та мінімальні нижні відступи враховуються окремо. Контент O4 прокручується на низьких вікнах. Висоти багаторядкових лейблів панелі вимірюються явно після зміни font / ширини, щоб intrinsic height не обрізав останній рядок.

Констрейнти перед `scaleConstant(height:)` відновлюються до базових значень — повторний layout та зміна розміру не накопичують масштаб. Необов’язковий `height` доданий також до `CGFloat.scaledByHeight`; решта екранів зберігає попередню поведінку.

`OnboardingHeroView` використовує CADisplayLink із weak proxy, однакові bounds / aspectFill для обох зображень та reveal-маски. Анімації зупиняються поза видимою сторінкою й не проскакують уперед після background. Reduce Motion показує нерухомий стан. Жести каруселі та ручки мають пріоритет над pager pan. При resize під час переходу pager повертається на цілу сторінку.

## Завершення та персоналізація

Вибір зберігається в `Constants.Keys.onboardingGoal` (`onboarding_goal`) і `HomeFocus.defaultsKey` (`redesign_home_focus`). `HomeFocus.current` змінює перший hero та інструмент для Upload / візарда: interior, exterior, garden або surfaces → newWalls. Пропуск очищує вибір, повертаючи стандартний interior.

Аналітика: `onboarding_step` та `onboarding_goal` (`goal`: interior/exterior/garden/surfaces). ATT на першому запуску запитується після O4; ready-listener AppsFlyer очікує збереженої відповіді, не відкриваючи ATT самостійно, далі чинний Adapty → `completeOnboarding()` → TabBar → `ob-placement-com` для користувачів без підписки. Повторний запуск веде на Home без launch-paywall відповідно до splash dev notes.

Ключ показу **`did_show_onboarding_8` не змінено**. Старі Welcome / Exterior / Garden / Rate XIB та ассети залишені в репозиторії, але pager їх більше не використовує. Стара storyboard-сцена Launch перейменована `UnusedLaunchViewController`, без старого outlet.

Тексти локалізовані всіма 15 мовами застосунку.

## QA

Відтворення перевірок: [full-app QA](qa/full-app-qa.md). Включає системне перемикання всіх 15 мов, повтор цілей онбордингу та перевірки bounds і каруселі.

Окрема схема **HomeAIOnboardingQA**, таргет `HomeAIUITests`:

`OnboardingReturningLaunchTests` у HomeAIFullQA проходить production startup router через DEBUG `--qa-launch-flow`: завершує O4 для кожної цілі, перевіряє відповідний перший hero, завершує процес і повторно запускає застосунок без повторного OB та з Interior. `--qa-reset-onboarding` використовується тільки для першого тестового запуску. Pro-fixture відокремлює цей тест від SDK/ATT/upsell; completion gate, O4 і Home використовуються справжні.

- Continue через усі 4 кроки, screenshot після завершення scroll transition;
- відсутність Skip на всіх кроках і завершення вибором кожної з чотирьох цілей;
- український сценарій;
- анімована ручка, drag, свайп каруселі та повернення назад.

`HomeAITests/OnboardingLayoutTests` перевіряє читабельність, відсутність накладання CTA та повторне масштабування на 393×852, 375×667, 466×678, 669×951, 951×669, 768×1024 та 1024×768; також відповідність цілі й візарда та скасування Continue при resize Duo.

DEBUG-прапори для локального preview (без запуску SDK та мережевих сервісів):

```
--onboarding-preview
--onboarding-page 0          # 0…3
--onboarding-still           # нерухомі hero
--onboarding-splash          # залишитися на splash
```

Preview завершення ставить root identifier `onboarding.completed`; покупки й реальний paywall не відкриваються. Скриншоти та xcresult створюються лише під час відповідного QA-прогону; попередні артефакти прибрано.


Перевірено 2026-10-16: iPhone SE (18.6), iPhone 16 Pro (18.6), iPhone 17 Pro Max (26.4), iPhone Duo (27.1), iPad mini (18.6). Пройдено переходи, Skip, усі цілі, жести та українську локалізацію; фінальні resize/persistence/перерваний transition тести на Duo — 3/3.



Фінальний Duo-прогін: **6/6 UI, 0 failures** — п'ять preview-сценаріїв та один live SDK smoke test.


Опційний `LiveOnboardingSDKTests.testCompleteOnboardingWithLiveSDKs` перевіряє звичайний запуск та реальне завершення з ATT/AppsFlyer/Adapty, без покупок. За замовчуванням пропущений (потребує `REHOMELY_LIVE_SDK_QA=1` у середовищі test runner). Після явного дозволу користувача пройшов на Duo: 1/1, відсутність ATT на O1, запит після O4, відмова й вихід до чинного paywall (`duo-accepted.xcresult`). Системний алерт перевіряється через SpringBoard, із явним очікуванням закриття перед наступним сценарієм.

Нативний fold / перехід на другий дисплей Duo ще не підтверджено: simctl не надає команди шарніра, а перемикання живлення framebuffer спричинило збій SpringBoard. Після перезапуску перевірки застосунку продовжено на активному дисплеї; resize-перевірки покривають обидва розміри окремо.
