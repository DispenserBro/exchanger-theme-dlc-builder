@tool
extends Label

@export_enum("price", "support") var format_mode := "price"


func _process(_delta: float) -> void:
	var formatted := _format_text(text)
	if formatted != text:
		text = formatted


func _format_text(value: String) -> String:
	if format_mode == "support":
		var lines := value.split("\n")
		if lines.size() < 2:
			return value
		var heading := lines[0].replace(" ", "").trim_suffix(":").to_upper()
		if heading != "ТЕХПОДДЕРЖКА":
			return value
		return "ТЕХ ПОДДЕРЖКА:\n" + "\n".join(lines.slice(1))

	var upper := value.strip_edges().to_upper()
	var amount := value.strip_edges()
	for suffix in [" РУБ.", " ₽", " Р"]:
		if upper.ends_with(suffix):
			amount = amount.left(amount.length() - suffix.length()).strip_edges()
			break
	if amount.is_valid_int():
		return "%s руб." % amount
	return value
