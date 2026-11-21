extends Control

## The drag handle in a window's bottom right corner. A borderless window has
## no edges to grab, so this is the one place it can be resized from. Same
## mechanics as DraggableTitleBar: screen-space delta from the press, applied
## to the window, never below its minimum size.

const GRIP_SIZE := 16
const GRIP_COLOR := Color(1.0, 1.0, 1.0, 0.35)

## The window this grip resizes. Set before the grip enters the tree.
var window: Window = null

var _dragging: bool = false
var _start_mouse: Vector2i = Vector2i.ZERO
var _start_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(GRIP_SIZE, GRIP_SIZE)
	mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Drag to resize"


func _draw() -> void:
	# Three short diagonals, the usual corner grip.
	var edge: float = size.x
	for step: float in [4.0, 8.0, 12.0]:
		draw_line(Vector2(edge - step, edge), Vector2(edge, edge - step), GRIP_COLOR, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_start_mouse = DisplayServer.mouse_get_position()
			_start_size = window.size if window else Vector2i.ZERO
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging or event is not InputEventMouseMotion or not window:
		return
	var delta: Vector2i = DisplayServer.mouse_get_position() - _start_mouse
	var wanted: Vector2i = _start_size + delta
	var floor_size: Vector2i = window.min_size
	window.size = Vector2i(maxi(wanted.x, floor_size.x), maxi(wanted.y, floor_size.y))
	get_viewport().set_input_as_handled()
