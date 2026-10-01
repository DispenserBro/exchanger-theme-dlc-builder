@tool
extends Node2D

signal pet_animation_started(animation_name: StringName)
signal pet_animation_completed(animation_name: StringName)
signal pet_composite_action_started(action_name: StringName, run_id: int)
signal pet_composite_action_finished(action_name: StringName, run_id: int, completed: bool)

const FRAME_SIZE := Vector2i(128, 128)
const ANIMATION_NAMES := [
	&"climbing_down",
	&"climbing_start",
	&"climbing_up",
	&"dancing",
	&"come_closer",
	&"falling",
	&"hanging",
	&"sitting",
	&"idle",
	&"landing",
	&"turn_left",
	&"turn_right",
	&"walking_left_stop",
	&"walking_right_stop",
	&"walking_left",
	&"walking_right",
	&"walking_left_start",
	&"walking_start_right",
	&"action",
	&"climbing_action_start",
	&"climbing_action_stop",
	&"climbing_action",
]
const ANIMATION_FRAME_COUNTS := {
	&"climbing_down": 16,
	&"climbing_start": 19,
	&"climbing_up": 16,
	&"dancing": 95,
	&"come_closer": 36,
	&"falling": 30,
	&"hanging": 23,
	&"sitting": 30,
	&"idle": 19,
	&"landing": 11,
	&"turn_left": 10,
	&"turn_right": 10,
	&"walking_left_stop": 4,
	&"walking_right_stop": 4,
	&"walking_left": 19,
	&"walking_right": 19,
	&"walking_left_start": 5,
	&"walking_start_right": 5,
	&"action": 11,
	&"climbing_action_start": 11,
	&"climbing_action_stop": 11,
	&"climbing_action": 10,
}
const ANIMATION_SPEEDS := {
	&"climbing_down": 24.0,
	&"climbing_start": 24.0,
	&"climbing_up": 24.0,
	&"dancing": 24.0,
	&"come_closer": 24.0,
	&"falling": 24.0,
	&"hanging": 12.0,
	&"sitting": 24.0,
	&"idle": 24.0,
	&"landing": 24.0,
	&"turn_left": 24.0,
	&"turn_right": 24.0,
	&"walking_left_stop": 24.0,
	&"walking_right_stop": 24.0,
	&"walking_left": 24.0,
	&"walking_right": 24.0,
	&"walking_left_start": 24.0,
	&"walking_start_right": 24.0,
	&"action": 24.0,
	&"climbing_action_start": 24.0,
	&"climbing_action_stop": 24.0,
	&"climbing_action": 24.0,
}
const ONE_SHOT_ANIMATIONS := {
	&"climbing_start": true,
	&"come_closer": true,
	&"landing": true,
	&"turn_left": true,
	&"turn_right": true,
	&"walking_left_stop": true,
	&"walking_right_stop": true,
	&"walking_left_start": true,
	&"walking_start_right": true,
	&"climbing_action_start": true,
	&"climbing_action_stop": true,
}
const ACTION_ANIMATIONS := {
	&"idle": &"idle",
	&"sit": &"sitting",
	&"interact": &"action",
	&"celebrate": &"dancing",
	&"walk_left": &"walking_left",
	&"walk_right": &"walking_right",
	&"walk_start_left": &"walking_left_start",
	&"walk_start_right": &"walking_start_right",
	&"walk_finish_left": &"walking_left_stop",
	&"walk_finish_right": &"walking_right_stop",
	&"climb_start": &"climbing_start",
	&"climb_up": &"climbing_up",
	&"climb_down": &"climbing_down",
	&"climb_finish": &"idle",
	&"drag": &"hanging",
	&"drop": &"falling",
	&"come_closer": &"come_closer",
	&"landing": &"landing",
	&"turn_left": &"turn_left",
	&"turn_right": &"turn_right",
	&"action": &"action",
	&"climbing_action_start": &"climbing_action_start",
	&"climbing_action": &"climbing_action",
	&"climbing_action_stop": &"climbing_action_stop",
}
const RUNTIME_SCALE := 0.845
const WALK_SPEED := 88.0
const CLIMB_SPEED := 72.0
const HIT_SIZE := Vector2(128.0, 128.0)
const GROUND_OFFSET := Vector2(64.0, 96.0)
const SITTING_VISUAL_OFFSET := Vector2(0.0, 24.0)
const NON_SITTING_VISUAL_OFFSET := Vector2.ZERO
const COMPOSITE_INTERACT := &"interact"
const FACING_FRONT := &"front"
const FACING_LEFT := &"left"
const FACING_RIGHT := &"right"
const LEFT_FACING_ANIMATIONS := {
	&"walking_left": true,
	&"walking_left_start": true,
	&"walking_left_stop": true,
}
const RIGHT_FACING_ANIMATIONS := {
	&"walking_right": true,
	&"walking_start_right": true,
	&"walking_right_stop": true,
}
const FRONT_FACING_ANIMATIONS := {
	&"idle": true,
	&"sitting": true,
	&"turn_left": true,
	&"turn_right": true,
	&"come_closer": true,
	&"action": true,
	&"falling": true,
	&"landing": true,
	&"dancing": true,
}

