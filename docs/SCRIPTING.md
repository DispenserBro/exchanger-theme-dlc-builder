# Скрипты и runtime-логика темы

Темы Exchanger считаются доверенными. Любая production-сцена или вложенный компонент внутри
`themes/<theme-id>/package/` может содержать GDScript и стандартные runtime-узлы Godot.

## Где хранить скрипты

Рекомендуемая структура:

```text
themes/<theme-id>/package/
├── scripts/                 GDScript темы
├── components/              переиспользуемые сцены со скриптами
├── scenes/                  девять обязательных экранов
└── background_decoration.tscn
```

Прикрепляйте скрипт к узлу обычным действием Godot `Attach Script`. Путь должен находиться внутри
`package/`, например:

```text
res://themes/space-pixel/package/scripts/alien_controller.gd
```

В текстовых `.tscn` зависимости храните относительным путём, например
`../scripts/alien_controller.gd` из `scenes/` или `scripts/alien_controller.gd` из корня package.
Во время сборки package переносится в `res://exchanger_theme_dlc/`, поэтому жёсткая builder-ссылка
`res://themes/<id>/package/...` не является переносимой. Build-workspace автоматически заменяет
известный package-префикс на runtime namespace, если Godot Editor всё же пересохранил такой путь,
но относительные ссылки остаются предпочтительными и понятнее при переносе темы между проектами.

## Что разрешено

- `_ready()`, `_process()` и `_physics_process()`;
- собственные сигналы и подключения сигналов Godot;
- `Tween`, `AnimationPlayer`, `AnimatedSprite2D` и method tracks;
- `Timer`, аудиоплееры, видео, частицы, шейдеры и процедурная графика;
- загрузка ресурсов темы, ввод и остальные API Godot, доступные приложению;
- сетевые и файловые операции стандартными API Godot.

Builder больше не накладывает лимит на количество узлов, кадров, `AnimationPlayer`, FPS или
`speed_scale`. Exchanger также не применяет decoration budget.

## Жизненный цикл

Preview инстанцирует те же production-сцены, которые затем загружает Exchanger. Поэтому скрипт
работает в обоих окружениях без отдельной preview-копии. Изменения `.gd`, `.gdshader`, сцен,
ресурсов, изображений, шрифтов, аудио и OGV отслеживаются live reload preview.

При проверке контракта PackedScene предварительно инстанцируется, чтобы найти binding metadata.
Из-за этого код `_init()` может выполниться ещё до реального показа экрана. Логику, которой нужен
SceneTree, autoload или готовые дочерние узлы, размещайте в `_ready()`. Освобождайте сигналы и
внешние ссылки в `_exit_tree()`, если скрипт подключается к объектам вне своей сцены.

Экран создаётся заново при переходе к нему, если так работает текущий host-flow. Не храните
важное постоянное состояние только в полях узла темы: для него нужен app-owned сервис либо явно
выбранное внешнее хранилище.

## Взаимодействие с Exchanger

Exchanger продолжает подключать оплату, навигацию, настройки и оборудование к 481 обязательному
узлам через `exchanger_binding_id`. Скрипты темы могут параллельно подключаться к сигналам своих
узлов и менять своё дерево.

Прямые пути вроде `/root/ThemeManager` или внутренние пути C#-контроллеров технически доступны,
но не являются стабильным контрактом темы. При такой интеграции фиксируйте требуемую версию
Exchanger в документации темы.

## Пример

В шаблоне находится скрипт:

```text
themes/example/package/scripts/decoration_controller.gd
```

Он прикреплён к `background_decoration.tscn`, экспортирует параметры и показывает простую
анимацию через `_process()`. Свойство `animation_enabled` выключено по умолчанию; добавьте в
decoration дочерний спрайт и включите его, чтобы увидеть движение.

