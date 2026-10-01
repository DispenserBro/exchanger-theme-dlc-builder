extends Control

const PANEL_TITLE_SIZE := 46.0
const FIELD_HEIGHT := 62.0
const ACTION_HEIGHT := 66.0

@onready var _page: VBoxContainer = $PageScroll/PageMargin/Page
@onready var _buttons: Array[Button] = [
    $SectionTabs/General,
    $SectionTabs/Audio,
    $SectionTabs/Advertisement,
    $SectionTabs/Pricing,
    $SectionTabs/Payment,
]


func _ready() -> void:
    for index in _buttons.size():
        _buttons[index].pressed.connect(_show_section.bind(index))
    _show_section(0)


func _show_section(index: int) -> void:
    for child in _page.get_children():
        child.free()
    for button_index in _buttons.size():
        _buttons[button_index].button_pressed = button_index == index
    match index:
        0: _build_general(_page)
        1: _build_audio(_page)
        2: _build_advertisement(_page)
        3: _build_pricing(_page)
        4: _build_payment(_page)


func _add_panel(page: VBoxContainer, title: String, minimum_height: float = 0.0) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.theme_type_variation = &"WhitePanel"
    panel.custom_minimum_size = Vector2(0, minimum_height)
    page.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 25)
    margin.add_theme_constant_override("margin_top", 23)
    margin.add_theme_constant_override("margin_right", 25)
    margin.add_theme_constant_override("margin_bottom", 23)
    panel.add_child(margin)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 9)
    margin.add_child(content)

    var header := Label.new()
    header.custom_minimum_size = Vector2(0, PANEL_TITLE_SIZE)
    header.theme_type_variation = &"PanelTitle"
    header.add_theme_font_size_override("font_size", 23)
    header.text = title
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    content.add_child(header)

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 9)
    content.add_child(body)
    return body


func _panel_label(text: String, font_size: int = 18, centered: bool = false) -> Label:
    var label := Label.new()
    label.theme_type_variation = &"PanelText"
    label.text = text
    if text.length() > 42 or text.contains("\n"):
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    if centered:
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return label


func _semantic_label(text: String, variation: StringName, centered: bool = false) -> Label:
    var label := Label.new()
    label.theme_type_variation = variation
    label.text = text
    if text.length() > 42 or text.contains("\n"):
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if centered:
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return label


func _line_edit(placeholder: String, value: String = "") -> LineEdit:
    var field := LineEdit.new()
    field.custom_minimum_size = Vector2(0, FIELD_HEIGHT)
    field.placeholder_text = placeholder
    field.text = value
    return field


func _check(text: String, pressed: bool = false, disabled: bool = false) -> CheckButton:
    var field := CheckButton.new()
    field.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
    field.text = text
    field.button_pressed = pressed
    field.disabled = disabled
    return field


func _action(text: String) -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
    button.theme_type_variation = &"CompactButton"
    button.text = text
    return button


func _semantic_action(text: String, variation: StringName) -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
    button.theme_type_variation = variation
    button.text = text
    return button


func _spin(minimum: float, maximum: float, value: float, suffix: String = "") -> SpinBox:
    var field := SpinBox.new()
    field.custom_minimum_size = Vector2(190, FIELD_HEIGHT)
    field.min_value = minimum
    field.max_value = maximum
    field.value = value
    field.suffix = suffix
    return field


func _option(items: PackedStringArray, selected: int = 0) -> OptionButton:
    var field := OptionButton.new()
    field.custom_minimum_size = Vector2(0, FIELD_HEIGHT)
    for item in items:
        field.add_item(item)
    field.select(clampi(selected, 0, maxi(0, field.item_count - 1)))
    return field


func _row() -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    return row


func _expand(control: Control) -> Control:
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return control


