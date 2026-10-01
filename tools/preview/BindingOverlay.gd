extends Control

const ELEMENT_META_KEY := &"exchanger_binding_id"
const SCREEN_META_KEY := &"exchanger_screen_binding_id"
const LABEL_FONT_SIZE := 10
const LABEL_HEIGHT := 22.0
const LABEL_PADDING := 5.0

var target: Node


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)


func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    if target == null or not is_instance_valid(target):
        return
    for node in _all_nodes(target):
        if (not node.has_meta(ELEMENT_META_KEY) and not node.has_meta(SCREEN_META_KEY)) or not node is CanvasItem:
            continue
        var canvas_item := node as CanvasItem
        if not canvas_item.is_visible_in_tree():
            continue
        var binding_id := str(
            node.get_meta(ELEMENT_META_KEY)
            if node.has_meta(ELEMENT_META_KEY)
            else node.get_meta(SCREEN_META_KEY)
        )
        var bounds := _bounds_for(canvas_item)
        draw_rect(bounds, Color(1.0, 0.72, 0.08, 0.92), false, 2.0)
        var label_width := minf(size.x - 8.0, maxf(80.0, binding_id.length() * 6.0 + LABEL_PADDING * 2.0))
        var label_rect := Rect2(bounds.position, Vector2(label_width, LABEL_HEIGHT))
        label_rect.position.x = clampf(label_rect.position.x, 4.0, size.x - label_width - 4.0)
        if label_rect.position.y < 28.0:
            label_rect.position.y = bounds.end.y
        draw_rect(label_rect, Color(0.02, 0.06, 0.14, 0.94), true)
        draw_rect(label_rect, Color(1.0, 0.72, 0.08, 1.0), false, 1.0)
        draw_string(
            ThemeDB.fallback_font,
            label_rect.position + Vector2(LABEL_PADDING, 16.0),
            binding_id,
            HORIZONTAL_ALIGNMENT_LEFT,
            label_width - LABEL_PADDING * 2.0,
            LABEL_FONT_SIZE,
            Color.WHITE
        )


func _bounds_for(item: CanvasItem) -> Rect2:
    var inverse := get_global_transform().affine_inverse()
    if item is Control:
        var control := item as Control
        var top_left := inverse * control.get_global_transform_with_canvas() * Vector2.ZERO
        var bottom_right := inverse * control.get_global_transform_with_canvas() * control.size
        return Rect2(top_left, bottom_right - top_left).abs()
    if item is Node2D:
        var point := inverse * (item as Node2D).get_global_transform_with_canvas().origin
        return Rect2(point - Vector2(8.0, 8.0), Vector2(16.0, 16.0))
    return Rect2(Vector2.ZERO, Vector2(16.0, 16.0))


func _all_nodes(root: Node) -> Array[Node]:
    var result: Array[Node] = [root]
    var cursor := 0
    while cursor < result.size():
        var current := result[cursor]
        for child in current.get_children():
            result.append(child)
        cursor += 1
    return result
