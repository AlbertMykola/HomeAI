# Sentry crashes HOMEAI-1 / HOMEAI-2

Режим: **Lite**

## Цілі

Закрити два production-креші `1.1.11+2` у проєкті Sentry `homeai`, щоб той самий сценарій більше не валив апп.

## Контекст

- [HOMEAI-1](https://albertapps.sentry.io/issues/HOMEAI-1): `Duplicate states in queue` у `UIPageViewController.setViewControllers(animated: true)`. Interior `PageViewController` після Add Photo / action sheet. 1 юзер.
- [HOMEAI-2](https://albertapps.sentry.io/issues/HOMEAI-2): `EXC_BAD_ACCESS` у `didFinishLaunching` / `dispatch_once`. iPad Air 2, iOS 15.8.8, 35 МБ вільної RAM, crash loop. Стеки без dSYM.
- Онбординг (`OBPageViewController`) — не UIPageViewController, не чіпати.
- Той самий пейджер-патерн: `ReplaceObjectPageViewController`.

## Етапи

- [x] `UIPageViewController` helper: один анімований set за раз, completion замість sleep, не set під свайпом / модалкою
- [x] `PageViewController` + `ReplaceObjectPageViewController`: auto-advance ретраїть, data source німий під час transition
- [x] Add Photo: `completion` після dismiss пікера, не під час анімації
- [x] Launch: Sentry першим; Firebase / AppsFlyer / Amplitude після `didFinishLaunching` (не в scene multiplexer)
- [x] Збірка HomeAI

## Ризики

- HOMEAI-2 без символів: фікс зменшує пік пам’яті/гонку на старті, але не 100% якщо null у Facebook/Adapty. EXC_BAD_ACCESS не ловиться try/catch.
- Відкладений AppsFlyer на один runloop — все ще cold start, conversion не має зникнути.

## Питання

Немає — обидва креші з продакшену, скоуп фіксу очевидний.

## Перевірити

- Interior: фото → auto-advance на кімнату, без креша; Next під час свайпа не двоїть.
- Replace/Delete: те саме з Add Photo → object selection.
- Пікер: обрати фото, дочекатись dismiss, лише тоді зсув сторінки.
- Launch на симуляторі: Sentry/Firebase/Adapty/AppsFlyer стартануть.

# Лог
- [x] HOMEAI-1: `setPageSafely` + defer auto-advance while modal/swipe; picker completion after dismiss
- [x] HOMEAI-2: Sentry/Facebook/Adapty sync; Firebase/AppsFlyer/Amplitude на наступному runloop; Crashlytics user id лише після `FirebaseApp.app()`
- [x] `xcodebuild` Debug simulator **BUILD SUCCEEDED**
- [ ] Interior/Replace флоу з камерою на девайсі не ганяли
- [ ] iPad Air 2 / iOS 15 launch не перевіряли
- [ ] dSYM 1.1.11+2 у Sentry досі немає — HOMEAI-2 без 100% підтвердження SDK
