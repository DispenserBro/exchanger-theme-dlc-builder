# Быстрый старт из VS Code

## Требования

- Windows 10/11;
- Godot 4.7.x с поддержкой .NET (проект не компилирует C#, но использует ту же версию, что host);
- PowerShell 7 или Windows PowerShell 5.1;
- VS Code и рекомендованное расширение `geequlim.godot-tools`.

Скрипты находят Godot в таком порядке: параметр `-GodotExecutable`, переменная процесса
`GODOT4_EXECUTABLE`/`GODOT_EXECUTABLE`, запущенный Godot Editor, команда `godot` или `godot4` в
`PATH`. Машинно-зависимый путь в `.vscode/settings.json` не хранится.

## Первое открытие

1. Откройте именно папку `ExchangerThemeDlcBuilder` в VS Code.
2. Для ИИ-агента первым сообщением попросите прочитать `AGENTS.md` и
   `docs/PROJECT_CONTEXT.md`. Агент сам обязан восстановить память проекта.
3. Разрешите установку рекомендованного расширения.
4. Откройте проект в Godot Editor. Аддон `Exchanger Theme Manager` включён по умолчанию.
5. В меню `Редактор` нажмите `Выбрать тему`, выберите `space-pixel` и подтвердите выбор.

Команда запишет выбранный package в `build/active-theme.json` и откроет главную preview-сцену
прямо из него. `Создать тему` в том же меню создаёт готовую копию `example`, проверяет ID и
сразу выбирает новую тему. После проверки закройте Exchanger и выберите
`Редактор → Применить тему к Exchanger`: аддон соберёт активную тему в фоне и установит PCK.
Если нужен только переносимый файл без установки, выберите `Редактор → Экспортировать тему` и
сначала укажите нужный ID темы (он не обязан быть активным в preview), затем задайте имя `.pck` в
стандартном диалоге сохранения. Все длительные команды показывают этап и процент выполнения.

## Happy path новой темы

Предпочтительный интерактивный путь: `Редактор → Создать тему`. Для скриптовой автоматизации:

```powershell
Copy-Item -LiteralPath .\themes\example -Destination .\themes\my-theme -Recurse
# Отредактируйте ThemeId/DisplayName в themes/my-theme/package/manifest.json
.\activate-theme.ps1 -ThemeId my-theme
.\preview-theme.ps1 -ThemeId my-theme
.\test-theme.ps1 -ThemeId my-theme
.\build-theme.ps1 -ThemeId my-theme
```

Каталог `themes/my-theme/package/` сразу виден в Godot FileSystem — редактируйте сцены и ресурсы
там напрямую. Каждая созданная из `example` сцена уже содержит Theme, фон и decoration и при
прямом открытии выглядит так же, как в preview. Preview читает эти же файлы и автоматически
перезагрузит текущую вкладку после их сохранения.

## Следующее чтение

- перед изменением сцены — [BINDING_CONTRACT.md](BINDING_CONTRACT.md);
- перед сборкой и установкой — [WORKFLOW.md](WORKFLOW.md);
- при ошибке — [QA_AND_TROUBLESHOOTING.md](QA_AND_TROUBLESHOOTING.md).
