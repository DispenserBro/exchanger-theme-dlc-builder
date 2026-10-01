# QA и решение проблем

## Автоматический checklist

```powershell
.\tools\Test-PackagedBindingContract.ps1
.\test-theme.ps1 -ThemeId example
.\test-theme.ps1 -ThemeId space-pixel
.\build-theme.ps1 -ThemeId space-pixel
godot --headless --path . --script res://tools/verify_interactive_pet.gd -- --theme space-pixel
```

Проверяется формат manifest, девять сцен, root names/metadata, 481 immutable и 24 обязательных supplemental
обязательных ID, типы и уникальность, самодостаточные Theme/background/decoration, импорт GDScript
и остальных ресурсов, запуск preview и export PCK.
Если manifest содержит `InteractivePetScene`, `test-theme.ps1` и `build-theme.ps1` также запускают
generic pet verifier. Он проверяет scene/API/сигналы/анимации и неподвижность корня, но не ищет
текстуры по имени папки.

## Визуальный checklist 720×1280

1. Убедитесь, что в меню `Редактор` доступны `Выбрать тему`, `Создать тему`,
   `Экспортировать тему` и `Применить тему к Exchanger`, а selector показывает `example` и
   `space-pixel`. Экспорт должен позволять выбрать каждый ID независимо от активной темы, затем
   предложить путь `.pck`; применение — показать стандартный путь Exchanger.
2. Для выбора, создания, экспорта и применения проверьте окно прогресса: название этапа, процент,
   итоговый путь и доступную после завершения кнопку закрытия.
3. Откройте все девять вкладок: HOME, CASH, SUM, KEYPAD, CARD, SUCCESS, ERROR, SERVICE, SETTINGS.
4. С `BINDINGS: ON` убедитесь, что каждый функциональный элемент имеет рамку и осмысленный ID.
5. С `BINDINGS: OFF` проверьте отступы, центрирование изображений, контраст текста, отсутствие
   обрезания и перекрытий.
6. Проверьте длинные суммы, сообщения, русские подписи и все внутренние разделы SETTINGS.
7. В SETTINGS переключите `KEYBOARD: OFF → TEXT → NUM`: обе панели должны быть снизу,
   не выходить за 720×1280, иметь кнопку скрытия справа сверху и удобные touch-клавиши.
8. С `BINDINGS: ON` проверьте все 57 keyboard ID; при `OFF` клавиатуры не должны занимать место.
9. Переключите `INVENTORY: OFF → PANEL → DIALOG`: проверьте остаток, обе кнопки, статус,
   редактируемое количество и подтверждение; с `BINDINGS: ON` должны быть видны все 14 ID.
10. Убедитесь, что фон неподвижен, а движение ограничено отдельными спрайтами.
11. Сохраните `.tscn` или `.tres` при открытой вкладке и подтвердите live reload без сброса вкладки.
12. Просмотрите game/editor logs через `godot-ai`: новые parser/runtime/resource errors недопустимы.
13. Откройте хотя бы одну `.tscn` прямо из `themes/<id>/package/scenes/` и сравните с той же вкладкой:
   кроме внешней навигации/overlay галерея не должна менять её вид или дерево.

## Частые ошибки

### Godot 4.7 не найден

Запустите Godot Editor, добавьте `godot`/`godot4` в PATH, задайте в текущем терминале
`$env:GODOT4_EXECUTABLE = 'D:\path\to\Godot.exe'` или передайте `-GodotExecutable`. Не указывайте
исполняемый файл MCP-сервера `godot-ai`: это не Godot Editor.

### Preview показывает не ту тему

Повторите `activate-theme.ps1 -ThemeId <id>` и проверьте `build/active-theme.json`: поле
`Package` должно указывать на нужный `themes/<id>/package/`. Preview читает его напрямую.

### Изменение package не появилось

Preview должен быть запущен после активации. Сохраните файл на диск, подождите около секунды и
проверьте вывод `[Theme Preview]`. Для нового типа ресурса, которого нет в watched extensions,
перезапустите preview или дополните tooling отдельной задачей.

### Missing/duplicate/wrong type binding

Найдите ID в `contracts/screen_bindings.v2.json`, проверьте metadata узла и его Godot-класс.
Иерархия/имя дочернего узла не важны; ID, класс и уникальность обязательны.

### Packaged binding catalog differs

Не копируйте JSON вручную с изменением кодировки. Если host не менялся, восстановите точную копию
`contracts/screen_bindings.v2.json` в package. Если host изменился, выполните согласованную миграцию
из `BINDING_CONTRACT.md` и обновите Exchanger.

### Скрипт работает в preview, но не после сборки

Убедитесь, что `.gd` находится внутри `themes/<id>/package/` и прикреплён к экспортируемой сцене
либо загружается из неё. Проверьте относительные пути, parser errors при `test-theme.ps1` и журнал
Exchanger после полного перезапуска. `_init()` может вызываться при предварительной валидации
PackedScene; runtime-инициализацию, которой требуется SceneTree, размещайте в `_ready()`.

### PCK собрался, но Exchanger использует fallback

Закройте и перезапустите Exchanger, проверьте путь установки, manifest v2, hash контракта и журнал
ThemeManager. Затем выполните интеграционный checklist из `THEME_INTEGRATION.md`.

## Критерий готовности

Автоматические команды успешны, все девять экранов визуально проверены в портретном окне, журнал
чист, PCK содержит только production-ресурсы, изменения и ограничения отражены в docs/agentmemory.
