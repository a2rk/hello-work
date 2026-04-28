# HelloWork — Single-App Distribution Refactor (v0.12)

> Этот файл — **единственный источник истины** для агента, выполняющего таски. Перед каждой итерацией читать целиком, после — обновлять статусы.
>
> **Цель цикла**: убрать stub-installer pattern. Перейти к **одному `HelloWork.app`** в `/Applications`, который ставится drag-to-Applications, обновляется in-place через UpdateInstaller, переживает обновления без потери TCC/UserDefaults. Существующих юзеров (которые ставили stub) — мигрируем тихо.
>
> **Версионирование**: одна патч-версия на таск. Старт `0.11.6` → финиш **`0.12.0`** (минорный bump-флаг distribution-overhaul). Каждый таск = `gh release create`.

---

## 1. Зачем рефакторинг

### Симптом, который ловит юзер

1. Скачивает `HelloWork.dmg` (статичное имя) — внутри `HWInstaller.app`.
2. Тащит `HWInstaller` в `/Applications`, выдаёт права на запуск (Gatekeeper).
3. Stub запускается, качает engine (~3.6 MB), кладёт в `~/Library/Application Support/HelloWork/HelloWork.app`, запускает.
4. **Engine виден в Spotlight, но НЕТ в `/Applications`**. Юзер не понимает где приложение, как его повторно открыть, как обновить вручную, как удалить.
5. `/Applications/HWInstaller.app` остаётся торчать после установки — выглядит как мусор.

### Что с этим не так на уровне архитектуры

- **Two-bundle setup**: `dev.helloworkapp.macos` (stub) + `dev.helloworkapp.macos.engine` (engine). Два разных code-signing identifier, две иконки (ещё и инвертированные «чтобы отличать»), двойная путаница в TCC-настройках.
- **Engine в нестандартной локации**: `~/Library/Application Support/HelloWork/HelloWork.app`. macOS не предполагает .app в этой папке. Spotlight, Launchpad, Dock, drag-to-trash — всё ломается или работает странно.
- **UpdateInstaller уже умеет in-place self-update** (`Sources/HelloWork/Updates/UpdateInstaller.swift`) — скачивает DMG, заменяет `Bundle.main.bundleURL` через детач-скрипт. Stub стал ненужным.
- **Discoverability нулевая**: новый юзер качает DMG → видит «HWInstaller» → ставит → больше никогда не видит «HWInstaller», вместо него где-то «HelloWork». Cognitive cost высокий.

### Что должно стать

- Один `/Applications/HelloWork.app`. Ставится drag-to-Applications. Запускается из Spotlight, Launchpad, Dock как любая нормальная mac-аппа.
- Обновления — кнопка «Install update» в Preferences → Updates. UpdateInstaller заменяет себя в `/Applications` через helper-скрипт (механика уже работает).
- Существующим юзерам со stub-engine layout — тихая авто-миграция при первом запуске новой версии: убираем `~/Library/Application Support/HelloWork/HelloWork.app`, убираем `/Applications/HWInstaller.app`, перерегистрируем LoginItem на новый путь. Toast-уведомление: «HelloWork moved to /Applications».
- `dev.helloworkapp.macos.engine` остаётся bundle ID единственного приложения — TCC grants и UserDefaults сохраняются у существующих юзеров. Stub-ID `dev.helloworkapp.macos` забывается.

### Что должно быть «9.5/10»

- **Discoverability**: новый юзер за <30с понимает где приложение и как его запускать. DMG имеет background-image со стрелкой и `/Applications` shortcut.
- **Migration safety**: апгрейд со stub-engine на новый single-app — без потери favoriteLegendIds, managedApps, applied state, settings, devlog. TCC permissions не сбрасываются.
- **Update path**: UpdateInstaller замещает себя в `/Applications` через helper-скрипт без app-translocation проблем. После update — корректный relaunch.
- **Rollback**: если что-то сломалось — юзер тащит .app из старого DMG в /Applications, всё работает (потому что UserDefaults+TCC keyed по bundle ID, не по пути).
- **Clean uninstall**: drag-to-trash → Move to Trash → готово. UserDefaults и App Support чистятся отдельно (без in-app кнопки в этом цикле — out of scope).
- **Documentation**: README.md обновлён, в нём чёткая инструкция «download → drag → run».
- **Dead code = 0**. Stub-source, stub-scripts, инвертированная иконка — удалены полностью.

---

## 2. Текущая инфраструктура (что трогаем)

