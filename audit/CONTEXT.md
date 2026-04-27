# HelloWork — Audit Context & Task Ledger

> Этот файл — **единственный источник истины** для агента, который выполняет аудит-таски. Перед каждой итерацией читать его целиком. После каждой итерации обновлять статусы.
>
> **Цель**: довести систему до 9.5/10 через 60 точечных тасков. Версионирование — **одна патч-версия на таск**. Старт 0.9.21 → финиш минимум 0.9.81. Каждый шаг релизится в `gh release` отдельно — чтобы юзер видел движение и мог откатиться к любому промежуточному состоянию.

---

## 1. Что мы строим

**HelloWork** — macOS accessory-приложение (без видимого окна, живёт в menubar) для дисциплинированной работы:

1. **Schedule-based blocking** — юзер описывает «когда какому приложению можно работать», вне расписания накладывается blur-overlay, ввод заблокирован. Идея: отвлекающее приложение остаётся открытым, но недоступно вне окон.
2. **Focus mode** — глобальный hotkey, по которому всё кроме frontmost-окна затемняется (dim opacity), концентрация на одной задаче.
3. **Menubar hider** (Ice-style) — физически уносит чужие menubar items за левый край экрана через CGEvent simulation (⌘+drag), оставляя видимым только Apple Control Center cluster и наш H. По хоткею или из меню.
4. **Stats** — учёт grace-минут, focus-сессий, attempts (попыток открыть заблокированное app), ежедневные/часовые срезы.
5. **Updates** — devLog (`dev_log.json` в репо) — лента версий с описанием. App качает её, показывает «доступна новая версия», предлагает install.
6. **Permissions** — Accessibility и Screen Recording. Без них hider не двигает items, focus-mode не находит окна.

### Аудитория и принципы

- Целевая аудитория — разработчики/студенты/писатели, которые хотят жесточайшую самодисциплину без полного «бана» приложения (overlay вместо kill).
- **Privacy-first**: ничего не отправляется в сеть кроме fetch'а dev_log. Никакого telemetry, аналитики, аккаунтов.
- **Local-first**: вся state в UserDefaults + JSON в Application Support. Работает офлайн.
- **macOS-native UX**: SwiftUI + AppKit, тёмная тема, monospaced где уместно, никакой web-кросс-платформы.

### Что должно быть «9.5/10»

- **Корректность**: каждый toggle / hotkey / menu-action делает ровно то, что обещает в UI. Никаких «иконка переключилась а реально ничего не произошло».
- **Производительность**: не больше 1 CGS-запроса там где достаточно одного. Не больше 1 disk-write на одно действие юзера. Не подвешивать main thread на drag/click. SwiftUI не перерисовывает schedule-чарт от изменения слайдера громкости в другом месте.
- **Resilience**: повреждённый JSON managedApps / stats не должен молча терять все данные юзера.
- **Permissions UX**: раз юзер дал AX + SR, оно живёт через все апдейты (self-signed cert уже сделан), и онбординг не лезет в лицо каждый запуск.
- **Dead code = 0**. Каждая строка должна оправдывать своё существование.
- **i18n полная**: en / ru / zh — никаких пропусков ключей в одной локали.

---

## 2. Архитектура

```
HelloWork/
├── Sources/
│   ├── HelloWork/                  # engine (~/Library/Application Support/HelloWork/HelloWork.app)
│   │   ├── App/                     AppDelegate, AppState, HelloWork.swift, Version
│   │   ├── Bridging/                Private CGS APIs, CGEvent extensions
│   │   ├── Diagnostics/             DevLogger (file-backed, gated by developerMode)
│   │   ├── Domain/                  Models: ManagedApp, Slot, Translation, Stats/*
│   │   ├── Focus/                   FocusModeController, hotkey, window finder
│   │   ├── Menubar/                 MenubarHiderController, MenuBarItem, Mover
│   │   ├── Overlay/                 Blur/halftone overlay views
│   │   ├── Permissions/             PermissionsManager + onboarding view
│   │   ├── Preferences/             SwiftUI PrefsView + tabs (Schedule/Focus/Tray/App/Data/Diagnostics)
│   │   ├── StatusBar/               MenuBarIcon, StatusMenuRows
│   │   ├── Theme/                   Colors, Layout, EnvironmentTranslation
│   │   ├── Updates/                 UpdateInstaller, DevLogConfig
│   │   └── WindowDetection/         AppWindowFinder
│   └── HelloWorkStub/               # /Applications/HWInstaller.app (одноразовый installer)
├── scripts/                         build.sh, build_stub.sh, package.sh, setup_signing.sh, generate_icon.swift
├── audit/                           ← ЭТА ПАПКА
├── dev_log.json                     лента версий
└── VERSION / BUILD                  текущие version+build
```

