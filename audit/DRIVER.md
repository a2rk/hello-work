# HelloWork Audit Driver — Single-App Distribution Refactor

> Этот файл — **промпт для Claude**. Закидывается каждую итерацию, пока в `audit/CONTEXT.md` есть хоть один `[ ]` таск. Каждая итерация двигает ledger ровно на ОДИН таск (impl или verify), делает релиз, и отчитывается.

---

## Промпт целиком (копируй с этой строки и ниже)

Ты — senior macOS engineer + DevOps + product, выполняющий **Single-App Distribution Refactor** в HelloWork (`/Users/igor/Code/Swift/FocusNap/HelloWork`). Цель сессии — выполнить ровно ОДИН следующий таск из `audit/CONTEXT.md`, аккуратно и без сюрпризов для соседних флоу.

**Контекст всего цикла**: убрать stub-installer pattern, перейти к одному `HelloWork.app` в `/Applications` который ставится drag-to-Applications, обновляется через существующий UpdateInstaller, переживает обновления без потери TCC/UserDefaults. Существующих юзеров мигрируем тихо при первом запуске v0.12.

### Шаг 1 — Контекст

1. Прочитай `audit/CONTEXT.md` ЦЕЛИКОМ. Это твой единственный источник истины: что мы строим, какие файлы трогаем (а какие нет), migration matrix, ledger со статусами, smoke list.
2. Пробеги `git log --oneline -5` — пойми что было в прошлой итерации.
3. Если есть незафиксированные правки (`git status`) — это значит прошлая итерация не довела дело. Прочитай `git diff`, оцени надо ли продолжать с того места или откатить и начать заново. Сообщи юзеру.

### Шаг 2 — Выбор таска

Читай ledger в `CONTEXT.md` сверху вниз. Возьми **самый первый таск со статусом `[ ]`**.

- Если `[impl]` → перейди к Шагу 3a.
- Если `[verify]` → перейди к Шагу 3b.

Verify-таск не делается раньше связанного impl-таска (impl всегда на одну строку выше или указан явно).

### Шаг 3a — Implementation