В `space-pixel` скрипт `scripts/ufo_flight_controller.gd` управляет независимыми Tween-пролётами
двух `AnimatedSprite2D`. Он не вмешивается в их покадровое воспроизведение: после каждого прохода
спрайт разворачивается, выбирает новую случайную высоту и возвращается с противоположной стороны.
Отдельный `scripts/home_ufo_bobbing.gd` прикреплён к `visuals/home_top.tscn` и добавляет двум
референсным `TextureRect` лёгкое независимое вертикальное покачивание с округлением позиции до
целого пикселя.
Скрипт `scripts/stable_banner_animation.gd` прикреплён к двухкадровым `Banner` экранов Cash,
CardAmount, CardCustomAmount и CardTerminal и компенсирует различие видимых границ PNG через
frame-dependent scale/position, не заменяя и не отключая исходные кадры.

### Нейтральный контракт интерактивного питомца

Каждая тема может предоставить собственного питомца через необязательное поле manifest
`InteractivePetScene`. Рекомендуемый runtime-путь —
`res://exchanger_theme_dlc/components/interactive_pet.tscn`, однако сам manifest является
источником истины. Корень сцены наследует `Node2D`; анимационный компонент сам не меняет позицию
root, потому что перемещением управляет host. Он предоставляет методы `play_pet_animation()`, `pause_pet_animation()`,
`stop_pet_animation()`, `get_pet_animation_names()`, `get_pet_animation_frame_count()`,
`has_pet_animation()`, `get_current_pet_animation()` и `get_current_pet_frame()`. Сигналы
`pet_animation_started` и `pet_animation_completed` позволяют приложению строить интерактивное
поведение поверх визуального компонента.

Viewer дополнительно использует необязательные методы `is_pet_animation_looping()`,
`get_pet_animation_frames_per_second()` и `get_pet_preview_size()`. Без них базовые ручное
переключение, пауза и повтор работают, но viewer не обязан знать длительность цикла или исходный
размер сцены. Список кнопок всегда строится из `get_pet_animation_names()` и не фиксирует имена
или количество состояний.

Тема также может предоставить пару read-only методов `get_pet_animation_visual_offset(animation_name)`
и `get_pet_visual_offset()`. Если присутствует один из них, verifier требует оба. Первый сообщает
локальную поправку каждой анимации, второй — текущую; viewer использует объединённую область всех
объявленных поправок, чтобы вписать состояния разной высоты в stage без clipping.

Для runtime-поведения компонент может дополнительно предоставить методы:

```gdscript
get_pet_action_animation(action_name: StringName) -> StringName
get_pet_runtime_scale() -> float
get_pet_walk_speed() -> float
get_pet_climb_speed() -> float
get_pet_hit_size() -> Vector2
get_pet_ground_offset() -> Vector2
```

Все они необязательны для обратной совместимости. `get_pet_action_animation()` сопоставляет
нейтральные действия host с фактическими именами клипов конкретной темы. Для полного поведения
используются действия `idle`, `sit`, `interact`, `celebrate`, `walk_left`, `walk_right`,
`walk_start_left`, `walk_start_right`, `walk_finish_left`, `walk_finish_right`, `climb_start`,
`climb_up`, `climb_down`, `climb_finish`, `drag`, `drop` и `landing`.
`hanging` активно только во время удержания питомца. `falling` проигрывается во время падения
после отпускания и при падении со сохранённой позиции после смены экрана. После контакта с
опорой host один раз проигрывает прямую анимацию `landing`, затем переходит в `idle`; старые темы,
у которых `landing` отсутствует в списке анимаций, сохраняют fallback в `idle`. Запрос `dancing`,
поступивший во время `landing`, ставится в очередь до завершения приземления, после чего host явно
перезапускает праздничную анимацию четыре раза. Масштаб и обе скорости задаются положительными конечными числами;
`hit_size` — локальная область захвата пальцем/ЛКМ, а `ground_offset` — локальная точка контакта
лап с поверхностью. Host размещает root в `contact_point - ground_offset * runtime_scale`.

После завершённой ходьбы актуальный Exchanger выбирает состояние простоя вероятностно: с
вероятностью `35%` запускает `idle`, а с вероятностью `65%` — `sitting`. `idle` удобно
использовать для активного ожидания стоя, а `sitting` — для спокойной посадки персонажа.
`sitting` остаётся необязательной: если её нет в списке анимаций, host использует `idle`, поэтому
ранее собранные темы продолжают работать без изменений.

### Составные действия питомца