@export_category("Sprite Sheets")
@export var climbing_down_texture: Texture2D
@export var climbing_start_texture: Texture2D
@export var climbing_up_texture: Texture2D
@export var dancing_texture: Texture2D
@export var come_closer_texture: Texture2D
@export var falling_texture: Texture2D
@export var hanging_texture: Texture2D
@export var sitting_texture: Texture2D
@export var idle_texture: Texture2D
@export var landing_texture: Texture2D
@export var turn_left_texture: Texture2D
@export var turn_right_texture: Texture2D
@export var walking_left_stop_texture: Texture2D
@export var walking_right_stop_texture: Texture2D
@export var walking_left_texture: Texture2D
@export var walking_right_texture: Texture2D
@export var walking_left_start_texture: Texture2D
@export var walking_start_right_texture: Texture2D
@export var action_texture: Texture2D
@export var climbing_action_start_texture: Texture2D
@export var climbing_action_stop_texture: Texture2D
@export var climbing_action_texture: Texture2D

@export_category("Playback")
@export_enum(
	"climbing_down",
	"climbing_start",
	"climbing_up",
	"dancing",
	"come_closer",
	"falling",
	"hanging",
	"sitting",
	"idle",
	"landing",
	"turn_left",
	"turn_right",
	"walking_left_stop",
	"walking_right_stop",
	"walking_left",
	"walking_right",
	"walking_left_start",
	"walking_start_right",
	"action",
	"climbing_action_start",
	"climbing_action_stop",
	"climbing_action"
) var initial_animation := "idle"
@export var autoplay_on_ready := true
@export_range(0.1, 4.0, 0.05) var playback_speed_scale := 1.0
@export var return_to_sitting_after_one_shot := false

@export_category("Composite Action")
@export_range(1.0, 4.0, 0.05) var approach_visual_scale := 2.0
@export_range(0.1, 1.0, 0.05) var approach_scale_completion_ratio := 0.75
@export_range(0.0, 1.0, 0.01) var approach_hold_seconds := 0.15
@export_range(32.0, 1024.0, 1.0) var falling_distance_per_cycle := 320.0
@export_range(0.0, 512.0, 1.0) var vertical_wrap_margin := 192.0

@onready var _visual_root: Node2D = $VisualRoot
@onready var _sprite: AnimatedSprite2D = $VisualRoot/Sprite

var _sprite_base_position := Vector2.ZERO
var _facing: StringName = FACING_FRONT
var _composite_run_id := 0
var _composite_action: StringName = &""
var _composite_runtime: Object


func _ready() -> void:
	_sprite_base_position = _sprite.position
	_build_sprite_frames()
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)
	if autoplay_on_ready:
		play_pet_animation(StringName(initial_animation))


func get_pet_animation_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for animation_name in ANIMATION_NAMES:
		result.append(animation_name)
	return result


func get_pet_action_animation(action_name: StringName) -> StringName:
	return StringName(ACTION_ANIMATIONS.get(action_name, &""))


