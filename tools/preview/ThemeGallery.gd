extends Control

const ACTIVE_STATE_PATH := "res://build/active-theme.json"
const CANONICAL_PACKAGE_ROOT := "res://exchanger_theme_dlc"
const PET_PREVIEW_SCENE_PATH := "res://tools/preview/interactive_pet_preview.tscn"
const PET_MANIFEST_FIELD := "InteractivePetScene"
const PET_COMPONENT_RELATIVE_PATH := "components/interactive_pet.tscn"
const LEGACY_PET_COMPONENT_RELATIVE_PATH := "components/alien_pet.tscn"
const POLL_INTERVAL := 0.35
const RELOAD_DELAY := 0.45
const SCREEN_ORDER := [
    ["HOME", "screen.home"],
    ["CASH", "screen.cash_payment"],
    ["SUM", "screen.card_amount"],
    ["KEYPAD", "screen.card_custom_amount"],
    ["CARD", "screen.card_terminal"],
    ["SUCCESS", "screen.success"],
    ["ERROR", "screen.error"],
    ["SERVICE", "screen.service_access"],
    ["SETTINGS", "screen.settings"],
]
const WATCHED_EXTENSIONS := {
    "gd": true, "gdshader": true, "json": true, "material": true,
    "res": true, "scn": true, "tres": true, "tscn": true,
    "png": true, "jpg": true, "jpeg": true, "webp": true, "svg": true,
    "ttf": true, "otf": true, "wav": true, "ogg": true, "mp3": true,
    "ogv": true,
}
const TAB_META := &"full_scene_theme_preview_tab"
const OVERLAY_META := &"full_scene_theme_preview_overlay"
const KEYBOARD_PREVIEW_META := &"full_scene_theme_preview_keyboard"
const SERVICE_PREVIEW_META := &"full_scene_theme_preview_service"
const TAB_INDEX_META := &"preview_tab_index"
const TEXT_KEYBOARD_BINDING := "settings.keyboard_overlay.text_keyboard"
const NUMERIC_KEYBOARD_BINDING := "settings.keyboard_overlay.numeric_keyboard"
const SERVICE_PANEL_BINDING := "settings.scroll.content.service_inventory_panel"
const SERVICE_DIALOG_BINDING := "settings.service_dialog_overlay"

@onready var screens: TabContainer = $Screens
@onready var binding_overlay: Control = $BindingOverlay
@onready var navigation: HBoxContainer = $TopBar/Navigation
@onready var overlay_toggle: Button = $TopBar/Navigation/OverlayToggle
@onready var keyboard_preview_toggle: Button = $KeyboardPreviewToggle
@onready var service_preview_toggle: Button = $ServicePreviewToggle
@onready var pet_preview_button: Button = $TopBar/Navigation/PetPreview

var _source_package := ""
var _source_snapshot: Dictionary = {}
var _poll_elapsed := 0.0
var _reload_elapsed := -1.0
var _service_visibility_snapshots: Dictionary = {}


func _ready() -> void:
    _source_package = _active_package_path()
    var pet_component_path := _resolve_pet_component_path(_source_package)
    pet_preview_button.disabled = pet_component_path.is_empty()
    pet_preview_button.tooltip_text = (
        "Открыть просмотрщик анимаций питомца"
        if not pet_preview_button.disabled
        else "В активной теме не задан InteractivePetScene"
    )
    _load_active_theme()
    screens.tab_changed.connect(_on_tab_changed)
    overlay_toggle.toggled.connect(_on_overlay_toggled)
    keyboard_preview_toggle.pressed.connect(_on_keyboard_preview_pressed)
    service_preview_toggle.pressed.connect(_on_service_preview_pressed)
    pet_preview_button.pressed.connect(_open_pet_preview)
    for child in navigation.get_children():
        if child is Button and child.has_meta(TAB_INDEX_META):
            (child as Button).pressed.connect(
                _on_page_button_pressed.bind(int(child.get_meta(TAB_INDEX_META)))
            )
    var overlay_enabled := bool(get_tree().root.get_meta(OVERLAY_META, true))
    overlay_toggle.set_pressed_no_signal(overlay_enabled)
    _on_overlay_toggled(overlay_enabled)
    var selected := int(get_tree().root.get_meta(TAB_META, 0))
    screens.current_tab = clampi(selected, 0, maxi(0, screens.get_tab_count() - 1))
    _on_tab_changed(screens.current_tab)
    if not _source_package.is_empty():
        _source_snapshot = _capture_snapshot(_source_package)
        print("[Theme Preview] Watching %s" % _source_package)