### Файлы, которые удаляются полностью

```
HelloWork/
├── Sources/HelloWorkStub/             ← удаляется вся папка
│   ├── EngineManager.swift
│   ├── StubAppDelegate.swift
│   ├── StubL10n.swift
│   ├── StubView.swift
│   └── main.swift
├── scripts/
│   ├── build_stub.sh                  ← удаляется
│   ├── package_stub.sh                ← удаляется
│   ├── Info.plist.stub.template       ← удаляется
│   ├── AppIconInstaller.iconset/      ← удаляется
│   └── AppIconInstaller.icns          ← удаляется
└── Package.swift                      ← убираем target HelloWorkStub
```

### Файлы, которые меняются

```
HelloWork/
├── scripts/
│   ├── build.sh                       ← убираем "engine"-терминологию,
│   │                                     dist/HelloWork.app (без подпапки engine/)
│   ├── package.sh                     ← DMG с /Applications symlink + drag-layout,
│   │                                     volume name "HelloWork", статичный
│   │                                     HelloWork.dmg + версионный HelloWork-X.Y.Z.dmg
│   └── Info.plist.template            ← остаётся, но проверим нет ли stub-only ключей
├── Sources/HelloWork/
│   ├── App/AppDelegate.swift          ← + одноразовая миграция при старте
│   └── App/AppState.swift             ← + одноразовый toast «migrated to /Applications»
└── README.md                          ← инструкция установки переписывается
```

### Файлы, которые не трогаем

- `Sources/HelloWork/Updates/UpdateInstaller.swift` — уже работает с `/Applications` через helper-скрипт. `canSelfInstall` корректно проверяет writability родителя `Bundle.main.bundleURL`.
- Bundle ID `dev.helloworkapp.macos.engine` — **сохраняется**. Это критично для TCC grants и UserDefaults continuity у существующих юзеров.
- `setup_signing.sh` + `HelloWork Self-Signed` cert — те же. TCC ключуется по cert hash + bundle ID, оба не меняются → grants выживают.
- Legends/focus/schedule/stats/permissions/menubar — НЕ ТРОГАЕМ.

### Что кладём пользователю на диск (новый layout)

```
/Applications/HelloWork.app                    ← единственное место установки
~/Library/Preferences/dev.helloworkapp.macos.engine.plist   ← сохраняется как было
~/Library/Application Support/HelloWork/       ← сохраняется (devlog.txt, stats.json),
│                                                 БЕЗ HelloWork.app внутри после миграции
└── (HelloWork.app удалён)
~/Library/Caches/dev.helloworkapp.macos.engine/        ← сохраняется
~/Library/HTTPStorages/dev.helloworkapp.macos.engine/  ← сохраняется
```

### Migration matrix (что бывает с существующими юзерами)

| Старое состояние | Действие при первом запуске v0.12 из /Applications |
|---|---|
| `/Applications/HelloWork.app` есть, `~/Library/Application Support/HelloWork/HelloWork.app` есть, `/Applications/HWInstaller.app` есть | Тихо удаляем engine-копию из App Support и HWInstaller из /Applications. Re-register SMAppService на новый путь. Показать toast «moved to /Applications». |
| `/Applications/HelloWork.app` есть, App Support пустой от .app, HWInstaller отсутствует | Чистый новый юзер — ничего не делаем, миграция no-op. |
| `/Applications/HelloWork.app` нет, App Support содержит HelloWork.app, HWInstaller есть | Юзер запустил старый stub-flow — игнорируем (мы запускаемся из /Applications, иначе нас здесь не было бы). Не наш кейс. |
| `/Applications/HelloWork.app` есть, App Support contains HelloWork.app, HWInstaller отсутствует | Юзер мигрировал .app вручную ранее — стандартная миграция (удалить App Support .app). |

### LoginItem (SMAppService)

Если у юзера было включено «Launch at Login», SMAppService зарегистрирован на путь `~/Library/Application Support/HelloWork/HelloWork.app`. После миграции этот путь удалится — login item зависнет битый. Решение в Phase B: в migration step вызываем `SMAppService.mainApp.unregister()` ДО удаления старой engine-копии (чтобы система знала старый path и удалила запись), потом — если юзер хочет — `register()` с новым путём (Bundle.main укажет на /Applications). Но безопаснее: после миграции `launchAtLogin` сбрасывается в false, юзер сам включает повторно. Это коммуницируется в toast'е.

---

## 3. Архитектура миграционного флоу

