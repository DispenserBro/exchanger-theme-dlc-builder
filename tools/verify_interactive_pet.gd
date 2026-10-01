extends SceneTree

const ACTIVE_STATE_PATH := "res://build/active-theme.json"
const CANONICAL_PACKAGE_ROOT := "res://exchanger_theme_dlc"
const PACKAGED_MANIFEST_PATH := "res://exchanger_theme_dlc/manifest.json"
const PET_MANIFEST_FIELD := "InteractivePetScene"
const PET_COMPONENT_RELATIVE_PATH := "components/interactive_pet.tscn"
const LEGACY_PET_COMPONENT_RELATIVE_PATH := "components/alien_pet.tscn"
const REQUIRED_METHODS := [
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
const PET_CLIMB_EDGE_META := &"exchanger_pet_climb_edge"


func _init() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var failures := PackedStringArray()
	var pack_path := _argument_value("--pack", "")
	var explicit_scene_path := _argument_value("--scene", "")
	var optional := OS.get_cmdline_user_args().has("--optional")
	var pet_scene_path := ""
	var package_root := ""

	if not pack_path.is_empty():
		if not ProjectSettings.load_resource_pack(pack_path, false):
			_fail("Cannot mount PCK %s." % pack_path)
			return
		package_root = CANONICAL_PACKAGE_ROOT
		pet_scene_path = _resolve_packaged_scene_path(explicit_scene_path)
	else:
		package_root = _resolve_builder_package_root()
		pet_scene_path = _resolve_builder_scene_path(explicit_scene_path)

	if pet_scene_path.is_empty():
		if optional:
			print("[Interactive Pet] SKIP: theme does not declare an interactive pet.")
			quit(0)
			return
		_fail("Theme does not declare an interactive pet scene.")
		return

	var packed_scene := load(pet_scene_path) as PackedScene
	if packed_scene == null:
		_fail("Cannot load %s." % pet_scene_path)
		return

	var instance := packed_scene.instantiate()
	if not instance is Node2D:
		instance.queue_free()
		_fail("Interactive pet root must inherit Node2D: %s." % pet_scene_path)
		return
	var pet := instance as Node2D
	root.add_child(pet)
	await process_frame

	for method_name in REQUIRED_METHODS:
		if not pet.has_method(method_name):
			failures.append("Missing public method %s()." % method_name)
	_expect_signal(pet, &"pet_animation_started", failures)
	_expect_signal(pet, &"pet_animation_completed", failures)
	if not failures.is_empty():
		_finish(failures, pet_scene_path, 0, 0, 0, 0)
		return

	var animation_names: Array[StringName] = []
	var raw_names = pet.call(&"get_pet_animation_names")
	if not raw_names is Array:
		failures.append("get_pet_animation_names() must return an Array.")
	else:
		for raw_name in raw_names:
			var animation_name := StringName(str(raw_name))
			if animation_name.is_empty():
				failures.append("Animation names must not be empty.")
			elif animation_names.has(animation_name):
				failures.append("Duplicate animation name %s." % animation_name)
			else:
				animation_names.append(animation_name)
	if animation_names.is_empty():
		failures.append("Interactive pet must expose at least one animation.")

	var initial_position := pet.position
	var total_frames := 0
	for animation_name in animation_names:
		if not bool(pet.call(&"has_pet_animation", animation_name)):
			failures.append("has_pet_animation() rejected %s." % animation_name)
			continue
		var frame_count := int(pet.call(&"get_pet_animation_frame_count", animation_name))
		if frame_count <= 0:
			failures.append("Animation %s must contain at least one frame." % animation_name)
		else:
			total_frames += frame_count
		if not bool(pet.call(&"play_pet_animation", animation_name)):
			failures.append("play_pet_animation() rejected %s." % animation_name)

	await create_timer(0.25).timeout
	if pet.position != initial_position:
		failures.append("Animation playback changed the pet root position.")
	await _validate_optional_visual_offset(pet, animation_names, failures)
	if pet.has_method(&"get_pet_preview_size"):
		var preview_size = pet.call(&"get_pet_preview_size")
		if not preview_size is Vector2 or preview_size.x <= 0.0 or preview_size.y <= 0.0:
			failures.append("get_pet_preview_size() must return a positive Vector2.")
	_validate_optional_pet_profile(pet, animation_names, failures)
	_validate_landing_animation(pet, animation_names, failures)
	_validate_optional_composite_action(pet, failures)
	var navigation_counts := _validate_pet_navigation(package_root, failures)

	_finish(
		failures,
		pet_scene_path,
		animation_names.size(),
		total_frames,
		navigation_counts.x,
		navigation_counts.y
	)


func _validate_optional_composite_action(pet: Node, failures: PackedStringArray) -> void:
	var exposed_count := 0
	for method_name in COMPOSITE_METHODS:
		if pet.has_method(method_name):
			exposed_count += 1
	for signal_name in COMPOSITE_SIGNALS:
		if pet.has_signal(signal_name):
			exposed_count += 1
	if exposed_count == 0:
		return

	for method_name in COMPOSITE_METHODS:
		if not pet.has_method(method_name):
			failures.append("Partial composite pet API: missing %s()." % method_name)
	for signal_name in COMPOSITE_SIGNALS:
		if not pet.has_signal(signal_name):
			failures.append("Partial composite pet API: missing signal %s." % signal_name)
	if exposed_count != COMPOSITE_METHODS.size() + COMPOSITE_SIGNALS.size():
		return
	var supported = pet.call(&"has_pet_composite_action", &"interact")
	if not supported is bool:
		failures.append("has_pet_composite_action() must return bool.")


func _resolve_builder_scene_path(explicit_scene_path: String) -> String:
	if not explicit_scene_path.is_empty():
		return explicit_scene_path
	var package_path := _resolve_builder_package_root()
	if package_path.is_empty():
		return ""
	var manifest := _load_json(package_path.path_join("manifest.json"))
	return _resolve_scene_from_manifest(package_path, manifest)


func _resolve_builder_package_root() -> String:
	var theme_id := _argument_value("--theme", "")
	var package_path := ""
	if not theme_id.is_empty():
		package_path = "res://themes/%s/package" % theme_id
	else:
		var state := _load_json(ACTIVE_STATE_PATH)
		package_path = ProjectSettings.localize_path(str(state.get("Package", "")))
	package_path = package_path.replace("\\", "/").trim_suffix("/")
	if not package_path.begins_with("res://"):
		return ""
	return package_path


func _resolve_packaged_scene_path(explicit_scene_path: String) -> String:
	if not explicit_scene_path.is_empty():
		return explicit_scene_path
	var manifest := _load_json(PACKAGED_MANIFEST_PATH)
	return _resolve_scene_from_manifest(CANONICAL_PACKAGE_ROOT, manifest)


func _resolve_scene_from_manifest(package_root: String, manifest: Dictionary) -> String:
	var declared_path := str(manifest.get(PET_MANIFEST_FIELD, ""))
	var candidates := PackedStringArray()
	if not declared_path.is_empty():
		var relative_path := _package_relative_path(declared_path)
		if not relative_path.is_empty():
			candidates.append(relative_path)
	candidates.append(PET_COMPONENT_RELATIVE_PATH)
	candidates.append(LEGACY_PET_COMPONENT_RELATIVE_PATH)
	for relative_path in candidates:
		var candidate := package_root.path_join(relative_path)
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


func _expect_signal(pet: Node, signal_name: StringName, failures: PackedStringArray) -> void:
	if not pet.has_signal(signal_name):
		failures.append("Missing public signal %s." % signal_name)


func _validate_optional_visual_offset(
	pet: Node2D,
	animation_names: Array[StringName],
	failures: PackedStringArray
) -> void:
	var has_current_offset := pet.has_method(&"get_pet_visual_offset")
	var has_animation_offset := pet.has_method(&"get_pet_animation_visual_offset")
	if has_current_offset != has_animation_offset:
		failures.append("Pet visual offset introspection methods must be provided together.")
		return
	if not has_current_offset:
		return
	if not animation_names.has(&"sitting"):
		failures.append("A pet exposing get_pet_visual_offset() must provide sitting.")
		return
	var non_sitting_animation := &""
	for animation_name in animation_names:
		if animation_name != &"sitting":
			non_sitting_animation = animation_name
			break
	if non_sitting_animation.is_empty():
		failures.append("A pet exposing get_pet_visual_offset() must provide a non-sitting animation.")
		return
	if pet.call(&"get_pet_animation_visual_offset", &"sitting") != Vector2(0.0, 24.0):
		failures.append("Declared sitting visual offset must be Vector2(0, 24).")
	if pet.call(&"get_pet_animation_visual_offset", non_sitting_animation) != Vector2.ZERO:
		failures.append("Declared non-sitting visual offset must be Vector2.ZERO.")

	var initial_root_position := pet.position
	pet.call(&"play_pet_animation", &"sitting")
	await process_frame
	if pet.call(&"get_pet_visual_offset") != Vector2(0.0, 24.0):
		failures.append("Sitting visual offset must be Vector2(0, 24).")

	pet.call(&"play_pet_animation", non_sitting_animation)
	await process_frame
	if pet.call(&"get_pet_visual_offset") != Vector2.ZERO:
		failures.append("Non-sitting visual offset must be Vector2.ZERO.")

	pet.call(&"play_pet_animation", &"sitting")
	await process_frame
	if pet.call(&"get_pet_visual_offset") != Vector2(0.0, 24.0):
		failures.append("Returning to sitting must restore Vector2(0, 24) visual offset.")
	if pet.position != initial_root_position:
		failures.append("Visual offset switching changed the pet root position.")


func _validate_optional_pet_profile(
	pet: Node,
	animation_names: Array[StringName],
	failures: PackedStringArray
) -> void:
	if pet.has_method(&"get_pet_action_animation"):
		for action_name in INTERACTIVE_PET_ACTIONS:
			var animation_name := StringName(str(pet.call(&"get_pet_action_animation", action_name)))
			if not animation_name.is_empty() and not animation_names.has(animation_name):
				failures.append("Pet action %s maps to unknown animation %s." % [action_name, animation_name])

	_validate_positive_float_method(pet, &"get_pet_runtime_scale", failures)
	_validate_positive_float_method(pet, &"get_pet_walk_speed", failures)
	_validate_positive_float_method(pet, &"get_pet_climb_speed", failures)

	var reference_size := Vector2.ZERO
	if pet.has_method(&"get_pet_hit_size"):
		var hit_size = pet.call(&"get_pet_hit_size")
		if (
			not hit_size is Vector2
			or not _is_finite_vector2(hit_size)
			or hit_size.x <= 0.0
			or hit_size.y <= 0.0
		):
			failures.append("get_pet_hit_size() must return a finite positive Vector2.")
		elif hit_size is Vector2:
			reference_size = hit_size
	elif pet.has_method(&"get_pet_preview_size"):
		var preview_size = pet.call(&"get_pet_preview_size")
		if preview_size is Vector2:
			reference_size = preview_size

	if pet.has_method(&"get_pet_ground_offset"):
		var ground_offset = pet.call(&"get_pet_ground_offset")
		if not ground_offset is Vector2 or not _is_finite_vector2(ground_offset):
			failures.append("get_pet_ground_offset() must return a finite Vector2.")
		elif (
			reference_size.x > 0.0
			and reference_size.y > 0.0
			and (
				ground_offset.x < 0.0
				or ground_offset.y < 0.0
				or ground_offset.x > reference_size.x
				or ground_offset.y > reference_size.y
			)
		):
			failures.append("get_pet_ground_offset() must stay inside pet hit/preview size.")


func _validate_landing_animation(
	pet: Node,
	animation_names: Array[StringName],
	failures: PackedStringArray
) -> void:
	if not animation_names.has(&"landing"):
		return
	if not bool(pet.call(&"has_pet_animation", &"landing")):
		failures.append("Direct landing animation is not playable.")
		return
	if pet.has_method(&"is_pet_animation_looping") and bool(
		pet.call(&"is_pet_animation_looping", &"landing")
	):
		failures.append("Direct landing animation must be one-shot, not looping.")


func _validate_positive_float_method(
	pet: Node,
	method_name: StringName,
	failures: PackedStringArray
) -> void:
	if not pet.has_method(method_name):
		return
	var value := float(pet.call(method_name))
	if not is_finite(value) or value <= 0.0:
		failures.append("%s() must return a finite positive value." % method_name)


func _validate_pet_navigation(package_root: String, failures: PackedStringArray) -> Vector2i:
	if package_root.is_empty():
		failures.append("Cannot resolve theme package root for pet navigation validation.")
		return Vector2i.ZERO
	var manifest := _load_json(package_root.path_join("manifest.json"))
	var screen_map: Dictionary = manifest.get("ScreenScenes", {})
	var totals := Vector2i.ZERO
	for screen_id_value in screen_map:
		var screen_id := str(screen_id_value)
		if screen_id == "screen.settings":
			continue
		var declared_path := str(screen_map.get(screen_id, ""))
		var relative_path := _package_relative_path(declared_path)
		var scene_path := package_root.path_join(relative_path)
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			failures.append("Cannot load %s pet navigation scene: %s." % [screen_id, scene_path])
			continue
		var screen_root := packed_scene.instantiate()
		if screen_root == null:
			failures.append("Cannot instantiate %s pet navigation scene: %s." % [screen_id, scene_path])
			continue

		var roots: Array[Node] = []
		for node in _all_nodes(screen_root):
			if bool(node.get_meta(PET_NAVIGATION_ROOT_META, false)):
				roots.append(node)
		if roots.size() != 1:
			failures.append("%s must contain exactly one pet navigation root." % screen_id)
			screen_root.free()
			continue

		totals += _validate_pet_navigation_root(roots[0], failures, screen_id)
		screen_root.free()
	return totals


func _validate_pet_navigation_root(
	navigation_root: Node,
	failures: PackedStringArray,
	screen_id: String
) -> Vector2i:
	if not navigation_root is Node2D:
		failures.append("%s pet navigation root must inherit Node2D." % screen_id)
	if int(navigation_root.get_meta(&"exchanger_pet_navigation_version", 0)) != 1:
		failures.append("%s pet navigation root version must be 1." % screen_id)
	var bounds_value = navigation_root.get_meta(&"exchanger_pet_roaming_bounds", null)
	var bounds := bounds_value as Rect2 if typeof(bounds_value) == TYPE_RECT2 else Rect2()
	if (
		typeof(bounds_value) != TYPE_RECT2
		or not _is_finite_rect2(bounds)
		or bounds.size.x <= 0.0
		or bounds.size.y <= 0.0
	):
		failures.append("%s pet roaming bounds must be a finite positive Rect2." % screen_id)

	var surfaces: Dictionary = {}
	var climb_edges: Array[Dictionary] = []
	var climb_ids: Dictionary = {}
	for node in _all_nodes(navigation_root):
		if bool(node.get_meta(PET_SURFACE_META, false)):
			_validate_pet_surface(node, surfaces, bounds, failures)
		if bool(node.get_meta(PET_CLIMB_EDGE_META, false)):
			var edge_id := StringName(str(node.get_meta(&"exchanger_pet_climb_edge_id", "")))
			if edge_id.is_empty():
				failures.append("Pet climb edge id must not be empty.")
			elif climb_ids.has(edge_id):
				failures.append("Duplicate pet climb edge id %s." % edge_id)
			else:
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

	if surfaces.is_empty():
		failures.append("%s pet navigation root must contain at least one surface." % screen_id)
	var default_surface := StringName(str(navigation_root.get_meta(&"exchanger_pet_default_surface_id", "")))
	if default_surface.is_empty() or not surfaces.has(default_surface):
		failures.append("%s pet navigation default surface must reference an existing surface." % screen_id)
	for edge in climb_edges:
		_validate_pet_climb_edge(edge, surfaces, bounds, failures)
	return Vector2i(surfaces.size(), climb_edges.size())


func _validate_pet_surface(
	node: Node,
	surfaces: Dictionary,
	bounds: Rect2,
	failures: PackedStringArray
) -> void:
	var surface_id := StringName(str(node.get_meta(&"exchanger_pet_surface_id", "")))
	if surface_id.is_empty():
		failures.append("Pet surface id must not be empty.")
		return
	if surfaces.has(surface_id):
		failures.append("Duplicate pet surface id %s." % surface_id)
		return
	var from_x := float(node.get_meta(&"exchanger_pet_surface_from_x", NAN))
	var to_x := float(node.get_meta(&"exchanger_pet_surface_to_x", NAN))
	var surface_y := float(node.get_meta(&"exchanger_pet_surface_y", NAN))
	if not is_finite(from_x) or not is_finite(to_x) or not is_finite(surface_y) or from_x >= to_x:
		failures.append("Pet surface %s must have finite from_x < to_x and y." % surface_id)
	if _is_finite_rect2(bounds) and (
		not _rect_contains_inclusive(bounds, Vector2(from_x, surface_y))
		or not _rect_contains_inclusive(bounds, Vector2(to_x, surface_y))
	):
		failures.append("Pet surface %s must stay inside roaming bounds." % surface_id)
	var sit_points = node.get_meta(&"exchanger_pet_surface_sit_points", PackedFloat32Array())
	var sit_type := typeof(sit_points)
	if sit_type != TYPE_ARRAY and sit_type != TYPE_PACKED_FLOAT32_ARRAY:
		failures.append("Pet surface %s sit points must be an Array or PackedFloat32Array." % surface_id)
	else:
		for raw_x in sit_points:
			var sit_x := float(raw_x)
			if not is_finite(sit_x) or sit_x < from_x or sit_x > to_x:
				failures.append("Pet surface %s sit point must be finite and inside the surface." % surface_id)
	surfaces[surface_id] = {"from_x": from_x, "to_x": to_x, "y": surface_y}


func _validate_pet_climb_edge(
	edge: Dictionary,
	surfaces: Dictionary,
	bounds: Rect2,
	failures: PackedStringArray
) -> void:
	var edge_id: StringName = edge.id
	var from_id: StringName = edge.from
	var to_id: StringName = edge.to
	if from_id.is_empty() or not surfaces.has(from_id):
		failures.append("Pet climb edge %s has unknown from surface." % edge_id)
	if to_id.is_empty() or not surfaces.has(to_id):
		failures.append("Pet climb edge %s has unknown to surface." % edge_id)
	var x := float(edge.x)
	var from_y := float(edge.from_y)
	var to_y := float(edge.to_y)
	if not is_finite(x) or not is_finite(from_y) or not is_finite(to_y) or is_equal_approx(from_y, to_y):
		failures.append("Pet climb edge %s must have finite coordinates and non-zero height." % edge_id)
	if edge.side != &"left" and edge.side != &"right":
		failures.append("Pet climb edge %s side must be left or right." % edge_id)
	if _is_finite_rect2(bounds) and (
		not _rect_contains_inclusive(bounds, Vector2(x, from_y))
		or not _rect_contains_inclusive(bounds, Vector2(x, to_y))
	):
		failures.append("Pet climb edge %s must stay inside roaming bounds." % edge_id)
	if surfaces.has(from_id):
		var from_surface: Dictionary = surfaces[from_id]
		if (
			x < float(from_surface.from_x)
			or x > float(from_surface.to_x)
			or not is_equal_approx(from_y, float(from_surface.y))
		):
			failures.append("Pet climb edge %s must start on its from surface." % edge_id)
	if surfaces.has(to_id):
		var to_surface: Dictionary = surfaces[to_id]
		if (
			x < float(to_surface.from_x)
			or x > float(to_surface.to_x)
			or not is_equal_approx(to_y, float(to_surface.y))
		):
			failures.append("Pet climb edge %s must end on its to surface." % edge_id)


func _all_nodes(start: Node) -> Array[Node]:
	var result: Array[Node] = [start]
	var cursor := 0
	while cursor < result.size():
		for child in result[cursor].get_children():
			result.append(child)
		cursor += 1
	return result


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


func _finish(
	failures: PackedStringArray,
	pet_scene_path: String,
	animation_count: int,
	total_frames: int,
	surface_count: int,
	climb_edge_count: int
) -> void:
	if failures.is_empty():
		print(
			"[Interactive Pet] OK: %d animations, %d frames, stationary root, %d surfaces, %d climb edges across non-settings screens (%s)."
			% [animation_count, total_frames, surface_count, climb_edge_count, pet_scene_path]
		)
		quit(0)
		return
	for failure in failures:
		push_error("[Interactive Pet] %s" % failure)
	quit(1)


func _fail(message: String) -> void:
	push_error("[Interactive Pet] %s" % message)
	quit(1)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _argument_value(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(name)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return fallback
