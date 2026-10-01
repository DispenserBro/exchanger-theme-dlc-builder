extends Node2D

@export_range(0.0, 1920.0, 1.0) var min_flight_height := 260.0
@export_range(0.0, 1920.0, 1.0) var max_flight_height := 1660.0
@export_range(0.0, 10.0, 0.1) var min_edge_pause := 1.0
@export_range(0.0, 10.0, 0.1) var max_edge_pause := 3.0
@export_range(1.0, 1000.0, 1.0) var large_speed := 470.0
@export_range(1.0, 1000.0, 1.0) var small_speed := 437.0
@export_range(0.0, 30.0, 0.1) var small_initial_delay := 5.5

@onready var _large: AnimatedSprite2D = $UfoLarge
@onready var _small: AnimatedSprite2D = $UfoSmall

var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_fly_forever(_large, -380.0, 1500.0, large_speed, 0.0)
	_fly_forever(_small, -160.0, 1260.0, small_speed, small_initial_delay)


func _fly_forever(
	sprite: AnimatedSprite2D,
	left_edge: float,
	right_edge: float,
	speed: float,
	initial_delay: float
) -> void:
	var direction := 1
	_place_for_next_pass(sprite, left_edge, direction)

	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay).timeout

	while is_inside_tree() and is_instance_valid(sprite):
		var target_x := right_edge if direction > 0 else left_edge
		var duration := absf(target_x - sprite.position.x) / speed
		var flight := create_tween().set_trans(Tween.TRANS_LINEAR)
		flight.tween_property(sprite, "position:x", target_x, duration)
		await flight.finished

		if not is_inside_tree() or not is_instance_valid(sprite):
			return

		await get_tree().create_timer(
			_random.randf_range(min_edge_pause, max_edge_pause)
		).timeout

		direction *= -1
		_place_for_next_pass(sprite, target_x, direction)


func _place_for_next_pass(
	sprite: AnimatedSprite2D,
	edge_x: float,
	direction: int
) -> void:
	# Шаг 3 px сохраняет целочисленную высоту после масштаба production-сцен 2/3.
	var random_height := snappedf(
		_random.randf_range(min_flight_height, max_flight_height),
		3.0
	)
	sprite.position = Vector2(edge_x, random_height)
	sprite.flip_h = direction < 0
	sprite.set_meta("flight_direction", direction)
	sprite.set_meta("flight_height", random_height)
