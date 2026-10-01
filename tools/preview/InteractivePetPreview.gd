extends Control

const ACTIVE_STATE_PATH := "res://build/active-theme.json"
const CANONICAL_PACKAGE_ROOT := "res://exchanger_theme_dlc"
const PET_MANIFEST_FIELD := "InteractivePetScene"
const PET_COMPONENT_RELATIVE_PATH := "components/interactive_pet.tscn"
const LEGACY_PET_COMPONENT_RELATIVE_PATH := "components/alien_pet.tscn"
const GALLERY_SCENE_PATH := "res://tools/preview/preview.tscn"
const REQUIRED_PET_METHODS := [
    &"get_pet_animation_names",
    &"get_pet_animation_frame_count",
    &"has_pet_animation",
    &"play_pet_animation",
    &"pause_pet_animation",
    &"stop_pet_animation",
    &"get_current_pet_animation",
    &"get_current_pet_frame",
]
const COMPOSITE_METHODS := [
    &"has_pet_composite_action",
    &"start_pet_composite_action",
    &"cancel_pet_composite_action",
]
const COMPOSITE_SIGNALS := [
    &"pet_composite_action_started",
    &"pet_composite_action_finished",
]
const COMPOSITE_PREVIEW_ACTION := &"interact"
const COMPOSITE_PREVIEW_VIEWPORT := Rect2(0.0, 0.0, 720.0, 720.0)
const COMPOSITE_PREVIEW_SUPPORT_ID := "preview_highest_support"
const COMPOSITE_PREVIEW_SUPPORT := Vector2(360.0, 128.0)
const COMPOSITE_PREVIEW_START := Vector2(360.0, 620.0)

@onready var stage: Control = %Stage
@onready var animation_name_label: Label = %AnimationName
@onready var frame_label: Label = %FrameCounter
@onready var pause_button: Button = %PauseButton
@onready var auto_button: Button = %AutoButton
@onready var composite_button: Button = %CompositeButton
@onready var animation_buttons: GridContainer = %AnimationButtons
@onready var animation_button_template: Button = %AnimationButtonTemplate
@onready var auto_timer: Timer = %AutoTimer

var pet: Node2D
var _animation_names: Array[StringName] = []
var _current_index := 0
var _paused := false
var _composite_runtime: PetCompositePreviewRuntime
var _composite_run_id := 0
var _composite_display_scale := 1.0
var _composite_display_origin := Vector2.ZERO


func _ready() -> void:
    _connect_controls()
    if not _instantiate_active_pet():
        return
    _animation_names = _read_animation_names()
    if _animation_names.is_empty():
        _show_error("Компонент питомца не содержит доступных анимаций.")
        return
    _build_animation_buttons()
    _center_pet()
    _configure_composite_preview()
    var initial_name := StringName(str(pet.call(&"get_current_pet_animation")))
    _current_index = maxi(0, _animation_names.find(initial_name))
    _play_current_animation()


func _process(_delta: float) -> void:
    if not is_instance_valid(pet):
        set_process(false)
        return
    if _animation_names.is_empty():
        frame_label.text = "КАДР: —"
        return
    var animation_name := StringName(str(pet.call(&"get_current_pet_animation")))
    var frame_count := int(pet.call(&"get_pet_animation_frame_count", animation_name))
    var current_frame := int(pet.call(&"get_current_pet_frame"))
    frame_label.text = "КАДР: %d / %d" % [current_frame + 1, frame_count]


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_LEFT:
            _select_relative(-1)
        KEY_RIGHT:
            _select_relative(1)
        KEY_SPACE:
            _toggle_pause()
        KEY_R:
            _play_current_animation()
        KEY_ESCAPE:
            _return_to_gallery()
            return
        _:
            return
    var viewport := get_viewport()
    if viewport != null:
        viewport.set_input_as_handled()


func _connect_controls() -> void:
    stage.resized.connect(_center_pet)
    animation_buttons.resized.connect(_resize_animation_buttons)
    %GalleryButton.pressed.connect(_return_to_gallery)
    %PreviousButton.pressed.connect(_select_relative.bind(-1))
    %NextButton.pressed.connect(_select_relative.bind(1))
    pause_button.pressed.connect(_toggle_pause)
    %ReplayButton.pressed.connect(_play_current_animation)
    auto_button.toggled.connect(_on_auto_toggled)
    composite_button.pressed.connect(_start_composite_preview)
    auto_timer.timeout.connect(_select_relative.bind(1))