func _process(delta: float) -> void:
    if _source_package.is_empty():
        return
    if _reload_elapsed >= 0.0:
        _reload_elapsed -= delta
        if _reload_elapsed <= 0.0:
            get_tree().root.set_meta(TAB_META, screens.current_tab)
            get_tree().reload_current_scene()
            return
    _poll_elapsed += delta
    if _poll_elapsed < POLL_INTERVAL:
        return
    _poll_elapsed = 0.0
    var next_source := _capture_snapshot(_source_package)
    var source_changes := _changed_paths(_source_snapshot, next_source)
    _source_snapshot = next_source
    if not source_changes.is_empty():
        _reload_elapsed = RELOAD_DELAY


func _load_active_theme() -> void:
    if _source_package.is_empty():
        push_error("[Theme Preview] No active package is selected.")
        return
    var package_res_root := ProjectSettings.localize_path(_source_package).replace("\\", "/")
    if not package_res_root.begins_with("res://"):
        push_error("[Theme Preview] Active package must be inside this project: %s" % _source_package)
        return
    var manifest := _load_json(_source_package.path_join("manifest.json"))
    var scene_map: Dictionary = manifest.get("ScreenScenes", {})
    for descriptor in SCREEN_ORDER:
        var binding_id: String = descriptor[1]
        var canonical_path := str(scene_map.get(binding_id, ""))
        var relative_path := canonical_path.trim_prefix(CANONICAL_PACKAGE_ROOT).trim_prefix("/")
        var scene_path := package_res_root.path_join(relative_path)
        if not ResourceLoader.exists(scene_path):
            push_error("[Theme Preview] Missing scene for %s: %s" % [binding_id, scene_path])
            continue
        var packed := load(scene_path) as PackedScene
        if packed == null:
            continue
        var screen := packed.instantiate()
        screens.add_child(screen)


func _on_tab_changed(tab: int) -> void:
    _update_page_buttons(tab)
    if tab < 0 or tab >= screens.get_tab_count():
        binding_overlay.target = null
        keyboard_preview_toggle.visible = false
        service_preview_toggle.visible = false
        return
    var screen := screens.get_child(tab)
    binding_overlay.target = screen
    keyboard_preview_toggle.visible = (
        str(screen.get_meta(&"exchanger_screen_binding_id", "")) == "screen.settings"
    )
    service_preview_toggle.visible = keyboard_preview_toggle.visible
    _apply_service_preview_mode(screen)
    _apply_keyboard_preview_mode(screen)


func _on_page_button_pressed(tab: int) -> void:
    if tab >= 0 and tab < screens.get_tab_count():
        screens.current_tab = tab


func _open_pet_preview() -> void:
    get_tree().change_scene_to_file(PET_PREVIEW_SCENE_PATH)


func _update_page_buttons(selected_tab: int) -> void:
    for child in navigation.get_children():
        if child is Button and child.has_meta(TAB_INDEX_META):
            (child as Button).set_pressed_no_signal(
                int(child.get_meta(TAB_INDEX_META)) == selected_tab
            )


func _on_overlay_toggled(enabled: bool) -> void:
    binding_overlay.visible = enabled
    overlay_toggle.text = "BINDINGS: ON" if enabled else "BINDINGS: OFF"
    get_tree().root.set_meta(OVERLAY_META, enabled)


func _on_keyboard_preview_pressed() -> void:
    var mode := (int(get_tree().root.get_meta(KEYBOARD_PREVIEW_META, 0)) + 1) % 3
    get_tree().root.set_meta(KEYBOARD_PREVIEW_META, mode)
    if screens.current_tab >= 0 and screens.current_tab < screens.get_tab_count():
        _apply_keyboard_preview_mode(screens.get_child(screens.current_tab))