Если вы собираете последовательность со стороны дизайна, начните с отдельного пошагового гайда
[COMPOSITE_PET_ANIMATIONS.md](COMPOSITE_PET_ANIMATIONS.md). Ниже приведён точный технический
контракт между темой и Exchanger.

Уникальную последовательность конкретного вида питомца можно полностью оставить в теме. Для
этого компонент реализует весь необязательный контракт целиком:

```gdscript
signal pet_composite_action_started(action_name: StringName, run_id: int)
signal pet_composite_action_finished(action_name: StringName, run_id: int, completed: bool)

has_pet_composite_action(action_name: StringName) -> bool
start_pet_composite_action(action_name: StringName, runtime: Object, parameters: Dictionary) -> int
cancel_pet_composite_action(run_id: int, reason: StringName) -> void
```

Частичный набор методов или сигналов является ошибкой валидатора. `start_*` возвращает ровно
`runtime.GetRunId()` при принятии запуска и `0` при отказе. Тема испускает `started` после
принятия, а `finished(..., true)` — только после полного завершения. При отмене она прекращает
корутину, сбрасывает локальные визуальные преобразования и больше не вызывает переданный runtime.
Host также инвалидирует runtime при смене экрана, выгрузке темы, drag или конфликтующем действии,
поэтому после каждого `await` нужно проверять `runtime.IsActive()`.

Переданный scoped runtime предоставляет строго ограниченный интерфейс ко внешнему движению:

```text
GetRunId() -> int
IsActive() -> bool
GetViewportRect() -> Rect2
GetAnchor() -> Vector2
GetHighestSupport() -> Dictionary
SetMotionPolicy(policy: Dictionary) -> bool
SetAnchor(anchor: Vector2) -> Dictionary
MoveAnchor(delta: Vector2) -> Dictionary
LandOnSupport(surface_id: String) -> Dictionary
```

`anchor` — экранная точка контакта питомца, а не позиция его root. `GetHighestSupport()` возвращает
`accepted`, `valid`, `surface_id` и `anchor`; верхней считается доступная поверхность с наименьшим
Y, а при равенстве выбирается ближайшая по X. Результат `MoveAnchor()` содержит `accepted`,
фактический `anchor`, `wrapped`, `landed` и `surface_id`. `LandOnSupport()` выполняет явную
финальную привязку к существующей доступной поверхности.

Поддерживаемые поля `SetMotionPolicy()`:

- `navigation`: `suspended` запрещает обычную app-owned навигацию, `theme_driven` разрешает теме
  перемещать anchor;
- `support_contacts`: `ignore`, `solid` или `after_vertical_wrap`;
- `screen_bounds`: `clamp`, `allow` или `wrap_vertical_once`;
- `input_enabled`: разрешает или запрещает drag/tap во время составного действия;
- `landing_surface_id`: целевая опора для контактов после wrap;
- `wrap_margin`: внешний вертикальный запас в пикселях.

Это политика host-навигации, а не доступ к внутренним узлам приложения. Тема определяет порядок,
число повторов, визуальный scale и момент смены политики; приложение сохраняет экранную позицию,
проверяет границы/опоры и автоматически отзывает полномочия старого запуска. Неизвестные или старые
темы без этого API продолжают использовать одиночную semantic-анимацию `interact`.

Маршрут принадлежит не персонажу, а конкретному экрану темы. Поэтому каждая production-сцена,
кроме Settings, объявляет собственный невидимый граф поверхностей и вертикальных переходов через
v1 metadata, описанные в
[BINDING_CONTRACT.md](BINDING_CONTRACT.md). Горизонтальные отрезки могут совпадать с полом,
верхними гранями кнопок и окон; отдельные sit points разрешают питомцу останавливаться и сидеть.
Climb edges связывают поверхности и задают, у какого левого/правого края разрешён подъём. Host не
вычисляет эти места по NodePath и не меняет визуальные `Control` темы. При смене экрана он
сохраняет текущую экранную позицию, включает граф новой сцены и проигрывает `falling` до её default
surface, затем `landing` и `idle`; Settings скрывает питомца, не сбрасывая сохранённую позицию.