func _build_general(page: VBoxContainer) -> void:
    var identity := _add_panel(page, "ТЕКСТ НА ГЛАВНОМ ЭКРАНЕ", 593)
    identity.add_child(_semantic_label("НАЗВАНИЕ • ДО 48 ЗНАКОВ", &"FieldLabel"))
    identity.add_child(_line_edit("РАЗМЕН ЖЕТОНОВ", "РАЗМЕН ЖЕТОНОВ"))
    identity.add_child(_semantic_label("КОРОТКОЕ ОПИСАНИЕ • ДО 80 ЗНАКОВ", &"FieldLabel"))
    identity.add_child(_line_edit("Автомат выдачи жетонов", "Автомат выдачи жетонов"))
    identity.add_child(_semantic_label("ТЕЛЕФОН ПОДДЕРЖКИ • ДО 80 ЗНАКОВ", &"FieldLabel"))
    identity.add_child(_line_edit("Телефон поддержки уточняется", "Телефон поддержки уточняется"))

    var preview := _add_panel(page, "КАК ЭТО УВИДИТ ПОКУПАТЕЛЬ", 273)
    preview.add_child(_panel_label("РАЗМЕН ЖЕТОНОВ", 28, true))
    preview.add_child(_panel_label("Автомат выдачи жетонов", 20, true))
    preview.add_child(_panel_label("ТЕХПОДДЕРЖКА • Телефон поддержки уточняется", 17, true))


func _build_audio(page: VBoxContainer) -> void:
    var master := _add_panel(page, "ОБЩАЯ ГРОМКОСТЬ", 330)
    master.add_child(_panel_label("ВЛИЯЕТ НА ВСЕ ЗВУКИ ПРИЛОЖЕНИЯ"))
    var master_row := _row()
    var master_slider := HSlider.new()
    master_slider.custom_minimum_size = Vector2(0, 60)
    master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    master_slider.max_value = 100
    master_slider.value = 80
    master_row.add_child(master_slider)
    master_row.add_child(_panel_label("80%", 22))
    master.add_child(master_row)
    master.add_child(_check("ОТКЛЮЧИТЬ ВСЕ ЗВУКИ"))

    var advertisement := _add_panel(page, "ГРОМКОСТЬ ПРОМО-РОЛИКА", 250)
    advertisement.add_child(_panel_label("ОТДЕЛЬНАЯ ГРОМКОСТЬ ПРОМО-РОЛИКОВ"))
    var ad_slider := HSlider.new()
    ad_slider.custom_minimum_size = Vector2(0, 60)
    ad_slider.max_value = 100
    ad_slider.value = 45
    advertisement.add_child(ad_slider)

    var test := _add_panel(page, "ПРОВЕРКА", 250)
    test.add_child(_action("ПРОВЕРИТЬ ЗВУК"))
    test.add_child(_semantic_label("ИЗМЕНЕНИЯ СОХРАНЯЮТСЯ АВТОМАТИЧЕСКИ", &"StatusText", true))


func _build_advertisement(page: VBoxContainer) -> void:
    var settings := _add_panel(page, "ПРОМО НА ГЛАВНОМ ЭКРАНЕ", 390)
    settings.add_child(_check("ПОКАЗЫВАТЬ ПРОМО", true))
    settings.add_child(_check("ПРОМО-РОЛИК БЕЗ ЗВУКА", true))
    settings.add_child(_semantic_label("ТЕКСТ ВМЕСТО ПРОМО • ДО 120 СИМВОЛОВ", &"FieldLabel"))
    settings.add_child(_line_edit("ПРОМО-БЛОК", "ПОЛУЧИ СВОИ ЖЕТОНЫ!"))

    var media := _add_panel(page, "ПОСТЕР И ПЛЕЙЛИСТ", 390)
    media.add_child(_semantic_label("ПУТЬ К ПОСТЕРУ PNG / JPG / WEBP", &"FieldLabel"))
    media.add_child(_line_edit("user://promo/poster.png"))
    media.add_child(_semantic_label("ЛОКАЛЬНЫЙ ПРОМО-РОЛИК OGV", &"FieldLabel"))
    var video_row := _row()
    video_row.add_child(_expand(_line_edit("D:/media/promo.ogv")))
    var remove := _action("УДАЛИТЬ")
    remove.custom_minimum_size.x = 150
    remove.theme_type_variation = &"DangerButton"
    video_row.add_child(remove)
    media.add_child(video_row)
    media.add_child(_action("+ ДОБАВИТЬ ПРОМО-РОЛИК"))

    var summary := _add_panel(page, "ПРЕДВАРИТЕЛЬНЫЙ ИТОГ", 190)
    summary.add_child(_panel_label("ПРОМО ВКЛЮЧЕНО • ПОСТЕР ЗАДАН • ПРОМО-РОЛИКОВ: 1", 17, true))


