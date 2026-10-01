extends Control

@export_range(0.0, 20.0, 1.0) var left_amplitude := 4.0
@export_range(0.0, 20.0, 1.0) var right_amplitude := 5.0
@export_range(0.5, 10.0, 0.1) var left_period := 3.2
@export_range(0.5, 10.0, 0.1) var right_period := 3.8

@onready var _left: TextureRect = $AlienLeft
@onready var _right: TextureRect = $CustomTextBlock/AlienRight

var _left_base_position := Vector2.ZERO
var _right_base_position := Vector2.ZERO
var _elapsed := 0.0


func _ready() -> void:
	_left_base_position = _left.position
	_right_base_position = _right.position


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, maxf(left_period, right_period) * 10.0)
	_apply_bob(_left, _left_base_position, left_amplitude, left_period, 0.0)
	_apply_bob(_right, _right_base_position, right_amplitude, right_period, PI)


func _apply_bob(
	sprite: TextureRect,
	base_position: Vector2,
	amplitude: float,
	period: float,
	phase: float
) -> void:
	# Округление сохраняет чёткие пиксельные края при Nearest-фильтрации.
	var offset_y := roundf(sin(_elapsed * TAU / period + phase) * amplitude)
	sprite.position = base_position + Vector2(0.0, offset_y)
	sprite.set_meta("bob_offset_y", offset_y)
