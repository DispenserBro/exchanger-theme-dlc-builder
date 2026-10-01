extends SceneTree

const DEFAULT_CONTRACT := "res://contracts/screen_bindings.v2.json"
const MANIFEST_PATH := "res://exchanger_theme_dlc/manifest.json"
const PACKAGED_CONTRACT_PATH := "res://exchanger_theme_dlc/contracts/screen_bindings.v2.json"
const SELF_CONTAINED_VISUALS_META := &"exchanger_self_contained_visuals"
const CANONICAL_PACKAGE_ROOT := "res://exchanger_theme_dlc/"
const INTERACTIVE_PET_MANIFEST_FIELD := "InteractivePetScene"
const INTERACTIVE_PET_METHODS := [
    &"get_pet_animation_names",
    &"get_pet_animation_frame_count",
    &"has_pet_animation",
    &"play_pet_animation",
    &"pause_pet_animation",
    &"stop_pet_animation",
    &"get_current_pet_animation",
    &"get_current_pet_frame",
]
const INTERACTIVE_PET_COMPOSITE_METHODS := [
    &"has_pet_composite_action",
    &"start_pet_composite_action",
    &"cancel_pet_composite_action",
]
const INTERACTIVE_PET_COMPOSITE_SIGNALS := [
    &"pet_composite_action_started",
    &"pet_composite_action_finished",
]
const INTERACTIVE_PET_ACTIONS := [
    &"idle",
    &"sit",
    &"interact",
    &"walk_left",
    &"walk_right",
    &"walk_start_left",
    &"walk_start_right",
    &"walk_finish_left",
    &"walk_finish_right",
    &"climb_start",
    &"climb_up",
    &"climb_down",
    &"climb_finish",
    &"drag",
    &"drop",
    &"landing",
    &"celebrate",
]
const PET_NAVIGATION_ROOT_META := &"exchanger_pet_navigation_root"
const PET_SURFACE_META := &"exchanger_pet_surface"
const PET_SURFACE_VISIBILITY_BINDING_META := &"exchanger_pet_surface_visibility_binding_id"
const PET_CLIMB_EDGE_META := &"exchanger_pet_climb_edge"
const IMMUTABLE_BINDING_COUNT := 481
const SUPPLEMENTAL_RUNTIME_BINDINGS := {
    "screen.home": {
        "home.scroll.content.advertisement_panel": ["Control"],
        "home.scroll.content.stock_status.meter.empty": ["Control"],
        "home.scroll.content.stock_status.meter.low": ["Control"],
        "home.scroll.content.stock_status.meter.enough": ["Control"],
        "home.scroll.content.stock_status.meter.much": ["Control"],
        "home.scroll.content.stock_status.approximate_count": ["Label"],
    },
    "screen.card_amount": {
        "card_amount.content.reward_panel.content.bonus": ["Label"],
        "card_amount.content.top_bar.home_navigation_button": ["Button"],
    },
    "screen.cash_payment": {
        "cash_payment.content.top_bar.home_navigation_button": ["Button"],
    },
    "screen.card_custom_amount": {
        "card_custom_amount.content.top_bar.home_navigation_button": ["Button"],
    },
    "screen.card_terminal": {
        "card_terminal.content.top_bar.home_navigation_button": ["Button"],
    },
    "screen.success": {
        "success.content.home_navigation_button": ["Button"],
    },
    "screen.error": {
        "error.content.home_navigation_button": ["Button"],
    },
    "screen.service_access": {
        "service_access.content.home_navigation_button": ["Button"],
    },
    "screen.settings": {
        "settings.scroll.content.music_panel": ["Control"],
        "settings.scroll.content.sound_effects_panel": ["Control"],
        "settings.footer": ["PanelContainer"],
        "settings.footer.save_and_exit_button": ["Button"],
        "settings.scroll.content.footer_clearance": ["Control"],
        "settings.scroll.content.service_inventory_panel.margin.content.description": ["Label"],
        "settings.scroll.content.service_inventory_panel.margin.content.inventory_enabled": ["CheckButton"],
        "settings.scroll.content.service_inventory_panel.margin.content.purchase_limit_enabled": ["CheckButton"],
        "settings.scroll.content.menu_visibility_panel": ["PanelContainer"],
        "settings.scroll.content.menu_visibility_panel.margin.content.show_stock_status": ["CheckButton"],
        "settings.scroll.content.menu_visibility_panel.margin.content.show_right_character": ["CheckButton"],
        "settings.scroll.content.menu_visibility_panel.margin.content.show_promotion_block": ["CheckButton"],
    },
}
const OPTIONAL_SUPPLEMENTAL_RUNTIME_BINDINGS := {
    "screen.cash_payment": {
        "cash_payment.content.banner_text": ["Label"],
    },
    "screen.home": {
        "home.decoration.custom_text_block": ["Control"],
        "home.decoration.right_character": ["TextureRect"],
    },
    "screen.settings": {
        "settings.scroll.content.animated_banner_texts_panel": ["Control"],
        "settings.scroll.content.advertisement_poster_panel.margin.content.select_button": ["Button"],
        "settings.scroll.content.menu_visibility_panel.margin.content.show_interactive_pet": ["CheckButton"],
    },
}
const HOME_PET_SURFACE_VISIBILITY_BINDINGS := {
    &"stock_window": "home.scroll.content.stock_status",
    &"advertisement_window": "home.scroll.content.advertisement_panel",
}

