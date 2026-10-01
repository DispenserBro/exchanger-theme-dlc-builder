# Создание полносценовой темы Exchanger

Для первого запуска начните с [быстрого старта](QUICK_START.md). Каноническое описание manifest и
metadata находится в [BINDING_CONTRACT.md](BINDING_CONTRACT.md), а последовательность команд — в
[WORKFLOW.md](WORKFLOW.md).

## Модель темы

Manifest версии 2 передаёт приложению полный визуальный корень каждого экрана. Exchanger оставляет
у себя бизнес-логику, навигацию, оплату, COM-контроллер и сохранение настроек, а тематическая сцена
определяет расположение, графику, анимацию и Godot `Control`-узлы. Приложение находит нужные узлы
по metadata binding-id и подключает к ним свою логику.

Production-тема считается доверенной. На корень, дочерние и вложенные сцены можно назначать
GDScript, подключать сигналы и использовать обычные runtime-узлы Godot: `AnimationPlayer`,
`AnimatedSprite2D`, `Timer`, `AudioStreamPlayer*`, `HTTPRequest`, частицы и шейдеры. Подробный
порядок и особенности жизненного цикла описаны в [SCRIPTING.md](SCRIPTING.md).

Оплата, выдача, COM-протокол и постоянные настройки остаются app-owned подсистемами Exchanger.
Скрипт темы может управлять своим деревом и взаимодействовать с доступным Godot runtime, но прямые
обращения к внутренним NodePath host не входят в стабильный binding-контракт.

Визуальное дерево самодостаточно: root `Control` применяет `../ui_theme.tres`, содержит
полноэкранный `ThemeBackground` и инстанс `BackgroundDecoration` перед рабочим UI, а
также metadata `exchanger_self_contained_visuals = true`. Поэтому открытая `.tscn`, вкладка preview
и экран Exchanger используют одну и ту же композицию. В manifest `UiThemePath` сохраняется как
описание package Theme, но `BackgroundTexturePath` и `BackgroundDecorationPath` пусты — иначе
внешний background-layer host продублирует содержимое сцены.

## Структура builder

```text
themes/
├── example/                           # копируемая валидная тема-шаблон
│   ├── source/                        # исходники и локальные references
│   └── package/                       # единственное содержимое будущего PCK
└── space-pixel/
    ├── source/                        # сохранённые исходные материалы пользователя
    └── package/
        ├── manifest.json
        ├── ui_theme.tres
        ├── background_decoration.tscn
        ├── assets/
        ├── components/
        ├── visuals/
        └── scenes/
contracts/screen_bindings.v2.json      # точный machine-readable каталог биндингов
tools/preview/                         # preview overlay; никогда не входит в PCK
addons/exchanger_theme_manager/        # EditorPlugin выбора и создания тем
build/                                 # PCK, выбор темы и скрытые временные workspaces
```

Редактируйте `themes/<theme-id>/package/`: это единственный источник preview и будущего PCK.
`source/references/` не экспортируется и игнорируется Git.
Старые `themes_src/` и `preview_scenes/` временно сохранены как архив исходных материалов и прежних
визуальных макетов; новые темы создаются только внутри `themes/`.

## Создание новой темы

1. В Godot Editor выберите `Редактор → Создать тему`.
2. Введите ID из строчных латинских букв, цифр и дефисов и понятное название.
3. Аддон скопирует `themes/example`, обновит `ThemeId`/`DisplayName`, активирует тему и откроет
   preview.

Все темы сразу видны в Godot FileSystem: `.gdignore` внутри `themes/` не используется. Аддон
удаляет legacy-файл из корня каждой темы при открытии проекта и не копирует его при создании темы.
Для неинтерактивной автоматизации новая тема создаётся копированием `example`, после чего
активируется:

```powershell
.\activate-theme.ps1 -ThemeId <theme-id>
```

4. Откройте `res://themes/<theme-id>/package/` в Godot и редактируйте исходники темы напрямую:
   работающий preview читает эти же файлы и автоматически перезагружается после сохранения.