### Точка входа: `AppDelegate.applicationDidFinishLaunching`

```swift
// pseudo-code порядка действий при старте
1. consumePreviousUpdateStatus()  // существующий механизм UpdateInstaller
2. MigrationManager.runIfNeeded() // НОВОЕ
3. ... остальной existing bootstrap (state init, permissions, etc.)
```

### `MigrationManager` (новый файл)

`Sources/HelloWork/App/MigrationManager.swift`:

```
@MainActor
enum MigrationManager {
    static let migrationFlagKey = "helloWorkDistributionMigratedTo_0_12"

    static func runIfNeeded(state: AppState) async
    // 1. Если UserDefaults флаг migrationFlagKey == true → return.
    // 2. Если Bundle.main.bundleURL не в /Applications → return (we're in dev or
    //    weird location; не мигрируем).
    // 3. Detect и cleanup:
    //    a. Если Application Support/HelloWork/HelloWork.app — удалить
    //    b. Если /Applications/HWInstaller.app — переместить в Trash через
    //       NSWorkspace.recycle (юзер увидит и сможет восстановить если что)
    //    c. Если SMAppService был зарегистрирован — unregister (state перечитает)
    // 4. Set флаг в true.
    // 5. Запланировать toast: state.queueMigrationToast = true
}
```

### Toast после миграции

`AppState.queueMigrationToast: Bool` — @Published, set MigrationManager после успешной миграции, читает PrefsView/MainView и показывает one-time pill «HelloWork moved to /Applications. Old installer removed.» с кнопкой «Got it» и автодисмиссом 8с.

### Update flow (без изменений)

UpdateInstaller уже работает корректно когда `Bundle.main.bundleURL` в `/Applications`:
- `canSelfInstall == true` (parent /Applications writable obviously)
- helper-script `rm -rf /Applications/HelloWork.app && cp -R /Volumes/.../HelloWork.app /Applications/ && codesign && open` — рабочий путь
- TCC grants persist (тот же cert + bundle ID + bundle path)

В цикле верифицируем end-to-end через manual smoke (Phase F).

---

## 4. Глобальные правила выполнения тасков

1. **Ничего вне scope**: только distribution / migration / build-pipeline / docs. Legends, hider, focus, schedule, stats, permissions, menubar — НЕ ТРОГАЕМ.
2. **Bundle ID не меняем**. Никогда. Даже если очень хочется. Это сломает TCC и UserDefaults у тысяч юзеров (потенциально).
3. **Self-signed cert не пересоздаём**. То же — TCC keys из login keychain не теряем.
4. **Migration идемпотентен**. Запуск дважды = no-op после первого. Флаг в UserDefaults.
5. **Никаких новых абстракций ради будущего**. MigrationManager — один файл, минимум кода.
6. **Comments — только WHY**. Не описываем что делает `removeItem`.
7. **i18n**: все user-facing строки (toast, README) — en + ru + zh, в строгом порядке полей `Translation.swift`.
8. **devlog**: точки `devlog("migration", ...)` в MigrationManager (start, each step success/fail, finish).
9. **Verify-таск НЕ правит код продакта**. Только смотрит diff, тестит, документирует.
10. **Релиз каждый таск**. Старт 0.11.6, финал 0.12.0 (минорный).

### Когда релизить (per-task политика)

После каждого закрытого таска (impl или verify):
```bash
./scripts/bump.sh patch       # для финального TASK-D01: bump.sh minor
./scripts/build.sh && ./scripts/package.sh
# (build_stub.sh / package_stub.sh — удалены в TASK-B03)
# entry в dev_log.json (1-3 sentence customMessage, 2-4 points)
git add -A && git commit -m "Hello work X.Y.Z — TASK-NNN: <name>"
git tag vX.Y.Z && git push origin main && git push origin vX.Y.Z
gh release create vX.Y.Z dist/HelloWork-X.Y.Z.dmg dist/HelloWork.dmg \
    --title "..." --notes "..."
```

В новом цикле — два DMG-артефакта в релизе:
- `HelloWork-X.Y.Z.dmg` — версионный, для UpdateInstaller fetch'а
- `HelloWork.dmg` — статичная копия latest (для landing page / README link)

---

## 5. Task Ledger

Формат: `[ ] = pending`, `[~] = in_progress`, `[x] = done`. Verify-таск нельзя пометить done пока impl выше не done.

### Phase A — Migration safety net (8 tasks)

Безопасность существующих юзеров — **первая** фаза. Если миграция не работает — нельзя катить ничего другого.