func get_pet_animation_frame_count(animation_name: StringName) -> int:
	return int(ANIMATION_FRAME_COUNTS.get(animation_name, 0))


func has_pet_animation(animation_name: StringName) -> bool:
	return (
		is_instance_valid(_sprite)
		and _sprite.sprite_frames != null
		and _sprite.sprite_frames.has_animation(animation_name)
	)


func play_pet_animation(animation_name: StringName, restart := true) -> bool:
	if not has_pet_animation(animation_name):
		push_warning("Unknown interactive pet animation: %s" % animation_name)
		return false
	_apply_animation_visual_offset(animation_name)
	if restart:
		_sprite.set_frame_and_progress(0, 0.0)
	_sprite.speed_scale = playback_speed_scale
	_sprite.play(animation_name)
	_remember_animation_facing(animation_name)
	pet_animation_started.emit(animation_name)
	return true


func pause_pet_animation() -> void:
	if is_instance_valid(_sprite):
		_sprite.pause()


func stop_pet_animation() -> void:
	if is_instance_valid(_sprite):
		_sprite.stop()


func get_current_pet_animation() -> StringName:
	if not is_instance_valid(_sprite):
		return &""
	return _sprite.animation


func get_current_pet_frame() -> int:
	if not is_instance_valid(_sprite):
		return -1
	return _sprite.frame


func is_pet_animation_looping(animation_name: StringName) -> bool:
	return (
		is_instance_valid(_sprite)
		and _sprite.sprite_frames != null
		and _sprite.sprite_frames.has_animation(animation_name)
		and _sprite.sprite_frames.get_animation_loop(animation_name)
	)


func get_pet_animation_frames_per_second(animation_name: StringName) -> float:
	if not has_pet_animation(animation_name):
		return 0.0
	return _sprite.sprite_frames.get_animation_speed(animation_name) * playback_speed_scale


func get_pet_preview_size() -> Vector2:
	return Vector2(FRAME_SIZE)


func has_pet_composite_action(action_name: StringName) -> bool:
	return action_name == COMPOSITE_INTERACT


func start_pet_composite_action(
	action_name: StringName,
	runtime: Object,
	parameters: Dictionary
) -> int:
	if not has_pet_composite_action(action_name) or not _is_valid_runtime(runtime):
		return 0
	if _composite_run_id != 0:
		cancel_pet_composite_action(_composite_run_id, &"replaced")

	var run_id := int(runtime.call(&"GetRunId"))
	if run_id <= 0:
		return 0
	_composite_run_id = run_id
	_composite_action = action_name
	_composite_runtime = runtime
	pet_composite_action_started.emit(action_name, run_id)
	call_deferred(&"_run_interact_composite", run_id, runtime, parameters.duplicate(true))
	return run_id


func cancel_pet_composite_action(run_id: int, _reason: StringName) -> void:
	if run_id != _composite_run_id:
		return
	_finish_composite_action(run_id, false, false)


func get_pet_runtime_scale() -> float:
	return RUNTIME_SCALE


func get_pet_walk_speed() -> float:
	return WALK_SPEED


func get_pet_climb_speed() -> float:
	return CLIMB_SPEED


func get_pet_hit_size() -> Vector2:
	return HIT_SIZE


func get_pet_ground_offset() -> Vector2:
	return GROUND_OFFSET


func get_pet_animation_visual_offset(animation_name: StringName) -> Vector2:
	if not ANIMATION_NAMES.has(animation_name):
		return Vector2.ZERO
	if animation_name == &"sitting":
		return SITTING_VISUAL_OFFSET
	return NON_SITTING_VISUAL_OFFSET


func get_pet_visual_offset() -> Vector2:
	if not is_instance_valid(_sprite):
		return Vector2.ZERO
	return _sprite.position - _sprite_base_position


func _apply_animation_visual_offset(animation_name: StringName) -> void:
	_sprite.position = _sprite_base_position + get_pet_animation_visual_offset(animation_name)


