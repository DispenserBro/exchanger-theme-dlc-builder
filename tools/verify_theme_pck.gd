extends SceneTree

const MANIFEST_PATH := "res://exchanger_theme_dlc/manifest.json"


func _init() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var pack_path := _argument_value("--pack", "")
    var require_scripts := "--require-scripts" in OS.get_cmdline_user_args()
    if pack_path.is_empty():
        _fail("Pass an absolute PCK path with --pack.")
        return
    if not ProjectSettings.load_resource_pack(pack_path, false):
        _fail("Could not mount PCK: %s" % pack_path)
        return
    if not FileAccess.file_exists(MANIFEST_PATH):
        _fail("Mounted PCK does not contain %s" % MANIFEST_PATH)
        return

    var manifest_value = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    if not manifest_value is Dictionary:
        _fail("Theme manifest is not a JSON object.")
        return
    var manifest: Dictionary = manifest_value
    var screen_scenes: Dictionary = manifest.get("ScreenScenes", {})
    var script_nodes := 0

    for screen_id in screen_scenes:
        var scene_path := str(screen_scenes[screen_id])
        var packed := load(scene_path) as PackedScene
        if packed == null:
            _fail("Could not load %s for %s." % [scene_path, screen_id])
            return
        var instance := packed.instantiate()
        if instance == null:
            _fail("Could not instantiate %s for %s." % [scene_path, screen_id])
            return
        root.add_child(instance)
        await process_frame
        for node in _all_nodes(instance):
            if node.get_script() != null:
                script_nodes += 1
        root.remove_child(instance)
        instance.free()

    if require_scripts and script_nodes == 0:
        _fail("Theme PCK loaded successfully, but no attached runtime scripts were found.")
        return

    print(
        "[Theme PCK Smoke] OK: %d screen(s), %d scripted node instance(s)."
        % [screen_scenes.size(), script_nodes]
    )
    quit(0)


func _all_nodes(scene_root: Node) -> Array[Node]:
    var result: Array[Node] = [scene_root]
    var cursor := 0
    while cursor < result.size():
        for child in result[cursor].get_children():
            result.append(child)
        cursor += 1
    return result


func _argument_value(name: String, fallback: String) -> String:
    var args := OS.get_cmdline_user_args()
    var index := args.find(name)
    if index >= 0 and index + 1 < args.size():
        return args[index + 1]
    return fallback


func _fail(message: String) -> void:
    push_error("[Theme PCK Smoke] %s" % message)
    quit(1)