var _errors: PackedStringArray = []


func _init() -> void:
    call_deferred("_validate")


func _validate() -> void:
    var contract_path := _argument_value("--contract", DEFAULT_CONTRACT)
    var contract := _load_json(contract_path)
    _expect(FileAccess.file_exists(PACKAGED_CONTRACT_PATH), "Packaged binding catalog is missing: %s" % PACKAGED_CONTRACT_PATH)
    if FileAccess.file_exists(PACKAGED_CONTRACT_PATH):
        _expect(
            FileAccess.get_sha256(contract_path) == FileAccess.get_sha256(PACKAGED_CONTRACT_PATH),
            "Packaged binding catalog differs from the builder authority"
        )
    var manifest := _load_json(MANIFEST_PATH)
    if contract.is_empty() or manifest.is_empty():
        _finish()
        return

    var binding_count := 0
    for screen_value in contract.get("Screens", []):
        binding_count += (screen_value as Dictionary).get("Bindings", []).size()
    _expect(
        binding_count == IMMUTABLE_BINDING_COUNT,
        "immutable ThemeView contract must contain %d bindings; found %d"
        % [IMMUTABLE_BINDING_COUNT, binding_count]
    )

    _expect(manifest.get("Format") == "ExchangerThemeDlc", "manifest Format must be ExchangerThemeDlc")
    _expect(int(manifest.get("FormatVersion", 0)) == 2, "manifest FormatVersion must be 2")
    _expect(
        str(manifest.get("BackgroundTexturePath", "")).is_empty(),
        "self-contained themes must keep manifest BackgroundTexturePath empty"
    )
    _expect(
        str(manifest.get("BackgroundDecorationPath", "")).is_empty(),
        "self-contained themes must keep manifest BackgroundDecorationPath empty"
    )
    _validate_interactive_pet(manifest)
    var has_interactive_pet := not str(manifest.get(INTERACTIVE_PET_MANIFEST_FIELD, "")).is_empty()

    var screen_map: Dictionary = manifest.get("ScreenScenes", {})
    var global_bindings: Dictionary = {}
    for screen_value in contract.get("Screens", []):
        var screen: Dictionary = screen_value
        var screen_id := str(screen.get("BindingId", ""))
        var expected_path := str(screen.get("Path", ""))
        var actual_path := str(screen_map.get(screen_id, ""))
        _expect(actual_path == expected_path, "%s must map to %s" % [screen_id, expected_path])
        if actual_path != expected_path or not ResourceLoader.exists(actual_path):
            _error("Scene is missing: %s" % expected_path)
            continue

        var packed := load(actual_path) as PackedScene
        if packed == null:
            _error("Scene is not a PackedScene: %s" % actual_path)
            continue
        var root := packed.instantiate()
        if root == null:
            _error("Scene cannot be instantiated: %s" % actual_path)
            continue

        _expect(root.name == StringName(str(screen.get("RootName", ""))), "%s root must be named %s" % [screen_id, screen.get("RootName", "")])
        var screen_metadata_key := str(contract.get("ScreenMetadataKey", "exchanger_screen_binding_id"))
        _expect(str(root.get_meta(screen_metadata_key, "")) == screen_id, "%s root metadata must equal its screen binding id" % screen_id)
        _validate_self_contained_visuals(
            root,
            screen_id,
            bool(manifest.get("UseNearestTextureFilter", false))
        )
        if has_interactive_pet and screen_id != "screen.settings":
            _validate_pet_navigation(root, screen_id)
        _validate_bindings(root, screen, global_bindings, str(contract.get("ElementMetadataKey", "exchanger_binding_id")))
        _validate_fixed_slot_defaults(root, screen_id, str(contract.get("ElementMetadataKey", "exchanger_binding_id")))
        root.free()

    for manifest_screen in screen_map:
        if not _contract_has_screen(contract, str(manifest_screen)):
            _error("Unknown ScreenScenes key: %s" % manifest_screen)

    _finish()


func _validate_interactive_pet(manifest: Dictionary) -> void:
    var scene_path := str(manifest.get(INTERACTIVE_PET_MANIFEST_FIELD, ""))
    if scene_path.is_empty():
        return
    _expect(
        scene_path.begins_with(CANONICAL_PACKAGE_ROOT),
        "%s must point inside %s" % [INTERACTIVE_PET_MANIFEST_FIELD, CANONICAL_PACKAGE_ROOT]
    )
    _expect(not scene_path.contains(".."), "%s must not contain '..'" % INTERACTIVE_PET_MANIFEST_FIELD)
    _expect(scene_path.ends_with(".tscn"), "%s must point to a .tscn scene" % INTERACTIVE_PET_MANIFEST_FIELD)
    if not scene_path.begins_with(CANONICAL_PACKAGE_ROOT) or not ResourceLoader.exists(scene_path):
        _error("Interactive pet scene is missing: %s" % scene_path)
        return
    var packed_scene := load(scene_path) as PackedScene
    if packed_scene == null:
        _error("Interactive pet resource is not a PackedScene: %s" % scene_path)
        return
    var pet := packed_scene.instantiate()
    if pet == null:
        _error("Interactive pet scene cannot be instantiated: %s" % scene_path)
        return
    _expect(pet is Node2D, "interactive pet root must inherit Node2D")
    for method_name in INTERACTIVE_PET_METHODS:
        _expect(pet.has_method(method_name), "interactive pet must expose %s()" % method_name)
    _expect(pet.has_signal(&"pet_animation_started"), "interactive pet must expose pet_animation_started")
    _expect(pet.has_signal(&"pet_animation_completed"), "interactive pet must expose pet_animation_completed")
    _validate_optional_pet_profile(pet)
    pet.free()


