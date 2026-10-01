# Контекст проекта и handoff

Дата актуализации: 14 сентября 2026 года.

## Текущее состояние

- Builder работает на Godot 4.7.1, главное preview — `tools/preview/preview.tscn`, размер
  `720×1280`.
- Реализован полный формат `ExchangerThemeDlc` v2: 9 production-сцен, 481 обязательный immutable
  element-binding из JSON и 26 обязательных supplemental runtime-binding, проверяемых Builder
  отдельно. Четыре optional ID (тексты баннеров, выбор промо-изображения и переключатель
  питомца) сохраняют обратную совместимость; полностью обновлённая тема содержит 511
  element-binding;
  metadata корней экранов и навигации питомца считаются отдельно.
- `themes/example` — валидная тема-шаблон; `themes/space-pixel` — текущая оформленная тема.
- В SETTINGS `space-pixel` кнопка добавления промо-ролика использует явный кегль `17 px`.
  Благодаря этому её минимальная ширина равна `365 px`, панель списка промо не расширяет общий
  `VBoxContainer`, а все видимые панели раздела «ПРОМО» занимают стандартную ширину `664 px` в
  viewport `720×1280`. Актуальные `build/space-pixel.pck` и `build/active_theme.pck` совпадают:
  `1700400` bytes, SHA-256
  `8082656B3F8DBAA74D6FC55659FDE99D636BF4A626BCECA99F93BA8C9123ECF7`.
- `space-pixel` содержит самостоятельный компонент интерактивного питомца
  `package/components/interactive_pet.tscn`: 22 анимации, 414 кадров, Nearest-фильтрация и публичный
  GDScript-API с прямыми именами анимаций/runtime-профилем. Обычное перемещение исполняет host по
  отдельному theme-owned navigation v1 активного экрана; составной `interact` остаётся в теме и
  управляет экранной anchor-точкой только через scoped runtime host.
- Optional composite contract позволяет теме задавать последовательность клипов, scale и временные
  политики навигации, контактов с опорами, границ и ввода. `space-pixel` выполняет условный поворот,
  `come_closer` ×2, повторы `action`, вычисляемый `falling` через низ/верх экрана, `landing` на самой
  высокой доступной опоре и `idle`. Любая отмена инвалидирует run-scoped bridge; старые темы
  сохраняют одиночный semantic fallback.
- Для автора темы добавлен отдельный дизайнерский гайд `docs/COMPOSITE_PET_ANIMATIONS.md`: от
  подготовки клипов и pivot `VisualRoot` до раскадровки policy, работы с anchor, отмены и QA.
- Non-sitting состояния питомца используют нулевую локальную поправку дочернего
  `AnimatedSprite2D`. Только `sitting` имеет поправку `(0,24)`, которая опускает его на `20,28`
  экранного пикселя при scale `0.845`; root, hit box и `GROUND_OFFSET` не меняются.
- Все восемь non-settings сцен `space-pixel` содержат невидимые metadata-графы питомца: всего 54
  поверхности верхних граней пола/кнопок/окон и 49 climb edges. Settings намеренно остаётся без
  графа. Визуальные `Control` не менялись; координаты являются реальными contact points в
  `720×1280`.
- Exchanger вызывает прямую анимацию `dancing` темы `space-pixel`
  при начале клиентской выдачи и явно проигрывает четыре полных цикла после посадки на Success.
- Обычное падение питомца использует последовательность прямых анимаций
  `falling → landing → idle`: это относится и к отпусканию после drag, и к падению со старой позиции
  при смене экрана. `landing` является необязательным для старых тем: при отсутствии анимации host сразу
  включает `idle`. Запрос `celebrate` во время приземления ждёт завершения `landing`, после чего
  запускаются четыре праздничных цикла.
- 7 сентября обновлённый набор исходников питомца синхронизирован в package: добавлены девять
  состояний (`come_closer`, `idle`, `landing`, `turn_left/right`, `action` и три
  `climbing_action*`),
  обновлён `dancing`, а `home`/`cross` включены как runtime-пиктограммы. Клип
  `walking_finish_right` переименован в `walking_right_stop`, `walking_finish` — в
  `walking_left_stop`, а `walking_start` — в `walking_left_start`; имена файлов синхронизированы в
  архиве, source и package. Актуальные `space-pixel.pck` и Builder `active_theme.pck` совпадают:
  `1658512` bytes, SHA-256
  `76518563591159EC4B8087911D2BB29924BC29C12AAA4FF1544D97ED01648E91`.
- Preview показывает реальные production-сцены, переключает все экраны, отображает binding overlay
  первой кнопкой слева и поддерживает live reload с сохранением текущей вкладки. Он не назначает
  сценам Theme/фон/decoration и не добавляет демонстрационные дочерние узлы.
- Кнопка `PET` основной галереи открывает отдельный `tools/preview/interactive_pet_preview.tscn`:
  viewer динамически загружает `InteractivePetScene` активной темы, строит кнопки из её API и
  автоматически вписывает персонажа в stage с масштабом до `4×`. Отдельная кнопка запускает
  составной `interact` через тестовый runtime с viewport и верхней опорой. Preview tooling не
  входит в PCK.
- Все 18 production-сцен `example` и `space-pixel` самодостаточны: root применяет package Theme,
  содержит `ThemeBackground`/`BackgroundDecoration` и metadata
  `exchanger_self_contained_visuals = true`.
- Home, CardAmount и Settings содержат готовые theme-owned runtime-узлы: 16 кнопок сумм,
  16 строк бонусов, 16 строк готовых сумм и 12 строк промо. Host не должен изменять визуальное
  дерево ThemeView.
- Итоговые панели CashPayment, CardAmount и CardCustomAmount имеют общий заголовок «К ВЫДАЧЕ» и
  раздельные theme-owned Label базовых жетонов слева и бонуса справа. В CardAmount исходный
  immutable-binding `...reward_panel.content.value` сохранён для базы, а отдельный Bonus использует
  supplemental runtime-binding `card_amount.content.reward_panel.content.bonus`; старые темы без
  него поддерживаются host legacy fallback.
- В SETTINGS обеих тем заранее находятся скрытые theme-owned текстовая и цифровая клавиатуры:
  33 буквенных слота, переключатели языка/символов/регистра, действия редактирования и цифры 0–9.
- SETTINGS обеих тем содержит готовый раздел «Сервис» для учёта жетонов и скрытый диалог
  пересчёта/ручного добавления. Их 14 binding-id входят в неизменяемый контракт, включая
  отдельные Label точного остатка hopper 1/2. Три обязательных supplemental binding не входят
  в JSON-каталог 481 элемента: Label `...service_inventory_panel.margin.content.description`
  позволяет host менять описание по режиму учёта, а `CheckButton`
  `...service_inventory_panel.margin.content.inventory_enabled` включает учёт остатка по умолчанию, а
  `CheckButton` `...service_inventory_panel.margin.content.purchase_limit_enabled` по умолчанию запрещает
  продажу сверх учтённого остатка;
  host только обновляет готовые theme-owned узлы и подписывает сигналы.
- Полный supplemental-срез состоит из 26 обязательных ID: 6 Home, 7 кнопок навигации «Главная»,
  1 CardAmount и 12 Settings. Кнопки навигации добавлены на все экраны, кроме Home и Settings:
  на экранах с Back они находятся справа от неё, а на Success/Error/ServiceAccess занимают её
  стандартную позицию. Возврат отменяет незавершённую оплату; на Success кнопка недоступна во
  время выдачи. Основа кнопки — `KeypadButton`: в `space-pixel` это готовый
  `assets/ui/button_square.png` с наложенной `interactive_pet/home.png`, а `example` рисует
  встроенную пиктограмму дома без дополнительного ассета.
  Optional `home.decoration.custom_text_block` объединяет готовые речевую плашку и персонажа
  справа, когда они есть в дизайне; `home.decoration.right_character` сохранён как legacy
  fallback для старых тем. Канонический перечень типов и ID находится в
  `docs/BINDING_CONTRACT.md`.