- [x] **TASK-A01 [impl]** — Создать `Sources/HelloWork/App/MigrationManager.swift`. Public API: `static func runIfNeeded(state: AppState) async`. Основной алгоритм:  → released as v0.11.6
  1. Проверка UserDefaults `helloWorkDistributionMigratedTo_0_12 == true` → return immediately.
  2. Проверка `Bundle.main.bundleURL.path.hasPrefix("/Applications/")` → если нет (dev build, AppTranslocation), флаг НЕ ставим, return.
  3. Detection блок: `oldEnginePath = ~/Library/Application Support/HelloWork/HelloWork.app`, `oldStubPath = /Applications/HWInstaller.app`. Логируем что нашли через `devlog("migration", ...)`.
  4. Cleanup блок (each в отдельном do-catch, partial-failure tolerant):
     - Если oldEnginePath exists → `try FileManager.default.removeItem(at:)`.
     - Если oldStubPath exists → `try NSWorkspace.shared.recycle(at:)` (в Trash, не permanent).
  5. SMAppService: если `state.launchAtLogin == true` → `try? SMAppService.mainApp.unregister()` (старая регистрация на удалённый path). Сбрасываем `state.launchAtLogin = false` через helper, юзер сам пере-включит из new path.
  6. Set флаг `helloWorkDistributionMigratedTo_0_12 = true`.
  7. `state.queueMigrationToast = true` (через @MainActor).
  - Файлы: `Sources/HelloWork/App/MigrationManager.swift` (новый).
  - Acceptance: Unit-thinkable scenarios (ниже Phase F): чистый new install — no-op без ошибок и без флага = false. Stub-engine layout — все три действия выполняются, флаг = true. Повторный запуск — return на step 1.

- [x] **TASK-A02 [verify]** — TASK-A01  → OK. Subtle: SMAppService.mainApp ключуется к текущему bundle path, поэтому orphaned регистрация старого engine очищается macOS auto-cleanup'ом — наш unregister идёт для нового пути (no-op если не registered, не падает). Acceptable. Released as v0.11.7

- [x] **TASK-A03 [impl]** — Подключить `MigrationManager.runIfNeeded(state:)` в `AppDelegate.applicationDidFinishLaunching` ПОСЛЕ `state` initialized но ДО `state.checkForUpdates()` и до permissions onboarding. Внутри Task { await ... }.  → released as v0.11.8 (sync-вызов: API не async, и runs быстро — Task wrap не нужен)
  - Файлы: `Sources/HelloWork/App/AppDelegate.swift`.
  - Acceptance: Migration runs once per fresh install of v0.12. На второй запуск — return-on-flag, devlog показывает «already migrated».

- [x] **TASK-A04 [verify]** — TASK-A03  → OK. Order corretly: consumePreviousUpdateStatus → MigrationManager.runIfNeeded → checkForUpdates. Sync вызов оправдан (миграция fast, не async). Edge: NSWorkspace.recycle завершается callback'ом; флаг ставится до его completion → если recycle silently failed, HWInstaller может остаться в /Applications, девлог запишет ошибку. Acceptable. Released as v0.11.9

- [x] **TASK-A05 [impl]** — Добавить `AppState.queueMigrationToast: Bool` (`@Published`, persists в UserDefaults НЕ нужно — one-time-flag в migration сам по себе).  → released as v0.11.10 (queueMigrationToast добавлен, MigrationManager сетит true в step 4, 3 translation keys EN/RU/ZH)
  - 3 translation keys: `migrationToastTitle`, `migrationToastBody`, `migrationToastDismiss`. EN/RU/ZH.
    - EN: «HelloWork moved to /Applications» / «Old installer removed. Launch at Login was reset — re-enable it in Settings if needed.» / «Got it»
    - RU: «HelloWork переехал в /Applications» / «Старый инсталлер убран в Корзину. Автозапуск сброшен — включи заново в Настройках если нужно.» / «Понятно»
    - ZH: «HelloWork 已移至 /Applications» / «旧安装器已移至废纸篓。登录启动已重置 — 如需要请在设置中重新启用。» / «知道了»
  - Файлы: `Sources/HelloWork/App/AppState.swift`, `Sources/HelloWork/Domain/Translation.swift`, `Sources/HelloWork/Domain/Translations.swift`.
  - Acceptance: 3 ключа добавлены в strict order в Translation struct и во все 3 локали Translations.swift. Build clean.