func _instantiate_active_pet() -> bool:
    var source_package := _active_package_path()
    var component_path := _resolve_pet_component_path(source_package)
    if component_path.is_empty():
        _show_error("В активной теме не задан компонент интерактивного питомца.")
        return false
    var packed_scene := load(component_path) as PackedScene
    if packed_scene == null:
        _show_error("Не удалось загрузить компонент питомца: %s" % component_path)
        return false
    var instance := packed_scene.instantiate()
    if not instance is Node2D:
        instance.queue_free()
        _show_error("Корень компонента питомца должен наследовать Node2D.")
        return false
    pet = instance as Node2D
    for method_name in REQUIRED_PET_METHODS:
        if not pet.has_method(method_name):
            pet.queue_free()
            pet = null
            _show_error("У компонента питомца отсутствует метод %s()." % method_name)
            return false
    if not pet.has_signal(&"pet_animation_completed"):
        pet.queue_free()
        pet = null
        _show_error("У компонента питомца отсутствует сигнал pet_animation_completed.")
        return false
    stage.add_child(pet)
    pet.connect(&"pet_animation_completed", _on_pet_animation_completed)
    if pet.has_signal(&"pet_composite_action_finished"):
        pet.connect(&"pet_composite_action_finished", _on_composite_action_finished)
    return true


func _read_animation_names() -> Array[StringName]:
    var result: Array[StringName] = []
    var raw_names = pet.call(&"get_pet_animation_names")
    if not raw_names is Array:
        return result
    for raw_name in raw_names:
        var animation_name := StringName(str(raw_name))
        if not animation_name.is_empty() and not result.has(animation_name):
            result.append(animation_name)
    return result


func _build_animation_buttons() -> void:
    var group := ButtonGroup.new()
    for animation_name in _animation_names:
        var button := animation_button_template.duplicate() as Button
        button.name = "Animation_%s" % _safe_node_name(animation_name)
        button.visible = true
        button.text = str(animation_name)
        button.button_group = group
        button.set_meta(&"animation_name", animation_name)
        button.pressed.connect(_select_animation.bind(animation_name))
        animation_buttons.add_child(button)
    animation_button_template.visible = false
    _resize_animation_buttons()


func _resize_animation_buttons() -> void:
    var separation := float(animation_buttons.get_theme_constant("h_separation"))
    var column_width := floorf((animation_buttons.size.x - separation) * 0.5)
    if column_width <= 0.0:
        return
    for child in animation_buttons.get_children():
        if child is Button:
            child.custom_minimum_size.x = column_width


func _center_pet() -> void:
    if not is_instance_valid(pet):
        return
    if _is_composite_preview_active():
        _layout_composite_preview()
        return
    var frame_size := Vector2(128.0, 128.0)
    if pet.has_method(&"get_pet_preview_size"):
        var reported_size = pet.call(&"get_pet_preview_size")
        if reported_size is Vector2 and reported_size.x > 0.0 and reported_size.y > 0.0:
            frame_size = reported_size
    var min_visual_offset := Vector2.ZERO
    var max_visual_offset := Vector2.ZERO
    if pet.has_method(&"get_pet_animation_visual_offset"):
        for animation_name in _animation_names:
            var raw_offset = pet.call(&"get_pet_animation_visual_offset", animation_name)
            if raw_offset is Vector2:
                min_visual_offset.x = minf(min_visual_offset.x, raw_offset.x)
                min_visual_offset.y = minf(min_visual_offset.y, raw_offset.y)
                max_visual_offset.x = maxf(max_visual_offset.x, raw_offset.x)
                max_visual_offset.y = maxf(max_visual_offset.y, raw_offset.y)
    var preview_envelope_size := frame_size + max_visual_offset - min_visual_offset
    var available_size := stage.size
    if available_size.x <= 0.0 or available_size.y <= 0.0:
        return
    var preview_scale := minf(4.0, minf(
        available_size.x / preview_envelope_size.x,
        available_size.y / preview_envelope_size.y
    ))
    preview_scale = maxf(preview_scale, 0.01)
    pet.scale = Vector2.ONE * preview_scale
    pet.position = (
        (available_size - preview_envelope_size * preview_scale) * 0.5
        - min_visual_offset * preview_scale
    )


func _select_relative(offset: int) -> void:
    if _animation_names.is_empty():
        return
    _current_index = wrapi(_current_index + offset, 0, _animation_names.size())
    _play_current_animation()


func _select_animation(animation_name: StringName) -> void:
    var index := _animation_names.find(animation_name)
    if index < 0:
        return
    _current_index = index
    _play_current_animation()


func _play_current_animation() -> void:
    if _animation_names.is_empty() or not is_instance_valid(pet):
        return
    _cancel_composite_preview(&"manual_animation")
    var animation_name := _animation_names[_current_index]
    if not bool(pet.call(&"play_pet_animation", animation_name)):
        _show_error("Компонент отклонил анимацию %s." % animation_name)
        return
    _paused = false
    pause_button.text = "ПАУЗА"
    _update_animation_info(animation_name)
    _update_animation_buttons(animation_name)
    _schedule_auto_advance(animation_name)