- Встроенный EditorPlugin `Exchanger Theme Manager` добавляет в меню `Редактор` команды
  `Выбрать тему`, `Создать тему`, `Экспортировать тему` и `Применить тему к Exchanger`.
  Экспорт сначала предлагает любую валидную тему по ID, затем открывает стандартный save-dialog и
  асинхронно собирает её в выбранный PCK без переключения preview и установки. Выбор, создание,
  экспорт и применение показывают этапы и процент в общем окне прогресса; применение устанавливает
  активную тему в стандартный пользовательский каталог. Все каталоги тем постоянно видны в Godot
  FileSystem и не содержат `.gdignore`.
- Сборка создаёт `build/<theme-id>.pck` и `build/active_theme.pck`; установка в Exchanger выполняется
  только явным `-InstallToDefaultUserPath`.
- Постоянного `exchanger_theme_dlc/` в корне больше нет. Preview читает активный package напрямую
  по `build/active-theme.json`; каноническая папка создаётся только во временном изолированном
  workspace на время validator/export и затем удаляется.

## Последняя подтверждённая проверка

Актуальные подтверждённые проверки:

- 11 сентября 2026 года после проверки исправленного PCK в Exchanger только сидящий питомец
  оставался выше нужной позиции. `sitting` получил отдельный visual offset `(0,24)`, который
  опускает его на `20,28` экранного пикселя при scale `0.845`; non-sitting offset остаётся
  нулевым. `GROUND_OFFSET=(64,96)`, `VisualRoot`, навигационные точки, Exchanger host и
  binding-контракт не менялись. Contract check, validator, pet verifier, preview smoke и build
  прошли; живой PET-preview `720×1280` подтвердил current offset `(0,24)` и отсутствие clipping.
  `build/space-pixel.pck` и `build/active_theme.pck` совпадают: `1700352` bytes,
  SHA-256 `931A2EAA118722B95E49EA097C8CE41CE9E655F2CF7248CCA050B28A9AF50357`;
- 11 сентября 2026 года устранено завышенное положение питомца на поверхностях: в
  `interactive_pet.gd` non-sitting visual offset изменён с `(0,-24)` на `(0,0)`. При runtime
  scale `0.845` прежняя поправка поднимала видимый спрайт на `20,28` экранного пикселя, хотя host
  сохранял корректный anchor. `GROUND_OFFSET=(64,96)`, `VisualRoot`, навигационные точки и
  binding-контракт не менялись. Contract check, validator, pet verifier, preview smoke и build
  прошли; `build/space-pixel.pck` и `build/active_theme.pck` совпадают: `1700256` bytes,
  SHA-256 `C1872763DA443190FA3CA2D281E1599B8C4F772CF290A19F3E4E580CAFE2336F`;
- 10 сентября 2026 года composite-действие `interact` в `space-pixel` синхронизировано по
  финальной фазе приближения: `VisualRoot` достигает масштаба ×2 за первые `75%` клипа
  `come_closer`, сохраняет его на заключительной четверти клипа и ещё `0.15` секунды после
  последнего кадра, и только затем запускает `action`. Точечный runtime-тест PET-preview
  зафиксировал scale `2.0` уже на кадре 27, на финальном кадре 35 и в начале `action`;
- 10 сентября 2026 года устранена линейная фильтрация содержимого `space-pixel` в Exchanger при
  физическом разрешении `1080×1920`: корни всех девяти self-contained production-сцен теперь
  явно задают `texture_filter = 1` (`Nearest`). Раньше nearest был задан фону и отдельным
  изображениям, а Builder дополнительно маскировал проблему глобальной настройкой проекта;
  текст и прочие наследующие элементы в host могли получать линейный фильтр. Binding-каталог и
  host-контракт не изменялись. Валидатор теперь требует Nearest на каждом production-root, если
  manifest задаёт `UseNearestTextureFilter: true`. Все девять вкладок с binding overlay проверены
  в живом preview `720×1280`; contract check, validator/preview smoke и build прошли. Итоговые
  `build/space-pixel.pck` и `build/active_theme.pck` после финальной composite-правки имеют размер
  `1698608` bytes и SHA-256
  `4F65DA0758C4234BA752F112C50830010D0914E1EC5FCD76FD70D913614B45A3`;
- 9 сентября 2026 года экранные заголовки `space-pixel` уменьшены: общий `ScreenTitle` использует
  `36 px` вместо `42 px`, а заголовок ServiceAccess — `30 px` вместо `34 px`. Блок техподдержки
  в собственном footer Home и общем `components/footer.tscn` сдвинут на `32 px` влево
  (`x = 341 px`) без изменения размеров, binding-id и runtime-форматирования телефона. Все девять
  вкладок просмотрены в живом preview `720×1280`: заголовки и номер не обрезаются, блок поддержки
  не пересекается с логотипом. Contract check, validator/preview smoke и build прошли;
  `build/space-pixel.pck` и `build/active_theme.pck` совпадают: `1697968` bytes, SHA-256
  `628A7D5BDFFB03DF1DEAF835069C243FCC1FFF8D6AA39850B937A336EB0F6417`;

- 9 сентября 2026 года добавлены четыре compatible optional supplemental binding: `cash_payment.content.banner_text`
  (`Label`) для подписи нижней анимированной плашки CashPayment и
  `settings.scroll.content.animated_banner_texts_panel` (`Control`) для готовой панели настройки
  всех четырёх нижних баннеров. Immutable JSON-каталог сохраняет 481 binding и прежний SHA-256;
  полностью обновлённая тема содержит 509 element-binding, но старый PCK валиден и получает
  отсутствующие optional-узлы из встроенной темы. Добавлены также
  `settings.scroll.content.advertisement_poster_panel.margin.content.select_button` (`Button`) для
  системного выбора изображения промо и
  `settings.scroll.content.menu_visibility_panel.margin.content.show_interactive_pet`
  (`CheckButton`) для отключения theme-owned интерактивного питомца.
  `Sync-HostBindingContract -Check`, packaged contract для example/space-pixel и `test-theme`
  обеих тем прошли.

- 9 сентября 2026 года добавлена supplemental-навигация `home_navigation_button` для
  CashPayment, CardAmount, CardCustomAmount, CardTerminal, Success, Error и ServiceAccess.
  Immutable JSON-каталог не менялся: по-прежнему 481 binding и SHA-256
  `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`; с supplemental-слоем
  на момент этой поставки каждая новая тема содержала 505 обязательных binding. В `space-pixel` расширены верхние
  поверхности Back и добавлены три поверхности/перехода навигации, поэтому граф теперь имеет
  54 поверхности и 49 climb edges. `Sync-HostBindingContract -Check`,
  `Test-PackagedBindingContract.ps1`, `test-theme example`, `test-theme space-pixel` и
  build/install прошли. Установленный PCK Exchanger: `1664336` bytes, SHA-256
  `E2CCD76C0374CE3B6285371DF4113511C39C22BCB131D4D3A10F5B391AFBA0A1`.

- 8 сентября 2026 года настройка Home «ПОКАЗЫВАТЬ ПОЛЬЗОВАТЕЛЬСКИЙ ТЕКСТ» получила optional
  binding `home.decoration.custom_text_block`: в `space-pixel` это готовая группа речевой плашки
  и правого персонажа, поэтому host может скрыть её целиком вместе с обязательным Label текста,
  не перестраивая ThemeView. Старый optional `home.decoration.right_character` сохранён для
  выпущенных тем. Визуальные координаты и ассеты не изменялись; скрипт покачивания использует
  новый вложенный путь персонажа. Contract copies (481 immutable binding) не менялись;
  `Test-PackagedBindingContract.ps1`, `test-theme example`, `test-theme space-pixel`, packaged
  pet verifier (22 анимации, 414 кадров, 51 поверхность, 46 переходов) и build/install прошли.
  Установленный PCK Exchanger: `1658288` bytes, SHA-256
  `4DD492DA3B181B86B291D7930F400B1F8B660658EC1AECBC519266C4EFD6B642`;

