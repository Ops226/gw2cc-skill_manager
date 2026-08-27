extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_TransformID.txt. The value is a
## [enum SkillConstants.ProfessionState].

@export var value: int = 1

func _get_uid() -> String:
	return "Transform ID"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	if not context.player:
		return false
	return context.transformid == value

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Transform ID is ")
	add_int(row, 100, &"value", 1, 0)
	return row
