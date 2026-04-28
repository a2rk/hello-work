# HelloWork — Audit Cycle Context: **Meditation Module**

> Этот файл — **единственный источник истины** для агента, который выполняет таски в текущем audit cycle. Перед каждой итерацией читать целиком, после — обновлять статусы.

---

## 1. Goal of current cycle — Meditation Module

**Задача**: добавить новый модуль **«Медитация»** — короткая (1 минута) фокус-практика для разработчиков. Поверх всех окон накладывается тёмный canvas (98% black), на нём появляется зелёная точка которая медленно, плавно и непредсказуемо движется по экрану. Задача юзера — следить глазами за точкой ровно 60 секунд, ни о чём не думая.

**Зачем это HelloWork**:
- Усиливает основной use-case — приложение помогает разработчикам управлять вниманием.
- В сочетании с focus-mode (overlay'ы поверх отвлекающих apps) и schedule-blocking, это даёт **активную** mental practice. Не «блокировать» а «тренировать».
- Privacy-first остаётся: никаких сетевых запросов, никаких данных наружу.

**User flow**:
1. Юзер кликает «Начать медитацию» (sidebar или хоткей `⌃⌥M`).
2. Экран мгновенно затемняется (~150ms fade-in).
3. В случайной точке на primary screen появляется зелёная точка.
4. Точка плавно движется к новой случайной цели каждые 2-5 секунд.
5. Маленький прогресс-индикатор внизу (опционально, off by default).
6. Через 60 секунд — fade-out canvas, точка исчезает, юзер возвращается в работу.
7. ESC в любой момент — instant close.

**Что должно быть «9.5/10»**:
- **Smooth animation**: 60 fps, без jank'а, точка движется как медитативная, не «летает».
- **Random + natural**: разные сессии — разные пути. Алгоритм generation: bezier через random control points + lerp между целями с easing.
- **Mental immersion**: 98% затемнение, ничего вокруг точки не отвлекает; нет UI поверх кроме самой точки.
- **Reversibility**: ESC всегда работает, instant close без артефактов.
- **Multi-monitor (MVP)**: точка — на primary screen; остальные экраны затемняются полностью без точки. (Multi-screen рисование точки — out of scope для MVP, может быть Phase G follow-up.)
- **Persistence**: count сессий + total medit-минут — в UserDefaults, schema-versioned.
- **i18n**: ru/en/zh для всех UI-строк.
- **No regressions**: focus, hider, schedule, legends, updates — никак не задеваются.

---

## 2. Architecture context

### Новые файлы

```
Sources/HelloWork/
├── Domain/
│   └── Meditation/                            ← НОВАЯ ПАПКА
│       ├── MeditationSession.swift            Codable: длительность, дата, completed
│       ├── MeditationStats.swift              Aggregated count/totalMinutes/lastDate
│       ├── MeditationHotkey.swift             Зеркало FocusHotkey/MenubarHotkey
│       └── MeditationDotAnimator.swift        Pure algorithm: target generation + lerp/easing
├── Meditation/                                ← НОВАЯ ПАПКА (UI/window layer)
│   ├── MeditationController.swift             @MainActor, ObservableObject; start/stop/timer
│   ├── MeditationWindow.swift                 NSWindow fullscreen, level above all
│   ├── MeditationCanvasView.swift             SwiftUI: dark layer + dot
│   └── MeditationDotView.swift                SwiftUI: glowing pulsing circle
├── Preferences/
│   └── Meditation/                            ← НОВАЯ ПАПКА
│       └── MeditationSettingsCard.swift       Settings card: hotkey + duration + start button
└── Domain/Translation*.swift                  +новые ключи (en/ru/zh)
```

### Изменения в existing files

```
Sources/HelloWork/App/
├── AppState.swift                             + meditation: MeditationController()
│                                              + meditationStats: MeditationStats
│                                              + meditationHotkey: MeditationHotkey
└── AppDelegate.swift                          + registerMeditationHotkey()
                                               + setupMeditation()

Sources/HelloWork/Preferences/
└── PrefSection.swift                          + case .meditation
└── PrefsView.swift                            + routing на MeditationSettingsCard
```

### Файлы которые НЕ трогаем

`Domain/Legends/`, `Focus/`, `Hider`, `Menubar`, `Updates`, `WindowDetection`, `StatusBar` — изолированы.

### Ключевые подсистемы и инварианты

| Подсистема | Инвариант |
|---|---|
| `MeditationController` | start() идемпотентный — повторный вызов когда сессия активна → no-op. stop() возвращает window к исходному state без артефактов. |
| `MeditationWindow` | level = `.statusBar + 1` (выше menubar). `ignoresMouseEvents = false` (чтобы ESC работал). При закрытии — orderOut + release. Один window на screen. |
| `MeditationDotAnimator` | Pure logic, no UI. На каждый tick (60Hz) выдаёт current dot position. Цели генерируются с min distance 200pt от предыдущей и margin 120pt от edges. |
| `MeditationStats` | Persisted через `VersionedMeditationStats` (как managedApps / legendsState). Поля: `sessionsCount`, `totalSeconds`, `lastSessionDate`. |
| Hotkey | По умолчанию `⌃⌥M`. Не пересекается с `⌃⇧B` (menubar) и `⌃⌥F` (focus). |
| Multi-monitor | Затемняем ВСЕ экраны (по window на screen). Точку рисуем только на primary. На вторичных — просто dark canvas. |

### Hotkey conflict map (для проверки в TASK-A05)

```
⌃⇧B   — menubar hider toggle
⌃⌥F   — focus mode toggle
⌃⌥M   — meditation start (новый — выбран потому что М = Meditation)
F18   — preset alternative для меditation
```

### Параметры (defaults — потом сделаем настраиваемыми)

```swift
duration: TimeInterval = 60.0          // 1 минута
overlayOpacity: Double = 0.98          // 98% затемнение
dotSize: CGFloat = 16                  // диаметр в pt
dotColor: Color = Theme.accent         // зелёный (наш существующий)
dotGlowRadius: CGFloat = 12            // soft glow вокруг
targetDwell: ClosedRange<TimeInterval> = 2.0...5.0  // время «дыхания» на каждой цели
edgeMargin: CGFloat = 120              // расстояние от точки до edge'а screen
minTargetDistance: CGFloat = 200       // мин расстояние между последовательными целями
fadeInDuration: TimeInterval = 0.5     // плавное появление overlay'а
fadeOutDuration: TimeInterval = 0.4    // и исчезновение
```

---

## 3. Global rules (стабильные между циклами)

1. **Bundle ID `dev.helloworkapp.macos.engine` не меняем.**
2. **Self-signed cert «HelloWork Self-Signed» не пересоздаём.**
3. **Минимум edge-case-handling** — только на границах (Decode, IO, NSWindow lifecycle).
4. **Никаких новых абстракций ради будущего**.
5. **Comments — только WHY**, не WHAT. Особенно для нетривиальных инвариантов окна и анимации.
6. **Без эмодзи в коде**.
7. **i18n**: каждая user-facing строка — en + ru + zh, в strict order Translation.swift.
8. **Schema versioning**: `MeditationStats` обернуть в `VersionedMeditationStats`.
9. **devlog**: точки `devlog("meditation", ...)` в start/stop/timer-tick/window-create/cleanup.
10. **Verify-таск НЕ правит код продакта**.

### Соседние модули — НЕ трогаем кроме явного scope

`Domain/Legends/`, `Focus/`, `Hider`, `Menubar`, `Schedule`, `Stats` (старый, не путать с MeditationStats), `Permissions`, `Updates/UpdateInstaller.swift`.

---

## 4. Release policy — **ЭТОТ ЦИКЛ ОСОБЫЙ** (single-release-at-end)

> ⚠️ **В этом цикле НЕТ per-task релизов.** Стандартный workflow «один таск = один patch + DMG + gh release» **отключён**.

**Причина**: цикл — наполнение нового feature module. Промежуточные релизы (Phase A с domain models без UI, Phase B с window без точки, etc.) — нерабочие/неполные с точки зрения юзера. Релизить их — спам в Releases без value.

### Что делаем в каждой итерации

1. Выбираем next таск по ledger (как обычно).
2. Меняем код.
3. **Только**: `swift build` чисто; локальный tест где это возможно (мелкие unit-проверки, превью SwiftUI views).
4. **НЕТ**: `bump.sh`, `package.sh` (DMG), `git tag`, `git push --tags`, `gh release create`.
5. Можно (опционально) делать обычный `git commit` для checkpoint'а — но **без tag'а** и **без push'а с тегом**.
6. Помечаем таск `[x]` в ledger, описываем что сделали + acceptance match.

### Финальный таск (TASK-M45) — ОДИН релиз

После того как Phase A-F закрыты и smoke-list (TASK-M43) прошёл:
- `./scripts/bump.sh minor` (0.12.8 → **0.13.0** — major feature)
- Полный pipeline: `build.sh && package.sh`
- Один большой `dev_log.json` entry с подытогом
- `git add -A && git commit`, `git tag v0.13.0`, `git push origin main && git push origin v0.13.0`
- `gh release create v0.13.0 dist/HelloWork-0.13.0.dmg dist/HelloWork.dmg --title "v0.13.0 🧘 Meditation module" --notes "..."`

**ОДНА финальная версия**, не серия. Если что-то не работает на финальном smoke — не релизим, фиксим, повторяем smoke. Релизим только после зелёного smoke.

---

## 5. Task Ledger

Формат: `[ ] = pending`, `[~] = in_progress`, `[x] = done`. Verify-таск нельзя пометить done пока impl-таск выше не done.

### Phase A — Domain models + state foundation (10 tasks)

> Чистая модель, никакого UI. Если что-то ломается на этом этапе — далеко не прошли.

- [ ] **TASK-M01 [impl]** — `Sources/HelloWork/Domain/Meditation/MeditationSession.swift`. Codable struct:
  ```swift
  struct MeditationSession: Codable, Identifiable {
      let id: UUID
      let startedAt: Date
      let plannedDuration: TimeInterval   // 60.0 default
      let completedDuration: TimeInterval // 0..60, set on stop
      let completedNaturally: Bool         // true если дошёл до конца, false если ESC/abort
  }
  ```
  - Файлы: `Sources/HelloWork/Domain/Meditation/MeditationSession.swift`
  - Acceptance: декодит/энкодит туда-обратно идентично; `id` всегда новый UUID при init; `completedNaturally = (completedDuration >= plannedDuration - 0.5)` логика прозрачна.

- [ ] **TASK-M02 [verify]** — TASK-M01

- [ ] **TASK-M03 [impl]** — `Sources/HelloWork/Domain/Meditation/MeditationStats.swift` — aggregated stats, schema-versioned (`VersionedMeditationStats` wrapper):
  ```swift
  struct MeditationStats: Codable {
      var sessionsCount: Int
      var totalSeconds: TimeInterval
      var lastSessionDate: Date?
      mutating func record(_ session: MeditationSession)  // только если completedNaturally
  }
  struct VersionedMeditationStats: Codable {
      let version: Int  // 1 на старте
      let stats: MeditationStats
  }
  ```
  - Файлы: `Sources/HelloWork/Domain/Meditation/MeditationStats.swift`
  - Acceptance: `record(_:)` идемпотентна для unique session.id (записываем один раз); aborted сессии (completedNaturally=false) НЕ инкрементят count, но добавляются в totalSeconds (разработчик медитировал хоть сколько-то).

- [ ] **TASK-M04 [verify]** — TASK-M03

- [ ] **TASK-M05 [impl]** — `Sources/HelloWork/Domain/Meditation/MeditationHotkey.swift` — зеркало `MenubarHotkey`. Преsets: `ctrlOptM` (default), `f17`, `hyperM`. + `custom(keyCode, modifiers)`. + serialize/deserialize/displayString.
  - Файлы: `Sources/HelloWork/Domain/Meditation/MeditationHotkey.swift`
  - Acceptance: build clean; serialize → deserialize round-trip; displayString корректный для preset и custom.

- [ ] **TASK-M06 [verify]** — TASK-M05

- [ ] **TASK-M07 [impl]** — `Sources/HelloWork/Domain/Meditation/MeditationDotAnimator.swift` — pure animation logic, без UI:
  ```swift
  struct MeditationDotAnimator {
      let bounds: CGRect           // primary screen frame
      let edgeMargin: CGFloat = 120
      let minTargetDistance: CGFloat = 200
      let dwellRange: ClosedRange<TimeInterval> = 2.0...5.0

      private var currentTarget: CGPoint
      private var nextTarget: CGPoint
      private var transitionStart: Date
      private var transitionDuration: TimeInterval

      mutating func tick(at date: Date) -> CGPoint  // возвращает current position
      private mutating func generateNextTarget()    // random с constraints
  }
  ```
  - Реализация: lerp от `currentTarget` к `nextTarget` с easing `easeInOut` (обычная cubic). По завершении transition — generateNextTarget + новый transitionStart.
  - Acceptance: на 60Hz tick'е выдаёт smooth path; на конкретном seed — deterministic; цели всегда внутри `bounds.insetBy(edgeMargin)`; min distance соблюдается.

- [ ] **TASK-M08 [verify]** — TASK-M07

- [ ] **TASK-M09 [impl]** — `AppState`-интеграция:
  - Добавить `meditation: MeditationController` (init в lazy / в init AppState).
  - `meditationStats: MeditationStats` + persistence через `Self.meditationStatsKey`.
  - `meditationHotkey: MeditationHotkey` + UserDefaults persistence (key `helloWorkMeditationHotkey`).
  - `func recordMeditation(_ session: MeditationSession)` — обновляет stats + persist.
  - Файлы: `Sources/HelloWork/App/AppState.swift`
  - Acceptance: build clean; perist works (set, restart, read); MeditationController — placeholder `final class` пока (наполнение в B01).

- [ ] **TASK-M10 [verify]** — TASK-M09

### Phase B — Overlay window (8 tasks)

> Затемнение экрана. Тестим без точки сначала — даём команду «show overlay 60s», проверяем fade-in/out, ESC.

- [ ] **TASK-M11 [impl]** — `Sources/HelloWork/Meditation/MeditationWindow.swift` — кастомный NSWindow:
  - `init(screen: NSScreen)` — fullscreen на конкретный screen.
  - `level = .statusBar + 1` — выше menubar.
  - `backgroundColor = .clear`, `isOpaque = false` — позволяет custom view'у управлять прозрачностью.
  - `ignoresMouseEvents = false` — чтобы ESC keypress работал.
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` — на каждом desktop, не трогает fullscreen apps.
  - `acceptsMouseMovedEvents = false`.
  - Override `canBecomeKey = true` — нужно для key events.
  - Файлы: `Sources/HelloWork/Meditation/MeditationWindow.swift`
  - Acceptance: window появляется на правильном screen, имеет правильный level, не ломает другие апп-окна.

- [ ] **TASK-M12 [verify]** — TASK-M11

- [ ] **TASK-M13 [impl]** — `Sources/HelloWork/Meditation/MeditationCanvasView.swift` — SwiftUI view:
  - Корневой ZStack со `.background(Color.black.opacity(0.98))` — затемнение.
  - `.onKeyPress(.escape) { onAbort() }` — ESC обрабатывает.
  - Точку пока **не рисуем** (для C01) — только canvas.
  - Параметр `onAbort: () -> Void` callback.
  - Файлы: `Sources/HelloWork/Meditation/MeditationCanvasView.swift`
  - Acceptance: при показе — экран затемняется на 98%; ESC вызывает callback.

- [ ] **TASK-M14 [verify]** — TASK-M13

- [ ] **TASK-M15 [impl]** — `Sources/HelloWork/Meditation/MeditationController.swift` — главный controller:
  ```swift
  @MainActor
  final class MeditationController: ObservableObject {
      @Published private(set) var isActive: Bool = false
      @Published private(set) var session: MeditationSession?
      @Published private(set) var elapsed: TimeInterval = 0
      private var windows: [MeditationWindow] = []
      private var timer: Timer?

      func start() { ... }   // Создаёт windows на ВСЕХ screens, fade-in, запускает timer
      func stop(naturally: Bool) { ... }  // Closes windows, persist session, fade-out
  }
  ```
  - При `start()`: проверка `!isActive`, создаёт `MeditationSession`, по window на каждый `NSScreen.screens`, hosting `MeditationCanvasView`, `orderFrontRegardless()`, `makeKey()` для primary, fade-in animation.
  - Timer (`.scheduledTimer` 1/60 sec) обновляет `elapsed`. При `elapsed >= duration` → `stop(naturally: true)`.
  - При `stop(naturally:)`: timer invalidate, fade-out (animator block), потом `orderOut` + clear windows array. `state.recordMeditation(session)`.
  - Hooking: ABC выше указали что AppState владеет controller'ом (TASK-M09).
  - Файлы: `Sources/HelloWork/Meditation/MeditationController.swift`, `Sources/HelloWork/App/AppState.swift` (взаимная связка)
  - Acceptance: ручной тест в AppDelegate — `state.meditation.start()` затемняет ВСЕ screens; через 60 сек — fade-out; ESC → callback → `stop(naturally: false)`; повторный start во время активной — игнорируется; persist в UserDefaults виден.

- [ ] **TASK-M16 [verify]** — TASK-M15

- [ ] **TASK-M17 [impl]** — Multi-screen handling: на каждый screen в `NSScreen.screens` создаётся window. На primary — будет точка (Phase C); на вторичных — только dark canvas.
  - Подключить уведомление `NSApplication.didChangeScreenParametersNotification` — если во время сессии screen connect/disconnect, плавно close + recreate. (Edge case, можно отложить в Phase G follow-up.)
  - Файлы: `Sources/HelloWork/Meditation/MeditationController.swift`
  - Acceptance: на 2 screen'ах — оба затемнены при start.

- [ ] **TASK-M18 [verify]** — TASK-M17

### Phase C — Dot animation (8 tasks)

> Зелёная точка. Generation + lerp + glow + pulse.

- [ ] **TASK-M19 [impl]** — `Sources/HelloWork/Meditation/MeditationDotView.swift` — SwiftUI view:
  - `Circle().fill(Theme.accent)` диаметра 16pt.
  - `.shadow(color: Theme.accent.opacity(0.55), radius: 12, x: 0, y: 0)` — soft glow.
  - Pulse: `@State scale: CGFloat` от 0.92 до 1.08, `.animation(.easeInOut(duration: 2).repeatForever)`.
  - Position controlled извне (param: `position: CGPoint`).
  - Файлы: `Sources/HelloWork/Meditation/MeditationDotView.swift`
  - Acceptance: standalone preview — точка пульсирует в фиксированной позиции с glow.

- [ ] **TASK-M20 [verify]** — TASK-M19

- [ ] **TASK-M21 [impl]** — Интеграция animator + dot view в canvas:
  - `MeditationCanvasView` принимает `dotPosition: CGPoint` (Binding или @ObservedObject) и рендерит `MeditationDotView` поверх dark layer (только на primary screen).
  - Параметр `showDot: Bool` — на secondary screen'ах = false.
  - `MeditationController` создаёт `MeditationDotAnimator(bounds: NSScreen.main!.frame)` и через timer обновляет `dotPosition`.
  - Файлы: `Sources/HelloWork/Meditation/MeditationCanvasView.swift`, `MeditationController.swift`
  - Acceptance: точка движется по экрану в течение сессии.

- [ ] **TASK-M22 [verify]** — TASK-M21

- [ ] **TASK-M23 [impl]** — Easing-улучшение: проверить что движение визуально «медитативное», не «дёрганое». Вероятно switch с `easeInOut` на `easeInOutQuart` или spring (через DampedHarmonic). Возможно tweak `dwellRange` (2-5 sec → 3-7 sec) если кажется быстрым.
  - Файлы: `Sources/HelloWork/Domain/Meditation/MeditationDotAnimator.swift`
  - Acceptance: визуальная проверка — движение плавное, без рывков, точка не «прилипает» к edges.

- [ ] **TASK-M24 [verify]** — TASK-M23

- [ ] **TASK-M25 [impl]** — Fade-in entrance dot'а: при появлении — opacity от 0 до 1 за 0.6с, scale от 0.5 до 1.0 spring. Чтобы юзер визуально подготовился.
  - Файлы: `Sources/HelloWork/Meditation/MeditationDotView.swift`
  - Acceptance: при start — точка плавно появляется; при stop — плавно растворяется (opacity → 0 за 0.4с).

- [ ] **TASK-M26 [verify]** — TASK-M25

### Phase D — Timer + UX polish (6 tasks)

- [ ] **TASK-M27 [impl]** — Минималистичный progress indicator: тонкая прогресс-линия по нижнему edge экрана (height 2pt, цвет `Theme.accent.opacity(0.4)`). Заполняется слева направо за 60 секунд. Off by default — настраивается опцией `showProgressLine: Bool` в Settings. По умолчанию `true` (помогает не считать в уме).
  - Файлы: `Sources/HelloWork/Meditation/MeditationCanvasView.swift`, `AppState` + `helloWorkMeditationShowProgress` UserDefaults key.
  - Acceptance: прогресс заполняется корректно; toggle off — линия не видна.

- [ ] **TASK-M28 [verify]** — TASK-M27

- [ ] **TASK-M29 [impl]** — Completion feedback: за 0.3с до конца — лёгкий «вспышка» dot'а (scale 1.4 → 1.0 + opacity 1 → 0). После fade-out — короткое system sound (NSSound `Glass` или `Tink`). Опционально (toggle).
  - Файлы: `Sources/HelloWork/Meditation/MeditationController.swift`, `AppState` + `helloWorkMeditationCompletionSound` key.
  - Acceptance: при natural completion — звук + flash; при ESC abort — НИЧЕГО (silent close).

- [ ] **TASK-M30 [verify]** — TASK-M29

- [ ] **TASK-M31 [impl]** — Hotkey wiring: `AppDelegate.registerMeditationHotkey()` — регистрирует `state.meditationHotkey` через тот же `HotkeyManager` что использует focus и menubar. Вызывает `state.meditation.start()`.
  - Файлы: `Sources/HelloWork/App/AppDelegate.swift`
  - Acceptance: установить хоткей `⌃⌥M` → нажатие → start; нажатие во время активной сессии → no-op (уже active).

- [ ] **TASK-M32 [verify]** — TASK-M31

### Phase E — UI entry points (6 tasks)

- [ ] **TASK-M33 [impl]** — `PrefSection.meditation` + перевод в Translation:
  - `Translation.swift`: `let sectionMeditation: String`
  - EN: «Meditation» / RU: «Медитация» / ZH: «冥想»
  - В `PrefSection.swift` добавить `case .meditation` + symbol image (`leaf` или `circle.dotted` или `eye`).
  - Файлы: `Sources/HelloWork/Domain/Translation.swift`, `Translations.swift`, `Preferences/PrefSection.swift`.
  - Acceptance: новый sidebar item появляется в Preferences.

- [ ] **TASK-M34 [verify]** — TASK-M33

- [ ] **TASK-M35 [impl]** — `Sources/HelloWork/Preferences/Meditation/MeditationSettingsCard.swift`:
  - Заголовок «Meditation» + subtitle (стандартный pattern других settings).
  - Hero stat: «You've meditated **N times** for **M minutes** total».
  - Кнопка «Start session» (большая accent-pill) → state.meditation.start().
  - Hotkey row: текущий + edit-кнопка (через `HotkeyRecorderView` который у нас есть для focus/menubar).
  - Toggle row: «Show progress line» (state.meditationShowProgress).
  - Toggle row: «Completion sound» (state.meditationCompletionSound).
  - Файлы: `Sources/HelloWork/Preferences/Meditation/MeditationSettingsCard.swift`
  - Acceptance: card выглядит как остальные Settings, кнопка стартует сессию, stats обновляются после успешной сессии.

- [ ] **TASK-M36 [verify]** — TASK-M35

- [ ] **TASK-M37 [impl]** — Routing в `PrefsView.content`:
  - `case .section(.meditation): MeditationSettingsCard(state: state)`.
  - Файлы: `Sources/HelloWork/Preferences/PrefsView.swift`
  - Acceptance: клик по sidebar item → показывается card.

- [ ] **TASK-M38 [verify]** — TASK-M37

### Phase F — i18n + final polish (4 tasks)

- [ ] **TASK-M39 [impl]** — Добавить все translation keys для модуля. Минимум:
  - `meditationStartButton` (EN: "Start session" / RU: "Начать сессию" / ZH: "开始")
  - `meditationStatsTitle(_ count: Int, _ minutes: Int) -> String` (EN: "You've meditated \(count) times for \(minutes) minutes total" / RU/ZH)
  - `meditationHotkeyLabel`, `meditationShowProgressTitle`, `meditationShowProgressDesc`, `meditationCompletionSoundTitle`, `meditationCompletionSoundDesc`
  - `meditationDuration60s` (просто "1 minute" / "1 минута" / "1分钟")
  - `meditationActiveBadge` ("Meditating..." / "Медитация..." / "冥想中...")
  - Файлы: `Translation.swift`, `Translations.swift` (3 локали в strict order).
  - Acceptance: build clean; нет hard-coded strings в UI; все 3 локали populated.

- [ ] **TASK-M40 [verify]** — TASK-M39

- [ ] **TASK-M41 [impl]** — Edge cases:
  - Если screens.isEmpty (нереально, но) → start no-op + devlog warning.
  - Если приложение уходит в background во время сессии → continue normally (medit overlay outermost level).
  - Если юзер триггерит focus mode во время медитации → focus игнорируется (одна practice за раз).
  - Hotkey conflict: при попытке поставить ⌃⇧B (menubar) или ⌃⌥F (focus) на meditation — UI alert «Hotkey already used».
  - Файлы: `Sources/HelloWork/Meditation/MeditationController.swift`, `Sources/HelloWork/App/AppDelegate.swift`
  - Acceptance: вышеперечисленные сценарии обработаны корректно, devlog показывает решения.

- [ ] **TASK-M42 [verify]** — TASK-M41

### Phase G — Final regression + 0.13.0 release (4 tasks)

- [ ] **TASK-M43 [impl]** — Manual smoke list:
  1. Свежий launch → sidebar показывает Meditation.
  2. Settings card → click «Start session» → экран затемняется на всех screens.
  3. Зелёная точка появляется на primary, движется плавно.
  4. Прогресс-линия снизу заполняется в течение 60 сек.
  5. Через 60 сек — fade-out, звук, возврат в работу.
  6. Stats обновились: count +1, totalSeconds +60.
  7. Снова Start → ESC через 10 сек → silent close, count НЕ обновился, totalSeconds +10.
  8. Поставить хоткей ⌃⌥M → запуск через хоткей работает.
  9. Restart app → stats persist, hotkey persist.
  10. Все 3 локали (en/ru/zh) — переключение, тексты переведены.
  - Acceptance: все 10 пунктов smoke прошли. Если что-то не ОК — follow-up (`## 7`).

- [ ] **TASK-M44 [verify]** — TASK-M43

- [ ] **TASK-M45 [impl]** — **ЕДИНСТВЕННЫЙ РЕЛИЗ ЦИКЛА**. Запускается **только** после того как TASK-M43 smoke прошёл зелёным. Полный pipeline:
  - `./scripts/bump.sh minor` → 0.12.8 → **0.13.0** (major feature)
  - `./scripts/build.sh && ./scripts/package.sh` → два DMG (versioned + static)
  - Большой `dev_log.json` entry с подытогом всех Phase A-F:
    ```json
    {
        "version": "0.13.0",
        "date": "<current-date>",
        "customMessage": "🧘 Meditation module shipped. 1-минутные фокус-сессии: 98% затемнение + зелёная точка движется плавно по экрану, юзер следит глазами. Снимает mental fatigue после блока кода.",
        "main": "Phases A-F (44 tasks): domain models, overlay window multi-screen, dot animator с lerp+easing+glow+pulse, timer+progress+sound, hotkey ⌃⌥M, Settings card со stats. Stats schema-versioned, persist'ятся между запусками.",
        "points": [
            "Meditation module — 1-минутные сессии",
            "98% затемнение + анимированная точка на primary screen",
            "Multi-screen: secondary screens darkened без точки",
            "Hotkey ⌃⌥M, ESC abort, completion sound",
            "Stats persisted (count + totalSeconds + lastDate)",
            "i18n EN/RU/ZH"
        ]
    }
    ```
  - `git add -A && git commit -m "v0.13.0 🧘 Meditation module"`
  - `git tag v0.13.0 && git push origin main && git push origin v0.13.0`
  - `gh release create v0.13.0 dist/HelloWork-0.13.0.dmg dist/HelloWork.dmg --title "v0.13.0 🧘 Meditation module" --notes "..."`
  - Acceptance: GitHub Release v0.13.0 создан с двумя DMG; юзер может скачать и установить; smoke-list TASK-M43 прошёл.

- [ ] **TASK-M46 [verify]** — TASK-M45 → проверка что релиз действительно опубликован, DMG mount'ится, версия в Info.plist соответствует. **AUDIT CYCLE COMPLETE.**

---

## 6. Метрики «9.5 / 10»

После закрытия Phase G:

- ✅ Sidebar item «Meditation» виден в Preferences.
- ✅ Settings card со stats + Start button + hotkey + 2 toggles.
- ✅ Кнопка / хоткей запускает сессию: затемнение всех screens, точка на primary.
- ✅ Точка движется плавно (60 fps), путь random но natural.
- ✅ Прогресс-линия заполняется ровно за 60 секунд.
- ✅ Natural completion: вспышка + звук + fade-out.
- ✅ ESC abort: silent close, stats обновлены частично.
- ✅ Stats persisted между запусками (schema-versioned).
- ✅ Hotkey conflict-aware (⌃⇧B и ⌃⌥F занять нельзя).
- ✅ Multi-screen: все экраны затемнены.
- ✅ i18n: ru/en/zh для всех UI-строк.
- ✅ Нет регрессий в legends, focus, hider, schedule, updates.
- ✅ devlog `meditation` категория для каждого нетривиального события.

---

## 7. Follow-up tasks

> Verify-таски ДОПИСЫВАЮТ сюда новые задачи если обнаружат регрессию или non-trivial gap.

(пусто на старте цикла)

---

## 8. Notes & не-задачи (out of scope)

- **Точка на нескольких screens одновременно** — может быть Phase H follow-up. Сейчас достаточно primary.
- **Кастомизация цвета точки** — out of scope.
- **Кастомная длительность** (30s / 90s / 5min) — out of scope для MVP. Хардкод 60s.
- **Гайдед-режим (instructions / голос / музыка)** — explicitly out of scope. Продукт минималистичный.
- **Биометрия (eye tracking) / aware mode** — нет.
- **Sound при tick'ах** — нет (только completion).
- **Saved sessions log с историей** — может быть Phase I после релиза.