func _run_interact_composite(run_id: int, runtime: Object, parameters: Dictionary) -> void:
	var suspended_policy := {
		"navigation": "suspended",
		"support_contacts": "ignore",
		"screen_bounds": "allow",
		"input_enabled": false,
	}
	if not bool(runtime.call(&"SetMotionPolicy", suspended_policy)):
		_finish_composite_action(run_id, false)
		return

	var turn_animation := _turn_animation_for_facing()
	if turn_animation != &"" and not await _play_animation_cycles(
		turn_animation,
		1,
		run_id,
		runtime
	):
		return

	var reduced_effects := bool(parameters.get("reduced_effects", false))
	if not reduced_effects and not await _play_animation_with_visual_scale(
		&"come_closer",
		1.0,
		approach_visual_scale,
		run_id,
		runtime
	):
		return

	var action_repetitions := clampi(int(parameters.get("action_repetitions", 3)), 1, 16)
	if not await _play_animation_cycles(&"action", action_repetitions, run_id, runtime):
		return

	if not reduced_effects and not await _play_wrapped_fall(run_id, runtime):
		return
	if not await _play_animation_cycles(&"landing", 1, run_id, runtime):
		return
	if not _is_composite_active(run_id, runtime):
		return
	play_pet_animation(&"idle")
	_finish_composite_action(run_id, true)


func _play_wrapped_fall(run_id: int, runtime: Object) -> bool:
	var support_value: Variant = runtime.call(&"GetHighestSupport")
	if not support_value is Dictionary:
		_finish_composite_action(run_id, false)
		return false
	var support := support_value as Dictionary
	if not bool(support.get("accepted", false)) or not bool(support.get("valid", false)):
		_finish_composite_action(run_id, false)
		return false

	var viewport := runtime.call(&"GetViewportRect") as Rect2
	var start_anchor := runtime.call(&"GetAnchor") as Vector2
	var target_anchor := support.get("anchor", Vector2.ZERO) as Vector2
	var target_surface_id := String(support.get("surface_id", ""))
	if viewport.size.x <= 0.0 or viewport.size.y <= 0.0 or target_surface_id.is_empty():
		_finish_composite_action(run_id, false)
		return false

	var first_leg := maxf(0.0, viewport.end.y + vertical_wrap_margin - start_anchor.y)
	var second_leg := maxf(0.0, target_anchor.y - (viewport.position.y - vertical_wrap_margin))
	var total_distance := maxf(1.0, first_leg + second_leg)
	var calculated_cycles := maxi(1, ceili(total_distance / falling_distance_per_cycle))
	var cycle_seconds := _animation_cycle_seconds(&"falling")
	if cycle_seconds <= 0.0:
		_finish_composite_action(run_id, false)
		return false
	var total_seconds := float(calculated_cycles) * cycle_seconds
	var fall_speed := total_distance / total_seconds
	var falling_policy := {
		"navigation": "theme_driven",
		"support_contacts": "after_vertical_wrap",
		"screen_bounds": "wrap_vertical_once",
		"input_enabled": false,
		"landing_surface_id": target_surface_id,
		"wrap_margin": vertical_wrap_margin,
	}
	if not bool(runtime.call(&"SetMotionPolicy", falling_policy)):
		_finish_composite_action(run_id, false)
		return false
	if not play_pet_animation(&"falling"):
		_finish_composite_action(run_id, false)
		return false

	var elapsed := 0.0
	var wrapped := false
	var landed := false
	while elapsed < total_seconds and not landed:
		await get_tree().process_frame
		if not _is_composite_active(run_id, runtime):
			return false
		var delta := minf(get_process_delta_time(), total_seconds - elapsed)
		elapsed += delta
		var move_value: Variant = runtime.call(&"MoveAnchor", Vector2.DOWN * fall_speed * delta)
		if not move_value is Dictionary:
			_finish_composite_action(run_id, false)
			return false
		var move_result := move_value as Dictionary
		if not bool(move_result.get("accepted", false)):
			_finish_composite_action(run_id, false)
			return false
		if bool(move_result.get("wrapped", false)):
			wrapped = true
			var wrapped_anchor := move_result.get("anchor", Vector2.ZERO) as Vector2
			wrapped_anchor.x = target_anchor.x
			runtime.call(&"SetAnchor", wrapped_anchor)
			_visual_root.scale = Vector2.ONE
		landed = bool(move_result.get("landed", false))

	if not wrapped:
		_finish_composite_action(run_id, false)
		return false
	if not landed:
		var landing_value: Variant = runtime.call(&"LandOnSupport", target_surface_id)
		if not landing_value is Dictionary or not bool(
			(landing_value as Dictionary).get("landed", false)
		):
			_finish_composite_action(run_id, false)
			return false
	return true