- 8 сентября 2026 года документация и валидируемый semantic action list синхронизированы с
  обычным host-flow `drop → landing → idle`. `landing` добавлен в generic Theme Validator и
  PCK/source pet verifier: если тема возвращает для него непустое имя, оно обязано входить в
  `get_pet_animation_names()`, при этом старые темы с пустым mapping остаются допустимыми.
  Документы фиксируют одинаковое поведение после drag и смены экрана, а также очередь
  `celebrate` до завершения landing. `space-pixel` уже содержал корректные ресурсы и mapping:
  `landing` — one-shot на 11 кадров при 24 fps, `idle` — зацикленный на 19 кадров при 24 fps;
  production-сцены, sprite-sheet, биндинги и PCK не изменялись. Contract check, `test-theme`
  для `example` и `space-pixel`, а также verifier существующего PCK прошли; verifier подтвердил
  22 анимации, 414 кадров, неподвижный root, 51 поверхность и 46 climb edges. Builder PCK-копии
  остались байт-в-байт одинаковыми: `1658512` bytes, SHA-256
  `76518563591159EC4B8087911D2BB29924BC29C12AAA4FF1544D97ED01648E91`;

- 7 сентября 2026 года синхронизация с текущим Exchanger исправлена без изменения immutable
  контракта: `Sync-HostBindingContract.ps1` явно исключает все 17 supplemental runtime-binding из
  генерации JSON, даже когда host обращается к их каноническому пути через буквальный `GetNode`.
  `Test-PackagedBindingContract.ps1` защищает от попадания в каталог полный набор 17 ID, а не
  только прежние четыре. `Sync-HostBindingContract -Check` и проверка package-копий проходят:
  9 экранов, 481 binding, SHA-256
  `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`; production-сцены и PCK
  этой правкой не изменялись. Свежий PCK отдельно прошёл в Exchanger полный pet-smoke и
  исправленный payment-format smoke на mock-оборудовании без сохранения пользовательских Settings.

- 7 сентября 2026 года три клипа ходьбы `space-pixel` переименованы сквозным образом:
  `walking_finish_right → walking_right_stop`, `walking_finish → walking_left_stop` и
  `walking_start → walking_left_start`. Обновлены sprite-sheet в `themes_src`, theme source и
  package, `SpriteFrames`, export-поля, списки кадров/FPS/one-shot, facing-наборы, preview enum,
  документация и semantic mapping `walk_start_left`/`walk_finish_left`/`walk_finish_right`.
  `walking_start_right` завершает симметричную пару стартовых клипов. Старые четыре имени и файла
  отсутствуют. Принудительный
  Godot import, contract check, Theme Validator, pet verifier (`22` анимации, `414` кадров,
  `51` поверхность, `46` climb edges), preview smoke, build и PCK smoke (`9` экранов,
  `23` scripted instances) прошли. `build/space-pixel.pck` и `build/active_theme.pck` совпадают:
  `1658512` bytes, SHA-256
  `76518563591159EC4B8087911D2BB29924BC29C12AAA4FF1544D97ED01648E91`. Пользовательская копия
  Exchanger не перезаписывалась;

- 7 сентября 2026 года реализован optional composite contract интерактивного питомца между
  `space-pixel` и Exchanger. Theme-owned `interact` выполняет условный поворот, `come_closer` со
  scale `VisualRoot` до ×2, заданное число `action`, вычисляет полный путь `falling` через нижнюю и
  верхнюю границы, игнорирует опоры до wrap, приземляется на самую высокую доступную поверхность,
  проигрывает `landing` и возвращается в `idle`. Exchanger предоставляет только scoped runtime
  для anchor/viewport/поверхностей и политик, автоматически отзывает его при смене экрана/темы,
  drag и конфликтующих действиях; прежний semantic fallback сохранён. PET-preview получил отдельную
  кнопку и реальный запуск Godot завершил сценарий в `idle` без ошибок. Contract-синхронизация
  подтвердила 2 темы/481 binding и SHA-256 каталога
  `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`; `test-theme`, validator,
  preview smoke, PCK smoke (`9` экранов, `23` scripted instances), Release-сборка без предупреждений,
  NUnit `488/488` (18 аппаратных пропущены) и полный Exchanger `InteractivePetBehaviorSmoke` с
  явным PCK/mock прошли. Итоговые `build/space-pixel.pck` и Builder `build/active_theme.pck`:
  `1658436` bytes, SHA-256
  `37E86765C7F8DE542F799AF8523241A6EDE3F4DC4C481E28CCAC76D52C807AC6`. Пользовательский каталог
  Exchanger не перезаписывался;

- 7 сентября 2026 года верхняя плашка `CardAmount` темы `space-pixel` приведена к точной
  визуальной копии плашки `CashPayment/Summary`: обе используют цельный atlas-region
  `panel_medium.png`, `PanelContainer` размером `649×125` в позиции `(36,148)` и одинаковые
  трансформации заголовка, базовых жетонов и бонуса. Runtime-инспекция Godot 4.7.1 подтвердила
  совпадение global rect всех четырёх видимых элементов; binding-id и канонические пути `Value` и
  `Bonus` сохранены. Contract check, validator, interactive-pet verifier, preview smoke, сборка и
  PCK smoke (`9` экранов, `23` scripted instances) прошли. `build/space-pixel.pck` и
  `build/active_theme.pck` совпадают: `1435772` bytes, SHA-256
  `F505882620719F154319A9CD93208F42ECB59FCC615410827A44DADED8F61404`;

- 7 сентября 2026 года итоговые панели CashPayment, CardAmount и CardCustomAmount обеих тем
  синхронизированы по композиции. Caption CashPayment изменён с «БАЛАНС ЖЕТОНОВ» на «К ВЫДАЧЕ».
  CardAmount сохраняет обязательный `Label` Value с ID
  `card_amount.content.reward_panel.content.value` по пути
  `SafeMargin/Content/RewardPanel/Content/Value` для базовых жетонов слева и содержит отдельный
  theme-owned `Label` Bonus справа с supplemental ID
  `card_amount.content.reward_panel.content.bonus` по пути
  `SafeMargin/Content/RewardPanel/Content/Bonus`; его default — `БЕЗ БОНУСА`, а runtime-формат —
  `+ N ЖЕТОНОВ\nВ ПОДАРОК` или `БЕЗ БОНУСА`. CardCustomAmount сохранил контрактные Label Amount и
  Tokens на прежних путях, но теперь также размещает базу слева и бонус справа; sample бонуса имеет
  явный перенос перед «В ПОДАРОК». Validator проверяет точные типы/пути, порядок, размещение,
  default-тексты и CashPayment caption, а contract-test подтверждает сохранность Value и отсутствие
  нового supplemental ID в JSON. Visual QA всех трёх экранов обеих production-тем в отдельной
  Builder-сессии Godot 4.7.1 при `720×1280` подтвердил полную читаемость, отсутствие визуального
  столкновения, clipping и перекрытия соседних панелей/footer. Contract check, `test-theme`,
  validator/preview smoke, сборка с `-PreserveActiveTheme` и отдельный PCK smoke прошли; PCK содержат
  9 экранов и 9/23 scripted instances. JSON-контракт остался байт-в-байт прежним: 481 binding,
  SHA-256 `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`. Новые PCK:
  `example.pck` — `464876` bytes, SHA-256
  `02B8505FB7F0EF4F4E9C2905D97E8F8751A1DDE86DDF460AFC958CCE6AF51994`;
  `space-pixel.pck` — `1436988` bytes, SHA-256
  `4D9AA00FE2096794331B348916D1766B47A45D9EDFEE60BEAB0E424ED4761A67`.
  `active-theme.json`, Builder `active_theme.pck` и пользовательский `active_theme.pck` не
  изменились; тема не устанавливалась;

