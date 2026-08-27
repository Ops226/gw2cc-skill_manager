extends VBoxContainer

## A titled section that folds away, the stand-in for the ImGui TreeNode the
## original used for the two code editors and for each condition group.

signal toggled_open(is_open: bool)

var _header: Button = null
var _body: VBoxContainer = null
var _title: String = ""


func setup(title: String, tip: String = "", start_open: bool = false) -> void:
	_title = title
	add_theme_constant_override("separation", 2)

	_header = Button.new()
	_header.toggle_mode = true
	_header.button_pressed = start_open
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.tooltip_text = tip
	_header.toggled.connect(_on_toggled)
	add_child(_header)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.visible = start_open
	add_child(_body)

	_update_header()


func body() -> VBoxContainer:
	return _body


func is_open() -> bool:
	return _header != null and _header.button_pressed


func set_open(value: bool) -> void:
	if _header:
		_header.button_pressed = value


func _on_toggled(pressed: bool) -> void:
	_body.visible = pressed
	_update_header()
	toggled_open.emit(pressed)


func _update_header() -> void:
	_header.text = ("v  " if is_open() else ">  ") + _title