func _build_appearance(page: VBoxContainer) -> void:
    var theme_panel := _add_panel(page, "ВНЕШНЯЯ ТЕМА", 390)
    theme_panel.add_child(_check("ИСПОЛЬЗОВАТЬ ВНЕШНИЙ DLC", true))
    theme_panel.add_child(_semantic_label("ПУТЬ К ПАКЕТУ .PCK", &"FieldLabel"))
    theme_panel.add_child(_line_edit("user://theme_dlc/active_theme.pck", "user://theme_dlc/active_theme.pck"))
    theme_panel.add_child(_semantic_label("ПАКЕТ НАЙДЕН. РЕСУРСЫ ПРОВЕРЯТСЯ ПРИ ЗАПУСКЕ.", &"StatusText"))

    var effects := _add_panel(page, "ЭФФЕКТЫ", 250)
    effects.add_child(_panel_label("ОБЛЕГЧЁННЫЙ РЕЖИМ ОТКЛЮЧАЕТ НЕОБЯЗАТЕЛЬНЫЕ СПРАЙТЫ", 17))
    effects.add_child(_check("ОБЛЕГЧЁННЫЙ РЕЖИМ"))

    var status := _add_panel(page, "ПРИМЕНЕНИЕ ИЗМЕНЕНИЙ", 240)
    status.add_child(_panel_label("ЭФФЕКТЫ ПРИМЕНЯЮТСЯ СРАЗУ.", 17))
    status.add_child(_panel_label("DLC И ПУТЬ — ПОСЛЕ ПЕРЕЗАПУСКА.", 17))
    status.add_child(_panel_label("СЕЙЧАС АКТИВНА: SPACE PIXEL", 18))


func _build_pricing(page: VBoxContainer) -> void:
    var price := _add_panel(page, "СТОИМОСТЬ ОДНОГО ЖЕТОНА", 260)
    price.add_child(_panel_label("ЦЕНА ДОЛЖНА БЫТЬ ПОЛОЖИТЕЛЬНОЙ"))
    price.add_child(_spin(1, 10000, 10, " ₽"))

    var bonus := _add_panel(page, "ДОПОЛНИТЕЛЬНЫЕ ЖЕТОНЫ", 380)
    bonus.add_child(_panel_label("ПОРОГ СУММЫ → БОНУС"))
    var bonus_row := _row()
    bonus_row.add_child(_expand(_spin(10, 100000, 500, " ₽")))
    bonus_row.add_child(_panel_label("→", 24, true))
    bonus_row.add_child(_expand(_spin(0, 10000, 50, " ЖЕТ.")))
    bonus.add_child(bonus_row)
    bonus.add_child(_action("+ ДОБАВИТЬ ПРАВИЛО"))

    var preview := _add_panel(page, "ПРЕДВАРИТЕЛЬНЫЙ РАСЧЁТ", 230)
    preview.add_child(_panel_label("100 ₽ → 10 + 0 = 10 ЖЕТ.\n500 ₽ → 50 + 50 = 100 ЖЕТ.", 19, true))


func _build_payment(page: VBoxContainer) -> void:
    var methods := _add_panel(page, "СПОСОБЫ ОПЛАТЫ", 280)
    methods.add_child(_check("НАЛИЧНАЯ ОПЛАТА", true))
    methods.add_child(_check("ОПЛАТА КАРТОЙ", true))

    var card := _add_panel(page, "КАРТОЧНЫЕ СУММЫ", 400)
    card.add_child(_panel_label("МАКСИМАЛЬНАЯ СУММА"))
    card.add_child(_spin(10, 100000, 5000, " ₽"))
    card.add_child(_panel_label("ШАГ РУЧНОГО ВВОДА"))
    card.add_child(_spin(1, 10000, 10, " ₽"))
    card.add_child(_action("+ ДОБАВИТЬ СУММУ"))

    var timeouts := _add_panel(page, "ТАЙМАУТЫ", 330)
    for item in [["БЕЗДЕЙСТВИЕ", 120], ["ОЖИДАНИЕ ОПЛАТЫ", 90], ["ПОКАЗ РЕЗУЛЬТАТА", 8]]:
        var timeout_row := _row()
        timeout_row.add_child(_expand(_panel_label(item[0], 17)))
        timeout_row.add_child(_spin(3, 600, item[1], " С"))
        timeouts.add_child(timeout_row)


