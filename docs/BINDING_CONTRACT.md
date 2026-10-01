# Manifest v2 и binding-контракт

## Зачем нужны биндинги

Тема управляет внешним видом и может выполнять собственный доверенный GDScript. Exchanger находит
нужную кнопку, Label или поле по `exchanger_binding_id`, проверяет класс узла и подключает
app-owned обработчик. Поэтому автор темы может свободно менять иерархию, имена и внутреннюю логику,
но не ID и требуемый тип обязательных узлов.

## Manifest v2

`themes/<id>/package/manifest.json` содержит `Format: ExchangerThemeDlc`, `FormatVersion: 2` и
ровно девять `ScreenScenes`:

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

Каждый файл находится в `res://exchanger_theme_dlc/scenes/`. Корень — `Control` с metadata
`exchanger_screen_binding_id = screen.<key>`.

Manifest может дополнительно объявить интерактивного питомца:

```json
"InteractivePetScene": "res://exchanger_theme_dlc/components/interactive_pet.tscn"
```

Поле необязательно. Если оно задано, путь обязан находиться внутри
`res://exchanger_theme_dlc/`, указывать на существующую `.tscn`, а корень сцены должен наследовать
`Node2D` и реализовывать нейтральный pet API из [SCRIPTING.md](SCRIPTING.md). Путь к самой сцене
задаётся manifest, а её изображения подключаются обычными resource-ссылками из любого каталога
внутри `package/`: имя папки с текстурами не является частью контракта.

## Навигация питомца

Если manifest объявляет `InteractivePetScene`, текущий Builder требует невидимую навигацию версии
1 во всех восьми production-сценах, кроме `screen.settings`. Host находит её только по metadata и
не анализирует имена узлов или геометрию визуальных `Control`:

- единственный `Node2D`-корень: `exchanger_pet_navigation_root = true`,
  `exchanger_pet_navigation_version = 1`, `exchanger_pet_default_surface_id` и
  `exchanger_pet_roaming_bounds: Rect2`;
- горизонтальная поверхность — любой вложенный `Node2D` с `exchanger_pet_surface = true`,
  уникальным `exchanger_pet_surface_id`, числовыми `exchanger_pet_surface_from_x`,
  `exchanger_pet_surface_to_x`, `exchanger_pet_surface_y` и необязательным
  `exchanger_pet_surface_sit_points: PackedFloat32Array`;
- вертикальный переход — любой вложенный `Node2D` с `exchanger_pet_climb_edge = true`, уникальным
  `exchanger_pet_climb_edge_id`, ссылками `exchanger_pet_climb_from_surface_id` /
  `exchanger_pet_climb_to_surface_id`, координатами `exchanger_pet_climb_x`,
`exchanger_pet_climb_from_y`, `exchanger_pet_climb_to_y` и стороной
  `exchanger_pet_climb_side = left|right`.

Climb edge является двунаправленной связью: `from`/`to` фиксируют две стыкуемые поверхности и
соответствующие им Y, но host может пройти её вверх или вниз и выбрать прямую анимацию по
фактическому направлению движения.

Все координаты задаются в локальной системе соответствующего экрана и обозначают реальные
экранные точки контакта,
а не позицию верхнего левого угла сцены питомца. Host получает смещение лап через optional
`get_pet_ground_offset()` и размещает root по формуле
`contact_point - ground_offset * runtime_scale`. Поверхностями могут быть пол, верхние грани
кнопок и окон; climb edges явно связывают их в граф. Навигационные `Node2D` ничего не рисуют и не
меняют визуальное дерево/геометрию `Control`. Host сохраняет ограниченный fallback для старых тем
без v1-маркеров, но новая тема с питомцем без полного набора восьми графов не проходит Builder
Validator.

Builder дополнительно требует `exchanger_self_contained_visuals = true`: это не binding для
бизнес-логики, а признак того, что root сам применяет package Theme и содержит фон/decoration.
Preview не монтирует оформление и не изменяет дерево production-сцены.

## Каталог 481 элемента

`contracts/screen_bindings.v2.json` — авторитетная копия builder. Для каждого экрана она хранит
ID, допустимый Godot-класс, обязательность и fallback path host. Каждый package содержит точную
байтовую копию в `package/contracts/screen_bindings.v2.json`; host сверяет SHA-256 до загрузки сцен.

Текущий immutable-контракт:

| Экран | Биндингов в JSON |
| --- | ---: |
| `screen.home` | 14 |
| `screen.cash_payment` | 9 |
| `screen.card_amount` | 22 |
| `screen.card_custom_amount` | 18 |
| `screen.card_terminal` | 11 |
| `screen.success` | 4 |
| `screen.error` | 4 |
| `screen.service_access` | 19 |
| `screen.settings` | 380 |
| **Всего** | **481** |

Все 481 записи имеют `Required: true`. SHA-256 канонического файла:
`DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`.

На нужном узле задаётся metadata:

```text
exchanger_binding_id = home.scroll.content.payment_panel.margin.content.buttons.cash_button
```

ID уникален во всём пакете. Допускается наследник указанного класса. Все визуальные узлы принадлежат
теме: Exchanger не добавляет, не удаляет, не переносит и не стилизует `Control` внутри ThemeView.
Host только подключает сигналы и обновляет данные, видимость и доступность существующих узлов.

### Supplemental runtime bindings

После фиксации immutable JSON приложению понадобились дополнительные готовые theme-owned узлы.
Чтобы не менять байтовый контракт выпущенных тем, их ID проверяются Builder Validator отдельно.
Для новой темы обязательны ещё 26 element-binding; два дополнительных compatible binding ниже
могут отсутствовать в уже выпущенной теме:

| Экран | Binding ID | Требуемый тип |
| --- | --- | --- |
| Home | `home.scroll.content.advertisement_panel` | `Control` |
| Home | `home.scroll.content.stock_status.meter.empty` | `Control` |
| Home | `home.scroll.content.stock_status.meter.low` | `Control` |
| Home | `home.scroll.content.stock_status.meter.enough` | `Control` |
| Home | `home.scroll.content.stock_status.meter.much` | `Control` |
| Home | `home.scroll.content.stock_status.approximate_count` | `Label` |
| CardAmount | `card_amount.content.reward_panel.content.bonus` | `Label` |
| CashPayment | `cash_payment.content.top_bar.home_navigation_button` | `Button` (`KeypadButton`; в `space-pixel` — `button_square`) |
| CardAmount | `card_amount.content.top_bar.home_navigation_button` | `Button` (`KeypadButton`; в `space-pixel` — `button_square`) |
| CardCustomAmount | `card_custom_amount.content.top_bar.home_navigation_button` | `Button` (`KeypadButton`; в `space-pixel` — `button_square`) |
| CardTerminal | `card_terminal.content.top_bar.home_navigation_button` | `Button` (`KeypadButton`; в `space-pixel` — `button_square`) |
| Success | `success.content.home_navigation_button` | `Button` (`KeypadButton`; в `space-pixel` — `button_square`) |
| Error | `error.content.home_navigation_button` | `Button` (`KeypadButton`; в `space-pixel` — `button_square`) |
| ServiceAccess | `service_access.content.home_navigation_button` | `Button` (`KeypadButton`; в `space-pixel` — `button_square`) |
| Settings | `settings.scroll.content.music_panel` | `Control` |
| Settings | `settings.scroll.content.sound_effects_panel` | `Control` |
| Settings | `settings.footer` | `PanelContainer` |
| Settings | `settings.footer.save_and_exit_button` | `Button` |
| Settings | `settings.scroll.content.footer_clearance` | `Control` |
| Settings | `settings.scroll.content.service_inventory_panel.margin.content.description` | `Label` |
| Settings | `settings.scroll.content.service_inventory_panel.margin.content.inventory_enabled` | `CheckButton` |
| Settings | `settings.scroll.content.service_inventory_panel.margin.content.purchase_limit_enabled` | `CheckButton` |
| Settings | `settings.scroll.content.menu_visibility_panel` | `PanelContainer` |
| Settings | `settings.scroll.content.menu_visibility_panel.margin.content.show_stock_status` | `CheckButton` |
| Settings | `settings.scroll.content.menu_visibility_panel.margin.content.show_right_character` | `CheckButton` |
| Settings | `settings.scroll.content.menu_visibility_panel.margin.content.show_promotion_block` | `CheckButton` |

Полностью обновлённая тема содержит **511 element-binding**: 481 из JSON, 26 обязательных и четыре
optional supplemental. Metadata девяти корней `exchanger_screen_binding_id` считается отдельно.

`tools/Sync-HostBindingContract.ps1` намеренно исключает эти 30 ID из генерируемого
immutable JSON, даже если host обращается к их каноническому `FallbackPath` через буквальный
`GetNode`. Иначе обычная синхронизация ошибочно превращала бы supplemental-узел в новый элемент
зафиксированного каталога и ломала обратную совместимость выпущенных тем. Полный список выше
одновременно защищён `Test-PackagedBindingContract.ps1`.