func _validate_optional_pet_profile(pet: Node) -> void:
    var animation_names: Array[StringName] = []
    var raw_animation_names = pet.call(&"get_pet_animation_names")
    if raw_animation_names is Array:
        for raw_name in raw_animation_names:
            animation_names.append(StringName(str(raw_name)))

    if pet.has_method(&"get_pet_action_animation"):
        for action_name in INTERACTIVE_PET_ACTIONS:
            var animation_name := StringName(str(pet.call(&"get_pet_action_animation", action_name)))
            if not animation_name.is_empty():
                _expect(
                    animation_names.has(animation_name),
                    "interactive pet action %s maps to unknown animation %s" % [action_name, animation_name]
                )

    _validate_optional_composite_pet_action(pet)

    _validate_optional_positive_float(pet, &"get_pet_runtime_scale")
    _validate_optional_positive_float(pet, &"get_pet_walk_speed")
    _validate_optional_positive_float(pet, &"get_pet_climb_speed")

    var reference_size := Vector2.ZERO
    if pet.has_method(&"get_pet_hit_size"):
        var hit_size = pet.call(&"get_pet_hit_size")
        _expect(
            hit_size is Vector2
            and _is_finite_vector2(hit_size)
            and hit_size.x > 0.0
            and hit_size.y > 0.0,
            "get_pet_hit_size() must return a finite positive Vector2"
        )
        if hit_size is Vector2:
            reference_size = hit_size
    elif pet.has_method(&"get_pet_preview_size"):
        var preview_size = pet.call(&"get_pet_preview_size")
        if preview_size is Vector2:
            reference_size = preview_size

    if pet.has_method(&"get_pet_ground_offset"):
        var ground_offset = pet.call(&"get_pet_ground_offset")
        _expect(
            ground_offset is Vector2 and _is_finite_vector2(ground_offset),
            "get_pet_ground_offset() must return a finite Vector2"
        )
        if ground_offset is Vector2 and reference_size.x > 0.0 and reference_size.y > 0.0:
            _expect(
                ground_offset.x >= 0.0
                and ground_offset.y >= 0.0
                and ground_offset.x <= reference_size.x
                and ground_offset.y <= reference_size.y,
                "get_pet_ground_offset() must stay inside pet hit/preview size"
            )


func _validate_optional_composite_pet_action(pet: Node) -> void:
    var exposed_count := 0
    for method_name in INTERACTIVE_PET_COMPOSITE_METHODS:
        if pet.has_method(method_name):
            exposed_count += 1
    for signal_name in INTERACTIVE_PET_COMPOSITE_SIGNALS:
        if pet.has_signal(signal_name):
            exposed_count += 1
    if exposed_count == 0:
        return

    for method_name in INTERACTIVE_PET_COMPOSITE_METHODS:
        _expect(
            pet.has_method(method_name),
            "partial composite pet API: missing %s()" % method_name
        )
    for signal_name in INTERACTIVE_PET_COMPOSITE_SIGNALS:
        _expect(
            pet.has_signal(signal_name),
            "partial composite pet API: missing signal %s" % signal_name
        )
    if exposed_count != INTERACTIVE_PET_COMPOSITE_METHODS.size() + INTERACTIVE_PET_COMPOSITE_SIGNALS.size():
        return
    var supported = pet.call(&"has_pet_composite_action", &"interact")
    _expect(
        supported is bool,
        "has_pet_composite_action() must return bool"
    )


func _validate_optional_positive_float(pet: Node, method_name: StringName) -> void:
    if not pet.has_method(method_name):
        return
    var value := float(pet.call(method_name))
    _expect(is_finite(value) and value > 0.0, "%s() must return a finite positive value" % method_name)


