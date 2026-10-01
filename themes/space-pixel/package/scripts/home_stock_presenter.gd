@tool
extends Control

const STOCK_MANY := preload("../assets/ui/stock_many.png")
const STOCK_LOW := preload("../assets/ui/stock_low.png")

@onready var _state: Label = $StockPanel/Margin/Content/State
@onready var _meter: TextureRect = $StockPanel/Margin/Content/Meter


func _process(_delta: float) -> void:
	if not is_instance_valid(_state) or not is_instance_valid(_meter):
		return

	var raw := _state.text.strip_edges().to_upper()
	if raw.begins_with("МНОГО"):
		_apply_state("МНОГО", STOCK_MANY, true)
	elif raw.begins_with("МАЛО"):
		_apply_state("МАЛО", STOCK_LOW, true)
	elif raw.contains("НЕТ ДАННЫХ"):
		_apply_state("НЕТ ДАННЫХ", null, false)


func _apply_state(caption: String, texture: Texture2D, show_meter: bool) -> void:
	if _state.text != caption:
		_state.text = caption
	if _meter.texture != texture:
		_meter.texture = texture
	if _meter.visible != show_meter:
		_meter.visible = show_meter
