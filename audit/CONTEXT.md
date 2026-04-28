# HelloWork — Audit Cycle Context

> Этот файл — **единственный источник истины** для агента, который выполняет таски в текущем audit cycle. Перед каждой итерацией читать целиком, после — обновлять статусы.
>
> Этот файл переиспользуется между циклами. Секции 1-2 переписываются под новый цикл. Секции 3-4 меняются редко. Секция 5 — ядро текущего цикла. Секции 6-7 — заполняются по ходу.

---

## 1. Goal of current cycle — Menubar Hider Fix

**Задача**: переписать менюбар-hider так, чтобы он реально скрывал чужие menubar items на macOS Sequoia. Сейчас наша имплементация только лагает но иконки остаются на месте. Эталон — [Ice](https://github.com/jordanbaird/Ice) (GPLv3) — работает на той же машине с теми же permissions.

**Почему сейчас**: фича заявлена, юзер reported что не работает.

**Корневые причины (диагностика, см. секцию 2)**:
1. Мы шлём 4 события (Down/Dragged×2/Up), правильно — 2 (Down с cmd на off-screen + Up на target).
2. Не зовём `permitAllEvents` для `eventSuppressionState*` — Sequoia подавляет synth events возле menubar.
3. Постим в `.cghidEventTap`, надо в `.cgSessionEventTap`.
4. `Thread.sleep` вместо EventTap-callback'а на доставку.
5. Двигаем «на абсолютный X», правильно — «relative to target item windowID».
6. `CGEventSource(.combinedSessionState)` — должно быть `.hidSystemState`.

---

## 2. Architecture context

### Файлы которые трогаем

```
Sources/HelloWork/Menubar/
├── MenuBarItem.swift              ← минимальные правки (модель ОК)
├── MenuBarItemMover.swift         ← ПЕРЕПИСАТЬ полностью (это ядро бага)
└── MenubarHiderController.swift   ← обновить вызовы под новый API mover'а

Sources/HelloWork/Bridging/
├── CGEventExtensions.swift        ← правка factory: убрать promoted Dragged-flag
└── (новый) EventTap.swift         ← Ice-style helper для подтверждения доставки

Sources/HelloWork/Bridging/
└── Private.swift                  ← возможно добавить CGSCopyMenuBarOnScreenItems
                                     или CGSGetWindowOwnerWithEvent для park-логики
```

### Файлы которые НЕ трогаем

`AppState.swift` (state остаётся), `MenubarHotkey.swift` (хоткей-инфраструктура нормальна), модули focus/schedule/permissions/legends — никак не связаны.

### Ключевые инварианты

- **Bundle ID и signing identity не меняем** (стабильное общее правило).
- **Public API `MenubarHiderController.toggle()/collapseAll()/expandAll()/peek()/applyAuto()`** — поведение должно остаться идентичным; меняется только внутренняя реализация.
- **`isHideable` фильтр** — оставляем как есть. Apple-managed items (Time, Control Center, Spotlight, IME, Notification Center, Dock) и наша own-item не двигаются.
- **Permissions**: остаётся требование Accessibility (AXIsProcessTrusted). Screen Recording — НЕ обязателен для самого move'а (это была наша гипотеза, у Ice нет такого требования). Прямо из-за этого требование убираем — в onAccessibilityRequired не апать Screen Recording.

### Ice-эталон в `/tmp/ice-compare/`

Скачано:
- `MenuBarItemManager.swift` (1671 строка) — основной mover
- `MenuBarItem.swift` (240 строк) — модель

Использовать как референс: что именно постится, как ждётся, как формируется destination.

---

## 3. Global rules (стабильные между циклами)

1. **Bundle ID `dev.helloworkapp.macos.engine` не меняем никогда.**
2. **Self-signed cert «HelloWork Self-Signed» не пересоздаём.**
3. **Минимум edge-case-handling**: только на границах.
4. **Никаких новых абстракций ради будущего**: только нужное.
5. **Никаких комментариев-объяснялок WHAT**: только WHY.
6. **Без эмодзи в коде**.
7. **i18n**: en + ru + zh в strict order Translation.swift.
8. **Schema versioning** для persistence.
9. **devlog**: точки `devlog("category", ...)` для диагностики.
10. **Verify-таск НЕ правит код продакта**.

### Соседние модули — НЕ трогаем кроме явного scope

`Domain/Legends/`, `Focus/`, `Hider`, `Schedule`, `Stats`, `Permissions`, `UpdateInstaller` core — только если задача явно требует.

---

## 4. Release policy — **ЭТОТ ЦИКЛ ОСОБЫЙ**

> ⚠️ **В этом цикле НЕТ per-task релизов.** Стандартный workflow «один таск = один patch + DMG + gh release» **отключён**.

**Причина**: цикл — debug + переписывание ядра, который требует много локальных итераций с тестированием. Релизить промежуточные сломанные версии бессмысленно — юзеры получат регрессии.

### Что делаем в каждой итерации

1. Выбираем next таск по ledger (как обычно).
2. Меняем код.
3. **Только**: `swift build` чисто; `./scripts/build.sh` (получаем `dist/HelloWork.app` свежий) — для локального теста.
4. **НЕТ**: `bump.sh`, `package.sh` (DMG), `git tag`, `git push`, `gh release create`.
5. Можно (опционально) делать обычный `git commit` для checkpoint'а — но **без tag'а и push'а**.
6. Юзер тестит вручную: запускает `dist/HelloWork.app`, жмёт menubar-hider hotkey, смотрит в консоль/devlog работает ли.
7. Помечаем таск `[x]` в ledger, описываем что сделали + результат теста.

### Финальный таск (TASK-Z01) — ОДИН релиз

После того как всё работает (юзер подтвердил smoke-тест на своей машине):
- `./scripts/bump.sh patch` или `minor` (юзер скажет какой)
- Полный pipeline: build → package → commit → tag → push → gh release create
- ОДНА финальная версия, не серия.

**Если что-то не работает** даже после исчерпания плана — **STOP**, обсуждаем с юзером. Не релизим неработающее.

---

## 5. Task Ledger

Формат: `[ ] = pending`, `[~] = in_progress`, `[x] = done`. Verify-таск нельзя пометить done пока impl-таск выше не done.

### Phase A — Diagnostics infrastructure (4 tasks)

> Цель: навести наблюдаемость, иначе будем биться вслепую. И сделать «тестовый стенд» — кнопку которая скрывает ОДИН item, чтобы итерировать быстро.

- [ ] **TASK-A01 [impl]** — Расширить devlog в `MenuBarItemMover.move`: до/после каждого `event.post` логать `event.type.rawValue`, `event.flags.rawValue`, `event.location` (через `event.location`), `eventTargetUnixProcessID` (через `getIntegerValueField`), `windowID` field. Логать `AXIsProcessTrusted()` и `CGEventSource(.combinedSessionState).flags` ПЕРЕД каждым call'ом move().
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`
  - Acceptance: после вызова `collapseInternal` в devlog видно полный «до/после» каждого события: что отправили, что вернулось через `Bridging.getWindowFrame`, какой permissions state.

- [ ] **TASK-A02 [verify]** — TASK-A01

- [ ] **TASK-A03 [impl]** — Добавить **debug-кнопку «Test single move»** в `Preferences/Settings/SettingsAppTab.swift` (видна только в dev-mode). Кнопка: берёт `MenuBarItem.currentItems()` отфильтрованный по `isHideable`, выбирает ПЕРВЫЙ (самый левый), пытается `MenuBarItemMover.hide(item)` без сохранения backup. Юзер видит результат сразу — двинулся или нет.
  - Файлы: `Sources/HelloWork/Preferences/Settings/SettingsAppTab.swift`, без изменений в Mover (юзает существующий API).
  - Acceptance: в dev-mode появляется кнопка «🧪 Test single hide»; клик → один item исчезает (или нет), в Diagnostics-tab видно полный devlog цикла.

- [ ] **TASK-A04 [verify]** — TASK-A03

### Phase B — `permitAllEvents` + правильный event source (4 tasks)

> Гипотеза: одного добавления `permitAllEvents` может быть достаточно (это самый частый Sequoia-pitfall). Делаем минимально-инвазивно, тестим.

- [ ] **TASK-B01 [impl]** — В `MenuBarItemMover.move`: ДО первого `event.post` вызвать:
  ```swift
  if let permitSource = CGEventSource(stateID: .combinedSessionState) {
      permitSource.setLocalEventsFilterDuringSuppressionState(
          .permitLocalMouseEvents.union(.permitLocalKeyboardEvents).union(.permitSystemDefinedEvents),
          state: .eventSuppressionStateRemoteMouseDrag
      )
      permitSource.setLocalEventsFilterDuringSuppressionState(
          .permitLocalMouseEvents.union(.permitLocalKeyboardEvents).union(.permitSystemDefinedEvents),
          state: .eventSuppressionStateSuppressionInterval
      )
      permitSource.localEventsSuppressionInterval = 0
  }
  ```
  Это снимает Sequoia-supression который блокирует synth-events возле menubar.
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`
  - Acceptance: build clean; debug кнопка из A03 — пробуем, юзер сообщает работает ли.

- [ ] **TASK-B02 [verify]** — TASK-B01. Если **уже работает** — пропускаем Phase C-F и идём в Phase Z (cleanup + release).

- [ ] **TASK-B03 [impl]** — Сменить `CGEventSource(stateID: .combinedSessionState)` на `CGEventSource(stateID: .hidSystemState)` (как у Ice — для самого источника событий). `permitSource` (B01) остаётся `.combinedSessionState` — там Ice так и оставляет. Это два разных source'а с разными ролями.
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`
  - Acceptance: build clean; снова тест от A03 — двигается?

- [ ] **TASK-B04 [verify]** — TASK-B03

### Phase C — Правильная event-sequence (4 tasks)

> Если B не помог: переходим на Ice'овский протокол — **2 события** вместо 4. mouseDown на off-screen (20000, 20000) с cmd-flag + mouseUp на endPoint без cmd. Никаких Dragged.

- [ ] **TASK-C01 [impl]** — В `MenuBarItemMover.move`: убрать `Dragged`-события. Заменить sequence на:
  ```swift
  let startPoint = CGPoint(x: 20_000, y: 20_000)
  let events: [(MenuBarItemEventType, CGPoint)] = [
      (.move(.leftMouseDown), startPoint),
      (.move(.leftMouseUp),   endPoint),
  ]
  ```
  Это минимальный seq который macOS WindowServer интерпретирует как «двигаем menubar item».
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`
  - Acceptance: тест от A03 — двигается?

- [ ] **TASK-C02 [verify]** — TASK-C01. Если работает — пропускаем D-F, идём в Z.

- [ ] **TASK-C03 [impl]** — В `CGEventExtensions.swift`: пересмотреть `cgEventFlags` для `.move(.leftMouseDown)` → должен быть только `.maskCommand`. Для `.move(.leftMouseUp)` → пусто (Ice не ставит cmd на mouseUp). Убрать `.move(.leftMouseDragged)` case (не используется после C01).
  - Файлы: `Sources/HelloWork/Bridging/CGEventExtensions.swift`
  - Acceptance: enum case `.leftMouseDragged` всё ещё есть для совместимости (вдруг где-то в click-paths); flag-логика match Ice.

- [ ] **TASK-C04 [verify]** — TASK-C03

### Phase D — Switch event tap target (4 tasks)

> Если C не помог: меняем tap с `.cghidEventTap` на `.cgSessionEventTap`. Убираем дублирующий `postToPid`.

- [ ] **TASK-D01 [impl]** — В `MenuBarItemMover.move`: заменить:
  ```swift
  event.post(tap: .cghidEventTap)
  event.postToPid(item.pid)
  ```
  на:
  ```swift
  event.post(tap: .cgSessionEventTap)
  ```
  Single tap. Без postToPid. Sleep между событиями оставить пока на 50ms (timing'ом займёмся в E).
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`
  - Acceptance: тест от A03.

- [ ] **TASK-D02 [verify]** — TASK-D01. Если работает — Z.

- [ ] **TASK-D03 [impl]** — Если D02 не сработал: попробовать `.cgAnnotatedSessionEventTap` (annotated session — другой типа event tap). Это retry-альтернатива. Документировать в комментариях что попробовали 3 варианта.
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`
  - Acceptance: тест от A03.

- [ ] **TASK-D04 [verify]** — TASK-D03

### Phase E — EventTap-based delivery confirmation (4 tasks)

> Если D не помог: проблема может быть в timing'е — мы постим события быстрее чем WindowServer успевает обработать. Заменяем blind sleep на ожидание получения event'а через temporary CGEventTap.

- [ ] **TASK-E01 [impl]** — Создать `Sources/HelloWork/Bridging/EventTap.swift` — простой helper:
  ```swift
  @MainActor
  final class EventTap {
      static func waitForEvent(
          matching original: CGEvent,
          on tap: CGEventTapLocation,
          timeout: TimeInterval
      ) async -> Bool { ... }
  }
  ```
  Внутри: `CGEvent.tapCreate(tap: .listenOnly, ...)` со фильтром по `eventSourceUserData` совпадающему с `original`. Возвращает true когда event получен; false — timeout. По возврату — disable+release tap.
  - Файлы: `Sources/HelloWork/Bridging/EventTap.swift` (новый)
  - Acceptance: build clean; helper работает в простом sanity-теcте (можно отдельной debug-кнопке).

- [ ] **TASK-E02 [verify]** — TASK-E01

- [ ] **TASK-E03 [impl]** — В `MenuBarItemMover.move`: заменить `Thread.sleep(0.05)` на `await EventTap.waitForEvent(matching: event, on: .cgSessionEventTap, timeout: 0.05)`. Если timeout — devlog warning, но продолжаем (best-effort fallback).
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`
  - Async-cascade: метод становится `async`, controller вызывает в `Task { @MainActor }`.
  - Acceptance: тест A03.

- [ ] **TASK-E04 [verify]** — TASK-E03

### Phase F — Destination-as-target-item model (5 tasks)

> Если E не помог: проблема в том что macOS не понимает «двинь на X=−1000». Переходим на Ice'овский target-item destination — `mouseUp.windowID` указывает на item рядом с которым ставим.

- [ ] **TASK-F01 [impl]** — Создать `MoveDestination` enum:
  ```swift
  enum MoveDestination {
      case leftOfItem(MenuBarItem)
      case rightOfItem(MenuBarItem)
  }
  ```
  В `Sources/HelloWork/Menubar/MenuBarItemMover.swift`.
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`

- [ ] **TASK-F02 [impl]** — Найти/создать «park» item. Опции:
  1. (предпочтительно) Найти самый левый Apple-managed item (у нас он immovable, но он стабильно слева — мы можем `.leftOfItem(applemost-left)` и наш item уйдёт ещё левее, за край экрана).
  2. (fallback) Сами создаём invisible NSStatusItem с `length = 0` как анкер. Двигаем «слева от анкера».
  
  Решение: вариант 1, ищем `MenuBarItem.currentItems()` отсортированные по midX, берём leftmost `!isMovable`.
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift` или новый `ParkItemFinder.swift` если разрослось.
  - Acceptance: helper `findParkAnchor() -> MenuBarItem?` возвращает leftmost Apple-managed item.

- [ ] **TASK-F03 [impl]** — Переписать `MenuBarItemMover.move(item:to destination: MoveDestination)`:
  - `endPoint` для mouseUp: `destination`.targetItem.frame.midX (примерно), но КЛЮЧЕВОЕ — `windowID` field на mouseUp event указывает на `destination`.targetItem.windowID. Не на item который двигаем.
  - `mouseDownEvent` — windowID указывает на item который двигаем.
  - В `MenuBarItem.menuBarItemEvent(type:location:item:pid:source:)` — расширить чтобы принимал ОТДЕЛЬНЫЕ `windowID` для down vs up. Или добавить варианты `.menuBarItemMoveDownEvent / UpEvent`.
  - `hide(_ item)` теперь делает `move(item, to: .leftOfItem(parkAnchor))`.
  - `restore(_ item, original: ...)` — нужно знать соседа. Сохраняем при collapse не только X, но и **левого соседа windowID**. Тогда restore = `move(item, to: .rightOfItem(neighbor))`.
  - Файлы: `Sources/HelloWork/Menubar/MenuBarItemMover.swift`, `Sources/HelloWork/Menubar/MenubarHiderController.swift`
  - Acceptance: тест A03 → один item уходит ВЛЕВО за Apple-managed зону.

- [ ] **TASK-F04 [verify]** — TASK-F03

- [ ] **TASK-F05 [impl]** — Restore: при collapse `MenubarHiderController.collapseInternal()` вместо `savedPositions: [windowID: X]` сохраняем `savedNeighbors: [windowID: leftNeighborWindowID]`. При restore идём слева направо, для каждого item делаем `mover.move(item, to: .rightOfItem(neighbor))`.
  - Файлы: `Sources/HelloWork/Menubar/MenubarHiderController.swift`
  - Acceptance: тест A03 для full-collapse + expand → все вернулись.

- [ ] **TASK-F06 [verify]** — TASK-F05

### Phase G — Full Ice scrombleEvent (если ничего не помогло) (3 tasks)

> Last resort: портируем full scrombleEvent — двойной EventTap (один на `.pid`, другой на session). Сложно, поэтому только если F не помог.

- [ ] **TASK-G01 [impl]** — Расширить `EventTap` helper до полного варианта Ice'овского `scrombleEvent`. Двойной tap chain.
  - Файлы: `Sources/HelloWork/Bridging/EventTap.swift`, `MenuBarItemMover.swift`
  - Acceptance: build clean.

- [ ] **TASK-G02 [verify]** — TASK-G01. Тест A03.

- [ ] **TASK-G03 [impl]** — Если **И ЭТО** не помогло — STOP. Документируем что попробовали в `audit/CONTEXT.md` секции 7. Обсуждаем с юзером дальнейшие пути (например, пересмотреть подход — Login Items хайдинг через preferences API вместо drag).

### Phase Z — Cleanup + единый релиз (4 tasks)

> Запускаем когда менюбар-hider работает на смоук-тесте юзера.

- [ ] **TASK-Z01 [impl]** — Cleanup кода: удалить debug-кнопку «Test single move» (или оставить за dev-mode гарантированно), удалить лишние devlog'и (оставить только важные), убрать комментарии типа «попробовали 3 варианта». Оставить только финальный код + WHY-комменты на нетривиальные шаги.
  - Файлы: `MenuBarItemMover.swift`, `MenubarHiderController.swift`, `EventTap.swift`, `CGEventExtensions.swift`, `SettingsAppTab.swift`.
  - Acceptance: build clean, debug-кнопка скрыта в release-сборке, devlog категории `mover`/`hider`/`bridge` info-only.

- [ ] **TASK-Z02 [verify]** — TASK-Z01

- [ ] **TASK-Z03 [impl]** — Финальный релиз:
  - `./scripts/bump.sh patch`
  - `./scripts/build.sh && ./scripts/package.sh`
  - dev_log entry с описанием что фиксили (Ice-style protocol, suppression permits, target-item destination)
  - `git add -A && git commit -m "Hello work X.Y.Z — Menubar hider works (Ice-style rewrite)"`
  - `git tag vX.Y.Z && git push origin main && git push origin vX.Y.Z`
  - `gh release create vX.Y.Z dist/HelloWork-X.Y.Z.dmg dist/HelloWork.dmg --title "..." --notes "..."`
  - Acceptance: GitHub Release создан, юзер скачивает свежую версию, hider работает.

- [ ] **TASK-Z04 [verify]** — TASK-Z03

---

## 6. Metrics «9.5 / 10»

После закрытия Phase Z:

- ✅ Юзер жмёт хоткей → menubar items (не Apple-managed) уезжают за край экрана за ≤ 500ms.
- ✅ Юзер жмёт хоткей повторно → items возвращаются на свои места в правильном порядке.
- ✅ Auto-hide при focus mode / schedule работает.
- ✅ Peek (временно показать) работает.
- ✅ Не нужен Screen Recording permission. Достаточно Accessibility.
- ✅ Devlog показывает чёткий success-path; на failure — конкретную причину (timeout / no AX / event-not-received).
- ✅ Нет регрессий в соседних фичах (focus, schedule, legends, updates).

---

## 7. Follow-up tasks

> Verify-таски ДОПИСЫВАЮТ сюда новые задачи если обнаружат регрессию или non-trivial gap.

(пусто на старте цикла)