- 7 сентября 2026 года в SETTINGS → «Сервис» обеих тем Label `Description`
  получил supplemental binding-id
  `settings.scroll.content.service_inventory_panel.margin.content.description`, чтобы host мог менять
  описание по режиму учёта. Сразу после него добавлен theme-owned `CheckButton`
  «УЧИТЫВАТЬ ОСТАТОК ЖЕТОНОВ» с supplemental binding-id
  `settings.scroll.content.service_inventory_panel.margin.content.inventory_enabled` и
  включённым состоянием по умолчанию. Сразу после него добавлен второй theme-owned
  `CheckButton` «НЕ ПРОДАВАТЬ БОЛЬШЕ ОСТАТКА» с supplemental binding-id
  `settings.scroll.content.service_inventory_panel.margin.content.purchase_limit_enabled`, также
  включённый по умолчанию. Он позволяет host ограничивать продажу доступным учтённым остатком.
  Минимальная высота `ServiceInventoryPanel` увеличена только на высоту новой строки и штатный
  отступ VBox: с `696` до `772` px. Validator проверяет ID, типы, точные пути, порядок обоих
  переключателей, тексты и начальные состояния; contract-test отдельно гарантирует, что все три
  supplemental ID не попали в immutable JSON. Visual QA обеих production-сцен в отдельной
  Builder-сессии Godot 4.7.1 при `720×1280` подтвердил полную видимость обоих переключателей,
  hopper-полей и статуса, отсутствие clipping/перекрытий и корректное отделение footer: у
  `example` панель имеет фактическую высоту `773` px и зазор до footer `20` px, у `space-pixel` —
  `817` px и `47` px соответственно. Contract check, `test-theme`, validator/preview smoke,
  сборка с `-PreserveActiveTheme` и PCK smoke обеих тем прошли; PCK содержат 9
  экранов и 9/23 scripted instances. JSON-контракт остался байт-в-байт прежним:
  481 binding, SHA-256
  `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`. Новые PCK:
  `example.pck` — `464268` bytes, SHA-256
  `AC03334354D285E36A25BFB81D60880F829700F083AF5D728F10AB15C764B63D`;
  `space-pixel.pck` — `1436492` bytes, SHA-256
  `166660916913E4766FC91437155BB8B78A405150B3A599CF401CD78A83DFB727`.
  `active-theme.json`, Builder `active_theme.pck` и пользовательский `active_theme.pck` не
  изменились; тема не устанавливалась;

- 7 сентября 2026 года `Exchanger Theme Manager` обновлён до `1.3.3`: результат
  `JSON.parse_string()` явно объявлен как `Variant`, а результат `Array.pop_back()` приведён к
  `Node`. В `theme_manager_plugin.gd` больше нет небезопасного вывода типа из `Variant`;

- 7 сентября 2026 года в SETTINGS → «Общие» обеих тем визуально удалены строка названия
  приложения и панель предпросмотра, а подпись поля покупательской фразы изменена на
  «СВОЙ ТЕКСТ • ДО 48 ЗНАКОВ». Все существующие `application_name` и
  `branding_preview_panel` binding-узлы сохранены с прежними ID/типами и скрыты; лимит поля
  `short_text` остался равен 48. Пояснение раздела больше не упоминает название или предпросмотр.
  Visual QA обеих production-сцен в отдельной Builder-сессии Godot 4.7.1 при `720×1280`
  подтвердил отсутствие пустых строк, обрезания и перекрытий, а также сохранность фиксированного
  footer. Contract check, validator/preview smoke, `test-theme` и build обеих тем с сохранением
  active state прошли; PCK smoke подтвердил 9 экранов и 9/23 scripted instances. Контракт остался
  байт-в-байт прежним: 481 binding, SHA-256
  `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`, поэтому обязательное
  правило обновления `docs/BINDING_CONTRACT.md` не применяется. Новые PCK:
  `example.pck` — `463324` bytes, SHA-256
  `25E90059652EC26BD1779F7D6761F1CD1248A458F8C93F8E242596D3988FDE9F`;
  `space-pixel.pck` — `1435548` bytes, SHA-256
  `E5941A4E7437BA996945E85551714F8B6E11F77A64808C68B29A8B88F66629AB`.
  `active_theme.pck` в Builder и пользовательском каталоге Exchanger не изменялись и не
  устанавливались;

- 4 сентября 2026 года runtime scale интерактивного питомца `space-pixel` увеличен ровно на 30%
  (`0.65 → 0.845`), а сниженная высота оставлена только для `sitting`: все остальные анимации
  получили локальную поправку `(0,-24)`. Contract check, test/validator с переходом
  `sitting → non-sitting → sitting`, preview smoke, build, PCK verifier и host
  `InteractivePetBehaviorSmoke` с явным PCK прошли. PCK имеет размер
  `1435452` bytes и SHA-256
  `390C9E3F83B026304F0E75E5A6AAD4458684BBCDFC847FFB542B6CFB1AC278E9`. Visual QA preview
  `720×1280` подтвердил crisp Nearest, отсутствие clipping и пересечения с заголовком для обеих
  высот. Пользовательский `active_theme.pck` не устанавливался.
- 3 сентября 2026 года `Exchanger Theme Manager` обновлён до `1.3.1`: JSON-протокол прогресса
  между Windows PowerShell 5.1 и Godot использует только ASCII-сообщения и стабильные stage-id,
  а все видимые русские названия этапов формируются внутри GDScript. Это исключает mojibake вида
  `РџС...` независимо от системной кодовой страницы. Контрольная сборка `example` через
  `powershell.exe` завершилась с `Stage=complete`, `Percent=100`, сохранила активной тему
  `space-pixel`; package binding contract синхронизирован для обеих тем, SHA-256
  `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`. После editor filesystem
  scan Godot 4.7.1 новых parser/runtime errors не зарегистрировал;

- 3 сентября 2026 года `Exchanger Theme Manager` обновлён до `1.3.0`: диалоги выбора, создания,
  экспорта и применения получили сведения о теме и этапах, операции показывают общий progress bar,
  а экспорт позволяет выбрать любой валидный ThemeId независимо от активного preview. Скрипт
  `build-theme.ps1` принимает `-ProgressPath` и публикует JSON-состояние стадий сборки; режим
  `-PreserveActiveTheme` не даёт редакторскому экспорту менять активное состояние и его PCK-копию.
  Контрольный экспорт неактивной `example` завершился `complete/100%` и сохранил хэши active state
  и `active_theme.pck`; PCK smoke подтвердил 9 экранов/9 scripted instances. Повторные contract,
  validator, pet verifier, preview smoke и сборка `space-pixel` прошли; её PCK сохранил размер
  `1431068` bytes и SHA-256
  `5756191317B0318F1833657573B75A5240E96E3B4B063A7E6012C7165B9A2B7D`. Headless Godot 4.7.1
  подтвердил загрузку плагина и регистрацию команд меню без parser/runtime errors;

- 3 сентября 2026 года `Exchanger Theme Manager` обновлён до `1.2.0`: добавлена команда
  `Редактор → Экспортировать тему` со стандартным `FileDialog`, выбором произвольного `.pck` и
  фоновой общей build-задачей. Экспорт не устанавливает тему; команда применения сохранена
  отдельно. Аддон загружен в Godot 4.7.1 без parser/runtime errors. Экспорт `space-pixel` через
  произвольный `-OutputPath`, validator, pet verifier, общий PCK smoke, preview smoke и contract
  check прошли; тестовый PCK содержит 9 экранов/23 scripted instances, имеет размер `1431068`
  bytes и SHA-256 `5756191317B0318F1833657573B75A5240E96E3B4B063A7E6012C7165B9A2B7D`;

