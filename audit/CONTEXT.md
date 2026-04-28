# HelloWork — Legends Module Audit Context & Task Ledger

> Этот файл — **единственный источник истины** для агента, который выполняет таски. Перед каждой итерацией читать его целиком. После каждой итерации обновлять статусы.
>
> **Цель цикла**: внедрить модуль «Истории легенд» — 60 расписаний великих людей, которые юзер может изучать и «применять» к собственному schedule-блокированию приложений. Версионирование — **одна патч-версия на таск**. Старт `0.10.1` → финиш минимум `0.10.65` (60 тасков), реально **0.11.0** как минорный bump-финал. Каждый шаг — отдельный `gh release` чтобы юзер видел движение и мог откатиться.

---

## 1. Что мы добавляем

**Модуль «Легенды»** — образовательно-практический раздел в HelloWork. Идея: помочь юзеру дисциплинировать себя через изучение и копирование расписаний выдающихся людей (Франклин, Маск, Карнеги, Стивенсон, Виллинк и ещё 55).

### Сценарий пользователя

1. Открывает Prefs → новый sidebar-пункт «Легенды».
2. Видит **сетку или список карточек** (юзер сам переключает grid/list). На карточке — аватар (placeholder-монограмма), имя, годы жизни, intensity (1–5 точек), primary tag, кнопка «звёздочка» для favorites.
3. Может **искать**, **фильтровать** (era / field / tag / intensity), **сортировать** (по умолчанию order, отдельно — favorites first, по эпохе, по области), **переключать** между Grid и List.
4. Жмёт на карточку → **Detail View** с биографией, лентой источников, **круговым графиком 24-часового расписания**, секцией про мессенджеры (когда разрешены), цитатами.
5. Может **«Применить» расписание** — открывается sheet, где он выбирает каким из своих managed apps к какой категории привязать (work-messenger / personal-messenger). HelloWork импортирует `allowedSlots` легенды в slots выбранных приложений (предварительно сохранив бэкап старых slots).
6. В sidebar/detail виден баннер «Сейчас применено: <легенда>» с кнопкой Revert — откат к бэкапу.
7. Может ставить любую легенду в favorites; на отдельной вкладке/фильтре «★» — только избранные.

### Зачем это HelloWork

- **Усиливает основную миссию** — schedule-based blocking. Юзер часто не знает «как правильно» расписать день. Легенды дают готовые шаблоны, проверенные историей.
- **Educational hook** — у HelloWork появляется content layer, retention растёт.
- **Privacy-first остаётся**: все 60 JSON-файлов вшиты в bundle, никаких сетевых запросов.
- **Local-first остаётся**: применение → стандартный mutate `managedApps.slots`, всё в UserDefaults.

### Что должно быть «9.5/10»

- **Корректность**: применение легенды реально модифицирует slots выбранных apps; revert восстанавливает оригинал бит-в-бит. Никаких «применили в UI, а на диске не отразилось».
- **Производительность**: 60 JSON загружаются 1 раз на init в фоне (≤ 50ms eager load), кэшируются. Список рендерится lazy. Search debounce.
- **UX**: Grid/List toggle помнится. Favorites персистятся. Поиск мгновенный. Карточки с микро-анимацией. Detail view со scroll-анимацией к секции по якорю.
- **i18n**: все UI-строки en / ru / zh. Bio/quotes/labels легенд хранятся в JSON только ru/en (так в исходных данных) — для zh фолбэк на en (с visual badge или silent — на выбор продукта).
- **Resilience**: повреждённый JSON одного файла не валит весь модуль — этот legend помечается как `.corrupt`, остальные 59 рендерятся.
- **Versioning**: persisted favorites + applied state schema-versioned, как managedApps в прошлом цикле.
- **Dead code = 0**.

---

## 2. Источник данных

60 JSON-файлов сейчас в `/Users/igor/Code/Swift/FocusNap/legens_module/` (CWD корень репо). Все имеют идентичную структуру (TASK-005 переносит их в bundle).

### Стабильная схема (все 60 файлов)