func _validate_pet_navigation(screen_root: Node, screen_id: String) -> void:
    var navigation_roots: Array[Node] = []
    for node in _all_nodes(screen_root):
        if bool(node.get_meta(PET_NAVIGATION_ROOT_META, false)):
            navigation_roots.append(node)
    if navigation_roots.is_empty():
        _error("%s must contain one pet navigation root" % screen_id)
        return
    _expect(navigation_roots.size() == 1, "%s must contain exactly one pet navigation root" % screen_id)
    if navigation_roots.size() != 1:
        return

    var navigation_root := navigation_roots[0]
    _expect(navigation_root is Node2D, "pet navigation root must inherit Node2D")
    _expect(
        int(navigation_root.get_meta(&"exchanger_pet_navigation_version", 0)) == 1,
        "pet navigation root version must be 1"
    )
    var bounds_value = navigation_root.get_meta(&"exchanger_pet_roaming_bounds", null)
    _expect(typeof(bounds_value) == TYPE_RECT2, "pet navigation root must declare Rect2 roaming bounds")
    var bounds := bounds_value as Rect2 if typeof(bounds_value) == TYPE_RECT2 else Rect2()
    _expect(
        _is_finite_rect2(bounds) and bounds.size.x > 0.0 and bounds.size.y > 0.0,
        "pet roaming bounds must be finite and positive"
    )

    var surfaces: Dictionary = {}
    var climb_edges: Array[Dictionary] = []
    var climb_ids: Dictionary = {}
    for node in _all_nodes(navigation_root):
        if bool(node.get_meta(PET_SURFACE_META, false)):
            var surface_id := StringName(str(node.get_meta(&"exchanger_pet_surface_id", "")))
            _expect(not surface_id.is_empty(), "pet surface id must not be empty")
            _expect(not surfaces.has(surface_id), "duplicate pet surface id %s" % surface_id)
            var from_x := float(node.get_meta(&"exchanger_pet_surface_from_x", NAN))
            var to_x := float(node.get_meta(&"exchanger_pet_surface_to_x", NAN))
            var surface_y := float(node.get_meta(&"exchanger_pet_surface_y", NAN))
            _expect(
                is_finite(from_x) and is_finite(to_x) and is_finite(surface_y) and from_x < to_x,
                "pet surface %s must have finite from_x < to_x and y" % surface_id
            )
            if _is_finite_rect2(bounds):
                _expect(
                    _rect_contains_inclusive(bounds, Vector2(from_x, surface_y))
                    and _rect_contains_inclusive(bounds, Vector2(to_x, surface_y)),
                    "pet surface %s must stay inside roaming bounds" % surface_id
                )
            var sit_points = node.get_meta(&"exchanger_pet_surface_sit_points", PackedFloat32Array())
            var sit_type := typeof(sit_points)
            _expect(
                sit_type == TYPE_ARRAY or sit_type == TYPE_PACKED_FLOAT32_ARRAY,
                "pet surface %s sit points must be an Array or PackedFloat32Array" % surface_id
            )
            if sit_type == TYPE_ARRAY or sit_type == TYPE_PACKED_FLOAT32_ARRAY:
                for raw_x in sit_points:
                    var sit_x := float(raw_x)
                    _expect(
                        is_finite(sit_x) and sit_x >= from_x and sit_x <= to_x,
                        "pet surface %s sit point must be finite and inside the surface" % surface_id
                    )
            if not surface_id.is_empty() and not surfaces.has(surface_id):
                surfaces[surface_id] = {"from_x": from_x, "to_x": to_x, "y": surface_y}
            if screen_id == "screen.home" and HOME_PET_SURFACE_VISIBILITY_BINDINGS.has(surface_id):
                _expect(
                    str(node.get_meta(PET_SURFACE_VISIBILITY_BINDING_META, ""))
                    == str(HOME_PET_SURFACE_VISIBILITY_BINDINGS[surface_id]),
                    "pet surface %s must target visibility binding %s"
                    % [surface_id, HOME_PET_SURFACE_VISIBILITY_BINDINGS[surface_id]]
                )

        if bool(node.get_meta(PET_CLIMB_EDGE_META, false)):
            var edge_id := StringName(str(node.get_meta(&"exchanger_pet_climb_edge_id", "")))
            _expect(not edge_id.is_empty(), "pet climb edge id must not be empty")
            _expect(not climb_ids.has(edge_id), "duplicate pet climb edge id %s" % edge_id)
            if not edge_id.is_empty():
                climb_ids[edge_id] = true
            climb_edges.append({
                "id": edge_id,
                "from": StringName(str(node.get_meta(&"exchanger_pet_climb_from_surface_id", ""))),
                "to": StringName(str(node.get_meta(&"exchanger_pet_climb_to_surface_id", ""))),
                "x": float(node.get_meta(&"exchanger_pet_climb_x", NAN)),
                "from_y": float(node.get_meta(&"exchanger_pet_climb_from_y", NAN)),
                "to_y": float(node.get_meta(&"exchanger_pet_climb_to_y", NAN)),
                "side": StringName(str(node.get_meta(&"exchanger_pet_climb_side", ""))),
            })

    _expect(not surfaces.is_empty(), "pet navigation root must contain at least one surface")
    var default_surface := StringName(str(navigation_root.get_meta(&"exchanger_pet_default_surface_id", "")))
    _expect(
        not default_surface.is_empty() and surfaces.has(default_surface),
        "pet navigation default surface must reference an existing surface"
    )
    for edge in climb_edges:
        _validate_pet_climb_edge(edge, surfaces, bounds)


