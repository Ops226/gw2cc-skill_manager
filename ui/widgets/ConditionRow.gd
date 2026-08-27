extends HBoxContainer

## Hosts one condition's own editor plus the two-click delete button, the port of
## the per-condition block in `sm_skill:RenderConditionEditor`
## (sm_skill.lua:503-536).

const Style := preload("res://plugins/skill_manager/ui/Style.gd")

const DELETE_ICON := preload("res://plugins/skill_manager/assets/delete.svg")
const DELETE_SIZE := Style.ICON_SMALL

signal changed()
signal deleted()
## Raised on the first click of the two-click delete, so the editor can clear the
## arming of any other row.
signal armed()

var condition: Resource = null

var _delete: Button = null
var _armed: bool = false


func setup(new_condition: Resource) -> void:
	condition = new_condition
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var editor: Control = condition.build_editor()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(editor)
	condition.changed.connect(func() -> void: changed.emit())

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	_delete = Style.icon_button(DELETE_ICON, DELETE_SIZE, "Delete this Condition.")
	_delete.pressed.connect(_on_delete)
	add_child(_delete)


## First click arms and turns the button amber, the second commits. The original
## did the same rather than opening a confirmation dialog.
func _on_delete() -> void:
	if not _armed:
		_armed = true
		Style.tint(_delete, Style.ARMED, Style.ARMED_HOVER, Style.ARMED_ACTIVE)
		armed.emit()
		return
	deleted.emit()


func disarm() -> void:
	if not _armed:
		return
	_armed = false
	Style.untint(_delete)