- 3 сентября 2026 года `space-pixel` получил theme-owned navigation v1 для интерактивного
  питомца во всех восьми non-settings сценах. Невидимые metadata-графы содержат 51
  горизонтальную contact surface и 46 связанных climb edges; Settings намеренно исключён.
  Визуальные `Control` и 285 кадров не менялись. Component API сопоставляет semantic
  actions с существующими анимациями (`drag = hanging`, `drop = falling`, совместимый
  `climb_finish = sitting`) и сообщает scale `0.65`, walk/climb speeds `88/72 px/s`, hit size
  `128×128`, ground offset `(64,96)`. Generic validator/verifier
  требуют граф у каждой non-settings сцены темы с питомцем и проверяют уникальность IDs,
  конечность/границы координат, sit points, ссылки и стыковку climb edges с поверхностями.
  Contract SHA-256 `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`
  не изменился. `test-theme space-pixel`, validator, preview smoke, export и pet verifier прошли:
  `13` анимаций, `285` кадров, `51` поверхность, `46` climb edges. Текущие
  `build/space-pixel.pck`, `build/active_theme.pck` и установленная Exchanger-копия совпадают:
  `1431068` bytes, SHA-256
  `5756191317B0318F1833657573B75A5240E96E3B4B063A7E6012C7165B9A2B7D`. Расширенный host
  runtime-smoke с mock-оборудованием подтвердил touch/LMB drag, подъём на Home/CashPayment,
  активацию индивидуального графа каждой сцены, сохранение позиции и `falling`-падение при
  переходе, скрытие в Settings и возврат с падением. После добавления `celebrate` smoke также
  подтвердил очередь до посадки, ровно четыре запуска `dancing` и возврат в `Sitting`;
  Exchanger unit-тесты: 419/419;

- 3 сентября 2026 года feature-level контракт интерактивного питомца нейтрализован: optional
  manifest field `InteractivePetScene` указывает на произвольную theme-owned `Node2D`-сцену внутри
  package; canonical space-pixel компонент/скрипт и builder tooling переименованы в
  `interactive_pet.*`. Viewer больше не инстанцирует space-pixel статически: он загружает
  компонент активной темы, строит кнопки из `get_pet_animation_names()` и не обращается к папкам
  текстур. Generic verifier используется в `test-theme.ps1` и `build-theme.ps1`, проверяет API,
  сигналы, анимации и неподвижность root как в package, так и в PCK. Существующие каталоги
  `source/alien_animation` и `package/assets/animations/alien_pet` сохранены без переименования как
  внутренняя структура конкретной темы. Legacy `components/alien_pet.tscn` распознаётся только
  discovery fallback для старых packages. Contract check, `test-theme example` (pet SKIP),
  `test-theme space-pixel`, живой viewer `720×1280`, validator, preview smoke, export и общий PCK
  smoke прошли; viewer показал 13 динамических кнопок и 285 кадров без parser/runtime errors.
  `build/space-pixel.pck` и `build/active_theme.pck` совпадают: `1388444` bytes, SHA-256
  `BECBD72EDA68B67C5744B4BE642756186876A6D9754E6DF3B025FC78FD0D3C16`;

- 2 сентября 2026 года `Exchanger Theme Manager` обновлён до `1.1.0`: команда
  `Редактор → Применить тему к Exchanger` запускает validator/export/install активной темы в
  фоновом `Thread`, показывает компактные состояния выполнения/ошибки и не блокирует UI редактора.
  Аддон успешно загружен Godot 4.7.1 в editor mode. Для `space-pixel` прошли byte-identical
  contract check, validator, preview smoke и PCK smoke (`9` сцен, `23` scripted instances).
  `build/space-pixel.pck`, `build/active_theme.pck` и установленная пользовательская копия имеют
  размер `1388536` bytes и SHA-256
  `D2D4BCF640374B76D8EFF48919EA7CD9A46AC7059DA42A73A630BE73B39C12D4`;

- 2 сентября 2026 года исходные sprite-sheet из `alien_animation` перенесены в theme-specific
  `themes/space-pixel/source/alien_animation` и `package/assets/animations/alien_pet`. Компонент,
  позднее переименованный в `interactive_pet.tscn`, реализует 13 состояний без движения корня.
  Отдельный viewer всех состояний проверен живым запуском при `720×1280`; он использует тот же
  production-компонент и стартует с `sitting`. Contract check, validator, preview smoke, общий
  PCK smoke и отдельный pet-PCK smoke прошли. Viewer также проверен переходами `PET` → viewer и
  `Esc` → галерея; parser-ошибка вывода типа `initial_name` устранена явным `StringName`.
  Package-копия binding-контракта синхронизирована с авторитетным JSON. Собранные
  `space-pixel.pck` и `active_theme.pck` совпадают: `1389432` bytes, SHA-256
  `1392F51A12014EB1653F976B252FA55DCC5EFDE53B18563858DEF878CA2ADF3C`; установка в Exchanger
  не выполнялась.

- 1 сентября 2026 года обе Home-сцены получили theme-owned Label
  `home.scroll.content.stock_status.approximate_count`: состояние расположено слева, полоска
  по центру, приблизительный остаток справа. Builder проверяет этот Label и четыре состояния
  полоски как supplemental runtime bindings, не меняя JSON-контракт 477;
- template/example дополнительно приведён к актуальной двуххопперной сервисной панели контракта;
  contract check, validator и preview smoke прошли для example и space-pixel;

- package-копии `example` и `space-pixel` совпали с авторитетным контрактом SHA-256
  `7ABC98D7770782D0EB658E6EC8CD8FA4F504B0F61862C84FD5E3580341FE73F2`;
- каталог содержит 473 биндинга, включая 57 keyboard bindings, 4 `short_text` bindings, 12
  сервисных bindings и
  отдельное поле введённой суммы CardCustomAmount;
- обе темы прошли Godot import, validator и headless preview smoke после переноса визуального
  chrome внутрь всех production-сцен;
- SETTINGS preview получил диагностическое состояние `KEYBOARD: OFF/TEXT/NUM`, которое меняет
  только `Visible` двух уже существующих панелей и позволяет проверить их binding overlay;
- валидатор подтвердил уникальность всех 473 ID, допустимые типы и наличие всех 57 keyboard
  bindings в `example` и `space-pixel`;
- Godot EditorFileSystem индексирует `themes/example` и `themes/space-pixel` без `.gdignore` и
  без duplicate UID; package-сцены открываются напрямую из `themes/<id>/package/scenes/`;
- `space-pixel` успешно собран в PCK; export включил вложенную
  `components/on_screen_keyboards.tscn` и прошёл предварительный validator;
- validator требует пустой `suffix` у всех 16 полей количества дополнительных жетонов, чтобы
  тема не могла снова отнять у многозначного числа место припиской;
- служебные ряды текстовой клавиатуры `example` и `space-pixel` выровнены по единой высоте
  `76 px` и зазорам `12 px`; в `space-pixel` отдельный стиль обрезает прозрачные края
  `button_long.png`, стрелки имеют touch-target `88×76 px`, а длинные действия не сжимают текст;
- кнопки скрытия обеих экранных клавиатур сохраняют тип `Button`, прежние binding ID и логику,
  но используют крупную центрированную стрелку вниз вместо надписи «СКРЫТЬ»; touch-target каждой
  кнопки равен `64×64 px`. `space-pixel` переиспользует `button_down.png`, а шаблон `example` —
  собственный кодовый SVG `assets/ui/keyboard_hide.svg`;
- описание приложения `subtitle` остаётся удалённым. Отдельная настройка «Короткий текст» использует
  новые ID `home.scroll.content.speech_text` и три `settings...short_text` binding: HOME bubble
  переносит и центрирует до 48 символов, SETTINGS содержит поле, ошибку и предпросмотр;
- живой preview через `godot-ai` загрузил 9 вкладок, переключил каждую из них, включил/выключил
  binding overlay и не записал ошибок в game/editor logs;