func _toggle_pause() -> void:
    if _animation_names.is_empty() or not is_instance_valid(pet):
        return
    _paused = not _paused
    if _paused:
        pet.call(&"pause_pet_animation")
        auto_timer.paused = true
        pause_button.text = "ПРОДОЛЖИТЬ"
    else:
        pet.call(&"play_pet_animation", _animation_names[_current_index], false)
        auto_timer.paused = false
        pause_button.text = "ПАУЗА"


func _on_auto_toggled(enabled: bool) -> void:
    auto_button.text = "АВТОПОКАЗ: ВКЛ" if enabled else "АВТОПОКАЗ: ВЫКЛ"
    if enabled:
        _play_current_animation()
    else:
        auto_timer.stop()


func _configure_composite_preview() -> void:
    var supported := true
    for method_name in COMPOSITE_METHODS:
        supported = supported and pet.has_method(method_name)
    for signal_name in COMPOSITE_SIGNALS:
        supported = supported and pet.has_signal(signal_name)
    supported = supported and bool(
        pet.call(&"has_pet_composite_action", COMPOSITE_PREVIEW_ACTION)
    ) if supported else false
    composite_button.disabled = not supported
    composite_button.tooltip_text = (
        "Запустить составное действие interact через тестовый runtime host."
        if supported
        else "Активная тема не предоставляет составное действие interact."
    )


func _start_composite_preview() -> void:
    if composite_button.disabled or not is_instance_valid(pet):
        return
    _cancel_composite_preview(&"restarted")
    auto_button.set_pressed_no_signal(false)
    _on_auto_toggled(false)
    _composite_run_id += 1
    _composite_runtime = PetCompositePreviewRuntime.new(
        _composite_run_id,
        COMPOSITE_PREVIEW_VIEWPORT,
        COMPOSITE_PREVIEW_START,
        COMPOSITE_PREVIEW_SUPPORT_ID,
        COMPOSITE_PREVIEW_SUPPORT
    )
    _composite_runtime.anchor_changed.connect(_apply_composite_anchor)
    _layout_composite_preview()
    _apply_composite_anchor(COMPOSITE_PREVIEW_START)
    var returned_run_id := int(pet.call(
        &"start_pet_composite_action",
        COMPOSITE_PREVIEW_ACTION,
        _composite_runtime,
        {"action_repetitions": 3, "reduced_effects": false}
    ))
    if returned_run_id != _composite_run_id:
        _cancel_composite_preview(&"start_rejected")
        _show_error("Тема отклонила запуск составного действия interact.")
        return
    composite_button.disabled = true
    animation_name_label.text = "СОСТАВНОЕ ДЕЙСТВИЕ: interact"


func _layout_composite_preview() -> void:
    var available_size := stage.size
    if available_size.x <= 0.0 or available_size.y <= 0.0:
        return
    _composite_display_scale = minf(
        available_size.x / COMPOSITE_PREVIEW_VIEWPORT.size.x,
        available_size.y / COMPOSITE_PREVIEW_VIEWPORT.size.y
    )
    _composite_display_origin = (
        available_size - COMPOSITE_PREVIEW_VIEWPORT.size * _composite_display_scale
    ) * 0.5
    if _composite_runtime != null:
        _apply_composite_anchor(_composite_runtime.GetAnchor())


func _apply_composite_anchor(anchor: Vector2) -> void:
    if not is_instance_valid(pet):
        return
    var runtime_scale := 1.0
    var ground_offset := Vector2.ZERO
    if pet.has_method(&"get_pet_runtime_scale"):
        runtime_scale = float(pet.call(&"get_pet_runtime_scale"))
    if pet.has_method(&"get_pet_ground_offset"):
        var reported_offset: Variant = pet.call(&"get_pet_ground_offset")
        if reported_offset is Vector2:
            ground_offset = reported_offset
    pet.scale = Vector2.ONE * runtime_scale * _composite_display_scale
    pet.position = _composite_display_origin + (
        anchor - ground_offset * runtime_scale
    ) * _composite_display_scale


func _on_composite_action_finished(
    action_name: StringName,
    run_id: int,
    completed: bool
) -> void:
    if run_id != _composite_run_id or action_name != COMPOSITE_PREVIEW_ACTION:
        return
    if _composite_runtime != null:
        _composite_runtime.invalidate()
    _composite_runtime = null
    composite_button.disabled = false
    animation_name_label.text = (
        "СОСТАВНОЕ ДЕЙСТВИЕ ЗАВЕРШЕНО"
        if completed
        else "СОСТАВНОЕ ДЕЙСТВИЕ ОТМЕНЕНО"
    )