Дополнительные compatible binding:

| Экран | Binding ID | Требуемый тип |
| --- | --- | --- |
| CashPayment | `cash_payment.content.banner_text` | `Label` |
| Settings | `settings.scroll.content.animated_banner_texts_panel` | `Control` |
| Settings | `settings.scroll.content.advertisement_poster_panel.margin.content.select_button` | `Button` |
| Settings | `settings.scroll.content.menu_visibility_panel.margin.content.show_interactive_pet` | `CheckButton` |

`cash_payment.content.banner_text` — подпись нижней анимированной плашки с НЛО на экране
наличной оплаты. `settings.scroll.content.animated_banner_texts_panel` — готовая панель четырёх
полей настройки текстов нижних баннеров: наличные, выбор суммы картой, ручной ввод суммы и шаблон
таймера терминала. В последнем поле `{seconds}` заменяется текущим числом секунд.
`select_button` открывает системный выбор файла изображения для промо-блока, а
`show_interactive_pet` — готовый переключатель с подписью «ИНТЕРАКТИВНЫЙ ПИТОМЕЦ»:
он включает или отключает питомца активной темы. Если manifest не объявляет
`InteractivePetScene`, host делает этот переключатель недоступным, не меняя сохранённое
предпочтение владельца. Все четыре ID получают
встроенный fallback в ранее выпущенных PCK.

`home_navigation_button` — готовая компактная theme-owned кнопка с изображением дома. Её основа
— `KeypadButton` (для `space-pixel` — `button_square`). На
CashPayment, CardAmount, CardCustomAmount и CardTerminal она стоит рядом с `BackButton`; на
Success, Error и ServiceAccess, где верхней кнопки «Назад» нет, занимает её обычное левое место.
Host только подключает безопасный возврат на Home. До завершения подтверждённой выдачи на Success
кнопка остаётся видимой, но недоступной. Старый PCK без ID получает встроенный fallback по
каноническому пути.

Один дополнительный биндинг необязателен:

| Экран | Binding ID | Тип для Builder Validator |
| --- | --- | --- |
| Home | `home.decoration.custom_text_block` | `Control` |
| Home | `home.decoration.right_character` | `TextureRect` |

Если Home содержит пользовательскую речевую плашку и персонажа рядом с ней, назначьте
`home.decoration.custom_text_block` готовой группе из фона плашки и персонажа. Host одновременно
переключает эту группу и Label `home.scroll.content.speech_text`; он не создаёт и не перестраивает
визуальные узлы. Для совместимости со старыми темами можно оставить
`home.decoration.right_character` на самом персонаже: тогда host скроет персонажа и текст, но
старая тема не обязана скрывать отдельный фон речевой плашки. Если персонажа или плашки нет, не
создавайте пустые узлы только ради optional ID.

### Что не является element-binding

Не добавляйте вымышленные `exchanger_binding_id` для фоновой графики, частиц, анимационных
контроллеров или питомца. Для них используются другие точки интеграции:

- production-сцена определяется через `ScreenScenes` и `exchanger_screen_binding_id` корня;
- интерактивный питомец подключается полем manifest `InteractivePetScene` и публичным pet API;
- составные действия питомца используют методы и сигналы composite API, а не binding metadata;
- поверхности, sit points и climb edges используют navigation v1 metadata;
- полностью автономные декоративные узлы не требуют связи с host.

Практический процесс создания составного действия описан в
[COMPOSITE_PET_ANIMATIONS.md](COMPOSITE_PET_ANIMATIONS.md).

Устаревшее описание приложения `subtitle` не входит в контракт и не должно создаваться темой.
Вместо него предусмотрена самостоятельная покупательская фраза: Label
`home.scroll.content.speech_text` расположен внутри авторской речевой плашки Home, а SETTINGS
содержит поле `...branding_panel...short_text`, Label ошибки `...short_text_error` и строку
предпросмотра `...branding_preview_panel...short_text`. Поле ограничено 48 символами; ни один из
этих ID не содержит `subtitle`. Переключатель SETTINGS по историческому ID
`...show_right_character` отображается пользователю как «ПОКАЗЫВАТЬ ПОЛЬЗОВАТЕЛЬСКИЙ ТЕКСТ» и
управляет всей optional-группой, а не только персонажем.

Home содержит готовые theme-owned Label состояния жетонов и подключения, а промо-блок —
`TextureRect`, `VideoStreamPlayer` и fallback-`Label`. `VideoStreamPlayer` не содержит
скрипта и управляется C#-логикой Exchanger через биндинг.