5. Запустите проект (`F6`/`F5`). Все девять production-сцен видны во вкладках, а overlay биндингов
   включён по умолчанию.
6. Соберите PCK командой из раздела «Сборка».

## Имена сцен

Имена и пути фиксированы:

| Screen binding | Файл | Имя корня |
| --- | --- | --- |
| `screen.home` | `screen_home.tscn` | `ThemeScreen_Home` |
| `screen.cash_payment` | `screen_cash_payment.tscn` | `ThemeScreen_CashPayment` |
| `screen.card_amount` | `screen_card_amount.tscn` | `ThemeScreen_CardAmount` |
| `screen.card_custom_amount` | `screen_card_custom_amount.tscn` | `ThemeScreen_CardCustomAmount` |
| `screen.card_terminal` | `screen_card_terminal.tscn` | `ThemeScreen_CardTerminal` |
| `screen.success` | `screen_success.tscn` | `ThemeScreen_Success` |
| `screen.error` | `screen_error.tscn` | `ThemeScreen_Error` |
| `screen.service_access` | `screen_service_access.tscn` | `ThemeScreen_ServiceAccess` |
| `screen.settings` | `screen_settings.tscn` | `ThemeScreen_Settings` |

В PCK каждый файл обязан находиться в `res://exchanger_theme_dlc/scenes/`.

Сцена `screen_card_custom_amount.tscn` в шаблоне уже содержит эталонную раскладку пинпада:
широкую рабочую панель, центрированную сетку `3×4`, зазоры `12 px` и двенадцать квадратных
клавиш `152×152 px`. При оформлении новой темы можно менять их графику и стили, сохраняя
binding-id, типы узлов и удобную touch-геометрию.

Клавиатура PIN-кода в `screen_service_access.tscn` использует ту же вариацию `KeypadButton`:
центрированную сетку `3×4`, зазоры `12 px` и двенадцать квадратных клавиш `112×112 px`.
Меньший размер оставляет место для статуса, действий `ВОЙТИ`/`ОТМЕНА` и общего footer.

## Metadata биндингов

Корень имеет metadata:

```text
exchanger_screen_binding_id = screen.<key>
```

Каждый интерактивный или динамически обновляемый элемент имеет:

```text
exchanger_binding_id = <точный id из contracts/screen_bindings.v2.json>
```