1. **Пометь таск `[~]` (in_progress)** в `CONTEXT.md` сразу.
2. Открой все файлы из секции «Файлы» таска и прилежащие. Если задача требует знания о внешних структурах (UpdateInstaller helper-script, AppDelegate flow, существующие TCC-механики, signing) — посмотри их в `Sources/` и `scripts/`.
3. **Подумай**: «Какие инварианты я не должен сломать (см. CONTEXT секции 1, 4, 6)? Bundle ID `dev.helloworkapp.macos.engine` сохраняется. Self-signed cert не пересоздаём. Migration идемпотентна.»
4. Реализуй минимально-достаточное изменение, следуя «Глобальным правилам» (CONTEXT секция 4).
5. **Если задача требует i18n** — обязательно en + ru + zh для каждой новой строки. Order полей в `Translation.swift` и `Translations.swift` строгий.
6. **Если задача правит migration** — подумай об идемпотентности и partial-failure tolerance (each step в do-catch отдельно, devlog'и).
7. **Если задача меняет build pipeline** — проверь оба DMG (versioned + static) собираются, оба mount'ятся.
8. **Соберись**: `swift build 2>&1 | grep -E "error:" | head -10`. Если ошибки — фикси пока чисто.
9. **Пометь таск `[x]`** в `CONTEXT.md`, добавь note о том что сделал (как в прошлом цикле — `→ released as vX.Y.Z`).
10. **Релиз** (всегда, для каждого таска):
    - `./scripts/bump.sh patch` (для финального TASK-F01 — `./scripts/bump.sh minor`)
    - `./scripts/build.sh && ./scripts/package.sh`
    - **ВАЖНО**: `build_stub.sh` и `package_stub.sh` УДАЛЕНЫ в TASK-B03. Не пытайся их вызывать. Если ты ДО TASK-B03 — они ещё могут существовать но в новом цикле НЕ часть pipeline.
    - В `dev_log.json` — entry: 1 предложение customMessage, 2-4 пункта points
    - `git add -A && git commit -m "Hello work X.Y.Z — TASK-NNN: <короткое название>"`
    - `git tag vX.Y.Z && git push origin main && git push origin vX.Y.Z`
    - `gh release create vX.Y.Z dist/HelloWork-X.Y.Z.dmg dist/HelloWork.dmg --title "..." --notes "..."`
11. Отчёт юзеру: какой таск закрыт, какая версия релиза, какой следующий.

### Шаг 3b — Verification

> ⚠️ Verify-таск НЕ редактирует код продакта. Только читает diff, тестит, документирует.

1. **Пометь таск `[~]`** в `CONTEXT.md`.
2. Найди связанный impl-таск (на одну строку выше). Перечитай описание + acceptance.
3. Прочитай diff impl-таска (`git log --grep="TASK-XNN" --all -p` или последние коммиты).
4. Прогони verification по чеклисту:
   - Соответствует ли изменение описанию проблемы и acceptance criteria?
   - Не сломаны ли соседние пути (см. инварианты CONTEXT, особенно «Bundle ID не меняем», «cert не пересоздаём», «migration идемпотентна»)?
   - Если impl касался MigrationManager / UpdateInstaller / build scripts — `swift build`, проверить что compile-чисто. Если scripts — `bash -n script.sh` (синтаксис) и сделать dry-run если возможно.
   - Smoke-сценарии описанные в acceptance.
5. **Если всё OK** — пометь таск `[x]`. **Релиз тоже делай** (per-task политика, см. шаг 3a пункт 10). В commit message укажи `TASK-XNN [verify]: OK`. В dev_log entry — короткое «верифицирован TASK-XNN, регрессий нет».
6. **Если найдена регрессия / gap** — НЕ помечай verify-таск как done. Допиши follow-up в секцию `## 10. Follow-up tasks` в CONTEXT.md в формате:
   ```
   - [ ] **TASK-XNN-followup [impl]** — короткое название
     - Found by: TASK-XNN [verify]
     - Файлы: ...
     - Проблема: ...
     - Acceptance: ...
   - [ ] **TASK-XNN-followup-verify [verify]** — TASK-XNN-followup
   ```
   Verify-таск (текущий) пометь `[x]` ТОЛЬКО если решено что follow-up закроет проблему. Опиши в чате что нашёл и зачем follow-up.
7. Отчёт юзеру: что верифицировал, всё ли OK, есть ли follow-up.

### Шаг 4 — Завершение итерации

В чат юзеру выведи **компактный** отчёт:
- ID + title таска
- Что сделал в одном-двух предложениях
- Текущий статус ledger'а: сколько `[x]` / `[~]` / `[ ]` всего, какая фаза в работе
- Был ли релиз и какая версия
- Какой следующий таск (ID + title)

Не делай больше одного таска за итерацию, даже если есть соблазн «прихватить мелочь рядом». Дисциплина важнее скорости.

### Запреты

- ❌ НЕ менять bundle ID `dev.helloworkapp.macos.engine` — сломаешь TCC и UserDefaults у существующих юзеров.
- ❌ НЕ пересоздавать «HelloWork Self-Signed» cert — сломаешь TCC grants.
- ❌ НЕ трогать `Sources/HelloWork/Domain/Legends/`, `Sources/HelloWork/Focus/`, `Hider`, `Schedule`, `Stats`, `Permissions`, `Menubar` — кроме случаев когда таск явно требует.
- ❌ НЕ трогать `Sources/HelloWork/Updates/UpdateInstaller.swift` core логику replace — она проверена прошлым циклом. TASK-C01 косметика и fallback-path только.
- ❌ НЕ скипать verify-таски.
- ❌ НЕ изобретать новые таски в CONTEXT (кроме секции follow-up из verify-сценария).
- ❌ НЕ создавать новые .md файлы в audit/ — только существующие.
- ❌ НЕ пушить с `--no-verify`, `--force`, force-push в main, не делать `git reset --hard` без явной команды юзера.
- ❌ НЕ удалять `devlog.txt`, `dist/`, кроме явной целевой задачи (TASK-B03 удаляет stub-related из scripts/).
- ❌ НЕ запускать `tccutil reset` (это дело юзера в smoke pass).
- ❌ НЕ трогать `.gitignore`, `setup_signing.sh`.
- ❌ НЕ пытаться вызывать `build_stub.sh` / `package_stub.sh` после TASK-B03 — они удалены.

### Критерии «good enough» для одной итерации

- Один таск завершён (impl или verify) корректно
- `swift build` → 0 errors
- ledger обновлён, статусы корректны
- Релиз: оба DMG (versioned + static) запакованы, тег запушен, GitHub Release создан, `dev_log.json` содержит entry
- Юзер видит ясный отчёт

### Особые ноты по этому циклу

**Migration сложнее обычного impl**:
- Каждый шаг migration в отдельном `do { try } catch` блоке. Один сбой не должен валить остальные.
- Devlog каждого шага с конкретным результатом: `migration: cleaned engine.app at <path>`, `migration: HWInstaller already absent`, `migration: SMAppService unregister failed: <err>`.
- Идемпотентность: первая инструкция `runIfNeeded` — проверка флага. Если true — return immediately.

**Build scripts надо тестировать**:
- После правки `build.sh` или `package.sh` — реально вызвать и убедиться что выход правильный (mount DMG, проверить layout).
- Не релизить если DMG повреждённый.

**Two DMG artifacts**:
- `dist/HelloWork-X.Y.Z.dmg` — версионный.
- `dist/HelloWork.dmg` — статичная копия latest.
- В `gh release create` — оба загружаются.

---

## Финал

Если пробежался по ledger'у сверху вниз и **ВСЕ таски `[x]`** (Phases A-F) — поздравь юзера. Спроси нужно ли:
- открыть Phase G для новых наблюдений и follow-up'ов
- запустить новый полный аудит и сгенерировать новый набор тасков
- закрыть процесс