- визуально подтверждены прямое открытие `example`/`space-pixel` scene-файлов, все девять
  `space-pixel` вкладок без overlay, портретные `720×1280` и отсутствие внешнего preview chrome;
- через `godot-ai` подтверждены готовые Home stock/promo visuals и восемь видимых CardAmount
  preset-кнопок; скрытые слоты 08–15 не создают пустых ячеек;
- в шаблоне `example` экран ручного ввода сохраняет полноразмерную панель `652×768 px` и клавиши
  `152×152 px`; в `space-pixel` этот экран приведён к отдельному JPG-референсу: панель занимает
  `646×466 px`, цифровые клавиши квадратные `46×46 px`, длинные действия находятся в нижнем ряду;
- на экране сервисного входа обеих тем PIN-клавиатура центрирована, а все двенадцать клавиш
  имеют одинаковый квадратный размер `112×112 px`; действия и footer не перекрываются;
- `space-pixel` использует пользовательские `tumbler_on.png` и `tumbler_off.png` для всех
  `CheckButton`; ON/OFF проверены в живом SETTINGS при исходном размере `128×64 px`, а все
  12 строк имеют одинаковые внутренние отступы слева и справа по `24 px`;
- все 57 `SpinBox` темы `space-pixel` используют пользовательские стрелки вверх/вниз; runtime-копии
  `32×32 px` сохраняют пиксельный вид, отделены от поля промежутком `10 px` и проверены действием
  цены `10 → 11 → 10`; у 16 бонусных полей удалён суффикс «жет.», чтобы многозначное количество
  помещалось в поле целиком;
- все `LineEdit` (normal/focus/read-only), внутренние текстовые поля `SpinBox` и `OptionButton`
  используют растягиваемый фон из видимой области `290×64 px` исходного `summa_bar.png`;
- обе полосы `HSlider` в SETTINGS → «ЗВУК» темы `space-pixel` увеличены по высоте с `14` до
  `36 px`, видимый круглый grabber отключён, а заполнение `100%` доходит до правого края;
  живой Exchanger подтвердил отсутствие обрезания и наложений в обоих блоках громкости;
- установленный `%APPDATA%/Godot/app_userdata/Exchanger/theme_dlc/active_theme.pck` сверён со
  сборкой по SHA-256; после полного перезапуска Exchanger экран «ОПЛАТА» показал новые тумблеры
  ON/OFF и квадратные стрелки SpinBox, а runtime-журнал подтвердил активацию `space-pixel`;
- прямой preview и обе команды test/build подтверждены при физически отсутствующем корневом
  `exchanger_theme_dlc/`; временные workspaces после завершения команд пусты;
- после пересохранения открытых `ui_theme.tres` и `screen_home.tscn` Godot Editor заменил
  переносимые ссылки на builder-only `res://themes/space-pixel/package/...`; относительные пути
  восстановлены, после чего изолированный validator снова загрузил все ресурсы без ошибок;
- `build/example.pck` пересобран из актуального package после обновления Home/Settings и контракта:
  размер `437356` bytes, SHA-256
  `38C23A7593082462E58F7DE2354013A9E548E2C45D58ACEDD8FC09CA82E38E95`; validator, preview smoke
  и PCK smoke прошли, последний инстанцировал 9 экранов и подтвердил 9 scripted node instances;
- `Test-PackagedBindingContract.ps1`, `test-theme example`, `test-theme space-pixel` и
  `build-theme space-pixel` прошли после удаления короткого описания. Импорт, полный validator,
  headless preview smoke и export PCK завершились без ошибок;
- Theme DLC не является самостоятельным приложением и намеренно не содержит main scene, поэтому
  запуск `--main-pack` не применяется для QA. Готовность пакета подтверждают validator/export и
  последующая интеграционная проверка в Exchanger;
- Exchanger переведён на full-trust theme runtime: host больше не отклоняет GDScript, runtime-узлы,
  размер PCK или прежний decoration budget; 263 unit-теста прошли, 17 hardware-тестов пропущены
  из-за отсутствия оборудования.
- Home темы `space-pixel` приведён к референсу
  `themes_src/space_pixel/references/photo_2026-08-20_14-09-56.jpg` в исходном `720×1280`:
  восстановлены белые bubble-плашки, исходный масштаб и позиции НЛО, панели на `y=338/490`,
  билборд, логотип и блок поддержки; обязательные пути и binding-id сохранены.
- Контрольный Godot-render снизил среднюю абсолютную RGB-разницу Home с референсом с `75,81` до
  `6,84`; полученная на том этапе сборка имела размер `684216` bytes и SHA-256
  `CD1AB4B914997A369874F7F1E01FCE44B71EEF0BD2297E544D3C3701D809B13B`.
- CashPayment, CardCustomAmount, CardAmount и CardTerminal темы `space-pixel` приведены к
  `photo_2026-08-20_14-10-27/36/40/43.jpg` прямым редактированием production-сцен. Сохранены все
  обязательные bindings, скрытые CardAmount-слоты 08–15 и исходные bill/coin/card-анимации.
  Повторная строгая сверка CardCustomAmount/CardAmount заменила приблизительный panel chrome на
  трёхчастные исходные текстуры и локальные StyleBox с раздельной геометрией фона и текста.
  Средняя RGB-разница внутри двух основных панелей снизилась с `13,28` до `7,64` и с `15,31`
  до `10,88` соответственно; финальные кадры вручную сверены по геометрии, заголовкам, кнопкам,
  CTA, bubble и footer. CashPayment сохраняет MAD `13,66`, CardTerminal — MAD `11,58`.
- Runtime CashPayment в Exchanger исправлен под уже существующий тройной binding-контракт:
  `balance` получает только рубли, `tokens` — базовое количество жетонов, `bonus` — бонус в
  формате `+ N ЖЕТОНОВ\nВ ПОДАРОК` либо `БЕЗ БОНУСА`. Поэтому host больше не стирает
  pixel-perfect значения production-сцены и не объединяет рубли с жетонами в одной строке.
  Форматирование покрыто отдельными тестами для нулевого баланса и двух бонусных порогов;
  на этом этапе полный набор Exchanger прошёл `272` unit-теста, `17` hardware-тестов штатно пропущены.
  Production Windows export успешно запустился, загрузил установленную `space-pixel` и завершился
  без theme/binding/fallback-ошибок. PCK осталась байт-в-байт прежней: `718536` bytes,
  SHA-256 `AEB8DD1199F71F1114D523CF9928FA6743383746A9DE689755131E8CE9F16BAA`.
- CardCustomAmount получил отдельный обязательный binding
  `card_custom_amount.content.keypad_panel.content.input_value`: введённая сумма обновляется внутри
  `summa_bar`, а верхние два Label показывают только базовые и бонусные жетоны через общий
  `PricingPolicy`. Контракт содержит 461 ID и имеет SHA-256
  `EF5C75B467C87107DF070C3885693D69BF57434259EF3F54DB82E5F074172753`.
  После расширения контракта прошли `276` unit-тестов, `17` hardware-тестов штатно пропущены;
  production export с mock-hardware загрузил внешнюю тему без theme/binding/fallback-ошибок.
  Новая установленная PCK: `721192` bytes, SHA-256
  `30A8806709BCA315E1F455FED1F438C5CD377B9ACEC35A249BABDFF12F1888C4`.
- Отдельная настройка «Короткий текст» добавила обязательный HOME Label
  `home.scroll.content.speech_text` и три SETTINGS binding с сегментом `short_text`; deprecated
  `subtitle` ID не возвращены. Поле ограничено 48 символами, а Label речевой плашки переносит,
  центрирует и обрезает текст в пределах авторской композиции. После включения строгого Nearest
  кегль HOME bubble увеличен с `12` до `16 px`, межстрочный интервал равен `-2 px`, а область
  Label сужена до реальной белой части спрайта (`x=408..590`, `y=62..135`), поэтому короткая
  фраза читается крупно и переносится внутри облака.
