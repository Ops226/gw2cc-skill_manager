extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_ContentID.txt.

const OPERATOR_LIST: Array[String] = ["==", "!="]

@export var operator: int = 1
@export var value: int = 1

func _get_uid() -> String:
	return "ContentID"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var target: Agent = context.attack_target
	if not target:
		return false
	var content: int = Context.content_id(target)
	return content == value if operator == 1 else content != value

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Target's Content ID is")
	add_combo(row, 50, OPERATOR_LIST, &"operator")
	add_int(row, 120, &"value", 1, 0)
	return row
