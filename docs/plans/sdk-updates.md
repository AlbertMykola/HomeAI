# SDK updates

Режим: **Lite**

## Цілі

Підняти всі сторонні SDK до актуальних стабільних релізів у межах поточного major (крім OpenAI 0.4 → 0.5 і Amplitude `main` → тег).

## Контекст

SPM у `HomeAI.xcodeproj` + вендорний Sentry `Vendor/SentryCocoa`.
`generative-ai-swift` уже на останньому `0.5.6` (репо archived). Adapty `4.1.3` і AppsFlyer `7.0.2` уже latest.

## Етапи

- [x] Бамп `minimumVersion` у `project.pbxproj`; Amplitude з `branch=main` на `1.19.0`
- [x] Sentry Cocoa `9.27.0` → `9.29.0` (офіційний zip URL + checksum у `Package.swift`; 9.29 уже SPM-valid)
- [x] `xcodebuild -resolvePackageDependencies` → новий `Package.resolved`
- [x] Збірка `HomeAI` (simulator)

## Поза скоупом

Міграція `GoogleGenerativeAI` → Firebase AI Logic, прибрати невикористаний MacPaw OpenAI package, зміна grouping Sentry issues.

## Ризики

- OpenAI 0.5.x має breaking OpenAPI regen; у аппі `import OpenAI` немає, але пакет лінкується.
- Sentry 9.29.0 один раз перегрупує native crashes (`mechanism.synthetic`).
- Firebase 12.19.x: `FirebaseAI` → `FirebaseAILogic` у 13.0; зараз не імпортуємо.

## Перевірити

- Resolve packages без конфліктів.
- `xcodebuild` Debug simulator.

# Лог

- [x] SPM pins: Firebase 12.19.2, Kingfisher 8.12.0, Facebook 18.1.1, Supabase 2.55.2, OpenAI 0.5.1, Lottie 4.6.1, Amplitude 1.19.0 (з `main`)
- [x] Sentry 9.29.0 через official binary URL у `Vendor/SentryCocoa/Package.swift`
- [x] Debug simulator `BUILD SUCCEEDED` (iPhone 16 / iOS 18.6)
- [ ] Device / TestFlight не ганяли
- [ ] Native crash grouping у Sentry після 9.29 не перевіряли