- После изменения `Test-PackagedBindingContract.ps1`, `test-theme example`,
  `test-theme space-pixel`, `build-theme space-pixel` и штатный `verify_theme_pck.gd` прошли.
  PCK smoke смонтировал пакет, инстанцировал 9 экранов и нашёл 3 scripted node instances.
- Footer из референса Home с логотипом `Robotic Retailers` и двухстрочным номером техподдержки
  присутствует на восьми production-экранах. Семь экранов используют общий
  `themes/space-pixel/package/components/footer.tscn`, Home сохраняет собственные обязательные
  footer bindings, SETTINGS намеренно остаётся без footer. В `CardCustomAmount` подтверждение
  поднято на `12 px`, поэтому его область не пересекается с footer.
- Актуальные `build/space-pixel.pck`, `build/active_theme.pck` и установленный
  `%APPDATA%/Godot/app_userdata/Exchanger/theme_dlc/active_theme.pck` байт-в-байт совпадают:
  размер `721192` bytes, SHA-256
  `30A8806709BCA315E1F455FED1F438C5CD377B9ACEC35A249BABDFF12F1888C4`.
  27 августа 2026 года после установки выполнен полный перезапуск Exchanger в `720×1280`:
  runtime-журнал подтвердил активацию `space-pixel`, theme/resource/fallback-ошибок не было,
  актуальные контрольные кадр и видео сохранены как
  `build/exchanger-speech-bubble-runtime.png` и `build/exchanger-speech-bubble-runtime.avi`.
  Корни всех девяти сцен наследуют `texture_filter = 1`, а production TTF импортируется без
  antialiasing, hinting и subpixel positioning, с oversampling `1.0`. Contract,
  validator/preview smoke и PCK smoke прошли; последний инстанцировал 9 экранов и нашёл
  10 scripted node instances.

## Зафиксированные решения

- Внешняя тема владеет визуальным деревом экранов; Exchanger владеет логикой и безопасностью.
- Интерактивный питомец является optional theme-owned компонентом из `InteractivePetScene`.
  Публичный контракт использует только нейтральные pet-методы/сигналы; расположение и имена
  текстурных каталогов не входят в контракт и определяются ссылками самой сцены.
- Навигация питомца также theme-owned: обязательные для темы с питомцем v1 `Node2D`-маркеры во
  всех non-settings сценах объявляют bounds, горизонтальные поверхности, точки сидения и
  связанные вертикальные края только через metadata. Settings намеренно исключён.
  Host не вычисляет маршруты из имён/геометрии `Control`; component API сопоставляет semantic
  actions с анимациями и сообщает scale `0.845`, скорости `88/72 px/s`, hit size `128×128` и
  ground offset `(64,96)`. `GROUND_OFFSET=(64,96)` остаётся host-точкой контакта для всех
  состояний; non-sitting анимации используют нулевую поправку дочернего визуала, а `sitting` —
  `(0,24)`. Root, navigation и hit box при переключении состояний не меняются.
- Exchanger не добавляет, не удаляет, не переносит и не стилизует `Control` внутри ThemeView;
  коллекции реализованы заранее созданными theme-owned слотами.
- Экранные клавиатуры являются теми же theme-owned слотами: host меняет только значения,
  `Visible`/`Disabled` и подключает сигналы; создание или перестройка клавиш в runtime запрещены.
- Сервисная панель и её диалог также являются theme-owned слотами. Preview-переключатель
  `INVENTORY: OFF/PANEL/DIALOG` меняет только видимость готовых узлов для диагностики.
- 28 августа 2026 года сервисный интерфейс добавлен в `example` и `space-pixel`: 12 новых
  binding-слотов довели контракт до 473 элементов (373 на экране Settings), SHA-256 контракта
  `7ABC98D7770782D0EB658E6EC8CD8FA4F504B0F61862C84FD5E3580341FE73F2`.
  Contract check, validator и preview smoke прошли для обеих тем. Итоговые
  `build/space-pixel.pck` и `build/active_theme.pck` имеют размер `730888` bytes и одинаковый
  SHA-256 `AD665F4FFC840091E670407D4ADC82463AA269A91D54E181E3639BC8AB8BEF68`.
- 1 сентября 2026 года `space-pixel` использует проектный `button_cancel.png` для всех действий
  «ОТМЕНА»/«УДАЛИТЬ». Пролёты НЛО главного экрана пересобраны по `interface.mp4`: большая
  композиция проходит экран на `0–4` секундах, малая — на `9,75–13` секундах 14-секундного
  цикла; координаты хранятся в системе `1080×1920` и один раз масштабируются production-сценой
  до `720×1280`. Оба набора используют `AnimatedSprite2D` с двумя кадрами: большой — `1 fps`,
  малый — `1,5 fps`. Старые одиночные пролёты и двойное уменьшение масштаба удалены. Godot preview
  визуально проверен на `t=1/2/3/10,5/12/12,5`; contract check, validator и preview smoke прошли.
  `build/space-pixel.pck`, `build/active_theme.pck` и установленная пользовательская копия
  совпадают: `741032` bytes, SHA-256
  `E97F95F544BC257CB309789FD67585F93FFD1569F5662FE78ACCE7E7D0193D8A`.
- 2 сентября 2026 года фиксированный 14-секундный `AnimationPlayer` пролётов заменён на
  `scripts/ufo_flight_controller.gd`. Большой и малый `AnimatedSprite2D` независимо проходят
  экран, после случайной паузы разворачиваются через `flip_h` и летят обратно; высота каждого
  нового прохода случайна в диапазоне `260–1660` координат исходной сцены и привязана к шагу
  `3 px`. Покадровые циклы из двух кадров продолжают работать параллельно с Tween-движением.
  Runtime-проверка подтвердила смену направления/высоты и работающий `flip_h`; contract check,
  validator, preview smoke и PCK smoke прошли. PCK smoke инстанцировал 9 экранов и 18 scripted
  node instances. Собранная, активная и установленная PCK совпадают: `741708` bytes, SHA-256
  `5034C3DB1DA44565ED45F682757C03E44D238ABDB1A0B2947F371A98C80C10BB`. В запущенном Exchanger
  скрипт загружен из `res://exchanger_theme_dlc/` во всех девяти decoration-инстансах; Home
  runtime подтвердил смену направления `-1 → 1`, высоты `1632 → 885` и активную смену кадров.
- Два референсных НЛО вокруг ценового блока Home получили отдельный theme-owned скрипт
  `scripts/home_ufo_bobbing.gd`: левый движется с амплитудой `4 px` и периодом `3,2 с`, правый —
  `5 px` и `3,8 с`, в противофазе. Каждый кадр смещения округлён до целого пикселя; базовые
  позиции `AlienLeft y=130` и `AlienRight y=83` не изменены. Contract check, validator, preview
  smoke и PCK smoke прошли; PCK smoke подтвердил 9 экранов и 19 scripted node instances.
  Exchanger runtime загрузил `res://exchanger_theme_dlc/scripts/home_ufo_bobbing.gd` и подтвердил
  изменение обеих Y-позиций при Nearest-фильтрации. PCK-копии совпадают: `743376` bytes,
  SHA-256 `1646AA10C8DD5EA9AE70FA21040507889FC1719FF26E122464E105E9D2012AFE`.
- Двухкадровый нижний `Banner` экрана Cash больше не меняет видимый размер при переключении.
  Исходные PNG `1024×256` сохранены; `scripts/stable_banner_animation.gd` компенсирует различие
  их цветных bounds (`263×167` против `257×163`) масштабом и смещением второго кадра. В builder
  runtime и в установленной PCK внутри Exchanger оба кадра получили одинаковый экранный Rect2
  `(34.996, 1000.8, 175.421, 111.389)`, autoplay `1 fps` продолжает работать. Contract check,
  validator, preview smoke и PCK smoke прошли; PCK smoke подтвердил 9 экранов и 20 scripted node
  instances. Собранная, активная и установленная PCK совпадают: `744728` bytes, SHA-256
  `FAD047504C95D14CFB8E999B7F5E4EA800BD3EE5AB4E95F3FA7F2836A4E3E8D5`.