Идентификатор не зависит от фактической иерархии тематической сцены. Узлы можно перемещать и
переименовывать, но binding-id, требуемый тип и уникальность изменять нельзя. Для `Button` нужен
узел класса `Button` или наследник, для `Label` — `Label`, для `Control` — любой наследник
`Control`. Каталог содержит 481 обязательный immutable element-binding и исходный fallback path
каждого. Текущий Builder дополнительно требует 24 supplemental runtime-binding; ещё два
совместимых optional ID для текстов баннеров не препятствуют проверке старой темы. Полностью
обновлённая тема содержит 509 element-binding. Их полный список приведён в
[BINDING_CONTRACT.md](BINDING_CONTRACT.md#supplemental-runtime-bindings).
Его байт-в-байт копия обязана находиться в каждой теме по пути
`package/contracts/screen_bindings.v2.json` и экспортируется как
`res://exchanger_theme_dlc/contracts/screen_bindings.v2.json`. Перед загрузкой сцен Exchanger
сверяет SHA-256 этого файла с закреплённым в приложении хешем контракта. Поэтому каталог нельзя
переформатировать, сокращать или генерировать независимо от host: нужна точная байтовая копия.

Ни один binding-контейнер не является пустым местом для runtime UI. Home содержит готовые
theme-owned состояния запаса/подключения и узлы промо. CardAmount и Settings содержат полный набор
фиксированных индексированных слотов. Дизайнер оформляет каждый слот в сцене; Exchanger только
заполняет существующие поля и скрывает неиспользуемые root-слоты.

Итоговые панели CashPayment, CardAmount и CardCustomAmount используют общий визуальный паттерн с
заголовком «К ВЫДАЧЕ»: базовые жетоны находятся слева, бонус — справа. В CardAmount сохраняйте
обязательный `Label` `Value` с binding-id `card_amount.content.reward_panel.content.value` по пути
`SafeMargin/Content/RewardPanel/Content/Value` и добавляйте сразу после него `Label` `Bonus` с
supplemental binding-id `card_amount.content.reward_panel.content.bonus` по пути
`SafeMargin/Content/RewardPanel/Content/Bonus`. `Value` содержит только базовые жетоны, `Bonus` —
`+ N ЖЕТОНОВ\nВ ПОДАРОК` либо `БЕЗ БОНУСА`. Supplemental ID не добавляется в JSON-каталог 481
элемента; его отсутствие в старой теме обрабатывает host fallback, но в новых темах он обязателен
для Builder Validator.

В CardCustomAmount существующие `Amount` и `Tokens` сохраняют контрактные ID и пути, но также
размещаются соответственно слева и справа. Двухстрочный bonus sample должен содержать явный перенос
перед «В ПОДАРОК»; динамический текст меняет host. Не объединяйте эти значения и не создавайте
runtime-узлы из host-кода.

Отдельный Label `home.scroll.content.speech_text` выводит короткую фразу покупателю в речевой
плашке Home. В SETTINGS ей соответствуют `short_text`, `short_text_error` и строка предпросмотра;
поле ограничено 48 символами. Это самостоятельная настройка, не описание приложения и не
устаревший `subtitle`. Label Home должен переносить текст, обрезать выход за границы и сохранять
горизонтальное/вертикальное центрирование внутри авторской плашки.

В актуальном интерфейсе SETTINGS → «Общие» владельцу автомата показывается поле с подписью
«СВОЙ ТЕКСТ • ДО 48 ЗНАКОВ» и контакты техподдержки. Узлы `application_name` и весь
`branding_preview_panel` сохраняются с прежними binding-id и типами только для совместимости,
но по умолчанию скрыты и не занимают место в композиции. Не удаляйте и не переименовывайте эти
узлы при оформлении темы.

Не добавляйте в preview демонстрационные замены этих узлов: начальные значения и видимость
настраиваются прямо в production-сцене. В `example` и `space-pixel` первые восемь сумм видимы,
резервные слоты 08–15 скрыты; бонусы и промо-строки начинают с видимого `empty_state`.

Экран SETTINGS также инстанцирует собственный
`package/components/on_screen_keyboards.tscn`. В нём заранее находятся две скрытые панели:
текстовая (33 буквенных слота 12/11/10 и служебные действия) и цифровая (0–9, очистка,
удаление). Менять композицию и оформление можно, но нельзя удалять binding metadata, менять тип
клавиш или включать фокус у `Button`. Кнопка скрытия каждой панели располагается справа в её
верхней строке. Для проверки используйте `KEYBOARD: OFF/TEXT/NUM` на вкладке SETTINGS preview.

В той же SETTINGS-сцене заранее создаются скрытые `ServiceInventoryPanel` и
`ServiceDialogOverlay`. Панель показывает учтённый остаток и две операции, а диалог содержит
редактируемое количество и подтверждение. Сохраняйте 14 точных ID из контракта, тип `SpinBox`
для `amount`, пустой suffix и начальное `visible = false` у панели и overlay. На самом
`Description` обязателен supplemental binding-id
`...service_inventory_panel.margin.content.description`, чтобы host мог менять описание
по режиму учёта. Сразу после `Description` панель также содержит supplemental
`CheckButton` `InventoryAccountingEnabled` с binding-id
`...service_inventory_panel.margin.content.inventory_enabled`, подписью
«УЧИТЫВАТЬ ОСТАТОК ЖЕТОНОВ» и включённым состоянием по умолчанию. Сразу после него обязателен
второй `CheckButton` `PurchaseLimitEnabled` с binding-id
`...service_inventory_panel.margin.content.purchase_limit_enabled`, подписью «НЕ ПРОДАВАТЬ БОЛЬШЕ ОСТАТКА» и
включённым состоянием по умолчанию. Минимальная высота сервисной панели — `772 px`; тема может увеличить
фактическую высоту из-за своих minimum sizes. Все три supplemental ID не входят в JSON-каталог 481
элемента, но обязательны для совместимого runtime и проверяются Builder
Validator. Для визуальной проверки используйте `INVENTORY: OFF/PANEL/DIALOG`.

## Preview и подписи

`tools/preview/BindingOverlay.gd` обходит реально загруженную production-сцену и показывает рамку
и binding-id каждого размеченного узла. Кнопка `BINDINGS: ON/OFF` находится первой слева в общей
верхней панели экранов и управляет overlay. Overlay и preview-скрипты находятся вне package,
поэтому не экспортируются в production PCK.

Галерея не меняет root, anchors, Theme или дочерние узлы production-сцены и не добавляет
демонстрационные подписи в Home-host. Единственное наложение — отдельный sibling `BindingOverlay`.

Preview следит за package активной темы, путь к которой записан в `build/active-theme.json`.
После изменения `.tscn`, `.tres`, JSON, изображений, шрифтов или звука галерея перезагружается
с сохранением выбранной вкладки.

## Интерактивный питомец темы

Питомец необязателен и полностью принадлежит конкретной теме. Создайте любую `Node2D`-сцену
внутри `package/`, реализуйте публичные методы и сигналы из [SCRIPTING.md](SCRIPTING.md), затем
укажите её канонический runtime-путь в `InteractivePetScene` manifest. Рекомендуемое имя сцены —
`components/interactive_pet.tscn`, но графику можно хранить в любой собственной подпапке package
и подключать обычными относительными resource-ссылками. Builder не требует `alien_pet`,
`alien_animation` или другого персонажно-зависимого имени каталога.

Кнопка `PET` доступна только когда active manifest объявляет загружаемую сцену. Viewer сам
инстанцирует компонент и создаёт кнопки по `get_pet_animation_names()`, поэтому число и имена
состояний выбирает автор темы. Старый путь `components/alien_pet.tscn` распознаётся только как
fallback миграции ранее собранных тем и не должен использоваться в новых packages.

Для составного действия начните с дизайнерской раскадровки и пошагового руководства
[COMPOSITE_PET_ANIMATIONS.md](COMPOSITE_PET_ANIMATIONS.md). Composite API не добавляет новых
`exchanger_binding_id`: питомец подключается через manifest и методы сцены, а его маршруты — через
navigation v1 metadata экранов.

Чтобы питомец ходил по элементам всех экранов, добавьте под root каждой production-сцены, кроме
`screen.settings`, невидимый `Node2D` с `exchanger_pet_navigation_root = true` и v1 metadata из
[BINDING_CONTRACT.md](BINDING_CONTRACT.md). Отдельными `Node2D` разметьте горизонтальные верхние
грани пола, кнопок и окон, допустимые точки сидения и вертикальные climb edges между ними.
Координаты являются реальными scene-local точками контакта; имена marker-узлов произвольны и host
их не читает. При смене экрана питомец падает со старой позиции на default surface нового графа,
затем использует все его поверхности. В Settings питомец скрыт. Не меняйте ради навигации
размеры/позиции визуальных `Control` и не добавляйте видимые линии: маркеры сами ничего не рисуют.

Для корректной посадки персонажа реализуйте optional `get_pet_ground_offset()` и runtime-профиль
из [SCRIPTING.md](SCRIPTING.md). Имена, передаваемые host, совпадают с реальными именами
анимаций темы. `get_pet_hit_size()` определяет зону захвата пальцем и зажатой ЛКМ; `hanging`
выбирает анимацию на время удержания и перетаскивания, `falling` — на время падения после
отпускания или перехода между экранами,
`landing` — одноразовую анимацию после контакта с опорой, а `idle` — устойчивый цикл ожидания
после её завершения. Если тема не предоставляет `landing`, host сразу переходит из `falling` в
`idle`, сохраняя совместимость со старыми темами. `celebrate` запускает праздничную анимацию при
начале выдачи жетонов; запрос, пришедший во время `landing`, ждёт окончания приземления. Host
проигрывает четыре полных цикла `celebrate`; для точного времени тема должна возвращать корректную
скорость через `get_pet_animation_frames_per_second()`.

После завершённой ходьбы Exchanger выбирает состояние простоя случайно: с вероятностью `35%`
запускает `idle`, а с вероятностью `65%` — `sitting`. Если `sitting` отсутствует, host использует
`idle`, поэтому старые темы не требуют обновления.

## Manifest v2

`ScreenScenes` должен содержать ровно девять канонических пар из таблицы выше. Старый словарь
`VisualSlots` допускается для обратной совместимости `space-pixel`, но полноэкранный host использует
`ScreenScenes`. Внутренние English-идентификаторы `Advertisement*` остаются стабильными; видимый
русский текст использует только «промо» и «промо-ролик».

## Проверка и синхронизация контракта

Для обычной автономной разработки темы сначала проверяйте копии без обращения к host:

```powershell
.\tools\Test-PackagedBindingContract.ps1
.\test-theme.ps1 -ThemeId <theme-id>
```

Каталог можно пересобрать из C# host:

```powershell
.\tools\Sync-HostBindingContract.ps1 -HostProject ..\exchanger
.\tools\Sync-HostBindingContract.ps1 -HostProject ..\exchanger -Check
```

Эталонные структуры сцен можно повторно импортировать из fallback-сцен host и автоматически
разметить:

```powershell
.\tools\Import-HostSceneTemplates.ps1 -HostProject ..\exchanger -ThemeIds example,space-pixel
```

Команда импорта перезаписывает `package/scenes`, поэтому индивидуальную композицию темы сначала
сохраните отдельно. Валидатор запускается автоматически при сборке и проверяет manifest, имена,
root metadata, наличие и типы всех биндингов и уникальность id. Скрипты и runtime-узлы темы
разрешены и проверяются обычным импортом Godot.

## Сборка

```powershell
.\build-theme.ps1 -ThemeId space-pixel
.\build-theme.ps1 -ThemeId my-theme -InstallToDefaultUserPath
.\build-theme.ps1 -ThemeSource D:\Themes\my-theme -OutputPath build\my-theme.pck
```

Сборка выбирает тему, копирует только `package/` во временный изолированный проект под
канонический runtime-путь `res://exchanger_theme_dlc/`, валидирует, создаёт
`build/<theme-id>.pck` и удаляет workspace. Совместимая копия также записывается в
`build/active_theme.pck`.

Для шрифтов сборка сохраняет настройки соседнего `.import` и переносит их на runtime-путь.
Для строгого pixel-font вида выставьте в Godot `Antialiasing: None`, `Hinting: None`,
`Subpixel Positioning: Disabled`, `Oversampling: 1.0`, а на корне production-сцены —
`Texture Filter: Nearest`. Это действует на весь текст, наследующий фильтр корня.
Если manifest содержит `UseNearestTextureFilter: true`, валидатор требует `Nearest` на корне
каждой из девяти production-сцен: одной фильтрации `ThemeBackground` недостаточно. При переходе
с логического `720×1280` на физическое `1080×1920` коэффициент равен `1,5`; Nearest убирает
смешивание соседних пикселей, но не может сделать дробное масштабирование равномерным — строгие
одинаковые pixel-блоки возможны только при целочисленном коэффициенте.

## Критерии готовности

- manifest версии 2 содержит девять `ScreenScenes`;
- имена файлов, корней и screen metadata строго канонические;
- 481 immutable и 24 обязательных supplemental element-binding присутствуют по одному разу и
  имеют допустимые типы;
- GDScript и все его зависимости импортируются без parser/runtime-ошибок;
- каждая сцена сама содержит package Theme, `ThemeBackground`, `BackgroundDecoration` и root-флаг
  `exchanger_self_contained_visuals = true`;
- визуальные эффекты и скриптовая логика корректно работают в preview и Exchanger;
- overlay показывает все биндинги на всех девяти вкладках;
- валидатор, preview smoke и export PCK проходят без ошибок;
- PCK проверен в Exchanger, включая переходы, ввод, настройки, оплату и выдачу.