Home также использует supplemental runtime bindings, которые валидатор проверяет отдельно от
481 элемента контракта: готовый root промо-панели, четыре визуальных состояния
полоски `home.scroll.content.stock_status.meter.empty/low/enough/much` и Label
`home.scroll.content.stock_status.approximate_count`. Тема заранее располагает состояние слева,
полоску по центру и приблизительный остаток справа; host меняет только текст и видимость. Полный
список supplemental ID приведён выше.

На экране наличной оплаты итог разделён на три независимых обязательных `Label`:

- `cash_payment.content.summary.margin.values.balance` — внесённая сумма в рублях,
  например `1000 РУБЛЕЙ`;
- `cash_payment.content.summary.margin.values.tokens` — базовое количество жетонов без бонуса,
  например `100 ЖЕТОНОВ`;
- `cash_payment.content.summary.margin.values.bonus` — бонус отдельным текстом, например
  `+ 50 ЖЕТОНОВ\nВ ПОДАРОК`; если бонуса нет, host выводит `БЕЗ БОНУСА`.

Не объединяйте рубли и жетоны в одном из этих узлов и не скрывайте `tokens` или `bonus`: Exchanger
заполняет все три значения независимо, а тема полностью определяет их положение и оформление.
Заголовок этой панели — «К ВЫДАЧЕ».

Экран выбора карточной суммы использует ту же композицию базовых и бонусных жетонов:

- `card_amount.content.reward_panel.content.value` — обязательный `Label` immutable-контракта по
  прежнему пути `SafeMargin/Content/RewardPanel/Content/Value`; host выводит в нём только базовое
  количество жетонов;
- `card_amount.content.reward_panel.content.bonus` — supplemental runtime `Label` по пути
  `SafeMargin/Content/RewardPanel/Content/Bonus`; host выводит `+ N ЖЕТОНОВ\nВ ПОДАРОК` или
  `БЕЗ БОНУСА`.

`Value` располагается слева, `Bonus` — справа. Supplemental ID намеренно не входит в immutable
JSON-каталог из 481 элемента. Это сохраняет совместимость старых тем: если отдельного `Bonus` нет,
host использует legacy fallback и выводит совмещённый итог в существующем `Value`. Новые темы,
которые проходят текущий Builder Validator, обязаны содержать оба готовых theme-owned `Label`.

Экран ручного ввода карточной суммы также разделяет платёжные данные:

- `card_custom_amount.content.keypad_panel.content.input_value` — введённая сумма в рублях без
  единиц измерения, например `1000`; это Label внутри поля под заголовком «ВВЕДИТЕ СУММУ»;
- `card_custom_amount.content.amount_panel.margin.values.amount` — базовое количество жетонов;
- `card_custom_amount.content.amount_panel.margin.values.tokens` — бонусные жетоны, например
  `+ 50 ЖЕТОНОВ\nВ ПОДАРОК`; при отсутствии бонуса host выводит `БЕЗ БОНУСА`.

Названия двух последних ID сохранены для совместимости существующих тем. Визуально оба верхних
Label относятся только к жетонам, располагаются слева и справа как на CashPayment; рубли выводятся
исключительно через `input_value`.

Динамические коллекции представлены фиксированными слотами:

- 16 кнопок `card_amount...preset_grid.slot_00..15`;
- 16 строк бонусов `settings...bonus_panel...rows.slot_00..15`;
- 16 строк готовых сумм `settings...preset_rows.slot_00..15`;
- 12 строк промо-роликов `settings...advertisement_playlist...rows.slot_00..11`.

Ещё 57 биндингов относятся к двум theme-owned экранным клавиатурам SETTINGS:

- текстовая панель с 33 фиксированными буквенными слотами в строках `12 + 11 + 10`;
- переключатели языка, регистра и спецсимволов, пробел, очистка, удаление и перемещение каретки;
- цифровая панель с десятью цифрами, очисткой и удалением;
- отдельная кнопка `СКРЫТЬ` в правом верхнем углу каждой панели.

Обе панели существуют в production-сцене заранее и имеют `visible = false`. Exchanger может
показывать одну панель, менять текст/видимость отдельных клавиш и подключать `pressed`, но не
добавляет клавиши и не меняет их расположение. Все кнопки обязаны иметь `focus_mode = None`,
чтобы нажатие экранной клавиши не забирало фокус у редактируемого поля.

Ещё 14 биндингов образуют theme-owned интерфейс учёта жетонов в SETTINGS:

- кнопка вкладки `settings.scroll.content.section_tabs.service_button`;
- скрытая панель `settings.scroll.content.service_inventory_panel` с остатком, статусом и
  действиями автоматического пересчёта/ручного добавления;