func _validate_pet_climb_edge(edge: Dictionary, surfaces: Dictionary, bounds: Rect2) -> void:
    var edge_id: StringName = edge.id
    var from_id: StringName = edge.from
    var to_id: StringName = edge.to
    _expect(not from_id.is_empty() and surfaces.has(from_id), "pet climb edge %s has unknown from surface" % edge_id)
    _expect(not to_id.is_empty() and surfaces.has(to_id), "pet climb edge %s has unknown to surface" % edge_id)
    var x := float(edge.x)
    var from_y := float(edge.from_y)
    var to_y := float(edge.to_y)
    _expect(
        is_finite(x) and is_finite(from_y) and is_finite(to_y) and not is_equal_approx(from_y, to_y),
        "pet climb edge %s must have finite coordinates and non-zero height" % edge_id
    )
    _expect(edge.side == &"left" or edge.side == &"right", "pet climb edge %s side must be left or right" % edge_id)
    if _is_finite_rect2(bounds):
        _expect(
            _rect_contains_inclusive(bounds, Vector2(x, from_y))
            and _rect_contains_inclusive(bounds, Vector2(x, to_y)),
            "pet climb edge %s must stay inside roaming bounds" % edge_id
        )
    if surfaces.has(from_id):
        var from_surface: Dictionary = surfaces[from_id]
        _expect(
            x >= float(from_surface.from_x)
            and x <= float(from_surface.to_x)
            and is_equal_approx(from_y, float(from_surface.y)),
            "pet climb edge %s must start on its from surface" % edge_id
        )
    if surfaces.has(to_id):
        var to_surface: Dictionary = surfaces[to_id]
        _expect(
            x >= float(to_surface.from_x)
            and x <= float(to_surface.to_x)
            and is_equal_approx(to_y, float(to_surface.y)),
            "pet climb edge %s must end on its to surface" % edge_id
        )


func _is_finite_vector2(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)


func _is_finite_rect2(value: Rect2) -> bool:
    return _is_finite_vector2(value.position) and _is_finite_vector2(value.size)


func _rect_contains_inclusive(rect: Rect2, point: Vector2) -> bool:
    return (
        point.x >= rect.position.x
        and point.y >= rect.position.y
        and point.x <= rect.end.x
        and point.y <= rect.end.y
    )


func _validate_self_contained_visuals(
    root: Node,
    screen_id: String,
    requires_nearest_filter: bool
) -> void:
    _expect(
        bool(root.get_meta(SELF_CONTAINED_VISUALS_META, false)),
        "%s must declare exchanger_self_contained_visuals = true" % screen_id
    )
    _expect(root is Control, "%s root must be a Control" % screen_id)
    if root is Control:
        _expect((root as Control).theme != null, "%s root must apply its package ui_theme" % screen_id)
        if requires_nearest_filter:
            _expect(
                (root as Control).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
                "%s root must use Nearest when manifest UseNearestTextureFilter is true"
                % screen_id
            )

    var background := root.get_node_or_null("ThemeBackground") as TextureRect
    _expect(background != null, "%s must contain ThemeBackground TextureRect" % screen_id)
    if background != null:
        _expect(background.texture != null, "%s ThemeBackground must have a texture" % screen_id)
    _expect(
        root.get_node_or_null("BackgroundDecoration") != null,
        "%s must contain BackgroundDecoration" % screen_id
    )


func _validate_bindings(root: Node, screen: Dictionary, global_bindings: Dictionary, metadata_key: String) -> void:
    var expected: Dictionary = {}
    var screen_id := str(screen.get("BindingId", ""))
    var supplemental: Dictionary = SUPPLEMENTAL_RUNTIME_BINDINGS.get(screen_id, {})
    var optional_supplemental: Dictionary = OPTIONAL_SUPPLEMENTAL_RUNTIME_BINDINGS.get(screen_id, {})
    for binding_value in screen.get("Bindings", []):
        var binding: Dictionary = binding_value
        expected[str(binding.get("Id", ""))] = binding

    var found: Dictionary = {}
    for node in _all_nodes(root):
        if not node.has_meta(metadata_key):
            continue
        var binding_id := str(node.get_meta(metadata_key))
        if binding_id.is_empty():
            _error("Empty exchanger_binding_id in %s at %s" % [screen.get("BindingId", ""), root.get_path_to(node)])
            continue
        if found.has(binding_id):
            _error("Duplicate binding %s inside %s" % [binding_id, screen.get("BindingId", "")])
            continue
        if global_bindings.has(binding_id):
            _error("Binding %s is reused by %s and %s" % [binding_id, global_bindings[binding_id], screen.get("BindingId", "")])
        found[binding_id] = node
        global_bindings[binding_id] = screen.get("BindingId", "")
        var allowed_types: Array = []
        if expected.has(binding_id):
            allowed_types = expected[binding_id].get("Types", [])
        elif supplemental.has(binding_id):
            allowed_types = supplemental[binding_id]
        elif optional_supplemental.has(binding_id):
            allowed_types = optional_supplemental[binding_id]
        else:
            _error("Binding %s is not declared for %s" % [binding_id, screen_id])
            continue
        if not allowed_types.is_empty() and not _is_any_class(node, allowed_types):
            _error("Binding %s has type %s; expected %s" % [binding_id, node.get_class(), ", ".join(allowed_types)])

    for binding_id in expected:
        var binding: Dictionary = expected[binding_id]
        if bool(binding.get("Required", true)) and not found.has(binding_id):
            _error("Required binding %s is missing from %s" % [binding_id, screen.get("BindingId", "")])
    for binding_id in supplemental:
        if not found.has(binding_id):
            _error("Required runtime binding %s is missing from %s" % [binding_id, screen_id])


