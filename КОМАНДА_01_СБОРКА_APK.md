# КОМАНДА_01 — СБОРКА APK (пошагово)

Итоговый артефакт этого конвейера: `STALKER_BUNKER.apk` (~32 МБ), подпись SHA-1 `7d1328b0…` — ставится поверх предыдущих установок БЕЗ сноса, если подпись та же.

## 1. Требования

| Компонент | Версия | Примечание |
|---|---|---|
| Godot | **4.6.1 stable** | обычная сборка (не .NET) |
| Export templates | **4.6.1.stable** | ставятся через Godot → Editor → Manage Export Templates |
| Android SDK | platform 34, build-tools **34.0.0** | |
| JDK | **21** | |
| Android Export Plugin | включить в Godot: Editor → Plugin / при первом экспорте спросит | |

## 2. Кейстор (КРИТИЧНО)

В `keystore/debug.keystore` лежит рабочий ключ проекта:

- SHA-1: `7d1328b0659c53ff2fa59e84ba5d05c34ca0cca2`
- storepass: `android`, alias: `androiddebugkey`, keypass: `android`
- Проверить: `keytool -list -keystore keystore/debug.keystore -storepass android`

**Куда положить:** `~/.android/debug.keystore` (Linux/macOS) или `%USERPROFILE%\.android\debug.keystore` (Windows).

**Грабля Godot 4.6 (наступали трижды):** когда редактор генерирует свежий `editor_settings-4.6.tres`, он АВТОМАТИЧЕСКИ создаёт свой собственный debug-ключ (CN=Godot) и прописывает его в настройки, а `java_sdk_path` остаётся ПУСТЫМ. Симптом: подпись собранного APK внезапно другая (инцидент с подписью `634f8f2f`) или экспорт падает с «A valid Java SDK path is required».

**Куда смотрит Godot:** файл настроек лежит в `~/.config/godot/editor_settings-4.6.tres` (Linux) — НЕ в `~/.local/share/godot/`! Там же живут шаблоны (`~/.local/share/godot/export_templates/`), но НЕ настройки. Если регенерировать файл вручную, используйте формат заголовка `[editor_settings]` (не `[gd_resource]`).

**Лечение:** `Editor → Editor Settings → Export → Android` — явно указать: Debug Keystore = путь к нашему файлу, User = `androiddebugkey`, Pass = `android`, Java SDK Path = корень JDK 21. Плюс удалить авто-ключ `~/.local/share/godot/keystores/` если редактор его создал. После любой регенерации editor settings — ПРОВЕРЯТЬ ВСЕ 4 ПОЛЯ. Лечебные строки в project-пресете уже стоят, но editor settings имеют приоритет.

## 3. Пресет экспорта

`export_presets.cfg` уже настроен и лежит в корне: preset называется **`Android`** (debug), package `com.stalker.revert`, текстурные форматы для мобилок включены. Трогать без нужды не надо.

## 4. Сборка из командной строки (Linux)

```bash
# 1) импорт ресурсов (после первого распаковывания или изменения ассетов)
godot --headless --path . --import

# 2) сборка APK
godot --headless --path . --export-debug "Android" STALKER_BUNKER.apk
```

В редакторе то же самое: Project → Export → пресет `Android` → **Export Project** (галку EFB/отладки по желанию).

## 5. Проверка результата

```bash
# подпись (должна быть 7d1328b0...)
apksigner verify --print-certs STALKER_BUNKER.apk | head -5

# установка поверх (та же подпись)
adb install -r STALKER_BUNKER.apk

# если менялась подпись: сначала снести
adb uninstall com.stalker.revert
```

Ожидаемый размер — около 32 МБ, ~1410 файлов внутри. Резко меньший размер (например, 5–10 МБ) = битый экспорт, так случалось при «сгоревшей» среде — пересобери начисто.

## 6. Логи на устройстве

```bash
adb logcat -s Godot:* AndroidRuntime:E
```

Все ошибки рантайма и print() из GDScript видны здесь.

## 7. Где лежат сохранения (для QA)

- Windows: `%APPDATA%\Godot\app_userdata\StalkerRevert\`
- Linux: `~/.local/share/godot/app_userdata/StalkerRevert/` (регистр имени важен!)
- Android: приватная папка приложения (`user://`), доступ только через саму игру или root.

Ключи сейва: `tower_floor` (текущий этаж башни), `tower_stars` (словарь звёзд, ключ — строка номера этажа), биомасса/крутки/инвентарь — см. `data/save_data.gd`.