- [x] **TASK-A06 [verify]** — TASK-A05  → OK. queueMigrationToast @Published триггерит SwiftUI re-render. MigrationManager сетит при .migrated path. 3 translation keys в strict order match Translation struct, все 3 локали (EN/RU/ZH) populated. Регрессий нет. Released as v0.11.11

- [x] **TASK-A07 [impl]** — Toast UI: subtle banner-card в верхней части PrefsView (или там где сейчас отображается corruption banner — паттерн уже есть). Auto-dismiss через 8 сек ИЛИ click «Got it». Только если `state.queueMigrationToast == true`. После dismiss — set false (в памяти; не возвращается).  → released as v0.11.12 (новый MigrationToastBanner.swift component, accent-colored card с arrow.uturn icon + auto-dismiss через DispatchWorkItem 8s)
  - Файлы: `Sources/HelloWork/Preferences/PrefsView.swift` (или новый MigrationToastView если правильнее модульно).
  - Acceptance: При запуске после миграции — toast виден один раз, dismissible, не возвращается. Не появляется на чистом install.

- [x] **TASK-A08 [verify]** — TASK-A07  → OK. Banner показывается только при queueMigrationToast=true, auto-dismiss DispatchWorkItem 8s корректно cancel'ится onDisappear (rapid nav безопасен), click button корректно сетит false. SwiftUI re-renders banner away. Регрессий нет. **Phase A CLOSED (8/8).** Released as v0.11.13

### Phase B — Build pipeline cleanup (8 tasks)

Удаляем stub-инфраструктуру. Build выдаёт один `dist/HelloWork.app`.

- [x] **TASK-B01 [impl]** — `Package.swift`: убрать `.executableTarget(name: "HelloWorkStub")`. Только HelloWork target остаётся.  → released as v0.11.14 (с этого момента pipeline только build.sh + package.sh, stub-скрипты перестают вызываться)
  - Файл: `Package.swift`.
  - Acceptance: `swift build --product HelloWork` собирается, `swift build --product HelloWorkStub` падает с «product not found».

- [x] **TASK-B02 [verify]** — TASK-B01  → OK. swift build --product HelloWork → success. swift build --product HelloWorkStub → 'no product named HelloWorkStub' (acceptance criteria match). Released as v0.11.15

- [x] **TASK-B03 [impl]** — Удалить файлы:  → released as v0.11.16 (Sources/HelloWorkStub/, build_stub.sh, package_stub.sh, Info.plist.stub.template, AppIconInstaller.iconset/, AppIconInstaller.icns удалены через git rm; build.sh и generate_icon.swift очищены от installer-icon refs)
  - `Sources/HelloWorkStub/` (вся папка)
  - `scripts/build_stub.sh`
  - `scripts/package_stub.sh`
  - `scripts/Info.plist.stub.template`
  - `scripts/AppIconInstaller.iconset/` (вся папка)
  - `scripts/AppIconInstaller.icns`
  - Acceptance: `git rm -r` отрабатывает, `swift build` чистый, ничего не ссылается на удалённые файлы.

- [x] **TASK-B04 [verify]** — TASK-B03  → OK. Grep по всем Sources/, scripts/, Package.swift даёт 0 stub-references. Build clean. Released as v0.11.17

- [ ] **TASK-B05 [impl]** — Refactor `scripts/build.sh`:
  - Убрать комменты про «engine» / «stub скачивает». Это просто `HelloWork.app`.
  - Output path: `dist/HelloWork.app` (без подпапки `dist/engine/`).
  - Остальное — bundle ID, sign flow, icons — без изменений.
  - Файлы: `scripts/build.sh`.
  - Acceptance: `./scripts/build.sh` создаёт `dist/HelloWork.app`, существующая `dist/engine/HelloWork.app` (если осталась) либо удаляется в скрипте, либо игнорируется.

- [ ] **TASK-B06 [verify]** — TASK-B05

- [ ] **TASK-B07 [impl]** — Refactor `scripts/package.sh`:
  - Output: TWO DMG'ов:
    - `dist/HelloWork-X.Y.Z.dmg` — версионный (для UpdateInstaller).
    - `dist/HelloWork.dmg` — статичная latest-копия (для landing / README).
  - DMG layout: `HelloWork.app` + symlink `Applications` → `/Applications`. Volume name «HelloWork». UDZO compression.
  - (Background image с стрелкой — out of scope этого таска; добавим только если останется время в Phase D.)
  - Источник: `dist/HelloWork.app` (новый путь после TASK-B05).
  - Файлы: `scripts/package.sh`.
  - Acceptance: после `./scripts/build.sh && ./scripts/package.sh` — два .dmg-файла существуют. Mount каждого показывает HelloWork.app + Applications symlink. Drag работает.