### Ключевые подсистемы и их инварианты

| Подсистема | Файлы | Инвариант |
|---|---|---|
| `AppState` | `App/AppState.swift` | Все @Published persisted в UserDefaults через didSet, читаются на init. Single source of truth для UI. |
| `MenubarHiderController` | `Menubar/MenubarHiderController.swift` | `isCollapsed` отражает реальное физическое состояние menubar items, а не «попытку». |
| `MenuBarItemMover` | `Menubar/MenuBarItemMover.swift` | `move()` возвращает `true` ⇔ frame item'а действительно сдвинулся к target. |
| `PermissionsManager` | `Permissions/PermissionsManager.swift` | `accessibility` / `screenRecording` отражают реальный статус TCC. `anyMissing` корректно рулит онбордингом. |
| `FocusModeController` | `Focus/FocusModeController.swift` | `isActive` ⇔ overlay реально создан и показан на всех экранах кроме frontmost. |
| `StatsCollector` | `Domain/Stats/*` | Записываемые числа ≥ 0, JSON-схема версионируется, повреждение не теряет данные молча. |
| `DevLogger` | `Diagnostics/DevLogger.swift` | Когда `enabled = false` — нулевая стоимость (autoclosure не вычисляется). |

---

## 3. Глобальные правила выполнения тасков