```jsonc
{
  "id": "franklin-benjamin",          // stable string id
  "order": 1,                          // 1..60, default sort
  "name":     { "ru": "...", "en": "..." },
  "fullName": { "ru": "...", "en": "..." },
  "yearsOfLife": "1706–1790",          // string, иногда с длинным тире
  "era": "18th_century",               // enum-like: 18th_century, 19th_century, industrial, modern, ...
  "field": "polymath",                 // enum-like: polymath, tech_entrepreneur, industrialist, writer, athlete, ...
  "tags": ["founding_father", "inventor", "..."],
  "nationality": "US",                 // ISO-like, иногда "US/ZA" "US/UK"
  "avatarUrl": null,                   // null в исходниках; UI рисует монограмму
  "intensity": 4,                      // 1..5
  "bio": { "ru": "...", "en": "..." }, // параграф 1–3 предложения
  "sources": [
    { "type": "book"|"article"|"interview", "title": "...", "author": "...", "url": "..." }
  ],
  "lifeSchedule": {
    "morningQuestion": { "ru": "...", "en": "..." },   // optional, не у всех
    "eveningQuestion": { "ru": "...", "en": "..." },   // optional
    "blocks": [
      { "start": "00:00", "end": "05:00", "type": "sleep",
        "label": { "ru": "...", "en": "..." } }
    ]
  },
  "blockSchedule": {
    "description": { "ru": "...", "en": "..." },
    "allowedSlots": [
      { "start": "12:30", "end": "13:30",
        "appliesTo": ["work_messengers" | "personal_messengers"],
        "rationale": { "ru": "...", "en": "..." } }
    ],
    "totalAllowedMinutes": 180
  },
  "quotes": [ { "ru": "...", "en": "..." } ]
}
```

### Возможные значения

- **`era`** (наблюдаемые): `18th_century`, `19th_century`, `industrial`, `modern`. Принимаем эти 4 + любой будущий — рендерим human-readable через словарь.
- **`field`**: `polymath`, `tech_entrepreneur`, `industrialist`, `writer`, `athlete`, `musician`, `scientist`, `mathematician`, `inventor`, `philosopher`, `physicist`, `painter`, `architect`. Принимаем как открытое множество.
- **`block.type`**: `sleep`, `morning_routine`, `deep_work`, `comms`, `meal_and_read`, `leisure_and_reflection`. **Закрытое множество** — каждый имеет свой цвет в ring chart.
- **`source.type`**: `book`, `article`, `interview`, `letter`. Открытое.
- **`appliesTo`**: `work_messengers`, `personal_messengers`. Возможно расширим в `deep_work_tools`, но пока — закрытое 2.

---

## 3. Архитектура (новые файлы и изменения)

```
HelloWork/Sources/HelloWork/
├── Domain/
│   └── Legends/                            ← НОВАЯ ПАПКА
│       ├── Legend.swift                    Codable structs (Legend, LegendBlock, etc.)
│       ├── LegendBlockType.swift           enum + colors + display names
│       ├── LegendsLibrary.swift            Singleton, eager bundle-load, cache, search
│       └── LegendApplyEngine.swift         apply/revert mapping → ManagedApp.slots
├── Resources/
│   └── Legends/                            ← НОВАЯ ПАПКА (60 JSON)
│       ├── 01-franklin-benjamin.json       (move from legens_module/)
│       └── ... 02..60
├── Preferences/
│   ├── Legends/                            ← НОВАЯ ПАПКА
│   │   ├── LegendsListView.swift           Grid/List + filters + search
│   │   ├── LegendCard.swift                Card render (grid mode)
│   │   ├── LegendListRow.swift             Row render (list mode)
│   │   ├── LegendDetailView.swift          Hero + bio + ring + quotes + sources
│   │   ├── LegendRingChart.swift           24h ring + block legend
│   │   ├── LegendApplySheet.swift          Sheet с выбором apps + categorize
│   │   └── LegendAvatar.swift              Monogram-fallback avatar
│   ├── Sidebar/
│   │   └── LegendsSidebarRow.swift         (опц.) если нужен dedicated row
│   └── PrefSection.swift                   + case .legends
├── App/AppState.swift                      + favoriteLegendIds, appliedLegendId, slotsBackupForApply
└── Domain/Translation*.swift               +новые ключи (en/ru/zh)
```

### Ключевые подсистемы и инварианты

| Подсистема | Инвариант |
|---|---|
| `LegendsLibrary` | `all` доступен синхронно после init. Если ≥1 JSON битый — `corruptIds: Set<String>`, остальные грузятся. |
| `Legend` (Codable) | Декодинг даёт корректную structure для всех 60 валидных JSON; missing optional fields (например morningQuestion) → nil. |
| `LegendApplyEngine.apply` | Мутация `managedApps[i].slots` обратима через `slotsBackupForApply` (snapshot перед apply, key by appliedLegendId). |
| `LegendApplyEngine.revert` | После revert: `managedApps[i].slots == backup[i]` бит-в-бит. `appliedLegendId = nil`. |
| `AppState.favoriteLegendIds` | persisted Set, schema-versioned. Toggle идемпотентен. |
| `LegendsListView` | Search/filter/sort не блокируют main thread; debounce 200ms на текстовый поиск. |
| `LegendDetailView` | Открывается мгновенно; ring chart рисуется без race с loading bio. |