- [ ] **TASK-B08 [verify]** — TASK-B07

### Phase C — Update flow validation (4 tasks)

UpdateInstaller уже работает. Но мы убрали stub — надо убедиться что ничего не сломалось и devlog message не упоминают engine.

- [ ] **TASK-C01 [impl]** — Pass через `UpdateInstaller.swift` + `UpdatesView.swift`:
  - Убрать упоминания «engine» в comments / log strings (если есть).
  - Проверить `canSelfInstall` логику для нового пути `/Applications/HelloWork.app` (visually).
  - Helper-скрипт внутри `spawnHelperAndExit` — fallback path был `/Applications/HWInstaller-fallback.app`. Поменять на `/Applications/HelloWork-fallback.app`.
  - НЕ менять core логику замены — она проверена прошлым циклом.
  - Файлы: `Sources/HelloWork/Updates/UpdateInstaller.swift`, `Sources/HelloWork/Preferences/Updates/UpdatesView.swift` (если есть текст).
  - Acceptance: `swift build` clean. UpdateInstaller код больше не упоминает engine/stub. Fallback path обновлён.

- [ ] **TASK-C02 [verify]** — TASK-C01

- [ ] **TASK-C03 [impl]** — Post-update verification: после relaunch новой версии (детектируется через сравнение `Bundle.main.shortVersion` с `state.previousLaunchVersion` из UserDefaults), показываем кратковременный info banner «Updated to vX.Y.Z». Auto-dismiss 5с. Сохраняем version after dismiss.
  - 1 translation key `updateCompletedToast(_ version: String) -> String`. EN/RU/ZH.
    - EN: «Updated to v\(version)»
    - RU: «Обновлено до v\(version)»
    - ZH: «已更新至 v\(version)»
  - Файлы: `AppState.swift` (поле previousLaunchVersion + queueUpdateToast), `Translation.swift`, `Translations.swift`, `PrefsView.swift` (rendering — рядом с migration toast).
  - Acceptance: В первом запуске после `bump.sh patch` + UpdateInstaller-цикла → toast «Updated to v0.11.X». Во втором — нет.

- [ ] **TASK-C04 [verify]** — TASK-C03

### Phase D — DMG polish (опционально, но в скоупе) (4 tasks)

Лучше выглядящий DMG → меньше вопросов «куда тащить».

- [ ] **TASK-D01 [impl]** — DMG background image: 600×400 PNG с логотипом + стрелкой → Applications. Положить в `scripts/dmg-background.png`. В `package.sh` — после mount staging, копируем PNG в `.background/background.png` внутри volume + AppleScript для positioning через `osascript`. Если background-image нет (graceful) — DMG как был после B07. Не падать.
  - Файлы: `scripts/dmg-background.png` (новый, художник или placeholder), `scripts/package.sh` (обновление).
  - Acceptance: mount DMG → красивый layout. Если PNG нет — DMG всё равно собирается, просто без background.

- [ ] **TASK-D02 [verify]** — TASK-D01

- [ ] **TASK-D03 [impl]** — Volume icon (`.VolumeIcon.icns` внутри DMG) — копия `scripts/AppIcon.icns`. Чтобы в Finder DMG показывался с нашей иконкой а не generic.
  - Файлы: `scripts/package.sh`.
  - Acceptance: mount DMG → finder volume icon = HelloWork.

- [ ] **TASK-D04 [verify]** — TASK-D03

### Phase E — Documentation (4 tasks)

- [ ] **TASK-E01 [impl]** — `README.md` обновление installation секции:
  - Убрать упоминания HWInstaller / stub / Application Support.
  - Один абзац: «Download HelloWork.dmg → drag HelloWork to Applications → first launch right-click Open (Gatekeeper) → grant Accessibility/Screen Recording permissions in onboarding».
  - Update: «In-app: Settings → Updates → Install latest».
  - Uninstall: «Drag HelloWork.app to Trash. Optionally remove `~/Library/Application Support/HelloWork/` and `~/Library/Preferences/dev.helloworkapp.macos.engine.plist`.»
  - Файлы: `README.md`.
  - Acceptance: README не содержит «HWInstaller», «stub», «engine.app». Содержит drag-to-Applications.

- [ ] **TASK-E02 [verify]** — TASK-E01