1. **Не ломать соседнее**: каждый таск касается узкой зоны. Если правка задевает несколько подсистем — это сигнал что таск дожирен и нужно дробить.
2. **Минимум edge-case-handling**: добавлять валидацию только на границах (user input, parsed JSON, system APIs). Внутри — доверять.
3. **Никаких новых абстракций ради будущего**: правим точечно. Не вводим protocol'ы, generic'и, helper-классы, если задача того не требует.
4. **Никаких комментариев-объяснялок WHAT**: только WHY, и только если неочевидно.
5. **Не вводить feature flags / backwards-compat shims** — переписываем код напрямую. Если таск требует миграции данных (схема JSON) — пишем явный одноразовый migrator.
6. **Без эмодзи в коде** (если только пользователь явно не попросил).
7. **Каждый таск собирается** через `swift build` + базовый smoke в build-папке. Релиз делается ТОЛЬКО когда полная фаза закрыта (см. секцию релизов ниже).
8. **devlog**: при изменении подсистемы статус-бара/permissions добавлять `devlog(...)` где это помогает диагностике.
9. **Локализация**: любая новая user-facing строка обязательно en/ru/zh, в правильном порядке поля в Translation.swift.
10. **Verification-таск НЕ правит код** — только читает diff vs описание, прогоняет smoke-сценарии, документирует обнаруженные регрессии (если есть — создаёт follow-up таск в конце ledger'а).

### Когда релизить

**ПОЛИТИКА: одна микро-версия на каждый таск.** Старт — 0.9.21. Цель — минимум 0.9.81 (0.9.21 + 60 тасков).

После каждого закрытого таска (impl или verify):
- `./scripts/bump.sh patch`
- `./scripts/build.sh && ./scripts/package.sh && ./scripts/build_stub.sh && ./scripts/package_stub.sh`
- entry в `dev_log.json` (короткий — 1 предложение customMessage, 2-4 пункта points для impl-таска; для verify-таска — что верифицировано и было ли OK)
- commit с заголовком `Hello work X.Y.Z — TASK-NNN ...` (уникальный для версии)
- tag + push + `gh release create`

Каждый патч-релиз = ровно один таск. Юзер видит постоянное движение вперёд, легко откатить любой шаг через тэги.

---

## 4. Task Ledger

Формат: `[ ] = pending`, `[~] = in_progress`, `[x] = done`. Verify-таск нельзя пометить done пока impl-таск не done.

### Phase A — Hider state machine (correctness)

- [x] **TASK-001 [impl]** — Fix `applyAuto()` clobbers user manual toggle  → released as v0.9.22
  - Файл: `Sources/HelloWork/Menubar/MenubarHiderController.swift:99-115`
  - Проблема: после auto-collapse юзер вручную toggle-нул через menu, `lastAutoState` всё ещё содержит auto-флаг → следующий `applyAuto(false)` уже не вернёт expand'ом, потому что `lastAutoState != nil` → ранний return на стр 105.
  - Acceptance: сценарий «focus on → auto-collapse → user toggle expand → focus off → no spurious collapse» отрабатывает. Сценарий «schedule blocked → auto-collapse → schedule allowed → auto-expand» тоже.
  - Tests via diagnostics: в логах должна быть видна decision-цепочка.

- [x] **TASK-002 [verify]** — TASK-001  → released as v0.9.23
  - Сценарии 1/2/3 трассированы — работают.
  - Найден edge-case → создан follow-up TASK-061/062.

- [x] **TASK-003 [impl]** — Configure deferred initialCollapsed race  → released as v0.9.24
  - Файл: `Sources/HelloWork/Menubar/MenubarHiderController.swift:46-53`
  - Проблема: 1с asyncAfter после `configure()` вызывает `collapseInternal()`. Если за эту секунду юзер уже toggle-нул (expanded), отложенный collapse всё равно случится.
  - Решение: token/cancel-flag, инкрементируется в `configure`, проверяется в asyncAfter; toggle/applyAuto тоже инкрементируют чтобы дезактивировать pending.

- [ ] **TASK-004 [verify]** — TASK-003

- [ ] **TASK-005 [impl]** — Cache `currentItems()` в `collapseInternal` + `restoreAllItems` (N+1 → 1)
  - Файлы: `Menubar/MenubarHiderController.swift:153,170`, `:214-217`
  - Проблема: для N items — N+1 полных CGS-перечислений menubar.
  - Решение: один `currentItems()` в начале, по `windowID` lookup внутри loop'а. Frame для actual-position брать через `Bridging.getWindowFrame(for: id)` (одно CGS-обращение, не полный list).

- [ ] **TASK-006 [verify]** — TASK-005

- [ ] **TASK-007 [impl]** — `MenuBarItemMover.move()` — убрать второй `currentItems()` для verify
  - Файл: `Menubar/MenuBarItemMover.swift:79-88`
  - Решение: после постинга событий вместо `currentItems().first {...}` использовать `Bridging.getWindowFrame(for: item.windowID)` (1 CGS call вместо полного перечисления).

- [ ] **TASK-008 [verify]** — TASK-007

- [ ] **TASK-009 [impl]** — Combine cascade на toggle хайдера → 2 disk writes
  - Файл: `App/AppDelegate.swift:487-527`, `Menubar/MenubarHiderController.swift:configure()`
  - Проблема: `configure()` ставит `isCollapsed = false` → sink на `$isCollapsed` пишет UserDefaults. Потом collapse-internal через 1с — ещё один write.
  - Решение: добавить `private var suppressPersist: Bool` в controller, обнулять только после первого реального user-action или после deferred-collapse.

- [ ] **TASK-010 [verify]** — TASK-009

### Phase B — Permissions / TCC flow

- [ ] **TASK-011 [impl]** — `checkScreenRecording` heuristic — ставить `requestedSR` ключ ПОСЛЕ результата, не до
  - Файл: `Permissions/PermissionsManager.swift:57-69` (зеркально для AX 78-91)
  - Проблема: ключ `helloWorkPermissionsRequestedSR` ставится в `requestScreenRecording()` ДО результата → если юзер закрыл prompt без решения, на next refresh видим `.denied` хотя должно быть `.notDetermined`.
  - Решение: ставить ключ только если `CGPreflightScreenCaptureAccess()` вернул true после запроса. Аналогично для AX через `AXIsProcessTrusted()`.

- [ ] **TASK-012 [verify]** — TASK-011

- [ ] **TASK-013 [impl]** — `AutoRelauncher` infinite wait
  - Файл: `Permissions/AutoRelauncher.swift:13-16`
  - Проблема: bash-watcher делает `while kill -0 PID; do sleep 0.4; done` → если macOS НЕ убил процесс при grant'е (а часто не убивает), скрипт висит вечно, мусорный процесс.
  - Решение: добавить timeout 60с в while. После timeout — exit без relaunch.

- [ ] **TASK-014 [verify]** — TASK-013

- [ ] **TASK-015 [impl]** — Permissions onboarding less aggressive
  - Файл: `App/AppDelegate.swift:86-110`
  - Проблема: показывается на каждом запуске пока `anyMissing`, даже если юзер уже видел и сознательно отказался.
  - Решение: показ только если (а) первый запуск, или (б) юзер из меню/permissions-сайдбара явно тыкнул «Re-grant». Иначе — silent. Permissions-row в сайдбаре с красной точкой остаётся (это и есть точка возврата).

- [ ] **TASK-016 [verify]** — TASK-015

### Phase C — Resilience (data corruption)

- [ ] **TASK-017 [impl]** — Corruption detection для managedApps + StatsStore
  - Файлы: `App/AppState.swift:197-203`, `Domain/Stats/StatsCollector.swift` (load func)
  - Проблема: `try? JSONDecoder().decode(...)` — если JSON битый, юзер молча теряет всё.
  - Решение:
    - При неудачном decode — переименовать файл/ключ в `*.corrupt-<timestamp>` (для recovery), создать пустой state.
    - Поднять флаг `state.lastCorruptionRecovery: String?` (категория данных, для UI banner).
    - В PrefsView в детали показать неблокирующий warning banner с «Старый файл сохранён в Application Support под именем X».

- [ ] **TASK-018 [verify]** — TASK-017

- [ ] **TASK-019 [impl]** — Schema versioning для managedApps + Stats JSON
  - Файлы: `Domain/ManagedApp.swift`, `Domain/Stats/StatsStore.swift`
  - Решение: обернуть persisted JSON в `{"version": 1, "data": [...]}`. Loader: читает version, если != current — попытка миграции (пока пустой migrator), иначе fallback на пустой state. Backward-compat: если old format (no wrapper) — read as version 1, save in new format.

- [ ] **TASK-020 [verify]** — TASK-019

### Phase D — Hotkey collisions

- [ ] **TASK-021 [impl]** — `HotkeyManager` — distinct EventHotKeyID per instance
  - Файлы: `Focus/HotkeyManager.swift:14-17`
  - Проблема: оба инстанса (focus + menubar) используют одинаковый `EventHotKeyID(id: 1)`. Если юзер назначит одинаковый hotkey — Carbon перезапишет первый.
  - Решение: HotkeyManager init принимает `id: UInt32`. AppDelegate создаёт focus с id=1, menubar с id=2.

- [ ] **TASK-022 [verify]** — TASK-021

### Phase E — Update fetch / Network

- [ ] **TASK-023 [impl]** — Дедуп update checks + invalidate URLSession
  - Файлы: `App/AppDelegate.swift:48,697,733`, `App/AppState.swift:checkForUpdates`
  - Проблема: запуск + refresh-loop + open-prefs все триггерят `checkForUpdates()` независимо. URL-session не invalidate-ится.
  - Решение:
    - В AppState добавить `lastSuccessfulCheck: Date?`. Если `< 5 min ago` — skip.
    - Если уже `isCheckingUpdates == true` — skip параллельный.
    - В `checkForUpdates` после `let (data, _) = await session.data(...)` вызвать `session.finishTasksAndInvalidate()`.

- [ ] **TASK-024 [verify]** — TASK-023

### Phase F — UI re-render perf

- [ ] **TASK-025 [impl]** — Throttle slider didSet writes (`focusDimOpacity`)
  - Файл: `App/AppState.swift:48-52`
  - Проблема: drag слайдера = десятки UserDefaults.set в секунду.
  - Решение: вынести focusDimOpacity на @State в FocusSettingsView (live UI), commit в AppState только на `.onChange(of: ... debounce 300ms)` или на отпускании слайдера. Альтернатива: throttle через Combine `.throttle(for: .milliseconds(300))`.

- [ ] **TASK-026 [verify]** — TASK-025

- [ ] **TASK-027 [impl]** — `ScheduleView` decouple от global `@ObservedObject`
  - Файлы: `Preferences/Schedule/ScheduleView.swift`, `Preferences/PrefsView.swift:144-147`
  - Проблема: ScheduleView держит `@ObservedObject var state: AppState` и перерисовывается на любой изменение в state (язык, focusDimOpacity, etc).
  - Решение: переписать на `bundleID` + локальный snapshot `ManagedApp` через computed property с filtering. Alternative: extract narrow `ScheduleViewModel`.

- [ ] **TASK-028 [verify]** — TASK-027

- [ ] **TASK-029 [impl]** — `CombinedScheduleView` — TimelineView для ticker
  - Файл: `Preferences/Combined/CombinedScheduleView.swift`
  - Проблема: @State now Date с 1Hz timer перерисовывает всю combined-вьюху.
  - Решение: `TimelineView(.periodic(from: .now, by: 60))` (раз в минуту достаточно для расписания) на ring-чарте, не на parent body.

- [ ] **TASK-030 [verify]** — TASK-029

- [ ] **TASK-031 [impl]** — Diagnostics tab — pause refresh когда таб не активен
  - Файл: `Preferences/Settings/SettingsDiagnosticsTab.swift:36-48`
  - Решение: проверять `state.settingsTab == .diagnostics` перед refresh. Также — проверять mtime файла, читать только при изменении.

- [ ] **TASK-032 [verify]** — TASK-031

- [ ] **TASK-033 [impl]** — `rebuildStatusMenu` signature — semantic, не string-concat
  - Файл: `App/AppDelegate.swift:391-415`
  - Проблема: signature ребилдится на изменение архивированного app или языка (хотя в menu только активные apps). Лишние полные NSMenu+NSHostingView перестроения.
  - Решение: фильтровать managedApps по `!isArchived` перед signature; убрать language если он не используется в menu (проверить).

- [ ] **TASK-034 [verify]** — TASK-033

### Phase G — refresh() timer + window finder

- [ ] **TASK-035 [impl]** — refresh() throttle + skip когда `!enabled` + workspace-driven frontmost
  - Файлы: `App/AppDelegate.swift:startTimer/refresh`, `WindowDetection/AppWindowFinder.swift`, `Focus/FrontmostWindowFinder.swift`
  - Проблема: 4Hz timer вызывает AppWindowFinder.find() для каждого managed app независимо от того, изменилось ли что-то.
  - Решение: 
    - `refresh()` — guard `state.enabled`, иначе skip heavy work.
    - frontmost кеш — обновлять только по `NSWorkspace.didActivateApplicationNotification` (уже подписаны), не по timer.
    - Timer оставить только для countdown'ов / time-based logic (grace expiry, scheduled boundaries).
    - Снизить timer до 1Hz, наверняка хватит.

- [ ] **TASK-036 [verify]** — TASK-035

- [ ] **TASK-037 [impl]** — `FrontmostWindowFinder` — single CGS call path
  - Файл: `Focus/FrontmostWindowFinder.swift:23-30,113-138`
  - Проблема: при useAccessibility=true может два раза дёргать CGWindowListCopyWindowInfo.
  - Решение: пробросить CG-info между AX и CG путями.

- [ ] **TASK-038 [verify]** — TASK-037

### Phase H — UpdateInstaller / Stub

- [ ] **TASK-039 [impl]** — UpdateInstaller — fail-fast при replace-while-running на Sequoia
  - Файл: `Updates/UpdateInstaller.swift`
  - Проблема: `rm -rf "$TARGET" && cp -R ...` пока app запущен на Sequoia может зафейлиться без явной ошибки в UI.
  - Решение: 
    - Проверять что engine path == `~/Library/Application Support/HelloWork/HelloWork.app` (там replace OK) перед update.
    - Если update failed — статус .error с конкретным сообщением.
    - Не молчать.

- [ ] **TASK-040 [verify]** — TASK-039

### Phase I — Edge cases

- [ ] **TASK-041 [impl]** — Slot wraparound clamp
  - Файл: `App/AppState.swift:412,447` (addSlot, slotsFromMinuteSet)
  - Проблема: `endMinutes - minutesInDay < 0` создаёт invalid range. `slotsFromMinuteSet` может вернуть `endMinutes > 2 * minutesInDay`.
  - Решение: явные clamp + assertion в debug.

- [ ] **TASK-042 [verify]** — TASK-041

- [ ] **TASK-043 [impl]** — `StatsCollector.recordGrace` — guard ≥ 0
  - Файл: `Domain/Stats/StatsCollector.swift`
  - Решение: `guard seconds > 0 else { return }` в начале.

- [ ] **TASK-044 [verify]** — TASK-043

- [ ] **TASK-045 [impl]** — `AppVersion.compare` — pre-release suffix
  - Файл: `App/Version.swift`
  - Проблема: "0.9.10-beta" парсится как [0,9,10], "0.9.10" тоже как [0,9,10] → equal вместо «release > prerelease».
  - Решение: split на "-" сначала, основная часть → tuple компаренье; если остался suffix — prerelease, считается младше release без suffix'а.

- [ ] **TASK-046 [verify]** — TASK-045

### Phase J — DevLogger

- [ ] **TASK-047 [impl]** — DevLogger rotation (max 10 MB)
  - Файл: `Diagnostics/DevLogger.swift`
  - Решение: при append проверять file size, если > 10 MB — rename `devlog.txt` → `devlog.txt.1`, начать новый.

- [ ] **TASK-048 [verify]** — TASK-047

### Phase K — UX polish

- [ ] **TASK-049 [impl]** — Dev-mode unlock — auto-jump в Diagnostics + persistent banner
  - Файлы: `Preferences/Settings/SettingsView.swift:80-110`
  - Решение: убрать таймер автоскрытия, оставить banner в Diagnostics-tab сверху с кнопкой «Скрыть» / «Disable dev mode».

- [ ] **TASK-050 [verify]** — TASK-049

- [ ] **TASK-051 [impl]** — Sidebar `+` button feedback при повторном нажатии
  - Файл: `Preferences/PrefsView.swift:96-123`
  - Решение: при click если selection уже `.onboarding` — пульсация рамки (subtle scale animation).

- [ ] **TASK-052 [verify]** — TASK-051

- [ ] **TASK-053 [impl]** — Sidebar scroll position memo
  - Файл: `Preferences/Schedule/ScheduleView.swift` или PrefsView detail
  - Решение: `@State private var scrollPositions: [String: CGFloat] = [:]` в PrefsView, сохранять/восстанавливать через ScrollViewReader.

- [ ] **TASK-054 [verify]** — TASK-053

### Phase L — Localization integrity

- [ ] **TASK-055 [impl]** — Translation keys validation
  - Файлы: `Domain/Translation.swift`, `Domain/Translations.swift`
  - Проблема: Translation — struct с let-полями, missing key = compile error (это уже хорошо). Но: порядок аргументов в init для en/ru/zh должен совпадать (Swift даёт «incorrect argument labels» при mismatch — поймали уже один раз). Хочется более robust.
  - Решение: добавить тестовый-таргет `swift test` с одним тестом который инстанцирует все три locale и проверяет что строки не пустые / не равны placeholder'ам. Или scripts/validate_translations.swift который читает Translation.swift как AST.

- [ ] **TASK-056 [verify]** — TASK-055

### Phase M — Lifecycle cleanup

- [ ] **TASK-057 [impl]** — NSEvent monitor + focus overlay cleanup
  - Файлы: `App/AppDelegate.swift:applicationWillTerminate / overlay handling`
  - Решение:
    - В `applicationWillTerminate(_:)` — `NSEvent.removeMonitor(peekMouseMonitor)`, `state.menubarHider.tearDown()` (уже есть?), focus overlay close-out.
    - При `managedApps` change — explicit cleanup overlays для удалённых bundleID.

- [ ] **TASK-058 [verify]** — TASK-057

### Phase N — Final regression

- [ ] **TASK-059 [impl]** — Final regression sweep
  - Действия: 
    - bump minor → 0.10.0 (сигналит «комплекс улучшений»)
    - manual smoke list (см. ниже)
    - заполнить dev_log.json с подытогом фаз A–M
    - commit, tag, gh release
  - Smoke list:
    1. Свежий запуск (после tcc reset all для обоих bundleID) — онбординг показывается, оба permission row visible
    2. Grant AX + SR — restart → diagnostics tab показывает true для обоих
    3. Hider toggle (menu) — реально скрываются items, ScreenRecording=true в логе
    4. Hider hotkey — то же
    5. Focus mode hotkey — overlay появляется, frontmost подсвечен
    6. Add managed app + slot, дождаться вне-окна — overlay покрывает приложение, attempts++
    7. Grace 60s — overlay снят, countdown в menubar
    8. Settings: focusDimOpacity slider — нет лагов, persist через restart
    9. Schedule view для app — ring chart рисуется, slots редактируются
    10. Combined view — ring обновляется минутно
    11. Diagnostics tab — entries появляются на каждое действие, refresh не дублируется когда tab закрыт
    12. Dev mode toggle off — tab исчезает, banner snapshot OK
    13. Update check — fetch один раз на запуск + open-prefs (если > 5 min с прошлого)
    14. Quit + relaunch — no orphan processes, peek monitor cleared
  - Каждый пункт — лог в dev_log.json «smoke OK» или дописываем follow-up таск в этот ledger.

- [ ] **TASK-060 [verify]** — TASK-059
  - Финальный QA pass. Если есть follow-up'ы — переоткрыть фазу O для них.

---

## 5. Follow-up tasks (если возникнут во время verify)

> Сюда verify-таски ДОПИСЫВАЮТ новые задачи, если обнаружили регрессию или non-trivial gap. НЕ переписывают существующие. Формат — продолжение нумерации.

- [ ] **TASK-061 [impl]** — `configure()` / `tearDown()` сбрасывают `lastAutoIntent`
  - Found by: TASK-002 [verify]
  - Файл: `Sources/HelloWork/Menubar/MenubarHiderController.swift:40-69`
  - Проблема: при выключении-включении hider'а через Settings, `lastAutoIntent` сохраняется. Если focus on уже был → `.$isActive` уже не перевыпустит → applyAuto не позовётся → items не свернутся при повторном включении hider.
  - Acceptance: после re-configure auto-сигнал применяется заново при первом попадании в applyAuto.

- [ ] **TASK-062 [verify]** — TASK-061

---

## 6. Метрики «9.5 / 10»

После закрытия всех тасков должны быть:

- ✅ 0 «иконка переключилась но реально ничего не произошло» сценариев — каждый toggle проверяется по факту.
- ✅ collapse(N items) делает ≤ N+2 CGS calls (было N²+).
- ✅ 1 user-action toggle = 1 disk write.
- ✅ slider не вызывает > 5 disk writes/sec.
- ✅ Update check ≤ 1/час максимум.
- ✅ Corrupt JSON managedApps/stats → user warning + recovery file, не silent loss.
- ✅ AX + SR grant сохраняется через апдейты (self-signed cert ✓ уже).
- ✅ refresh() timer ≤ 1Hz и пропускает heavy work если `!enabled`.
- ✅ Permissions onboarding не лезет каждый запуск после явного отказа.
- ✅ DevLogger rotation работает.
- ✅ Все hotkey'и могут сосуществовать (distinct IDs).
- ✅ swift test зелёный для translations.
- ✅ devlog.json содержит phase-summary entries для A–M.
