# Hello work

macOS-приложение для разработчиков с двумя+ мониторами. Накладывает блюр поверх отвлекающих приложений по графику, который ты сам рисуешь на 24-часовом круге.

## Установка

Скачай свежий `HelloWork-X.Y.Z.dmg` со [страницы релизов](https://github.com/a2rk/hello-work/releases/latest), смонтируй и перетащи `HelloWork.app` в `Applications`.

В первый запуск Gatekeeper попросит «ПКМ → Открыть → Открыть» — приложение подписано ad-hoc.

## Сборка из исходников

```sh
git clone https://github.com/a2rk/hello-work
cd hello-work
swift run HelloWork              # dev-режим
./scripts/build.sh               # → dist/HelloWork.app
./scripts/package.sh             # → dist/HelloWork-VERSION.dmg
```

Релиз — `./scripts/bump.sh minor && ./scripts/build.sh && ./scripts/package.sh && ./scripts/deploy.sh`.

## Архитектура

Feature-based модули в `Sources/HelloWork/`:

```
App/         — @main, AppDelegate, AppState, Version
Domain/      — Slot, ManagedApp, DragMode, UpdateInfo
Theme/       — цвета, размеры
Overlay/     — блюр-окна поверх приложений
StatusBar/   — иконка в menubar
Updates/     — конфиг dev-лога
WindowDetection/ — поиск окон через CGWindowList
Preferences/ — основное окно настроек со страницами
```

Старый монолит лежит в `legacy/HelloApp.swift` — для истории.

## Дев-лог

[`dev_log.json`](dev_log.json) — источник правды о версиях. Приложение тянет его из этой ветки и показывает на странице «Обновления».

Структура записи: `version`, `date`, `customMessage`, `main`, `points[]`, `dmgUrl`.