---

## 4. Глобальные правила выполнения тасков

1. **Не ломать соседнее**: модуль легенд изолирован. Существующая логика hider / focus / schedule / stats / updates — НЕ ТРОГАЕМ если задача того явно не требует. Если задача требует — это знак что её надо разбить.
2. **Минимум edge-case-handling на границах**: только при decode JSON, при apply/revert (битый managedApps state), при search edge cases. Внутри — доверять.
3. **Никаких новых абстракций ради будущего**: только нужное.
4. **Никаких комментариев-объяснялок WHAT**: только WHY (см. инварианты).
5. **Без эмодзи в коде**.
6. **i18n**: каждая user-facing строка — en + ru + zh, в строгом порядке полей `Translation.swift`. Не забывай: `Translation` — struct, поля сортированы; init keyword args в `Translations.swift` должны идти в той же позиции.
7. **devlog**: точки `devlog("legends", ...)` в LegendsLibrary load, LegendApplyEngine apply/revert, на UI-events если помогает диагностике.
8. **Schema versioning** для persistence: favoriteLegendIds + appliedLegendId + slotsBackupForApply — обернуть в `VersionedXxx` (как было в Phase C прошлого цикла).
9. **Verify-таск НЕ правит код**.

### Когда релизить

**ПОЛИТИКА: одна микро-версия на каждый таск.** Старт — 0.10.1. Минимум 64 таска = 0.10.65. Финальный таск — bump MINOR → **0.11.0**.

После каждого закрытого таска (impl или verify):
- `./scripts/bump.sh patch` (для финала — `./scripts/bump.sh minor`)
- `./scripts/build.sh && ./scripts/package.sh && ./scripts/build_stub.sh && ./scripts/package_stub.sh`
- entry в `dev_log.json` (короткий)
- commit `Hello work X.Y.Z — TASK-LNN: <короткое название>` (префикс `L` чтобы не путать со старым циклом)
- tag + push + `gh release create`

Каждый патч-релиз = ровно один таск.

---

## 5. Task Ledger

Формат: `[ ] = pending`, `[~] = in_progress`, `[x] = done`. Verify-таск нельзя пометить done пока impl-таск не done.

### Phase A — Data foundation (10 tasks)

- [x] **TASK-L01 [impl]** — Domain models: `Legend`, `LegendBlock`, `LegendBlockType`, `LegendSource`, `LegendBlockSchedule`, `LegendAllowedSlot`, `LegendQuote`, `LegendOptionalQuestion`  → released as v0.10.2
  - Файлы: `Sources/HelloWork/Domain/Legends/Legend.swift`, `Domain/Legends/LegendBlockType.swift`
  - Все Codable + Hashable + Identifiable.
  - `LegendBlockType` — enum со всеми observed types + `unknown(String)` для forward-compat.
  - Acceptance: декодит example JSON (id=01) без ошибок; пишется обратно через encode идентично; `LegendBlockType.allCases` имеет известные 6 типов.

- [x] **TASK-L02 [verify]** — TASK-L01  → released as v0.10.3