- На экране CardAmount отдельные `ReferenceAlien` и `SelectionBubble` заменены тем же цельным
  двухкадровым НЛО-баннером. Обязательный Label
  `card_amount.content.selection_label` сохранён поверх белой части баннера, поэтому Exchanger
  продолжает подставлять runtime-подсказку без изменения host-контракта. Нормализация кадров
  выполняется `scripts/stable_banner_animation.gd`; preview, validator, contract check и PCK smoke
  прошли, PCK smoke подтвердил 9 экранов и 21 scripted node instance. Установленный Exchanger
  загрузил Banner и скрипт из `res://exchanger_theme_dlc/`. Собранная, активная и установленная
  PCK совпадают: `744984` bytes, SHA-256
  `29A3386FB186415A5A2B30F6B9DFFF42BEBC532A8A43FA8809274F3F927B3784`.
- На CardCustomAmount пары `PromoAlien + PromoBubble`, а на CardTerminal
  `ReferenceUfo + StatusBubble` заменены цельными двухкадровыми НЛО-баннерами. Обязательные
  `card_custom_amount.content.hint` и `card_terminal.content.countdown` сохранены поверх белой
  части. Оба экрана визуально проверены отдельно в `720×1280`; contract check, validator, preview
  smoke и PCK smoke прошли, PCK smoke подтвердил 9 экранов и 23 scripted node instances.
  PCK-копии совпадают: `745864` bytes, SHA-256
  `44E36EBBA126BADC34FD65FFEF78F8E4C7A280D4F56704EBBDCC0F2C63C479B1`.
- 2 сентября 2026 года host-контракт синхронизирован до 479 биндингов: добавлены
  `card_terminal.content.top_bar.back_button`, наличный и безналичный таймауты Settings вместо
  прежнего общего поля. `example` и `space-pixel` содержат готовые theme-owned элементы;
  contract check, validator и preview smoke обеих тем прошли. Новый `space-pixel.pck` установлен
  в Exchanger: 747192 bytes, SHA-256
  `9C42625A26B7620662392FD06F681529157EC129E5BB85BF4990254896A877A1`.
  Headless runtime Exchanger с mock-оборудованием загрузил тему без binding-ошибок.
- 2 сентября 2026 года сервисные подписи `Hopper1Label` и `Hopper2Label` получили отдельные
  binding-id точного остатка. Контракт синхронизирован до 481 биндинга, SHA-256 —
  `DDDC89118BEEA78A820561464001656136ED42AC1AD5710FB109D25ADAF44143`. `example` и
  `space-pixel` прошли contract check, validator и preview smoke. Панель `space-pixel` визуально
  проверена в preview при `720×1280`: обе подписи целиком помещаются в существующие theme-owned
  Label и не перекрывают кнопки. Собранные `space-pixel.pck` и `active_theme.pck` совпадают:
  `748120` bytes, SHA-256 `B83FBB273588DA450C5A206BFC69C13517048DFD9D2861A2BEB2190BE4239E32`.
  Host runtime-smoke с явным путём к PCK и mock-оборудованием прошёл без binding-ошибок; пакет в
  пользовательский каталог не устанавливался.
- Preview и Exchanger инстанцируют те же готовые `ScreenScenes`; optional manifest-пути общего
  фона/decoration пусты, чтобы host не дублировал встроенные слои сцены.
- Production-тема является доверенной и может исполнять GDScript и содержать собственные
  runtime-узлы; manifest и 481 app-binding остаются обязательными.
- Host ищет элементы по metadata, а не NodePath, и сверяет SHA-256 каталога контракта.
- Основной фон статический. Покадровые анимации и НЛО — отдельные спрайты, не живой фон.
- Внутренние зависимости package задаются относительными путями, чтобы исходники всех тем
  безопасно индексировались и открывались одновременно.
- Русская терминология интерфейса: «промо» и «промо-ролик».
- Автономная память проекта использует `project: exchanger-theme-dlc-builder`.
- 10 сентября 2026 года причина отсутствия последних визуальных изменений в Exchanger оказалась
  не в новой сборке, а в устаревшей установленной копии PCK от 9 сентября. После повторной сборки
  и установки `build/active_theme.pck` и пользовательский
  `%APPDATA%/Godot/app_userdata/Exchanger/theme_dlc/active_theme.pck` после финальной
  composite-правки совпадают: `1698608` bytes, SHA-256
  `4F65DA0758C4234BA752F112C50830010D0914E1EC5FCD76FD70D913614B45A3`.
  Exchanger монтирует PCK при запуске, поэтому для применения заменённого файла требуется полностью
  закрыть и снова запустить приложение.

## Известные ограничения

- Preview не запускает настоящую оплату, выдачу, COM-контроллер и сохранение настроек. Он показывает
  начальные значения готовых theme-owned узлов; их реакцию на runtime-данные проверяют в Exchanger.
- Обновление binding-контракта требует доступного исходника совместимой версии Exchanger и
  синхронного изменения host hash/tests.
- `themes_src/` и `preview_scenes/` сохранены как архив ранней модели и могут путать поиск; новые
  изменения туда не вносятся.
- Фактический TTF идентифицирует себя как `VCR OSD Mono [RUS by Daymarius]`, версия от
  17 августа 2018 года, designer `MrManet`; поля copyright/license/license URL пусты. Оригинальный
  автор VCR OSD Mono публично разрешил коммерческое использование, но отдельное разрешение автора
  кириллической модификации из первичного источника не найдено. Для внутреннего использования файл
  сохранён ради pixel-perfect метрик; перед публичной поставкой нужно получить письменное
  подтверждение Daymarius либо заменить шрифт.
- Финальное визуальное совпадение всегда требует ручного просмотра всех экранов; headless smoke
  не оценивает композицию.

## Последнее изменение: переключатель интерактивного питомца

17 сентября 2026 года готовый `ShowInteractivePet` в Settings обеих production-тем
(`example`, `space-pixel`) получил краткую подпись «ИНТЕРАКТИВНЫЙ ПИТОМЕЦ». Его supplemental
binding ID и тип не менялись. Exchanger делает переключатель недоступным, если активный manifest
не содержит `InteractivePetScene`; сохранённое предпочтение при этом не стирается и применяется
при следующей теме с питомцем. Контракт `BINDING_CONTRACT.md` уточнён; PCK требуется пересобрать
перед установкой в приложение.

## Ближайшие разумные задачи

1. Перед публичной поставкой получить письменное разрешение на кириллическую модификацию шрифта
   либо заменить её на лицензированную альтернативу; для внутренней установки это не блокирует QA.
2. При изменениях host-контракта выполнить документированную миграцию и повторить runtime QA.
3. Для каждой новой темы начать с `example`, добавить её собственный `source/README.md` и
   документировать отличия/лицензии.
4. После визуальных изменений сравнивать preview и реальный Exchanger на одинаковом `720×1280`.

## Старт для нового ИИ-агента

1. Полностью прочитать корневой `AGENTS.md`.
2. Выполнить agentmemory recall с project id `exchanger-theme-dlc-builder` по текущей задаче.
3. Проверить `git status`, если папка уже подключена к Git; на момент создания handoff локальная
   папка могла ещё не быть инициализирована как отдельный репозиторий.
4. Прочитать профильный документ и `contracts/screen_bindings.v2.json` до изменения сцен.
5. Активировать конкретную тему и работать только в её `source/`/`package/`.
6. Завершить contract check, validator, preview smoke, визуальный QA и сохранение memory.

Ziva-Godot запрещён. Для Editor используется только `godot-ai`.
