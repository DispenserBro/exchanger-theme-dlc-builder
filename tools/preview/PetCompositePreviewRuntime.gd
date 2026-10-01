class_name PetCompositePreviewRuntime
extends RefCounted

signal anchor_changed(anchor: Vector2)

var _run_id: int
var _viewport_rect: Rect2
var _anchor: Vector2
var _support_id: String
var _support_anchor: Vector2
var _active := true
var _support_contacts := "solid"
var _screen_bounds := "clamp"
var _landing_surface_id := ""
var _wrap_margin := 0.0
var _wrapped := false


func _init(
	run_id: int,
	viewport_rect: Rect2,
	anchor: Vector2,
	support_id: String,
	support_anchor: Vector2
) -> void:
	_run_id = run_id
	_viewport_rect = viewport_rect
	_anchor = anchor
	_support_id = support_id
	_support_anchor = support_anchor


func GetRunId() -> int:
	return _run_id


func IsActive() -> bool:
	return _active


func GetViewportRect() -> Rect2:
	return _viewport_rect


func GetAnchor() -> Vector2:
	return _anchor


func GetHighestSupport() -> Dictionary:
	return {
		"accepted": _active,
		"valid": _active,
		"surface_id": _support_id,
		"anchor": _support_anchor,
	}


func SetMotionPolicy(policy: Dictionary) -> bool:
	if not _active:
		return false
	_support_contacts = str(policy.get("support_contacts", _support_contacts))
	_screen_bounds = str(policy.get("screen_bounds", _screen_bounds))
	_landing_surface_id = str(policy.get("landing_surface_id", ""))
	_wrap_margin = maxf(0.0, float(policy.get("wrap_margin", 0.0)))
	if _screen_bounds == "wrap_vertical_once":
		_wrapped = false
	return true


func SetAnchor(anchor: Vector2) -> Dictionary:
	if not _active:
		return {"accepted": false}
	_anchor = anchor
	anchor_changed.emit(_anchor)
	return {"accepted": true, "anchor": _anchor}


func MoveAnchor(delta: Vector2) -> Dictionary:
	if not _active:
		return {"accepted": false}

	var previous := _anchor
	var next := previous + delta
	var wrapped_now := false
	if (
		_screen_bounds == "wrap_vertical_once"
		and not _wrapped
		and next.y > _viewport_rect.end.y + _wrap_margin
	):
		var overflow := next.y - (_viewport_rect.end.y + _wrap_margin)
		next.y = _viewport_rect.position.y - _wrap_margin + overflow
		_wrapped = true
		wrapped_now = true

	var landed := false
	if (
		_support_contacts == "after_vertical_wrap"
		and _wrapped
		and _landing_surface_id == _support_id
		and delta.y >= 0.0
		and previous.y <= _support_anchor.y
		and next.y >= _support_anchor.y
	):
		next = _support_anchor
		landed = true

	_anchor = next
	anchor_changed.emit(_anchor)
	return {
		"accepted": true,
		"anchor": _anchor,
		"wrapped": wrapped_now,
		"landed": landed,
		"surface_id": _support_id if landed else "",
	}


func LandOnSupport(surface_id: String) -> Dictionary:
	if not _active or surface_id != _support_id:
		return {"accepted": _active, "landed": false}
	_anchor = _support_anchor
	anchor_changed.emit(_anchor)
	return {
		"accepted": true,
		"landed": true,
		"anchor": _anchor,
		"surface_id": _support_id,
	}


func invalidate() -> void:
	_active = false
