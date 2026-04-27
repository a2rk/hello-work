# Resources

Asset catalog для локализованных скриншотов онбординга.

## Как добавить скриншот

В каждой папке `onboarding_permissions_<lang>.imageset/` положи PNG-файлы:

```
onboarding_permissions_en.imageset/
├── Contents.json
├── permissions@1x.png   (рекомендуем 800×500)
├── permissions@2x.png   (1600×1000, retina)
└── permissions@3x.png   (опционально, 2400×1500)
```

И обнови `Contents.json` — пропиши `"filename"` для каждого scale.

Пока файлов нет — приложение показывает SwiftUI-плейсхолдер с пунктиром.

## Языки

- `onboarding_permissions_en` — английский
- `onboarding_permissions_ru` — русский
- `onboarding_permissions_zh` — китайский

Логика выбора в [LocalizedAsset.swift](../Permissions/LocalizedAsset.swift) — берёт скриншот по текущему языку, fallback на en, fallback на placeholder.
