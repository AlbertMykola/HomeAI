# Розмітка поточного інтерфейсу

Ієрархії екранів, Auto Layout, outlets/actions і прототипи клітинок зберігаються у storyboard. Відкривайте `.storyboard` у Xcode через Interface Builder. Фабрика `AppStoryboard` вибирає сцену за типом контролера; вона не створює ієрархію екрана кодом.

| Storyboard | Вміст |
|---|---|
| `Onboarding` | Launch, pager, Room, Tools, Words, вибір цілі |
| `Root` | Системний tab controller та overlay із прозорою плаваючою панеллю |
| `Home` | Головний екран і прототип останнього проєкту |
| `Inspiration` | Стрічка, картка, деталі ідеї |
| `Projects` | Проєкти, збережені ідеї, деталі проєкту |
| `Profile` | Free/Pro, рядки налаштувань, вибір мови |
| `Wizard` | Фото, tips, кімната, стилі, custom style, preview, фінальний крок |
| `Tools` | Екстер’єр, сад, підлога, стіни, меблі, перестановка, референс, план |
| `Editors` | Paint/Replace/Remove та площини canvas |
| `Generation` | Генерація і дозвіл сповіщень |
| `Result` | Результат, Ask, Compare, Share, зміна стилю, feedback |
| `Assistant` | Чат, повідомлення, історія, вкладення, вибір проєкту |
| `Paywall` | Pro, feature sheet, welcome, fallback paywall |
| `States` | Empty/error/success стани й alert |
| `Components` | Toast, hotspot, selection, sheet backdrop |

У Swift залишаються дані, локалізація, маршрутизація, жести, анімації та оновлення наявних constraints під розмір вікна чи клавіатуру. Тимчасові snapshots у переходах створюються лише на час анімації. Pager керує frames вкладених сцен; їхній контент редагується в Interface Builder.

Повторювані клітинки оголошені як storyboard prototypes. Панелі WizardNav, таббар і hero онбордингу також мають редаговану ієрархію у відповідних сценах. Старий `tools/xibgen` не використовується для поточного UI.

Статична перевірка сцен і зв’язків:

```sh
python3 tools/qa/audit_storyboards.py
```