func _play_animation_with_visual_scale(
	animation_name: StringName,
	from_scale: float,
	to_scale: float,
	run_id: int,
	runtime: Object
) -> bool:
	if not play_pet_animation(animation_name):
		_finish_composite_action(run_id, false)
		return false
	var duration := _animation_cycle_seconds(animation_name)
	if duration <= 0.0:
		_finish_composite_action(run_id, false)
		return false
	var frames_per_second := get_pet_animation_frames_per_second(animation_name)
	var final_frame_duration := 1.0 / frames_per_second
	var scale_duration := clampf(
		duration * approach_scale_completion_ratio,
		final_frame_duration,
		duration
	)
	var elapsed := 0.0
	_visual_root.scale = Vector2.ONE * from_scale
	while elapsed < duration:
		await get_tree().process_frame
		if not _is_composite_active(run_id, runtime):
			return false
		elapsed = minf(duration, elapsed + get_process_delta_time())
		# Finish the zoom before the clip ends. Its closing frames therefore
		# establish the final size instead of changing size at the action cut.
		var weight := minf(1.0, elapsed / scale_duration)
		_visual_root.scale = Vector2.ONE * lerpf(from_scale, to_scale, weight)
	_visual_root.scale = Vector2.ONE * to_scale
	var hold_elapsed := 0.0
	while hold_elapsed < approach_hold_seconds:
		await get_tree().process_frame
		if not _is_composite_active(run_id, runtime):
			return false
		hold_elapsed += get_process_delta_time()
	return true


func _play_animation_cycles(
	animation_name: StringName,
	cycles: int,
	run_id: int,
	runtime: Object
) -> bool:
	var cycle_seconds := _animation_cycle_seconds(animation_name)
	if cycle_seconds <= 0.0:
		_finish_composite_action(run_id, false)
		return false
	for _cycle in maxi(1, cycles):
		if not play_pet_animation(animation_name):
			_finish_composite_action(run_id, false)
			return false
		var elapsed := 0.0
		while elapsed < cycle_seconds:
			await get_tree().process_frame
			if not _is_composite_active(run_id, runtime):
				return false
			elapsed += get_process_delta_time()
	return true


func _animation_cycle_seconds(animation_name: StringName) -> float:
	var frame_count := get_pet_animation_frame_count(animation_name)
	var frames_per_second := get_pet_animation_frames_per_second(animation_name)
	if frame_count <= 0 or frames_per_second <= 0.0:
		return 0.0
	return float(frame_count) / frames_per_second


func _turn_animation_for_facing() -> StringName:
	match _facing:
		FACING_LEFT:
			return &"turn_left"
		FACING_RIGHT:
			return &"turn_right"
	return &""


func _remember_animation_facing(animation_name: StringName) -> void:
	if LEFT_FACING_ANIMATIONS.has(animation_name):
		_facing = FACING_LEFT
	elif RIGHT_FACING_ANIMATIONS.has(animation_name):
		_facing = FACING_RIGHT
	elif FRONT_FACING_ANIMATIONS.has(animation_name):
		_facing = FACING_FRONT


func _is_valid_runtime(runtime: Object) -> bool:
	if runtime == null:
		return false
	for method_name in [
		&"GetRunId",
		&"IsActive",
		&"GetViewportRect",
		&"GetAnchor",
		&"GetHighestSupport",
		&"SetMotionPolicy",
		&"SetAnchor",
		&"MoveAnchor",
		&"LandOnSupport",
	]:
		if not runtime.has_method(method_name):
			return false
	return true


