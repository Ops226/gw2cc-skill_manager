extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_LastTransformID.txt.
##
## The Lua read the *current* transform here, which made this an exact duplicate
## of Transform ID. Fixed to read the previous one, which is what the name and
## the weaver rotations that used it always meant.

@export var value: int = 1

func _get_uid() -> String:
	return "Last Transform ID"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	if not context.player:
		return false
	return context.lasttransformid == value

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Last Transform ID is ")
	add_int(row, 100, &"value", 1, 0)
	return row
