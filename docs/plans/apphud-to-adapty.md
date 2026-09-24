# Apphud → Adapty

Режим: **Full**

## Цілі

Прибрати Apphud SDK. Підписки, paywall, restore і user id — через Adapty. Свій `PaywallViewController` лишається (без AdaptyUI / Paywall Builder).

Ключ уже є: `Constants.Keys.apphud` = `public_live_IwMFkQu9.T9yq1wYc8VltAWFTXzdZ` (це Public SDK Key Adapty). Зараз він помилково йде в `Apphud.start` — SDK не той.

## Контекст

Старт: `AppDelegate` → `ApphudService.shared.start`.
Статус підписки: `ApphudService.shared.hasActiveSubscription` (~15 місць: NavigationManager, paywall-гейти, ліміти, ProBadge).
Продукти: `Apphud.fetchPlacements` → `PaywallProductsPresentation.make(from: [ApphudProduct])` через `SKProduct`.
User id: Crashlytics, Sentry, Amplitude `apphud_user_id`, Settings/support mail, Supabase `UserPhotos` folder.
Attribution: AppsFlyer UID + conversion, ASA token, Facebook anon id — усе через `Apphud.setAttribution`.

SPM: `https://github.com/apphud/ApphudSDK` 3.6.2 у `project.pbxproj` + `Package.resolved`.
Deployment target 15.6 — Adapty iOS вимагає 15.0+, ок.

## Етапи

- [x] SPM: додати `AdaptySDK-iOS` 4.1.3 (модуль **Adapty**, без AdaptyUI). Прибрати `ApphudSDK`.
- [x] `AdaptyService` замість `ApphudService`:
  - `start` → `Adapty.activate`
  - `hasActiveSubscription` → `accessLevels["premium"]?.isActive`
  - `userID` → `profile.profileId`
  - `fetchPaywallPresentation` → `getFlow` + `getPaywallProducts(flow:)`
  - `buyProduct` → `makePurchase`
  - `restore` → `restorePurchases`
  - `paywallShown` → `logShowFlow`
  - AppsFlyer: `setIntegrationIdentifier(.appsflyerId)` + `updateExternalAttribution`
  - Meta: `setIntegrationIdentifier(.facebookAnonymousId)`
  - ASA token → `updateExternalAttribution(..., .appleAds)` + Amplitude `FROM_ASA_ACTION`
- [x] Paywall-моделі на `AdaptyPaywallProduct`
- [x] Call sites `AdaptyService`
- [x] `Constants.Keys.adapty` + `adaptyAccessLevel`
- [x] Видалити Apphud-файли
- [x] Amplitude `adapty_profile_id`
- [x] `docs/project.md`, `docs/onboarding.md`
- [x] Збірка HomeAI

## Поза скоупом

AdaptyUI / Flow Builder, observer mode, новий paywall UI, нові placement id, customer user id / логін, AppsFlyer S2S токен у кабінеті Adapty (кабінет).

## Ризики

- Paywall порожній, якщо в Adapty немає тих самих placement ID + ≥2 продукти (weekly+yearly).
- Access level не `premium` — усі гейти вважатимуть юзера free.
- `Adapty.activate` має завершитись до `getPaywall` / `getProfile` (`#2002 notActivated`). Онбординг уже чекає `hasActiveSubscriptionWhenReady` (timeout 8 с) — той самий патерн.
- MMP: доки рекомендує UID AppsFlyer до `activate`. Зараз AppsFlyer стартує після Apphud. Залишаємо activate одразу + UID у conversion callback (як зараз), щоб не блокувати запуск.
- Старі папки Supabase (`UserPhotos/<apphudUserId>/`) не збігатимуться з новим profileId.
- Restore підхопить Apple-покупки, якщо продукти в Adapty = ті самі StoreKit product ids.

## Питання — відповіді

- Placement IDs: **ті самі**, що в коді.
- Access level: **`premium`** (дефолт Adapty; це внутрішній ключ «є підписка», не UI).
- Amplitude / імена: **все на Adapty** (`adapty_profile_id`, `AdaptyService`, `Constants.Keys.adapty`).

## Перевірка

- Збірка `xcodebuild -scheme HomeAI -sdk iphonesimulator`
- Старт: Adapty activate без `#2002`
- Онбординг Get Started → paywall `ob-placement-com`, 2 тарифи
- Покупка sandbox, restore
- Free-гейти (save/share/chat/limit) без підписки
- Premium юзер не бачить paywall на launch
- iPad не обов’язково

## Де оновити доки

`docs/project.md` (сервіс підписок), `docs/onboarding.md` (завершення OB).

# Лог

- [x] SPM Adapty 4.1.3, ApphudSDK прибрано
- [x] `AdaptyService` + paywall-моделі + call sites
- [x] Amplitude `adapty_profile_id`
- [x] Debug simulator build
- [ ] Живий paywall / покупка / restore не ганяли
- [ ] Access level `premium` у кабінеті не перевіряли
- [ ] iPad не ганяли