func _cancel_composite_preview(reason: StringName) -> void:
    if not _is_composite_preview_active():
        return
    pet.call(&"cancel_pet_composite_action", _composite_run_id, reason)
    _composite_runtime.invalidate()
    _composite_runtime = null
    composite_button.disabled = false


func _is_composite_preview_active() -> bool:
    return _composite_runtime != null and _composite_runtime.IsActive()


func _on_pet_animation_completed(animation_name: StringName) -> void:
    if (
        auto_button.button_pressed
        and not _animation_names.is_empty()
        and animation_name == _animation_names[_current_index]
    ):
        _select_relative(1)


func _schedule_auto_advance(animation_name: StringName) -> void:
    auto_timer.stop()
    if not auto_button.button_pressed or not is_instance_valid(pet):
        return
    var is_looping := false
    if pet.has_method(&"is_pet_animation_looping"):
        is_looping = bool(pet.call(&"is_pet_animation_looping", animation_name))
    if not is_looping:
        return
    var frames_per_second := 0.0
    if pet.has_method(&"get_pet_animation_frames_per_second"):
        frames_per_second = float(
            pet.call(&"get_pet_animation_frames_per_second", animation_name)
        )
    var frame_count := int(pet.call(&"get_pet_animation_frame_count", animation_name))
    var duration := float(frame_count) / maxf(frames_per_second, 0.01)
    auto_timer.start(maxf(duration, 1.0))


func _update_animation_info(animation_name: StringName) -> void:
    var frame_count := int(pet.call(&"get_pet_animation_frame_count", animation_name))
    var mode := "РЕЖИМ НЕ УКАЗАН"
    if pet.has_method(&"is_pet_animation_looping"):
        mode = "ЦИКЛ" if bool(
            pet.call(&"is_pet_animation_looping", animation_name)
        ) else "ОДИН РАЗ"
    animation_name_label.text = "АНИМАЦИЯ: %s  •  %d КАДРОВ  •  %s" % [
        animation_name,
        frame_count,
        mode,
    ]


func _update_animation_buttons(animation_name: StringName) -> void:
    for child in animation_buttons.get_children():
        if child is Button and child.has_meta(&"animation_name"):
            (child as Button).set_pressed_no_signal(
                StringName(child.get_meta(&"animation_name")) == animation_name
            )


func _active_package_path() -> String:
    var state := _load_json(ACTIVE_STATE_PATH)
    return str(state.get("Package", "")).replace("\\", "/")


func _resolve_pet_component_path(package_path: String) -> String:
    if package_path.is_empty():
        return ""
    var package_res_root := ProjectSettings.localize_path(package_path).replace("\\", "/")
    if not package_res_root.begins_with("res://"):
        return ""
    var manifest := _load_json(package_path.path_join("manifest.json"))
    var declared_path := str(manifest.get(PET_MANIFEST_FIELD, ""))
    var candidates := PackedStringArray()
    if not declared_path.is_empty():
        var declared_relative := _package_relative_path(declared_path)
        if not declared_relative.is_empty():
            candidates.append(declared_relative)
    candidates.append(PET_COMPONENT_RELATIVE_PATH)
    candidates.append(LEGACY_PET_COMPONENT_RELATIVE_PATH)
    for relative_path in candidates:
        var candidate := package_res_root.path_join(relative_path)
        if ResourceLoader.exists(candidate):
            return candidate
    return ""


func _package_relative_path(resource_path: String) -> String:
    var normalized := resource_path.replace("\\", "/")
    if normalized.contains(".."):
        return ""
    if normalized.begins_with(CANONICAL_PACKAGE_ROOT + "/"):
        return normalized.trim_prefix(CANONICAL_PACKAGE_ROOT + "/")
    if normalized.begins_with("res://"):
        return ""
    return normalized.trim_prefix("/")


func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var value = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}


func _safe_node_name(animation_name: StringName) -> String:
    var result := str(animation_name)
    for character in ["/", "\\", ":", "@", "\"", "%"]:
        result = result.replace(character, "_")
    return result


func _show_error(message: String) -> void:
    push_error("[Interactive Pet Preview] %s" % message)
    animation_name_label.text = "ОШИБКА: %s" % message
    frame_label.text = "КАДР: —"
    pause_button.disabled = true
    auto_button.disabled = true
    composite_button.disabled = true
    set_process(false)


func _return_to_gallery() -> void:
    _cancel_composite_preview(&"leave_preview")
    set_process(false)
    get_tree().change_scene_to_file(GALLERY_SCENE_PATH)
