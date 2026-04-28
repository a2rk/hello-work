# Как пользоваться этим набором — Single-App Distribution Refactor cycle

> TL;DR: один файл-промпт скармливаешь Claude каждую итерацию, он сам выберет следующий таск из distribution-refactor'а и сделает один шаг.

---

## Что лежит в `audit/`

| Файл | Что внутри | Кто его трогает |
|---|---|---|
| `CONTEXT.md` | Цель цикла, текущая инфраструктура, migration matrix, архитектура миграции, правила, **task ledger** (32 таска) со статусами, smoke list, dev_log template, wipe procedure | Claude правит статусы тасков; ты — если хочешь добавить таск или сменить приоритет |
| `DRIVER.md` | **Промпт**, который ты копируешь в Claude каждую итерацию | Никто не трогает после создания |
| `INSTRUCTIONS.md` | Этот файл — для тебя | Никто не трогает |

---

## Цель этого цикла

Убрать stub-installer pattern. Один `HelloWork.app` в `/Applications`. Drag-to-install. Existing юзеров (со stub-engine layout) тихо мигрировать при первом запуске v0.12. Сохранить TCC permissions и UserDefaults через миграцию (bundle ID `dev.helloworkapp.macos.engine` остаётся).

Старт: версия `0.11.6`. Финал: `0.12.0` (минорный bump после ~32 тасков). Каждый таск = одна патч-версия + GitHub Release.

---

## Workflow

### Каждая итерация

1. Открой Claude Code в этой репе.
2. Скопируй ВЕСЬ текст из `audit/DRIVER.md` (от строки «Ты — senior macOS engineer» до конца) и вставь в чат.
3. Жди отчёт. Claude скажет: ID таска, что сделал, версия релиза, какой следующий.
4. Проверь визуально (`git diff`, `git log`, посмотри файлы которые он правил, mount свежий DMG если build pipeline касался).
5. Если всё ОК — следующая итерация. Если поплыло — `git restore .` + перезапуск промпта.

### Через `/loop`

Если хочешь батчем — запускай `/loop делай дальше, не ограничивайся одной таской`. Claude в dynamic-mode сам себе ставит `ScheduleWakeup` и работает блоками по 5-10 тасков пока ты не остановишь.

### Нюансы цикла

- **Migration cycle — не то же что feature cycle**. Цена ошибки выше: одна regression в migration сломает данные у существующих юзеров. Поэтому verify-таски тут особенно важны.
- **Phases A → F нельзя переставлять**. A — migration safety net (защита существующих юзеров) — должна быть готова ДО того как новый build pipeline (B) выкатывается. B → C → D → E → F sequential.
- **Build pipeline тестировать вручную**. После TASK-B05/B07/D01/D03 — реально mount DMG, посмотреть, drag в /Applications в VM/чистом profile.
- **Phase F (smoke) — самый важный**. Это manual проход 6 сценариев на реальной машине. Если пройдёт — отпускаем 0.12.0. Если нет — fix-цикл.

---

## Если что-то идёт не так

### «Claude взял не тот таск»

«Ты должен был взять TASK-XNN, не TASK-YMM. Откати правки через `git restore .` и попробуй ещё раз».

### «Migration сломала existing юзеру данные на тестовой машине»

1. Сразу откатывай: на тестовой машине drag .app старой версии (v0.11.5) обратно из старого DMG.
2. Восстанавливаемся через `~/Library/.Trash` (HWInstaller туда уехал — можно вернуть).
3. UserDefaults plist trash-ить миграция не должна была — данные на месте.
4. В CONTEXT.md follow-up в секции 10: что нашёл, как воспроизвести, какое ожидаемое поведение.

### «Build pipeline сломал DMG (mount не работает / drag не работает)»

1. `git restore scripts/` — откат скрипта.
2. Manual rebuild старой версии для проверки что среда чиста.
3. Откати последний коммит/таск, помечай follow-up.

### «Хочу добавить свой таск»

Допиши руками в `audit/CONTEXT.md` в нужную фазу или в секцию `## 10. Follow-up tasks`. Формат как у остальных. Claude дойдёт по очереди.

### «Хочу пропустить таск»

Помечай `[x] **TASK-XNN [...]** ~skipped: <причина>~`. Claude увидит как done и не возьмёт. **Не пропускай Phase A (migration) полностью** — без неё не катить.

### «Claude закрыл цикл, нужен ещё»

Когда все таски `[x]`, попроси: «Запусти полный audit distribution flow + sanity check на всех 6 smoke сценариях, ищи слабые места, сгенери Phase G с новыми тасками если есть». Это создаст продолжение.

---

## Что НЕ делать

- ❌ Не запускай несколько Claude-сессий параллельно над этим ledger'ом — затрут друг друга.
- ❌ Не редактируй файлы продакта (`Sources/...`) пока итерация в работе.
- ❌ Не делай `git reset --hard` если итерация в `[~]` — потеряешь прогресс.
- ❌ Не правь `audit/DRIVER.md` без необходимости — изменит поведение всех будущих итераций.
- ❌ **НЕ меняй bundle ID `dev.helloworkapp.macos.engine`** — даже если кажется что «macos.engine» странное имя для стандартной аппы. Смена сломает TCC, UserDefaults, Caches у существующих юзеров. Меняем коммуникацию (UI/доки), а не идентификатор.
- ❌ **НЕ пересоздавай self-signed cert «HelloWork Self-Signed»** — TCC ключ зависит от его SHA, пересоздание = потеря всех grants.
- ❌ Не релизь Phase B (удаление stub-source + scripts) ДО того как Phase A (migration) реально работает на твоей машине. Иначе существующие юзеры окажутся со stub-installer DMG который не качает engine (потому что engine больше не релизится отдельно).

---

## Ожидаемая динамика

- **Тасков всего**: ~32 (16 impl + 16 verify), плюс возможные follow-up'ы.
- **Фаз**: 6 (A — migration safety net; B — build pipeline cleanup; C — update flow validation; D — DMG polish; E — documentation; F — final regression).
- **Темп**: 1 итерация = 1 таск. Реалистично 5-15 итераций в день, в режиме `/loop` — батчи.
- **Срок**: 2-4 дня регулярного прогона.
- **Версии**: 0.11.5 → 0.11.6 → ... → 0.12.0 (минорный финал, signal distribution overhaul).

---

## Финальная проверка перед стартом

1. У тебя в репо чисто (`git status` зелёный)?
2. Текущая ветка `main`, последний тег `v0.11.5`?
3. Self-signing cert «HelloWork Self-Signed» в keychain (`security find-identity -p codesigning ~/Library/Keychains/login.keychain-db | grep "HelloWork Self-Signed"`)?
4. Можешь собрать вручную (`swift build` → 0 errors)?
5. Есть VM или второй mac account для тестирования migration scenarios (Phase F manual smoke), либо готов делать wipe procedure (CONTEXT секция 9) на основной машине между прогонами?

Если 1-4 — да, и пятое — есть план как тестить миграцию — можно стартовать. Поехали.

---

## Memo: что НЕ цель этого цикла (на случай scope creep)

- Sparkle / иной стандартный update framework — не сейчас. Текущий UpdateInstaller работает.
- Notarization — не сейчас (требует Apple Developer Program, цикл и так большой).
- Code signing с trusted Developer ID — не сейчас.
- Auto-launch on login по умолчанию — нет, юзер сам.
- In-app «Reset all data» button — нет, drag-to-trash + ручной cleanup.
- DMG с ASLR / EULA / другими сложностями — нет.
- App Store distribution — нет, никогда (privacy-first, sandbox несовместим).

Если возникает соблазн — return to scope.