- [ ] **TASK-E03 [impl]** — Migration note in `dev_log.json` для **0.12.0 release**: customMessage объясняет что это distribution overhaul, как работает миграция, почему юзер видит toast.
  - Это часть финального TASK-F01 (final bump). Здесь — заготовка template-текста чтобы при финале не импровизировать.
  - Файлы: `audit/CONTEXT.md` секция 8 ниже (template сразу запишем).

- [ ] **TASK-E04 [verify]** — TASK-E03

### Phase F — Final regression + 0.12.0 (4 tasks)

- [ ] **TASK-F01 [impl]** — `bump.sh minor` → 0.11.X → 0.12.0. Final dev_log entry с использованием template из E03. Большой changelog список Phase A-E. Включить smoke list (Section 8 ниже).
  - Файлы: VERSION, BUILD, dev_log.json.
  - Acceptance: версия 0.12.0, релиз создан, два DMG залиты.

- [ ] **TASK-F02 [verify]** — TASK-F01

- [ ] **TASK-F03 [impl]** — Manual smoke pass (по smoke list секции 8). Записать результат каждого пункта в commit message + dev_log как «smoke: 1/6 ok, 2/6 ok, ...». Если что-то не ОК — следующий цикл.
  - Файлы: dev_log.json (entry для 0.12.1 если smoke-fix нужен).
  - Acceptance: все 6 пунктов smoke прошли. Если нет — follow-up.

- [ ] **TASK-F04 [verify]** — TASK-F03

---

## 6. Метрики «9.5 / 10»

После закрытия всех тасков должны быть верифицированы:

- ✅ Один `HelloWork.app` в `/Applications`. Discoverable через Spotlight, Launchpad, Dock.
- ✅ DMG drag-to-Applications работает с первого раза. Volume имеет `Applications` symlink.
- ✅ Существующие юзеры (stub-engine layout) при старте новой версии видят toast и автоматически очищаются от:
  - `~/Library/Application Support/HelloWork/HelloWork.app` (удалён)
  - `/Applications/HWInstaller.app` (в Trash)
- ✅ TCC permissions (Accessibility, Screen Recording) переживают миграцию — bundle ID и cert hash не менялись.
- ✅ UserDefaults (favorites, managedApps, applied legend, settings) переживают миграцию — bundle ID `dev.helloworkapp.macos.engine` сохранён.
- ✅ Update flow через UpdateInstaller работает из нового layout (`/Applications/HelloWork.app` → in-place replace via helper-script).
- ✅ Post-update toast «Updated to vX.Y.Z» появляется один раз после auto-update.
- ✅ Source-tree чистый: нет `Sources/HelloWorkStub/`, нет `build_stub.sh`, нет `package_stub.sh`, нет `Info.plist.stub.template`, нет `AppIconInstaller*`. Package.swift имеет один target.
- ✅ README.md обновлён без упоминаний stub/engine/Application Support как install location.
- ✅ Migration идемпотентна — повторный запуск приложения без re-install не делает ничего (флаг в UserDefaults).
- ✅ Build pipeline один раз `./scripts/build.sh && ./scripts/package.sh` создаёт оба DMG (versioned + static).
- ✅ devlog содержит «migration» категорию для каждого нетривиального шага миграции.

---

## 7. Smoke list (для TASK-F03 manual run)

Запускается на свежей mac-машине / VM или после полного wipe (см. процедуру в секции 9). 6 сценариев:

1. **Fresh install (новый юзер, без stub-installer history)**
   - Скачать `HelloWork.dmg` (latest release)
   - Mount, drag HelloWork → Applications
   - Right-click → Open (Gatekeeper)
   - Запустить, пройти permissions onboarding (Accessibility + Screen Recording)
   - Verify: `/Applications/HelloWork.app` есть, `~/Library/Application Support/HelloWork/HelloWork.app` НЕТ, `/Applications/HWInstaller.app` НЕТ
   - Verify: migration toast НЕ показывается (новый юзер, мигрировать нечего)

2. **Migration (старый юзер со stub-engine layout)**
   - Pre-state: установлен v0.11.5 через stub (есть `/Applications/HWInstaller.app` и `~/Library/Application Support/HelloWork/HelloWork.app`)
   - Установить v0.12.0 поверх: drag `/Applications/HelloWork.app` (новый из DMG) поверх существующего `/Applications/HWInstaller.app`? Нет — это разные имена. Drag `HelloWork.app` в `/Applications/` рядом, запустить
   - Verify: `~/Library/Application Support/HelloWork/HelloWork.app` удалился
   - Verify: `/Applications/HWInstaller.app` в Trash
   - Verify: migration toast показывается ОДИН раз
   - Verify: favoriteLegendIds, managedApps, applied legend, settings — все на месте (UserDefaults сохранён)
   - Verify: Accessibility и Screen Recording permissions всё ещё granted (TCC не сбросился)