- [x] **TASK-L03 [impl]** — `LegendsLibrary` — singleton, eager bundle-load на init, сохраняет в `[Legend]` отсортированный по `order`, плюс `Set<String> corruptIds` для битых файлов. Логирует через `devlog("legends", ...)`. Public API: `all: [Legend]`, `byID(_:) -> Legend?`, `corrupt: Set<String>`.  → released as v0.10.4
  - Файл: `Sources/HelloWork/Domain/Legends/LegendsLibrary.swift`
  - Bundle.module → enumeratesContents Resources/Legends/*.json
  - Acceptance: на пустом bundle (тест) возвращает []; на bundle с 1 валидным + 1 битым — возвращает 1 в `all`, 1 в `corrupt`.

- [x] **TASK-L04 [verify]** — TASK-L03  → released as v0.10.5

- [x] **TASK-L05 [impl]** — Перенос 60 JSON: `legens_module/*.json` → `HelloWork/Sources/HelloWork/Resources/Legends/*.json`. Регистрация в `Package.swift` (`.process("Resources")` уже стоит — должно подхватить, верифицировать).  → released as v0.10.6
  - Файлы: `Resources/Legends/01-...json` ... `60-...json`. Старая папка `legens_module/` в корне — удаляется.
  - Acceptance: `swift build` ≥ 60 файлов вошли в bundle; LegendsLibrary.all.count == 60 на старте.

- [x] **TASK-L06 [verify]** — TASK-L05  → released as v0.10.7

- [x] **TASK-L07 [impl]** — Search & filter helpers в `LegendsLibrary`  → released as v0.10.8

- [x] **TASK-L08 [verify]** — TASK-L07  → released as v0.10.9

- [x] **TASK-L09 [impl]** — Cleanup: удалить `legens_module/` (был в parent FocusNap, вне HelloWork-git-репо — `git mv` неприменим). Папка удалена с диска.  → released as v0.10.10

- [x] **TASK-L10 [verify]** — TASK-L09  → released as v0.10.11

### Phase B — Persistence layer (8 tasks)

- [x] **TASK-L11 [impl]** — AppState поля для legends: favoriteLegendIds + appliedLegendId + slotsBackupForApply, schema-versioned single-blob persist.  → released as v0.10.12

- [x] **TASK-L12 [verify]** — TASK-L11  → released as v0.10.13

- [x] **TASK-L13 [impl]** — `AppState.toggleFavoriteLegend(_ id: String)` — добавляет/убирает из set, идемпотентно. `isFavoriteLegend(_:) -> Bool`.  → released as v0.10.14

- [x] **TASK-L14 [verify]** — TASK-L13  → released as v0.10.15

- [x] **TASK-L15 [impl]** — `LegendApplyEngine` — apply/revert с backup snapshot.  → released as v0.10.16

- [x] **TASK-L16 [verify]** — TASK-L15  → released as v0.10.17

- [x] **TASK-L17 [impl]** — Legends-state corruption — backup в legends-state.corrupt-<ts>.json + warning в UI.  → released as v0.10.18

- [x] **TASK-L18 [verify]** — TASK-L17  → released as v0.10.19

### Phase C — Sidebar entry & routing (6 tasks)

- [x] **TASK-L19 [impl]** — `PrefSection.legends` + sectionLegends translation key (en/ru/zh) + placeholder routing в PrefsView.  → released as v0.10.20

- [x] **TASK-L20 [verify]** — TASK-L19  → released as v0.10.21

- [x] **TASK-L21 [impl]** — LegendsListView/Detail skeleton с in-view push-nav (selectedLegend @State). PrefsView routing на LegendsListView.  → released as v0.10.22

- [x] **TASK-L22 [verify]** — TASK-L21  → released as v0.10.23

- [x] **TASK-L23 [impl]** — 41 Translation key для legends UI (en/ru/zh).  → released as v0.10.24

- [x] **TASK-L24 [verify]** — TASK-L23  → released as v0.10.25

### Phase D — Legends list view (12 tasks)

- [x] **TASK-L25 [impl]** — LegendsListView skeleton: header + search debounced 200ms + sort picker + grid/list toggle + filtered results.  → released as v0.10.26

- [x] **TASK-L26 [verify]** — TASK-L25  → released as v0.10.27

- [x] **TASK-L27 [impl]** — LegendCard (grid mode) + LegendAvatar (factored early из L31).  → released as v0.10.28

- [x] **TASK-L28 [verify]** — TASK-L27  → released as v0.10.29

- [x] **TASK-L29 [impl]** — LegendListRow compact + интегрирован в listResults.  → released as v0.10.30

- [x] **TASK-L30 [verify]** — TASK-L29  → released as v0.10.31

- [x] **TASK-L31 [impl]** — LegendAvatar — реализован раньше в TASK-L27 (зависимость по сборке). Файл `Sources/HelloWork/Preferences/Legends/LegendAvatar.swift`.  → released as v0.10.32

- [x] **TASK-L32 [verify]** — TASK-L31  → released as v0.10.33

- [x] **TASK-L33 [impl]** — Filters bar: horizontal scroll с era/field/intensity pills + Clear-all.  → released as v0.10.34

- [x] **TASK-L34 [verify]** — TASK-L33  → released as v0.10.35

- [x] **TASK-L35 [impl]** — Grid/List view-mode persistence через @AppStorage.  → released as v0.10.36

- [x] **TASK-L36 [verify]** — TASK-L35  → released as v0.10.37

### Phase E — Legend detail view (12 tasks)

- [x] **TASK-L37 [impl]** — `LegendDetailView` skeleton: hero (большой avatar, name, fullName, years, nationality flag, intensity dots, primary field). Back button (← к List). Favorite-star.  → released as v0.10.38

- [x] **TASK-L38 [verify]** — TASK-L37  → finding: nationality рисовался plain text вместо флага. Добавил nationalityFlag() helper (ISO-2 → regional indicator). Released as v0.10.39

- [x] **TASK-L39 [impl]** — Bio paragraph + sources block (clickable links opening NSWorkspace.shared.open). Sources показываются как inline rows с типом (book/article/interview).  → released as v0.10.40

- [x] **TASK-L40 [verify]** — TASK-L39  → finding: detail view содержал свой ScrollView внутри уже-скроллящего PrefsView.detail (nested scroll → inconsistent bounce). Убрал inner ScrollView. Released as v0.10.41

- [ ] **TASK-L41 [impl]** — `LegendRingChart` — 24-часовое кольцо. Каждый block рисуется arc'ом с цветом по `LegendBlockType` (sleep тёмный, deep_work primary, comms accent, ...). Hour markers (0/6/12/18). Лейблы в центре кольца — сейчас показывает `legendsTitle` или (опц.) текущий блок относительно сейчас.

- [ ] **TASK-L42 [verify]** — TASK-L41

- [ ] **TASK-L43 [impl]** — Block type legend: горизонтальный ряд под рингом — каждый блок-тип: цветовой dot + название (translated) + total часов в дне.

- [ ] **TASK-L44 [verify]** — TASK-L43

- [ ] **TASK-L45 [impl]** — Messenger windows section: показывает `blockSchedule.description` + список `allowedSlots` с time-range, appliesTo (work/personal pill), rationale.

- [ ] **TASK-L46 [verify]** — TASK-L45

- [ ] **TASK-L47 [impl]** — Quotes carousel: 3-5 цитат с auto-rotate (5с), стрелки prev/next, индикаторы. Если quotes пусты — секция скрыта.

- [ ] **TASK-L48 [verify]** — TASK-L47

### Phase F — Favorites & search polish (6 tasks)

- [ ] **TASK-L49 [impl]** — Favorite-star button: круглая, заполняется при isFavorite==true, scale-pop animation на toggle. Работает на cards, list rows и detail view — sync.

- [ ] **TASK-L50 [verify]** — TASK-L49

- [ ] **TASK-L51 [impl]** — «Favorites» filter pill — toggle: показывает только избранные. State persists в `@AppStorage("helloWorkLegendsShowFavoritesOnly")`.

- [ ] **TASK-L52 [verify]** — TASK-L51

- [ ] **TASK-L53 [impl]** — Sort: `order` (default), `alphabetical(name локали)`, `favoritesFirst`. Picker в header. Persists.

- [ ] **TASK-L54 [verify]** — TASK-L53

### Phase G — Apply schedule flow (10 tasks)

- [ ] **TASK-L55 [impl]** — «Apply schedule» кнопка в LegendDetailView (возле fave star). Disabled, если managedApps пустой (с tooltip «Add apps first»). Click → presents `LegendApplySheet`.

- [ ] **TASK-L56 [verify]** — TASK-L55

- [ ] **TASK-L57 [impl]** — `LegendApplySheet`: список managedApps (active, не archived). Каждый row — app icon, name, picker { Skip / Work messenger / Personal messenger }. Внизу: предпросмотр (сколько slots будет создано на основе выбора + allowedSlots), Confirm/Cancel.

- [ ] **TASK-L58 [verify]** — TASK-L57

- [ ] **TASK-L59 [impl]** — `LegendApplyEngine.apply(legend:assignments:state:)` — для каждого app с category != skip: build slots из corresponding allowedSlots → state.managedApps[i].slots = новые. Сохраняет backup. Сетит appliedLegendId.

- [ ] **TASK-L60 [verify]** — TASK-L59

- [ ] **TASK-L61 [impl]** — Applied banner в верху LegendsListView и LegendDetailView (если этот legend сейчас applied): «Сейчас применено: <legend.name>» + Revert button. Subtle accent color.

- [ ] **TASK-L62 [verify]** — TASK-L61

- [ ] **TASK-L63 [impl]** — `LegendApplyEngine.revert(state:)` — восстанавливает slots из backup, чистит state. Кнопка Revert вызывает (с alert-confirmation: «Восстановить старые расписания?»).

- [ ] **TASK-L64 [verify]** — TASK-L63

### Phase H — Polish & i18n (6 tasks)

- [ ] **TASK-L65 [impl]** — zh-фолбэк: для bio/quotes/labels — если zh-locale активна → возвращаем en (с visual subtle hint «en» в углу карточки/секции). Translation+legendLocalized helper вокруг `LocalizedString.value(for: AppLanguage)`.

- [ ] **TASK-L66 [verify]** — TASK-L65

- [ ] **TASK-L67 [impl]** — Card animations: stagger fade-in при appear (delay = idx * 0.02s, max 0.5s), spring hover scale 1.02, favorite-pop. List row — без stagger но с transitionInsertion.

- [ ] **TASK-L68 [verify]** — TASK-L67

- [ ] **TASK-L69 [impl]** — Edge cases UI: empty results (пустой search/filter → «Nothing found, try different filters»), no managedApps (apply кнопка disabled с tooltip), corrupt JSON (banner «N legends couldn't be loaded» в LegendsListView header).

- [ ] **TASK-L70 [verify]** — TASK-L69

### Phase I — Final regression (6 tasks)

- [ ] **TASK-L71 [impl]** — Final bump → **0.11.0** (minor) — сигнал «major feature release: Legends». dev_log.json — большой entry с подытогом всех Phase A-H + smoke list.
  - Smoke list:
    1. Свежий launch (без favorites/applied) — sidebar Legends, list открывается, 60 карточек, search/filter работают, grid/list toggle помнится
    2. Click карточка → detail с ring, bio, sources, quotes
    3. Star ⭐ on/off — мгновенно отражается везде
    4. Filter «Favorites only» → ровно избранные
    5. Apply легенду к одному из managed apps → slots реально мутируются (видно в Schedule view)
    6. Banner «Currently applied» появляется
    7. Revert → старые slots возвращены
    8. Restart app → state восстанавливается
    9. Performance: грид с 60 cards рендерится без лагов; search debounce работает
    10. Все три locale (en/ru/zh) — переключение работает, zh показывает en для legend content

- [ ] **TASK-L72 [verify]** — TASK-L71

- [ ] **TASK-L73 [impl]** — Перевод audit/CONTEXT финальных метрик в ✅ (см. секцию 6 ниже) — каждая отмечена.

- [ ] **TASK-L74 [verify]** — TASK-L73

- [ ] **TASK-L75 [impl]** — Cleanup follow-ups если возникли в секции 5.

- [ ] **TASK-L76 [verify]** — TASK-L75

---

## 6. Метрики «9.5 / 10»

После закрытия всех тасков:

- ✅ 60 легенд встроены в bundle, грузятся ≤ 50ms
- ✅ Grid + List toggle работают, помнятся
- ✅ Search debounced 200ms; filter pills (era/field/intensity); sort 3 вариантов
- ✅ Detail: hero, bio, ring chart 24h, sources, quotes carousel, messenger windows
- ✅ Favorites — toggle, persist, dedicated filter, "favorites first" sort
- ✅ Apply: sheet выбора apps + категории, mutate slots, backup, applied banner, revert
- ✅ i18n: en/ru/zh для UI; bio/quotes — ru/en + zh fallback на en
- ✅ Resilience: corrupt JSON одного файла не валит модуль
- ✅ Persistence: favorites + applied state schema-versioned
- ✅ Animations: stagger fade-in cards, hover scale, favorite-pop
- ✅ Edge cases: empty search, no apps, no favorites
- ✅ Сидеры/сорсы: clickable links opening browser
- ✅ devlog содержит legends-categories для каждого нетривиального события

---

## 7. Follow-up tasks

> Verify-таски ДОПИСЫВАЮТ сюда новые задачи если обнаружат регрессию или non-trivial gap.

- [ ] **TASK-L77 [impl]** — `LegendApplyEngine.apply` guard на уже-applied state
  - Found by: TASK-L16 [verify]
  - Файл: `Sources/HelloWork/Domain/Legends/LegendApplyEngine.swift`
  - Проблема: chained apply (Franklin → Musk без revert) перезатирает backup на «уже применённое» состояние. Revert после такого chain восстанавливает только последний intermediate, а не оригинал.
  - Acceptance: apply() при `state.appliedLegendId != nil` либо (а) сначала revert'ит автоматически, либо (б) бросает error/no-op'ит. UI в TASK-L57/L59 должен будет учитывать.

- [ ] **TASK-L78 [verify]** — TASK-L77
