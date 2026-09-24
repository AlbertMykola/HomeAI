# Onboarding — Lite plan

Режим: **Lite** (ресерч → план → правки → лог → базова перевірка).  
Не чіпаємо: DesignOB, старі карусельні ассети, масове прибирання storyboard — це не блокує новий стек.

## Цілі

1. Добити візуальну розбіжність 1-го екрана з 2–4.
2. Підготувати повторний показ онбордингу для тесту / існуючих юзерів.
3. Прогнати 4 екрани на симуляторі.

## Поточний стек (вже в коді)

1. Interior — `WelcomeOBViewController` (XIB)
2. Exterior — `OBExteriorViewController` (XIB)
3. Garden — `GardenOBViewController` (XIB)
4. Change — `RateOBViewController` (XIB + `iphone ob 4.json`)

Контейнер: `OBPageViewController` (XIB-и, без верхнього page control).  
Завершення: Adapty → `didShowOnboarding` → TabBar → paywall `ob-placement-com`.

## Діри

| Що | Ризик | Рішення цього проходу |
|---|---|---|
| Welcome overlay height `multiplier 0.320366` | На iPad оверлей вищий за 280 | Константа **280**, як на інших екранах |
| Welcome `fadeLocation = 0.31756` | Інший fade, ніж Figma 51.756% | **0.51756** |
| Welcome page control клікабельний | Тап по точках змінює індикатор, не сторінку | `userInteractionEnabled = NO` |
| `did_show_onboarding_7` уже стоїть у частини юзерів | Новий OB не побачать | Бамп ключа на `_8` |
| Debug-запуск завжди йде в TabBar | Важко тестувати OB | `Debug.alwaysShowOnboarding` лише в DEBUG |
| Storyboard сцени Rate / Exterior зі старими outlet | Крах, якщо хтось інстанціює за ID | Перейменувати identifier на `Unused*` |
| DesignOB + старі ассети | Мертвий код | Поза скоупом |

## Етапи

1. Вирівняти Welcome overlay / fade / page control.
2. Бамп ключа + DEBUG-флаг показу OB.
3. Відв’язати старі storyboard ID.
4. Збірка + запуск симулятора, 4 скріни.

## Перевірка руками

- [x] 4 екрани, нижній page control 1/4 … 4/4, зверху немає другого (iPhone 17 Pro Max, uk)
- [x] Continue слайдить наступний екран (1→2→3→4 пройдені тапом)
- [x] Overlay візуально однаковий на всіх 4; 4-й грає Lottie, CTA «Розпочати»
- [ ] iPad — не прогнано в цьому проході
- [ ] Get Started → TabBar / paywall — не натискали останню кнопку (Adapty)

## Лог імплементації

- Welcome overlay: height 280, fade 0.51756, page control non-interactive
- Ключ `did_show_onboarding_8` — існуючі юзери побачать новий OB один раз
- `Debug.alwaysShowOnboarding` = true лише в DEBUG
- Storyboard ID старих Rate/Exterior: `Unused*` + `UIViewController`


## Ризики / не беремо

- Не видаляємо DesignOB і старі JPG — окремий cleanup.
- Не переписуємо спільний reveal у базовий клас.
- `alwaysShowOnboarding` має лишатись **false** у Release.
