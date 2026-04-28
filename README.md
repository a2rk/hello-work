> ave claude

# Hello work

macOS-приложение для разработчиков с двумя+ мониторами. Расписание блокировок, фокус-режим по хоткею, чистый menubar, и модуль "Легенды" — расписания великих людей. Privacy-first, local-only.

## Установка

### Скачать DMG (рекомендуется)

[**HelloWork.dmg**](https://github.com/a2rk/hello-work/releases/latest/download/HelloWork.dmg) → открой → перетащи **HelloWork** в **Applications** → запусти из Launchpad/Spotlight.

При первом запуске Gatekeeper покажет «не удаётся открыть, неверифицированный разработчик». Это потому что приложение подписано ad-hoc (без Apple Developer ID за $99/год). Что делать:

1. Right-click по HelloWork в Applications → **Open** → **Open** в диалоге
2. ИЛИ зайти **System Settings → Privacy & Security**, прокрутить вниз → **Open Anyway**

Дальше система запомнит выбор, обычный double-click работает.

### Через Homebrew

```sh
brew tap a2rk/hello-work https://github.com/a2rk/hello-work
brew install --cask hellowork
```

Brew качает тот же DMG, ставит в `/Applications/HelloWork.app`.

### Через `curl` (для скриптов установки)

```sh
curl -fsSL https://raw.githubusercontent.com/a2rk/hello-work/main/install.sh | bash
```

Скрипт качает DMG **через curl** (без quarantine-флага) и распаковывает в `/Applications`. Gatekeeper молчит, потому что quarantine attribute не выставляется.

## Обновления

В приложении: **Settings → Updates → Install latest**. Кнопка скачивает новый DMG, монтирует, заменяет `/Applications/HelloWork.app` на новую версию через helper-скрипт, и перезапускает приложение. TCC permissions (Accessibility, Screen Recording) сохраняются — bundle ID и signing identity не меняются.

После рестарта — short toast «Updated to vX.Y.Z» в верху Preferences (auto-dismiss 5с).

## Удаление

1. Перетащи `/Applications/HelloWork.app` в Корзину.
2. Опционально удали данные:
   ```sh
   rm -rf ~/Library/Application\ Support/HelloWork
   rm -f  ~/Library/Preferences/dev.helloworkapp.macos.engine.plist
   rm -rf ~/Library/Caches/dev.helloworkapp.macos.engine
   rm -rf ~/Library/HTTPStorages/dev.helloworkapp.macos.engine
   ```
3. Опционально TCC permissions: `tccutil reset Accessibility dev.helloworkapp.macos.engine && tccutil reset ScreenCapture dev.helloworkapp.macos.engine`.

## Сборка из исходников

```sh
git clone https://github.com/a2rk/hello-work
cd hello-work
./scripts/setup_signing.sh        # один раз — создаёт стабильный self-signed cert (TCC continuity через апдейты)
./scripts/build.sh                # → dist/HelloWork.app
./scripts/package.sh              # → dist/HelloWork-VERSION.dmg + dist/HelloWork.dmg (static latest)
```

Релиз: `./scripts/bump.sh minor && build всё && gh release create vX.Y.Z dist/HelloWork-X.Y.Z.dmg dist/HelloWork.dmg`.

## Архитектура

Single-app: `/Applications/HelloWork.app`, bundle ID `dev.helloworkapp.macos.engine`. Стабильный self-signed cert «HelloWork Self-Signed» гарантирует что TCC permissions переживают апдейты (TCC ключуется по cert hash + bundle ID, не по пути).

Feature-based модули в `Sources/HelloWork/`:

```
App/                    @main, AppDelegate, AppState, MigrationManager
Domain/                 Slot, ManagedApp, DragMode, UpdateInfo, AppPalette,
                        Legends/ (60 historical figures' schedules)
Theme/                  цвета, размеры
Overlay/                blur-окна поверх приложений
StatusBar/              иконка в menubar
Updates/                UpdateInstaller (in-place /Applications replacement)
WindowDetection/        поиск окон через CGWindowList
Focus/                  focus mode + hider hotkey
Menubar/                menubar hider controller + scanner
Permissions/            onboarding для Accessibility/ScreenRecording
Preferences/            окно настроек со страницами + банеры миграции/обновления
```

### Migration history

Версии до 0.12 использовали stub+engine pattern (HWInstaller в /Applications + engine в ~/Library/Application Support/HelloWork). С 0.12.0 это упрощено до одного `/Applications/HelloWork.app`.

При первом запуске v0.12+ из /Applications, `MigrationManager` тихо чистит:
- `~/Library/Application Support/HelloWork/HelloWork.app` (старый engine)
- `/Applications/HWInstaller.app` → Trash

Затем показывает one-time toast «HelloWork moved to /Applications». UserDefaults и TCC permissions сохраняются (bundle ID не менялся).

## Дев-лог

[`dev_log.json`](dev_log.json) — источник правды о версиях. Engine тянет его из main ветки и показывает на странице «Обновления».

Структура записи: `version`, `date`, `customMessage`, `main`, `points[]`, `dmgUrl`.
