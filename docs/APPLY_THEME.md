# Как применить тему в Exchanger

Эта инструкция описывает полный пользовательский путь: от выбора и редактирования темы до
установки нового PCK в Exchanger.

Важно различать действия:

- `Редактор → Выбрать тему` и `activate-theme.ps1` выбирают тему только для builder-preview;
- `Редактор → Экспортировать тему` позволяет выбрать любую тему по ID и создаёт указанный
  пользователем `.pck`, но не устанавливает его и не переключает preview;
- `Редактор → Применить тему к Exchanger` проверяет, собирает и устанавливает активную тему;
- `build-theme.ps1 -InstallToDefaultUserPath` выполняет ту же установку из PowerShell.

## 1. Открыть проект

Требуется Godot 4.7.x. Откройте проект `ExchangerThemeDlcBuilder` в Godot Editor, а PowerShell —
в корне проекта:

```powershell
Set-Location 'E:\Danil\Projects\Godot\ExchangerThemeDlcBuilder'
```

Скрипты автоматически ищут Godot среди запущенных процессов, команд `godot`/`godot4` в `PATH` и
переменных `GODOT4_EXECUTABLE`/`GODOT_EXECUTABLE`.

## 2. Выбрать тему для preview

В Godot Editor выберите `Редактор → Выбрать тему`, укажите нужную тему и подтвердите выбор.

Эквивалентная команда для `space-pixel`:

```powershell
.\activate-theme.ps1 -ThemeId space-pixel
```

Активация записывает выбранный package в `build/active-theme.json`. Она не собирает PCK и не
изменяет установленную тему Exchanger.

## 3. Редактировать production-файлы

Редактируйте файлы непосредственно в:

```text
themes/<theme-id>/package/
```

Основные каталоги и файлы:

- `scenes/` — девять экранов приложения;
- `components/` — общие компоненты темы;
- `assets/` — изображения, шрифты и звук;
- `visuals/` — дополнительные визуальные ресурсы;
- `ui_theme.tres` — стили элементов интерфейса;
- `background_decoration.tscn` — отдельная фоновая декорация.

`source/` используется для оригиналов и references, но в production PCK не экспортируется.

Все зависимости внутри `package/` должны оставаться переносимыми. Используйте относительные
ссылки, например `../ui_theme.tres` или `../assets/button.png`. Ссылки вида
`res://themes/<theme-id>/package/...` могут открываться в builder, но не разрешатся в изолированном
workspace сборки, где package монтируется как `res://exchanger_theme_dlc/`.

## 4. Проверить preview

Запустите проект из Godot либо выполните:

```powershell
.\preview-theme.ps1 -ThemeId space-pixel
```

Preview показывает реальные production-сцены без изменения их визуального дерева. Проверьте все
девять вкладок: `HOME`, `CASH`, `SUM`, `KEYPAD`, `CARD`, `SUCCESS`, `ERROR`, `SERVICE`, `SETTINGS`.

Сначала включите `BINDINGS: ON`, чтобы проверить размеченные функциональные элементы, затем
выключите overlay и проверьте внешний вид в портретном окне `720×1280`. В SETTINGS дополнительно
проверьте состояния `KEYBOARD: OFF/TEXT/NUM` и `INVENTORY: OFF/PANEL/DIALOG`.

Сохранённые изменения `.tscn`, `.tres`, JSON, изображений, шрифтов и звука обычно появляются через
live reload. Если этого не произошло, убедитесь, что активирована правильная тема, сохраните файл
на диск и перезапустите preview.

## 5. Выполнить автоматические проверки

```powershell
.\tools\Test-PackagedBindingContract.ps1
.\test-theme.ps1 -ThemeId space-pixel
```

Первая команда проверяет byte-identical копии binding-контракта во всех темах. Вторая создаёт
изолированный workspace, импортирует ресурсы, проверяет manifest v2, девять сцен, обязательные
биндинги и запрещённые production-узлы, а затем выполняет headless preview smoke.

Не переходите к установке, пока обе команды не завершатся успешно.

## 6. Закрыть Exchanger

Полностью закройте запущенное приложение перед заменой PCK. Live reload действует только в
builder-preview; Exchanger загружает внешний пакет при запуске.

## 7. Собрать и установить тему

Предпочтительный интерактивный путь: закройте Exchanger и выберите в Godot Editor
`Редактор → Применить тему к Exchanger`. Подтверждение показывает ID активной темы и конечный
путь. Сборка идёт в фоне; по завершении аддон сообщает об успехе либо показывает последние строки
ошибки PowerShell. Во время работы видны текущий этап и процент выполнения.

Эквивалентная команда:

```powershell
.\build-theme.ps1 -ThemeId space-pixel -InstallToDefaultUserPath
```

Команда валидирует тему, собирает `build/space-pixel.pck`, обновляет совместимую копию
`build/active_theme.pck` и устанавливает пакет по пути:

```text
%APPDATA%\Godot\app_userdata\Exchanger\theme_dlc\active_theme.pck
```

Команда без `-InstallToDefaultUserPath` только создаёт PCK в `build/`; в Exchanger такая сборка
автоматически не попадёт.

## 8. Перезапустить и проверить Exchanger

Запустите Exchanger заново и проверьте все затронутые экраны и интерактивные элементы. В журнале
должны быть указаны ожидаемые `ThemeId` и manifest версии 2.

Если приложение показывает встроенную fallback-тему:

1. убедитесь, что Exchanger был полностью перезапущен;
2. проверьте наличие установленного `active_theme.pck` по пути выше;
3. повторите validator и сборку без `-SkipValidation`;
4. проверьте журнал ThemeManager на ошибку manifest, контракта, binding-id или отсутствующего
   ресурса.

## Короткий ежедневный цикл

После редактирования темы выполните:

```powershell
.\activate-theme.ps1 -ThemeId space-pixel
.\tools\Test-PackagedBindingContract.ps1
.\test-theme.ps1 -ThemeId space-pixel
```

Затем закройте Exchanger, установите новую сборку и запустите приложение заново:

```powershell
.\build-theme.ps1 -ThemeId space-pixel -InstallToDefaultUserPath
```

## Выполнение через VS Code

Откройте палитру команд `Ctrl+Shift+P`, выберите `Tasks: Run Task` и последовательно запустите:

1. `Theme: активировать`;
2. `Theme: проверить копии контракта`;
3. `Theme: проверить validator и preview smoke`;
4. после закрытия Exchanger — `Theme: собрать и установить PCK (заменяет установленную тему)`.

Задача `Theme: полный локальный QA` выполняет проверки и обычную сборку, но не устанавливает PCK
в пользовательский каталог Exchanger.