func _validate_fixed_slot_defaults(root: Node, screen_id: String, metadata_key: String) -> void:
    var bindings: Dictionary = {}
    for node in _all_nodes(root):
        if node.has_meta(metadata_key):
            bindings[str(node.get_meta(metadata_key))] = node

    if screen_id == "screen.home":
        var speech_text := bindings.get("home.scroll.content.speech_text") as Label
        if speech_text != null:
            _expect(speech_text.autowrap_mode != TextServer.AUTOWRAP_OFF, "HOME speech text must wrap")
            _expect(speech_text.clip_text, "HOME speech text must clip overflow")
            _expect(
                speech_text.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
                "HOME speech text must be horizontally centered"
            )
            _expect(
                speech_text.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
                "HOME speech text must be vertically centered"
            )
        return

    if screen_id == "screen.cash_payment":
        var cash_caption := root.get_node_or_null(
            "SafeMargin/Content/Summary/Margin/Values/Caption"
        ) as Label
        _expect(cash_caption != null, "CASH PAYMENT summary Caption is missing")
        if cash_caption != null:
            _expect(cash_caption.text == "К ВЫДАЧЕ", "CASH PAYMENT summary Caption must be К ВЫДАЧЕ")
        return

    if screen_id == "screen.card_amount":
        for index in range(16):
            var slot_id := "card_amount.content.amount_panel.margin.content.preset_grid.slot_%02d" % index
            var slot := bindings.get(slot_id) as CanvasItem
            if slot != null and index >= 8:
                _expect(not slot.visible, "%s must be hidden by default" % slot_id)
        var card_amount_value_id := "card_amount.content.reward_panel.content.value"
        var card_amount_bonus_id := "card_amount.content.reward_panel.content.bonus"
        var card_amount_value := bindings.get(card_amount_value_id) as Label
        var card_amount_bonus := bindings.get(card_amount_bonus_id) as Label
        _expect(
            root.get_node_or_null("SafeMargin/Content/RewardPanel/Content/Value") == card_amount_value,
            "%s must keep the canonical Value path" % card_amount_value_id
        )
        _expect(
            root.get_node_or_null("SafeMargin/Content/RewardPanel/Content/Bonus") == card_amount_bonus,
            "%s must use the canonical Bonus path" % card_amount_bonus_id
        )
        if card_amount_value != null and card_amount_bonus != null:
            _expect(
                card_amount_bonus.get_index() == card_amount_value.get_index() + 1,
                "%s must be placed immediately after Value" % card_amount_bonus_id
            )
            _expect(
                card_amount_bonus.position.x > card_amount_value.position.x,
                "%s must be laid out to the right of Value" % card_amount_bonus_id
            )
            _expect(
                card_amount_bonus.text == "БЕЗ БОНУСА",
                "%s default text must be БЕЗ БОНУСА" % card_amount_bonus_id
            )
        return

    if screen_id == "screen.card_custom_amount":
        var clear_button := bindings.get(
            "card_custom_amount.content.keypad_panel.content.keypad.clear_button"
        ) as Button
        if clear_button != null:
            _expect(clear_button.visible, "card custom amount clear button must be visible")
            _expect(clear_button.text == "СТЕРЕТЬ", "card custom amount clear button text must be СТЕРЕТЬ")
        _expect_visible_default(
            bindings,
            "card_custom_amount.content.keypad_panel.content.keypad.backspace_button",
            false
        )
        var custom_amount_id := "card_custom_amount.content.amount_panel.margin.values.amount"
        var custom_bonus_id := "card_custom_amount.content.amount_panel.margin.values.tokens"
        var custom_amount := bindings.get(custom_amount_id) as Label
        var custom_bonus := bindings.get(custom_bonus_id) as Label
        _expect(
            root.get_node_or_null("SafeMargin/Content/AmountPanel/Margin/Values/Amount") == custom_amount,
            "%s must keep the canonical Amount path" % custom_amount_id
        )
        _expect(
            root.get_node_or_null("SafeMargin/Content/AmountPanel/Margin/Values/Tokens") == custom_bonus,
            "%s must keep the canonical Tokens path" % custom_bonus_id
        )
        if custom_amount != null and custom_bonus != null:
            _expect(
                custom_bonus.position.x > custom_amount.position.x,
                "%s must be laid out to the right of Amount" % custom_bonus_id
            )
            _expect(
                custom_bonus.text == "+ 50 ЖЕТОНОВ\nВ ПОДАРОК",
                "%s default text must use the two-line bonus format" % custom_bonus_id
            )
        return

    if screen_id != "screen.settings":
        return

    var short_text := bindings.get("settings.scroll.content.branding_panel.margin.content.short_text") as LineEdit
    if short_text != null:
        _expect(short_text.max_length == 48, "SETTINGS short text must be limited to 48 characters")

    var branding_content_path := "SafeMargin/Scroll/Content/BrandingPanel/Margin/Content"
    var application_name_label := root.get_node_or_null(
        "%s/ApplicationNameLabel" % branding_content_path
    ) as Label
    if application_name_label != null:
        _expect(not application_name_label.visible, "SETTINGS application name label must be hidden")
    var short_text_label := root.get_node_or_null(
        "%s/ShortTextLabel" % branding_content_path
    ) as Label
    if short_text_label != null:
        _expect(
            short_text_label.text == "СВОЙ ТЕКСТ • ДО 48 ЗНАКОВ",
            "SETTINGS short text label must be СВОЙ ТЕКСТ • ДО 48 ЗНАКОВ"
        )

    for hidden_binding_id in [
        "settings.scroll.content.branding_panel.margin.content.application_name",
        "settings.scroll.content.branding_panel.margin.content.application_name_error",
        "settings.scroll.content.branding_preview_panel",
        "settings.scroll.content.branding_preview_panel.margin.content.application_name",
        "settings.scroll.content.branding_preview_panel.margin.content.short_text",
        "settings.scroll.content.branding_preview_panel.margin.content.support_phone",
    ]:
        _expect_visible_default(bindings, hidden_binding_id, false)

    _expect_visible_default(
        bindings,
        "settings.scroll.content.service_inventory_panel",
        false
    )
    var service_inventory_panel := bindings.get("settings.scroll.content.service_inventory_panel") as Control
    if service_inventory_panel != null:
        _expect(
            is_equal_approx(service_inventory_panel.custom_minimum_size.y, 772.0),
            "settings.scroll.content.service_inventory_panel minimum height must be 772"
        )
    var inventory_description_id := "settings.scroll.content.service_inventory_panel.margin.content.description"
    var inventory_description := bindings.get(inventory_description_id) as Label
    if inventory_description != null:
        var canonical_inventory_description := root.get_node_or_null(
            "SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/Description"
        )
        _expect(
            canonical_inventory_description == inventory_description,
            "%s must use the canonical Description path" % inventory_description_id
        )
    var inventory_enabled_id := "settings.scroll.content.service_inventory_panel.margin.content.inventory_enabled"
    var inventory_enabled := bindings.get(inventory_enabled_id) as CheckButton
    if inventory_enabled != null:
        _expect(inventory_enabled.button_pressed, "%s must be enabled by default" % inventory_enabled_id)
        _expect(
            inventory_enabled.text == "УЧИТЫВАТЬ ОСТАТОК ЖЕТОНОВ",
            "%s text must be УЧИТЫВАТЬ ОСТАТОК ЖЕТОНОВ" % inventory_enabled_id
        )
        var canonical_inventory_enabled := root.get_node_or_null(
            "SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/InventoryAccountingEnabled"
        )
        _expect(
            canonical_inventory_enabled == inventory_enabled,
            "%s must use the canonical InventoryAccountingEnabled path" % inventory_enabled_id
        )
        if inventory_description != null:
            _expect(
                inventory_enabled.get_index() == inventory_description.get_index() + 1,
                "%s must be placed immediately after Description" % inventory_enabled_id
            )
    var purchase_limit_id := "settings.scroll.content.service_inventory_panel.margin.content.purchase_limit_enabled"
    var purchase_limit := bindings.get(purchase_limit_id) as CheckButton
    if purchase_limit != null:
        _expect(purchase_limit.button_pressed, "%s must be enabled by default" % purchase_limit_id)
        _expect(
            purchase_limit.text == "НЕ ПРОДАВАТЬ БОЛЬШЕ ОСТАТКА",
            "%s text must be НЕ ПРОДАВАТЬ БОЛЬШЕ ОСТАТКА" % purchase_limit_id
        )
        var canonical_purchase_limit := root.get_node_or_null(
            "SafeMargin/Scroll/Content/ServiceInventoryPanel/Margin/Content/PurchaseLimitEnabled"
        )
        _expect(
            canonical_purchase_limit == purchase_limit,
            "%s must use the canonical PurchaseLimitEnabled path" % purchase_limit_id
        )
        if inventory_enabled != null:
            _expect(
                purchase_limit.get_index() == inventory_enabled.get_index() + 1,
                "%s must be placed immediately after InventoryAccountingEnabled" % purchase_limit_id
            )
    _expect_visible_default(
        bindings,
        "settings.scroll.content.menu_visibility_panel",
        false
    )
    for binding_id in [
        "settings.scroll.content.menu_visibility_panel.margin.content.show_stock_status",
        "settings.scroll.content.menu_visibility_panel.margin.content.show_right_character",
        "settings.scroll.content.menu_visibility_panel.margin.content.show_promotion_block",
        "settings.scroll.content.menu_visibility_panel.margin.content.show_interactive_pet",
    ]:
        var toggle := bindings.get(binding_id) as CheckButton
        if toggle != null:
            _expect(toggle.button_pressed, "%s must be enabled by default" % binding_id)

    var footer := bindings.get("settings.footer") as PanelContainer
    var save_and_exit := bindings.get("settings.footer.save_and_exit_button") as Button
    var footer_clearance := bindings.get("settings.scroll.content.footer_clearance") as Control
    var settings_scroll := bindings.get("settings.scroll") as ScrollContainer
    var scroll_content := bindings.get("settings.scroll.content") as Control
    if footer != null:
        _expect(footer.visible, "settings.footer must be visible by default")
        _expect(footer.get_parent() == root, "settings.footer must be a root sibling of SafeMargin")
        _expect(
            is_equal_approx(footer.anchor_top, 1.0) and is_equal_approx(footer.anchor_bottom, 1.0),
            "settings.footer must stay anchored to the bottom edge"
        )
    if save_and_exit != null:
        _expect(
            save_and_exit.get_parent() == footer,
            "settings.footer.save_and_exit_button must be a direct child of settings.footer"
        )
        _expect(save_and_exit.text == "СОХРАНИТЬ И ВЫЙТИ", "settings footer button text is invalid")
    if footer_clearance != null:
        _expect(
            footer_clearance.get_parent() == scroll_content,
            "settings.scroll.content.footer_clearance must be a direct child of scroll content"
        )
        _expect(
            footer_clearance.custom_minimum_size.y >= 104.0,
            "settings.scroll.content.footer_clearance must reserve the footer height"
        )
    if settings_scroll != null:
        _expect(
            settings_scroll.size_flags_vertical == Control.SIZE_SHRINK_BEGIN,
            "settings.scroll must shrink from the bottom to avoid the fixed footer"
        )
        _expect(
            settings_scroll.custom_minimum_size.y <= 1100.0,
            "settings.scroll must leave room for the fixed footer at 720x1280"
        )
    _expect_visible_default(
        bindings,
        "settings.service_dialog_overlay",
        false
    )
    var service_amount := bindings.get("settings.service_dialog_overlay.dialog.margin.content.amount") as SpinBox
    if service_amount != null:
        _expect(service_amount.min_value == 0.0, "SETTINGS service amount must allow zero")
        _expect(service_amount.max_value >= 999999.0, "SETTINGS service amount must accept large inventory totals")
        _expect(service_amount.suffix.is_empty(), "SETTINGS service amount must not reserve space for a suffix")

    _expect_visible_default(
        bindings,
        "settings.scroll.content.bonus_panel.margin.content.rows.empty_state",
        true
    )
    _expect_visible_default(
        bindings,
        "settings.scroll.content.card_options_panel.margin.content.preset_rows.empty_state",
        false
    )
    _expect_visible_default(
        bindings,
        "settings.scroll.content.advertisement_playlist_panel.margin.content.rows.empty_state",
        true
    )
    for index in range(16):
        var bonus_id := "settings.scroll.content.bonus_panel.margin.content.rows.slot_%02d.bonus" % index
        var bonus_field := bindings.get(bonus_id) as SpinBox
        if bonus_field != null:
            _expect(
                bonus_field.suffix.is_empty(),
                "%s must not have a suffix so multi-digit token counts remain visible" % bonus_id
            )
        _expect_visible_default(
            bindings,
            "settings.scroll.content.bonus_panel.margin.content.rows.slot_%02d" % index,
            false
        )
        _expect_visible_default(
            bindings,
            "settings.scroll.content.card_options_panel.margin.content.preset_rows.slot_%02d" % index,
            index < 8
        )
    for index in range(12):
        _expect_visible_default(
            bindings,
            "settings.scroll.content.advertisement_playlist_panel.margin.content.rows.slot_%02d" % index,
            false
        )


