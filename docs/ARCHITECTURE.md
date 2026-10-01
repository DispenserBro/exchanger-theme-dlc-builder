# Архитектура и границы ответственности

## Общая модель

Theme Builder создаёт полные доверенные тематические сцены. Exchanger загружает PCK, проверяет
manifest и binding-контракт, создаёт тематическую сцену экрана и подключает свою C#-логику к
узлам по metadata. Фактическая иерархия, визуальные эффекты и GDScript-логика темы свободны, пока
соблюдены обязательные ID и типы.

```text
themes/<id>/package ───────────────> preview gallery + binding overlay
        │
        └── temporary build workspace/exchanger_theme_dlc
                         ├── validator
                         └── export ──> build/<id>.pck ──install──> Exchanger userdata
```

## Дерево проекта

```text
themes/
├── example/
│   ├── source/                 исходные материалы будущей темы
│   └── package/                полный безопасный шаблон v2
├── space-pixel/                текущая оформленная тема для preview
└── <theme-id>/
    ├── source/                 оригиналы, лицензии, references
    └── package/
        ├── manifest.json
        ├── contracts/screen_bindings.v2.json
        ├── scenes/             девять production-сцен
        ├── assets/             runtime-копии изображений/шрифтов/аудио
        ├── components/         вложенные сцены и runtime-компоненты темы
        ├── scripts/            GDScript доверенной темы
        ├── visuals/            необязательные визуальные фрагменты
        ├── ui_theme.tres
        └── background_decoration.tscn
contracts/                      авторитетная копия builder-контракта
tools/preview/                   галерея, live reload и overlay
addons/exchanger_theme_manager/ EditorPlugin выбора/создания тем
build/                           PCK, active-theme.json и временные build-workspaces
```

`themes_src/` и `preview_scenes/` — архив ранней partial-theme модели. Они не являются источником
новой разработки и не входят в PCK. Для новых задач используйте только `themes/` и
`tools/preview/`.

Каталоги тем не содержат `.gdignore` и всегда индексируются Godot, поэтому все исходники
`themes/<id>/package/` доступны в FileSystem. `Exchanger Theme Manager` использует те же видимые
каталоги для списка тем, а preview инстанцирует сцены выбранного package напрямую. Внутренние
зависимости package записываются относительными путями, поэтому каждая открытая сцена использует
ресурсы своей темы. Сгенерированные `.import`/`.uid` не копируются в новую тему. При сборке
обычные `.import` создаются заново, но sidecar-файлы шрифтов `.ttf`, `.otf`, `.woff` и `.woff2`
переносятся с заменой package-пути на runtime-путь: так сохраняются заданные автором antialiasing,
hinting, subpixel positioning и oversampling. Затем package временно копируется под namespace
`res://exchanger_theme_dlc/`; export preset включает только этот namespace и его зависимости.

Каждая production-сцена является полным визуальным корнем: на её root назначен package
`ui_theme.tres`, а фон и decoration-сцена находятся внутри её дерева перед
функциональным содержимым. Root помечен `exchanger_self_contained_visuals = true`. Preview не
назначает сцене Theme, не добавляет фон/декорации и не монтирует демонстрационные дочерние узлы —
только инстанцирует девять сцен во вкладки. `UiThemePath` остаётся описанием package Theme, а
legacy `BackgroundTexturePath` и `BackgroundDecorationPath` у
самодостаточной темы пусты, чтобы Exchanger не нарисовал тот же chrome второй раз.

## Что принадлежит Theme Builder

- композиция и стили девяти экранов;
- фон, анимации, шейдеры, частицы и другие визуальные эффекты;
- собственный GDScript и theme-owned runtime-компоненты;
- package-ресурсы и manifest;
- preview, binding overlay, validator и build scripts;
- локальные исходные материалы и документация темы.

## Что принадлежит Exchanger

- навигация и состояние пользовательского потока;
- оплата, выдача, COM-протокол и оборудование;
- сохранение и проверка настроек, PIN, таймеры и аудио-сервисы;
- управление данными готовых theme-owned Home-узлов: остаток жетонов, подключение и промо;
- загрузчик PCK, fallback-тема и авторитет поддерживаемой версии host-контракта.

Соседний Exchanger требуется только для обновления/проверки host-контракта и финального
интеграционного QA. Обычная визуальная разработка темы автономна.

## Доверенный PCK

В export preset перечислены только ресурсы временной package-копии и их зависимости. Production-
сцены не ограничены пассивными узлами: GDScript, `Timer`, `AudioStreamPlayer*`, `HTTPRequest`,
шейдеры и прочие стандартные возможности Godot разрешены. `source/`, references, docs, preview и
builder tooling не экспортируются. Host продолжает сверять SHA-256 package-копии контракта и при
ошибке структуры экранов или биндингов возвращается к встроенной fallback-теме.