func _apply_keyboard_preview_mode(screen: Node) -> void:
    var mode := int(get_tree().root.get_meta(KEYBOARD_PREVIEW_META, 0))
    var text_keyboard := _find_binding(screen, TEXT_KEYBOARD_BINDING) as CanvasItem
    var numeric_keyboard := _find_binding(screen, NUMERIC_KEYBOARD_BINDING) as CanvasItem
    if text_keyboard != null:
        text_keyboard.visible = mode == 1
    if numeric_keyboard != null:
        numeric_keyboard.visible = mode == 2
    keyboard_preview_toggle.text = ["KEYBOARD: OFF", "KEYBOARD: TEXT", "KEYBOARD: NUM"][mode]


func _on_service_preview_pressed() -> void:
    var mode := (int(get_tree().root.get_meta(SERVICE_PREVIEW_META, 0)) + 1) % 3
    get_tree().root.set_meta(SERVICE_PREVIEW_META, mode)
    if screens.current_tab >= 0 and screens.current_tab < screens.get_tab_count():
        _apply_service_preview_mode(screens.get_child(screens.current_tab))


func _apply_service_preview_mode(screen: Node) -> void:
    var panel := _find_binding(screen, SERVICE_PANEL_BINDING) as CanvasItem
    var dialog := _find_binding(screen, SERVICE_DIALOG_BINDING) as CanvasItem
    if panel == null or dialog == null:
        service_preview_toggle.text = "INVENTORY: OFF"
        return

    var screen_key := screen.get_instance_id()
    if not _service_visibility_snapshots.has(screen_key):
        var snapshot: Dictionary = {}
        for child in panel.get_parent().get_children():
            if child is PanelContainer and child.name != &"Header":
                snapshot[child] = child.visible
        _service_visibility_snapshots[screen_key] = snapshot

    var mode := int(get_tree().root.get_meta(SERVICE_PREVIEW_META, 0))
    var visibility_snapshot: Dictionary = _service_visibility_snapshots[screen_key]
    for node in visibility_snapshot:
        if is_instance_valid(node):
            (node as CanvasItem).visible = bool(visibility_snapshot[node]) if mode == 0 else false

    panel.visible = mode > 0
    dialog.visible = mode == 2
    var scroll := _find_binding(screen, "settings.scroll") as ScrollContainer
    if scroll != null and mode > 0:
        scroll.scroll_vertical = 0
    service_preview_toggle.text = ["INVENTORY: OFF", "INVENTORY: PANEL", "INVENTORY: DIALOG"][mode]


func _find_binding(root: Node, binding_id: String) -> Node:
    var pending: Array[Node] = [root]
    var cursor := 0
    while cursor < pending.size():
        var current := pending[cursor]
        cursor += 1
        if str(current.get_meta(&"exchanger_binding_id", "")) == binding_id:
            return current
        for child in current.get_children():
            pending.append(child)
    return null


func _active_package_path() -> String:
    var state := _load_json(ACTIVE_STATE_PATH)
    var package_path := str(state.get("Package", ""))
    return package_path.replace("\\", "/")


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


func _capture_snapshot(root_path: String) -> Dictionary:
    var result: Dictionary = {}
    _scan_directory(root_path, result)
    return result


func _scan_directory(path: String, result: Dictionary) -> void:
    if not DirAccess.dir_exists_absolute(path):
        return
    for file_name in DirAccess.get_files_at(path):
        if WATCHED_EXTENSIONS.has(file_name.get_extension().to_lower()):
            var file_path := path.path_join(file_name)
            result[file_path] = "%s:%s" % [FileAccess.get_modified_time(file_path), FileAccess.get_md5(file_path)]
    for directory_name in DirAccess.get_directories_at(path):
        _scan_directory(path.path_join(directory_name), result)


func _changed_paths(previous: Dictionary, current: Dictionary) -> PackedStringArray:
    var result := PackedStringArray()
    for path in current:
        if not previous.has(path) or previous[path] != current[path]:
            result.append(path)
    for path in previous:
        if not current.has(path):
            result.append(path)
    return result


func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var value = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}