func _is_composite_active(run_id: int, runtime: Object) -> bool:
	return (
		run_id == _composite_run_id
		and runtime == _composite_runtime
		and is_instance_valid(runtime)
		and bool(runtime.call(&"IsActive"))
	)


func _finish_composite_action(run_id: int, completed: bool, emit_finished := true) -> void:
	if run_id != _composite_run_id:
		return
	var action_name := _composite_action
	_composite_run_id = 0
	_composite_action = &""
	_composite_runtime = null
	if is_instance_valid(_visual_root):
		_visual_root.scale = Vector2.ONE
	if emit_finished:
		pet_composite_action_finished.emit(action_name, run_id, completed)


func _build_sprite_frames() -> void:
	var generated_frames := SpriteFrames.new()
	generated_frames.remove_animation(&"default")

	for animation_name in ANIMATION_NAMES:
		var texture := _texture_for(animation_name)
		if texture == null:
			continue
		var columns := floori(float(texture.get_width()) / float(FRAME_SIZE.x))
		var frame_count := int(ANIMATION_FRAME_COUNTS[animation_name])
		generated_frames.add_animation(animation_name)
		generated_frames.set_animation_speed(
			animation_name,
			float(ANIMATION_SPEEDS[animation_name])
		)
		generated_frames.set_animation_loop(
			animation_name,
			not ONE_SHOT_ANIMATIONS.has(animation_name)
		)

		for frame_index in frame_count:
			var atlas_frame := AtlasTexture.new()
			atlas_frame.atlas = texture
			atlas_frame.region = Rect2(
				float(frame_index % columns) * FRAME_SIZE.x,
				float(floori(float(frame_index) / float(columns))) * FRAME_SIZE.y,
				FRAME_SIZE.x,
				FRAME_SIZE.y
			)
			atlas_frame.filter_clip = true
			generated_frames.add_frame(animation_name, atlas_frame)

	_sprite.sprite_frames = generated_frames


func _texture_for(animation_name: StringName) -> Texture2D:
	match animation_name:
		&"climbing_down":
			return climbing_down_texture
		&"climbing_start":
			return climbing_start_texture
		&"climbing_up":
			return climbing_up_texture
		&"dancing":
			return dancing_texture
		&"come_closer":
			return come_closer_texture
		&"falling":
			return falling_texture
		&"hanging":
			return hanging_texture
		&"sitting":
			return sitting_texture
		&"idle":
			return idle_texture
		&"landing":
			return landing_texture
		&"turn_left":
			return turn_left_texture
		&"turn_right":
			return turn_right_texture
		&"walking_left_stop":
			return walking_left_stop_texture
		&"walking_right_stop":
			return walking_right_stop_texture
		&"walking_left":
			return walking_left_texture
		&"walking_right":
			return walking_right_texture
		&"walking_left_start":
			return walking_left_start_texture
		&"walking_start_right":
			return walking_start_right_texture
		&"action":
			return action_texture
		&"climbing_action_start":
			return climbing_action_start_texture
		&"climbing_action_stop":
			return climbing_action_stop_texture
		&"climbing_action":
			return climbing_action_texture
	return null


func _on_animation_finished() -> void:
	var completed_animation := _sprite.animation
	pet_animation_completed.emit(completed_animation)
	if return_to_sitting_after_one_shot and ONE_SHOT_ANIMATIONS.has(completed_animation):
		play_pet_animation(&"sitting")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for animation_name in ANIMATION_NAMES:
		var texture := _texture_for(animation_name)
		if texture == null:
			warnings.append("Missing sprite sheet for %s." % animation_name)
			continue
		if texture.get_width() % FRAME_SIZE.x != 0 or texture.get_height() % FRAME_SIZE.y != 0:
			warnings.append("Sprite sheet %s is not aligned to 128x128 cells." % animation_name)
			continue
		var available_frames := floori(float(texture.get_width()) / float(FRAME_SIZE.x)) * floori(
			float(texture.get_height()) / float(FRAME_SIZE.y)
		)
		if int(ANIMATION_FRAME_COUNTS[animation_name]) > available_frames:
			warnings.append("Sprite sheet %s does not contain all declared frames." % animation_name)
	return warnings