Текстуры, SpriteFrames и внутренняя иерархия не входят в публичный контракт. Сцена может ссылаться
на изображения из любой подпапки собственного `package/`; переименовывать каталог в `alien_pet`
не требуется. Важно лишь, чтобы все зависимости оставались внутри package и использовали
переносимые относительные либо канонические runtime-ссылки.

Реализация `space-pixel` находится в `components/interactive_pet.tscn`; её скрипт
`scripts/interactive_pet.gd` собирает 22 sprite-sheet и предоставляет следующий собственный набор
анимаций:

```text
action, climbing_action, climbing_action_start, climbing_action_stop,
climbing_down, climbing_start, climbing_up, come_closer, dancing, falling, hanging, idle,
landing, sitting, turn_left, turn_right,
walking_left, walking_left_start, walking_left_stop, walking_right,
walking_start_right, walking_right_stop
```

Через `get_pet_action_animation()` тема сопоставляет эти клипы нейтральным действиям host: `idle`
и `sitting` для ожидания, `action` для обычного действия, `dancing` для выдачи, парные
walking-анимации для ходьбы,
`climbing_start/up/down` для подъёма, `hanging` при удержании/перетаскивании, `falling` при
падении и `landing` для одноразового перехода к `idle` после обычной посадки. Актуальный host
после подъёма или спуска
сразу продолжает маршрут и не запрашивает `climb_finish`. Runtime-профиль рассчитан на сцены
`720×1280`: scale `0.845`, walk speed `88 px/s`, climb speed `72 px/s`, hit size `128×128`,
ground offset `(64,96)`. Для `sitting` визуальная поправка равна `(0,24)`, для каждой другой
анимации — `(0,0)`; root и `GROUND_OFFSET` при переключении не меняются. Поправка `sitting`
опускает только это состояние на `20,28` экранного пикселя при scale `0.845`. Прежняя поправка
`(0,-24)` у non-sitting состояний остаётся удалённой.

`come_closer`, `landing`, `turn_left`, `turn_right`, `climbing_action_start` и
`climbing_action_stop` являются one-shot-переходами. `idle`, `action` и `climbing_action`
зациклены. `space-pixel` предоставляет составной `interact`: учитывает последнее направление,
проигрывает `turn_left`/`turn_right`, при `come_closer` увеличивает `VisualRoot` до ×2, повторяет
`action`, вычисляет число циклов `falling` по полной длине пути, проходит через нижнюю и верхнюю
границы без контакта с промежуточными опорами, садится на самую высокую доступную поверхность,
проигрывает `landing` и возвращается в `idle`. При `reduced_effects=true` приближение и проход
через границу пропускаются, но действие, посадка и возврат в idle сохраняются.

Стартовые и завершающие состояния проигрываются один раз; остальные состояния зациклены. Экспорт
`return_to_sitting_after_one_shot` при необходимости автоматически возвращает питомца к `sitting`.
Все состояния можно проверить в отдельной сцене `tools/preview/interactive_pet_preview.tscn` или открыть
кнопкой `PET` в верхней панели основной галереи. Просмотрщик вписывает объединённую область всех
объявленных per-animation visual offsets в Stage; это только tooling и не меняет production-компонент.
Кнопка «СОСТАВНОЕ ДЕЙСТВИЕ: INTERACT» передаёт компоненту тестовый runtime с viewport и верхней
опорой, поэтому полный theme-owned сценарий можно проверить без запуска Exchanger.

## Проверка и сборка

```powershell
.\tools\Test-PackagedBindingContract.ps1
.\test-theme.ps1 -ThemeId <theme-id>
.\build-theme.ps1 -ThemeId <theme-id>
```

`test-theme.ps1` импортирует скрипты в изолированном Godot-проекте и обнаруживает parser/resource
errors. Для проверки `_ready()`, сигналов и runtime-поведения дополнительно запустите preview, а
после сборки — Exchanger с установленным PCK.

Готовый PCK можно отдельно смонтировать, инстанцировать все девять экранов и проверить наличие
прикреплённых скриптов:

```powershell
godot --headless --path . --script res://tools/verify_theme_pck.gd -- `
  --pack (Resolve-Path .\build\example.pck) --require-scripts
```
