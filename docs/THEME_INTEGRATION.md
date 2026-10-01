# Интеграция полносценовой темы в Exchanger

Этот документ описывает границу с основным приложением. Для локального цикла разработки используйте
[WORKFLOW.md](WORKFLOW.md), а для точной схемы контракта —
[BINDING_CONTRACT.md](BINDING_CONTRACT.md).

## Граница ответственности

Exchanger монтирует один внешний PCK, проверяет manifest v2 и создаёт визуальный корень выбранного
экрана из `ScreenScenes`. C#-контроллер экрана остаётся в приложении. Он разрешает нужные тематические
узлы по `exchanger_binding_id`, подписывает кнопки и обновляет текст/состояния. Он не добавляет,
не удаляет, не переносит и не стилизует визуальные узлы ThemeView. Тема считается доверенной:
прикреплённый GDScript и её runtime-узлы исполняются как часть инстанцированной сцены.
App-owned C#-контроллеры оплаты, оборудования и настроек остаются вне ThemeView, но тема может
содержать собственные таймеры, аудио, сетевые запросы и другую вспомогательную логику.

PackedScene уже содержит root Theme, `ThemeBackground` и `BackgroundDecoration`; это тот же файл,
который открывается напрямую и показывается в builder preview. `UiThemePath` описывает Theme
самодостаточных сцен. `BackgroundTexturePath` и `BackgroundDecorationPath` у
самодостаточных тем пусты, поэтому общий background-layer Exchanger не дублирует визуальные слои
экранной сцены.

При любой ошибке PCK приложение использует единственную встроенную fallback-тему.

## Установка

```powershell
.\build-theme.ps1 -ThemeId space-pixel -InstallToDefaultUserPath
```

Пакет устанавливается в:

```text
%APPDATA%\Godot\app_userdata\Exchanger\theme_dlc\active_theme.pck
```

Перед заменой PCK закройте Exchanger. После установки выполните полный перезапуск.

## Контракт

Источником истины для автономной работы builder является `contracts/screen_bindings.v2.json`.
Он генерируется и при согласованной миграции синхронизируется с:

- `src/core/ThemeManager/ThemeSceneContract.cs`;
- `src/core/ThemeManager/ThemeBindingResolver.cs`;
- вызовами `GetNode(SafeMargin/...)` в девяти C#-контроллерах экранов.

Путь, имя root, screen metadata, element metadata и тип каждого обязательного узла должны совпасть.
Фактическая иерархия узлов внутри сцены темы свободна: приложение ищет их по metadata, а не NodePath.

Каждая тема включает точную байтовую копию каталога по каноническому runtime-пути
`res://exchanger_theme_dlc/contracts/screen_bindings.v2.json`. Host до создания ThemeView вычисляет
SHA-256 встроенного файла и сравнивает его с закреплённым хешем поддерживаемой версии контракта.
Несовпадение означает несовместимый или изменённый пакет и приводит к безопасной fallback-теме.

## Проверка интеграции

1. В журнале активирован ожидаемый `ThemeId` и manifest версии 2.
2. Все девять экранов созданы из соответствующих `ScreenScenes`.
3. Кнопки навигации и оплаты реагируют на касание.
4. Динамические Label, формы, PIN-клавиатуры и настройки обновляются через биндинги.
5. Home находит готовые stock/connection/promo nodes без изменения дерева ThemeView.
6. Технические панели остаются скрытыми/управляются host-логикой так же, как во fallback-сцене.
7. В production PCK нет preview overlay, builder tooling, `source/` и references; GDScript и
   runtime-ресурсы самой темы присутствуют и запускаются без ошибок.
8. При повреждённой сцене, неверном типе или отсутствующем binding-id активируется безопасный fallback.

## Совместимость

Manifest v1 и `VisualSlots` относятся к прежней частичной модели. `space-pixel` пока сохраняет
старые English `Advertisement*` identifiers и `VisualSlots` для миграции, но новым темам следует
использовать v2 `ScreenScenes`. В пользовательском русском интерфейсе используются «промо» и
«промо-ролик».
