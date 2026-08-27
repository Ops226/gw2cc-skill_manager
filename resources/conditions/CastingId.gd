extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Casting_ID.txt.

@export var target: int = 1
@export var skillid: int = 1

func _get_uid() -> String:
	return "Casting (ID)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	if not agent:
		return false
	return Context.casting_id(agent) == skillid

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	add_label(row, "is casting Skill ID ")
	add_int(row, 150, &"skillid", 1, 0)
	return row
