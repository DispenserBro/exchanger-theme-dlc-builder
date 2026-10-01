extends Node2D

## Пример runtime-скрипта доверенной темы. Он прикреплён к общей decoration-сцене,
## но выключен по умолчанию, чтобы шаблон оставался визуально нейтральным.
@export var animation_enabled := false
@export_range(0.0, 200.0, 0.5) var vertical_amplitude := 12.0
@export_range(0.01, 10.0, 0.01) var cycles_per_second := 0.25

var _origin := Vector2.ZERO
var _phase := 0.0


func _ready() -> void:
    _origin = position
    set_process(animation_enabled)


func _process(delta: float) -> void:
    _phase = fmod(_phase + delta * cycles_per_second, 1.0)
    position = _origin + Vector2(0.0, sin(_phase * TAU) * vertical_amplitude)