- два Label `...hopper1_label` и `...hopper2_label`, в которых host показывает точный остаток
  соответствующего хоппера рядом с его названием;
- скрытый overlay `settings.service_dialog_overlay` с динамическими заголовком и описанием,
  редактируемым `SpinBox amount`, отменой и подтверждением.

Обе темы обязаны заранее содержать эту панель и диалог. Exchanger может менять значения,
`Visible`/`Disabled` и подключать сигналы, но не создаёт диалог, поля или кнопки и не изменяет
их геометрию. Значение `amount` не имеет текстового suffix, чтобы не обрезать многозначные числа.

Помимо этих 14 каталогизированных ID, Builder требует в сервисной панели три
supplemental runtime-binding. `settings.scroll.content.service_inventory_panel.margin.content.description`
— это `Label` по каноническому пути
`SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/Description`; host обновляет
его описание в зависимости от режима учёта.
`settings.scroll.content.service_inventory_panel.margin.content.inventory_enabled` — это
`CheckButton` по каноническому пути
`SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/InventoryAccountingEnabled`,
расположенный сразу после `Description`, с подписью «УЧИТЫВАТЬ ОСТАТОК ЖЕТОНОВ» и включённым
состоянием по умолчанию. Сразу после него расположен включённый по умолчанию `CheckButton`
`settings.scroll.content.service_inventory_panel.margin.content.purchase_limit_enabled` по каноническому
пути `SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/PurchaseLimitEnabled` с
подписью «НЕ ПРОДАВАТЬ БОЛЬШЕ ОСТАТКА». Host подключает к готовым переключателям сохранение
режима учёта и ограничения продаж доступным остатком; создавать эти узлы в runtime нельзя.
Supplemental ID не входят в `contracts/screen_bindings.v2.json`, поэтому
число 481 и байтовый SHA-256 каталога не изменяются.

Каждая строка целиком создана дизайнером и имеет binding root для переключения `Visible`, а её
поля, кнопка удаления и Label ошибки размечены отдельными индексированными ID. Неиспользуемые
слоты скрыты и поэтому не занимают место в Container. Для пустых коллекций предусмотрены
theme-owned `empty_state` Label.

## Как читать overlay

В preview включите `BINDINGS: ON`. Оранжевая рамка показывает геометрию размеченного узла, тёмная
подпись — точный ID, который увидит Exchanger. Подпись корня начинается с `screen.`. Наложение
подписей допустимо на плотных экранах и не влияет на PCK; для оценки композиции выключите overlay.

На вкладке SETTINGS кнопка `KEYBOARD: OFF/TEXT/NUM` последовательно показывает скрытое,
текстовое и цифровое состояния. Это только диагностическое переключение `Visible` уже
существующих theme-owned панелей; preview не добавляет клавиатуру в production-сцену.
Кнопка `INVENTORY: OFF/PANEL/DIALOG` аналогично показывает готовую сервисную панель и диалог,
скрывая на время просмотра прочие секции SETTINGS и не меняя их дерево или геометрию.

Если рамка отсутствует, у узла нет metadata. Если одна рамка неожиданно покрывает большую область,
binding назначен контейнеру, а не ожидаемому дочернему контролу — сверьте `Types` и `FallbackPath`
в JSON.

## Синхронизация без рассинхронизации

Обычная разработка темы не требует соседнего Exchanger:

```powershell
.\tools\Test-PackagedBindingContract.ps1
```

При согласованном изменении C# host используйте точную папку Exchanger:

```powershell
.\tools\Sync-HostBindingContract.ps1 -HostProject ..\exchanger
.\tools\Import-HostSceneTemplates.ps1 -HostProject ..\exchanger -ThemeIds example
.\tools\Sync-HostBindingContract.ps1 -HostProject ..\exchanger -Check
.\tools\Test-PackagedBindingContract.ps1
```

`Sync-HostBindingContract.ps1` генерирует каталог из вызовов `GetNode(SafeMargin/...)` host и
копирует его во все packages. `Import-HostSceneTemplates.ps1` перезаписывает `package/scenes` у
указанных тем: не запускайте его для оформленной темы без резервной копии/осознанного плана
переноса дизайна. После миграции валидируйте `example` и каждую тему, затем обновите закреплённый
SHA-256 и тесты в Exchanger в рамках отдельной host-задачи.

Нельзя вручную менять или переформатировать package-копию JSON: байтовый хеш изменится, даже если
смысл данных сохранится.