func _build_equipment(page: VBoxContainer) -> void:
    var connection := _add_panel(page, "ПОДКЛЮЧЕНИЕ К КОНТРОЛЛЕРУ", 500)
    connection.add_child(_check("ИСПОЛЬЗОВАТЬ ИМИТАЦИЮ ОБОРУДОВАНИЯ"))
    connection.add_child(_panel_label("COM-ПОРТ"))
    connection.add_child(_option(PackedStringArray(["COM1", "COM3", "COM7"]), 1))
    connection.add_child(_panel_label("СКОРОСТЬ ПОРТА"))
    connection.add_child(_option(PackedStringArray(["9600", "57600", "115200"]), 2))
    connection.add_child(_panel_label("ПОВТОР ПОДКЛЮЧЕНИЯ"))
    connection.add_child(_spin(1, 60, 5, " С"))

    var window := _add_panel(page, "ОКНО И ПРОИЗВОДИТЕЛЬНОСТЬ", 390)
    window.add_child(_check("ПОЛНОЭКРАННЫЙ РЕЖИМ", true))
    window.add_child(_check("ОКНО БЕЗ РАМКИ", true))
    window.add_child(_check("DEBUG-СБОРКА В ОКНЕ • НЕДОСТУПНО", false, true))
    window.add_child(_option(PackedStringArray(["30 FPS", "60 FPS", "120 FPS"]), 1))


func _build_diagnostics(page: VBoxContainer) -> void:
    var status := _add_panel(page, "СОСТОЯНИЕ ПРИЛОЖЕНИЯ", 290)
    status.add_child(_panel_label("ВЕРСИЯ: 0.1.0 • КОНТРОЛЛЕР: ГОТОВ", 18))
    status.add_child(_panel_label("ПОСЛЕДНИЕ БЕЗОПАСНЫЕ ПРЕДУПРЕЖДЕНИЯ"))
    status.add_child(_panel_label("НЕТ ПРЕДУПРЕЖДЕНИЙ.", 17))

    var logging := _add_panel(page, "ЖУРНАЛИРОВАНИЕ", 390)
    logging.add_child(_panel_label("МИНИМАЛЬНЫЙ УРОВЕНЬ"))
    logging.add_child(_option(PackedStringArray(["DEBUG", "INFO", "WARNING", "ERROR"]), 1))
    var limits := _row()
    limits.add_child(_expand(_spin(1, 100, 10, " МБ")))
    limits.add_child(_expand(_spin(1, 365, 30, " ДН.")))
    logging.add_child(limits)

    var test := _add_panel(page, "ТЕСТОВАЯ ВЫДАЧА", 280)
    test.add_child(_panel_label("ВЫДАЁТ ОДИН ЖЕТОН БЕЗ ОПЛАТЫ.", 17))
    test.add_child(_action("ПОДТВЕРДИТЬ ВЫДАЧУ 1 ЖЕТОНА"))
    test.add_child(_semantic_label("НАЖМИТЕ КНОПКУ ЕЩЁ РАЗ ДЛЯ ПОДТВЕРЖДЕНИЯ.", &"WarningText", true))

    var contract := _add_panel(page, "СОСТОЯНИЯ UI-КОНТРАКТА", 420)
    contract.add_child(_semantic_label("ПОЛЕ: ОБЯЗАТЕЛЬНОЕ ЗНАЧЕНИЕ", &"FieldLabel"))
    contract.add_child(_semantic_label("ГОТОВО: ИЗМЕНЕНИЯ СОХРАНЕНЫ.", &"StatusText"))
    contract.add_child(_semantic_label("ПРЕДУПРЕЖДЕНИЕ: НУЖЕН ПЕРЕЗАПУСК.", &"WarningText"))
    contract.add_child(_semantic_label("ОШИБКА: ИСПРАВЬТЕ ЗНАЧЕНИЕ.", &"ErrorText"))
    contract.add_child(_semantic_action("ВТОРИЧНОЕ ДЕЙСТВИЕ", &"SecondaryButton"))
    contract.add_child(_semantic_action("ОПАСНОЕ ДЕЙСТВИЕ", &"DangerButton"))
    contract.add_child(_semantic_action("ВКЛАДКА РАЗДЕЛА", &"SectionTabButton"))
