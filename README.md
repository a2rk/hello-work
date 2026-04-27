> ave claude

# Hello work

macOS-приложение для разработчиков с двумя+ мониторами. Расписание блокировок, фокус-режим по хоткею и чистый menubar — три кирпича дисциплины.

## Установка

### Recommended — `curl | bash` (без Gatekeeper alert'а)

```sh
curl -fsSL https://raw.githubusercontent.com/a2rk/hello-work/main/install.sh | bash
```

Скрипт качает stub-installer **через curl** (без quarantine-флага), кладёт в `/Applications` и запускает. Никакого «не удаётся открыть, разработчик не верифицирован» — flag отсутствует, Gatekeeper молчит.

### Homebrew

```sh
brew tap a2rk/hello-work https://github.com/a2rk/hello-work
brew install --cask hellowork
```

Brew качает через тот же механизм — без Gatekeeper alert'а.

### Вручную (DMG)

[Качай](https://github.com/a2rk/hello-work/releases/latest/download/HelloWork.dmg) и перетаскивай `Hello work.app` в `/Applications`.

При первом запуске будет alert «не удаётся открыть» — нужно зайти в **System Settings → Privacy & Security**, прокрутить вниз и нажать **Open Anyway**. Это потому что приложение подписано ad-hoc, без Apple Developer ID.

## Архитектура — stub + engine

`Hello work.app` — это **stub-installer** (~1 MB). При первом запуске он скачивает основной модуль (engine) с GitHub Release и кладёт в `~/Library/Application Support/HelloWork/HelloWork.app`. Дальше — silent launch engine, stub exits.

При следующих запусках stub просто запускает engine из Application Support, без UI.

Bundle IDs:
- Stub: `dev.helloworkapp.macos`
- Engine: `dev.helloworkapp.macos.engine`

## Сборка из исходников

```sh
git clone https://github.com/a2rk/hello-work
cd hello-work

# Engine (основной модуль)
./scripts/build.sh                # → dist/engine/HelloWork.app
./scripts/package.sh              # → dist/HelloWork-VERSION.dmg

# Stub (installer)
./scripts/build_stub.sh           # → dist/stub/Hello work.app
./scripts/package_stub.sh         # → dist/HelloWork.dmg (статичное имя)
```

Релиз: `./scripts/bump.sh minor && build всё && gh release create vX.Y.Z dist/HelloWork-X.Y.Z.dmg dist/HelloWork.dmg`.

## Архитектура engine

Feature-based модули в `Sources/HelloWork/`:

```
App/             @main, AppDelegate, AppState, Version
Domain/          Slot, ManagedApp, DragMode, UpdateInfo, AppPalette
Theme/           цвета, размеры
Overlay/         блюр-окна поверх приложений
StatusBar/       иконка в menubar
Updates/         конфиг dev-лога
WindowDetection/ поиск окон через CGWindowList
Focus/           focus mode + hider hotkey
Menubar/         menubar hider controller + scanner
Permissions/     onboarding для Accessibility
Preferences/     основное окно настроек со страницами
```

## Дев-лог

[`dev_log.json`](dev_log.json) — источник правды о версиях. Engine тянет его из этой ветки и показывает на странице «Обновления». Stub использует его чтобы знать какой engine качать.

Структура записи: `version`, `date`, `customMessage`, `main`, `points[]`, `dmgUrl`.