func _expect_visible_default(bindings: Dictionary, binding_id: String, expected: bool) -> void:
    var item := bindings.get(binding_id) as CanvasItem
    if item != null:
        _expect(item.visible == expected, "%s default visibility must be %s" % [binding_id, expected])


func _all_nodes(root: Node) -> Array[Node]:
    var result: Array[Node] = [root]
    var cursor := 0
    while cursor < result.size():
        var current := result[cursor]
        for child in current.get_children():
            result.append(child)
        cursor += 1
    return result


func _is_any_class(node: Node, allowed_types: Array) -> bool:
    for type_value in allowed_types:
        if node.is_class(str(type_value)):
            return true
    return false


func _contract_has_screen(contract: Dictionary, binding_id: String) -> bool:
    for screen_value in contract.get("Screens", []):
        if str(screen_value.get("BindingId", "")) == binding_id:
            return true
    return false


func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        _error("JSON file is missing: %s" % path)
        return {}
    var value = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not value is Dictionary:
        _error("JSON root must be an object: %s" % path)
        return {}
    return value


func _argument_value(name: String, fallback: String) -> String:
    var args := OS.get_cmdline_user_args()
    var index := args.find(name)
    if index >= 0 and index + 1 < args.size():
        return args[index + 1]
    return fallback


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _error(message)


func _error(message: String) -> void:
    _errors.append(message)


func _finish() -> void:
    if _errors.is_empty():
        print("[Theme Validator] OK: full-scene contract is valid.")
        quit(0)
        return
    for message in _errors:
        push_error("[Theme Validator] %s" % message)
    print("[Theme Validator] FAILED: %d error(s)." % _errors.size())
    quit(1)
