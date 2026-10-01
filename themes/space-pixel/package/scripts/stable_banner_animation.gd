extends AnimatedSprite2D

# Непрозрачная цветная область исходных кадров:
# frame_01: Rect2(0, 28, 263, 167)
# frame_02: Rect2(0, 39, 257, 163)
# Второй кадр масштабируется и сдвигается относительно центра 1024x256 так,
# чтобы обе области занимали одинаковые экранные границы.
@export var second_frame_scale_factor := Vector2(263.0 / 257.0, 167.0 / 163.0)
@export var second_frame_local_offset := Vector2(11.953307, -8.815951)

var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE


func _ready() -> void:
	_base_position = position
	_base_scale = scale
	frame_changed.connect(_apply_frame_compensation)
	_apply_frame_compensation()


func _apply_frame_compensation() -> void:
	if frame == 1:
		scale = _base_scale * second_frame_scale_factor
		position = _base_position + second_frame_local_offset * _base_scale
	else:
		scale = _base_scale
		position = _base_position

	set_meta("normalized_frame", frame)