3. **In-app update (auto-update path)**
   - Pre: установлен v0.12.0
   - Backend: создать релиз v0.12.1
   - В app: Settings → Updates → Install latest
   - Verify: app перезапускается через UpdateInstaller
   - Verify: `/Applications/HelloWork.app` имеет новую версию (Info.plist CFBundleShortVersionString)
   - Verify: post-update toast «Updated to v0.12.1»
   - Verify: TCC grants persist

4. **Manual fresh download replaces existing install**
   - Pre: v0.12.0 установлен
   - Download v0.12.1 dmg, drag → Applications, replace existing
   - Запустить
   - Verify: версия 0.12.1, всё работает, post-update toast НЕ показывается (мы не auto-updated, а replaced — это допустимая разница; or показывается, но это OK тоже)
   - Verify: data preserved

5. **Idempotent migration**
   - Pre: v0.12.0 установлен, миграция уже сработала
   - Quit + relaunch
   - Verify: migration toast НЕ показывается (флаг сработал)
   - Verify: devlog содержит «migration: already done, skip»

6. **Clean uninstall**
   - Drag `/Applications/HelloWork.app` to Trash
   - Запустить app — не запускается (его нет)
   - Optional cleanup: `~/Library/Application Support/HelloWork/`, plist, Caches, HTTPStorages
   - Verify: после переустановки v0.12.0 — fresh-install path (точка 1).

---

## 8. Template для финального dev_log entry (TASK-F01)

```json
{
    "version": "0.12.0",
    "date": "<current-date>",
    "customMessage": "🚀 Distribution overhaul. Один HelloWork.app в /Applications вместо stub+engine pattern. Существующие юзеры мигрируются автоматически: старый engine из ~/Library/Application Support убирается, HWInstaller в Trash, toast уведомляет. UserDefaults и TCC grants сохраняются (bundle ID не меняется).",
    "main": "Phase A migration safety (idempotent flag, auto-cleanup), B build pipeline cleanup (-stub source, -2 scripts), C UpdateInstaller validated for /Applications path, D DMG polish (background + volume icon), E README rewritten. 0.11.X→0.12.0 minor bump signals distribution overhaul.",
    "points": [
        "Single .app — discoverable through Spotlight/Launchpad/Dock",
        "Drag-to-Applications DMG layout",
        "Auto-migration from stub-engine layout (idempotent)",
        "TCC + UserDefaults preserved across migration",
        "In-app updates work in-place at /Applications",
        "Smoke list 6/6 passed"
    ],
    "dmgUrl": "https://github.com/a2rk/hello-work/releases/download/v0.12.0/HelloWork-0.12.0.dmg"
}
```

---

## 9. Procedure: full local wipe для smoke-теста точки 1

(Из переписки 27 апреля — для воспроизводимости.)

```bash
brew uninstall --cask hellowork \
  && rm -rf "$HOME/Library/Application Support/HelloWork" \
  && rm -f  "$HOME/Library/Preferences/dev.helloworkapp.macos.engine.plist" \
  && rm -rf "$HOME/Library/Caches/dev.helloworkapp.macos.engine" \
  && rm -rf "$HOME/Library/HTTPStorages/dev.helloworkapp.macos.engine" \
  && rm -f  "$HOME/Library/Caches/Homebrew/Cask/HelloWork.dmg--latest.dmg" \
  && rm -f  "$HOME/Library/Caches/Homebrew/downloads/"*HelloWork.dmg \
  && defaults delete dev.helloworkapp.macos.engine 2>/dev/null; \
  killall cfprefsd 2>/dev/null
```

TCC reset (если нужно эмулировать совсем чистого юзера — иногда нужно для тестирования onboarding):
```bash
tccutil reset Accessibility dev.helloworkapp.macos.engine
tccutil reset ScreenCapture dev.helloworkapp.macos.engine
```

---

## 10. Follow-up tasks

> Verify-таски ДОПИСЫВАЮТ сюда новые задачи если обнаружат регрессию или non-trivial gap в pre-existing коде.

(Пусто на старте цикла.)
