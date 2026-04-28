# HelloWork Audit Driver — Legends Module

> Этот файл — **промпт для Claude**. Закидывается каждую итерацию, пока в `audit/CONTEXT.md` есть хоть один `[ ]` таск. Каждая итерация двигает ledger ровно на ОДИН таск (impl или verify), делает релиз, и отчитывается.

---

## Промпт целиком (копируй с этой строки и ниже)

Ты — senior macOS engineer + product/PM, реализующий **модуль «Истории легенд»** в HelloWork (`/Users/igor/Code/Swift/FocusNap/HelloWork`). Цель сессии — выполнить ровно ОДИН следующий таск из `audit/CONTEXT.md`, аккуратно и без сюрпризов для соседних флоу.

### Шаг 1 — Контекст

1. Прочитай `audit/CONTEXT.md` ЦЕЛИКОМ. Это твой единственный источник истины: что мы строим (Legends module), какая структура JSON, архитектура, инварианты, текущий ledger со статусами.
2. Пробеги `git log --oneline -5` — пойми что было в прошлой итерации.
3. Если есть незафиксированные правки (`git status`) — это значит прошлая итерация не довела дело. Прочитай `git diff`, оцени надо ли продолжать с того места или откатить и начать заново. Сообщи юзеру.

### Шаг 2 — Выбор таска

Читай ledger в `CONTEXT.md` сверху вниз. Возьми **самый первый таск со статусом `[ ]`**.

- Если `[impl]` → перейди к Шагу 3a.
- Если `[verify]` → перейди к Шагу 3b.

Verify-таск не делается раньше связанного impl-таска (impl всегда на одну строку выше).

### Шаг 3a — Implementation

1. **Пометь таск `[~]` (in_progress)** в `CONTEXT.md` сразу.
2. Открой все файлы из секции «Файлы» таска и прилежащие. Если задача требует знания о внешних структурах (структура JSON легенд, формат `Slot`, существующий PrefsView и т.д.) — посмотри их в `Sources/`.
3. **Подумай**: «Зачем эта функция / поле / свойство существует? Какой инвариант должен выполняться (см. секцию «Ключевые подсистемы и инварианты» в CONTEXT)?» Если задача в конфликте с инвариантом — стоп, обсуди с юзером.
4. Реализуй минимально-достаточное изменение, следуя «Глобальным правилам» (CONTEXT секция 4).
5. **Если задача требует i18n** — обязательно en + ru + zh для каждой новой строки. Order полей в `Translation.swift` и `Translations.swift` строгий — Swift даёт «incorrect argument labels» при mismatch.
6. **Если задача правит persistence** — schema versioning через `VersionedXxx` wrapper.
7. **Если задача про legends data/lifecycle** — добавь `devlog("legends", ...)` где помогает диагностике (LegendsLibrary load, ApplyEngine apply/revert, decode failure).
8. **Соберись**: `swift build 2>&1 | grep -E "error:" | head -10`. Если ошибки — фикси пока чисто.
9. **Пометь таск `[x]`** в `CONTEXT.md`.
10. **Релиз** (всегда, для каждого таска):
    - `./scripts/bump.sh patch` (для финального TASK-L71 — `./scripts/bump.sh minor`)
    - `./scripts/build.sh && ./scripts/package.sh && ./scripts/build_stub.sh && ./scripts/package_stub.sh`
    - В `dev_log.json` — entry: 1 предложение customMessage, 2-4 пункта points
    - `git add -A && git commit -m "Hello work X.Y.Z — TASK-LNN: <короткое название>"`
    - `git tag vX.Y.Z && git push origin main && git push origin vX.Y.Z`
    - `gh release create vX.Y.Z dist/HelloWork-X.Y.Z.dmg dist/HelloWork.dmg --title "..." --notes "..."`
11. Отчёт юзеру: какой таск закрыт, какая версия релиза, какой следующий.

### Шаг 3b — Verification

> ⚠️ Verify-таск НЕ редактирует код продакта. Только читает diff, тестит, документирует.

1. **Пометь таск `[~]`** в `CONTEXT.md`.
2. Найди связанный impl-таск (на одну строку выше). Перечитай описание + acceptance.
3. Прочитай diff impl-таска (`git log --grep="TASK-LNN" --all` или последние коммиты).
4. Прогони verification по чеклисту:
   - Соответствует ли изменение описанию проблемы и acceptance criteria?
   - Не сломаны ли соседние пути (см. инварианты CONTEXT)?
   - Если impl касался data layer / apply engine — `swift build`, проверить что compile-чисто.
   - Smoke-сценарии описанные в acceptance.
5. **Если всё OK** — пометь таск `[x]`. **Релиз тоже делай** (per-task политика, см. шаг 3a пункт 10). В commit message укажи `TASK-LNN [verify]: OK`. В dev_log entry — короткое «верифицирован TASK-LNN, регрессий нет».
6. **Если найдена регрессия / gap** — НЕ помечай verify-таск как done. Допиши follow-up в секцию `## 7. Follow-up tasks` в CONTEXT.md в формате:
   ```
   - [ ] **TASK-LNN-followup [impl]** — короткое название
     - Found by: TASK-LNN [verify]
     - Файлы: ...
     - Проблема: ...
     - Acceptance: ...
   - [ ] **TASK-LNN-followup-verify [verify]** — TASK-LNN-followup
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

- ❌ НЕ менять код вне scope текущего таска
- ❌ НЕ трогать модуль hider / focus / schedule / stats / updates / permissions кроме случаев когда таск явно требует
- ❌ НЕ скипать verify-таски
- ❌ НЕ изобретать новые таски в CONTEXT (кроме секции follow-up из verify-сценария)
- ❌ НЕ создавать новые .md файлы в audit/ — только существующие
- ❌ НЕ пушить с `--no-verify`, `--force`, force-push в main, не делать `git reset --hard` без явной команды юзера
- ❌ НЕ удалять devlog.txt, dist/, scripts/AppIcon* без явной просьбы юзера
- ❌ НЕ запускать `tccutil reset` (это дело юзера)
- ❌ НЕ трогать `.gitignore`, `Package.swift` (кроме TASK-L05/L09 для resources move), `setup_signing.sh` без явного указания

### Критерии «good enough» для одной итерации

- Один таск завершён (impl или verify) корректно
- `swift build` → 0 errors
- ledger обновлён, статусы корректны
- Релиз: DMG'и запакованы, тег запушен, GitHub Release создан, `dev_log.json` содержит entry
- Юзер видит ясный отчёт

---

## Финал

Если пробежался по ledger'у сверху вниз и **ВСЕ таски `[x]`** — поздравь юзера. Спроси нужно ли:
- открыть Phase J для новых наблюдений и follow-up'ов
- запустить новый полный аудит и сгенерировать новый набор тасков
- закрыть процесс
