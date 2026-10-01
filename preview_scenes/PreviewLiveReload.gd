extends Control

const POLL_INTERVAL_SECONDS := 0.25
const RELOAD_DEBOUNCE_SECONDS := 0.45
const SELECTED_TAB_META := &"theme_preview_selected_tab"
const SELECTED_SETTINGS_TAB_META := &"theme_preview_selected_settings_tab"
const WATCHED_DIRECTORIES := [
    "res://exchanger_theme_dlc",
    "res://preview_scenes",
]
const WATCHED_FILES := [
    "res://preview.tscn",
]
const WATCHED_EXTENSIONS := {
    "jpeg": true,
    "jpg": true,
    "json": true,
    "gd": true,
    "mp3": true,
    "ogg": true,
    "otf": true,
    "png": true,
    "svg": true,
    "tres": true,
    "tscn": true,
    "ttf": true,
    "wav": true,
    "webp": true,
}
const HASHED_EXTENSIONS := {
    "json": true,
    "tres": true,
    "tscn": true,
}

var _poll_elapsed := 0.0
var _reload_countdown := -1.0
var _snapshot: Dictionary = {}
var _pending_changes: Dictionary = {}


func _ready() -> void:
    _restore_selected_tab()
    _snapshot = _capture_snapshot()
    print("[Theme Preview] Live reload is active.")


func _process(delta: float) -> void:
    if _reload_countdown >= 0.0:
        _reload_countdown -= delta
        if _reload_countdown <= 0.0:
            _reload_preview()
            return

    _poll_elapsed += delta
    if _poll_elapsed < POLL_INTERVAL_SECONDS:
        return

    _poll_elapsed = 0.0
    var next_snapshot := _capture_snapshot()
    var changed_paths := _find_changed_paths(_snapshot, next_snapshot)
    _snapshot = next_snapshot
    if changed_paths.is_empty():
        return

    for path in changed_paths:
        _pending_changes[path] = true
    _reload_countdown = RELOAD_DEBOUNCE_SECONDS


func _restore_selected_tab() -> void:
    var screens := get_node_or_null("Screens") as TabContainer
    if screens == null or screens.get_tab_count() == 0:
        return

    var selected_tab := int(get_tree().root.get_meta(SELECTED_TAB_META, screens.current_tab))
    screens.current_tab = clampi(selected_tab, 0, screens.get_tab_count() - 1)

    var settings_tabs := get_node_or_null("Screens/SETTINGS/Sections") as TabContainer
    if settings_tabs != null and settings_tabs.get_tab_count() > 0:
        var selected_settings_tab := int(
            get_tree().root.get_meta(SELECTED_SETTINGS_TAB_META, settings_tabs.current_tab)
        )
        settings_tabs.current_tab = clampi(
            selected_settings_tab,
            0,
            settings_tabs.get_tab_count() - 1
        )


func _capture_snapshot() -> Dictionary:
    var result: Dictionary = {}
    for directory_path in WATCHED_DIRECTORIES:
        _scan_directory(directory_path, result)
    for file_path in WATCHED_FILES:
        if FileAccess.file_exists(file_path):
            result[file_path] = _file_fingerprint(file_path)
    return result


func _scan_directory(directory_path: String, result: Dictionary) -> void:
    if not DirAccess.dir_exists_absolute(directory_path):
        return

    for file_name in DirAccess.get_files_at(directory_path):
        var file_path := directory_path.path_join(file_name)
        var extension := file_name.get_extension().to_lower()
        if WATCHED_EXTENSIONS.has(extension):
            result[file_path] = _file_fingerprint(file_path)

    for child_directory in DirAccess.get_directories_at(directory_path):
        _scan_directory(directory_path.path_join(child_directory), result)


func _file_fingerprint(file_path: String) -> String:
    var modified_time := FileAccess.get_modified_time(file_path)
    var file := FileAccess.open(file_path, FileAccess.READ)
    var file_size := file.get_length() if file != null else -1
    var extension := file_path.get_extension().to_lower()
    if HASHED_EXTENSIONS.has(extension):
        return "%s:%s:%s" % [modified_time, file_size, FileAccess.get_md5(file_path)]
    return "%s:%s" % [modified_time, file_size]


func _find_changed_paths(previous: Dictionary, current: Dictionary) -> PackedStringArray:
    var changed := PackedStringArray()
    for path in current:
        if not previous.has(path) or previous[path] != current[path]:
            changed.append(path)
    for path in previous:
        if not current.has(path):
            changed.append(path)
    return changed


func _reload_preview() -> void:
    var screens := get_node_or_null("Screens") as TabContainer
    if screens != null:
        get_tree().root.set_meta(SELECTED_TAB_META, screens.current_tab)

    var settings_tabs := get_node_or_null("Screens/SETTINGS/Sections") as TabContainer
    if settings_tabs != null:
        get_tree().root.set_meta(SELECTED_SETTINGS_TAB_META, settings_tabs.current_tab)

    var changed_paths := PackedStringArray(_pending_changes.keys())
    changed_paths.sort()
    _pending_changes.clear()
    _reload_countdown = -1.0

    for path in changed_paths:
        if ResourceLoader.exists(path):
            ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)

    print("[Theme Preview] Reloading after changes: %s" % ", ".join(changed_paths))
    var reload_error := get_tree().reload_current_scene()
    if reload_error != OK:
        push_error("[Theme Preview] Scene reload failed with error %s." % reload_error)
