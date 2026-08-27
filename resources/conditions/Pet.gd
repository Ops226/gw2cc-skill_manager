extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Pet.txt.

const OPERATOR_LIST: Array[String] = ["a Pet", "Not a Pet"]

@export var target: int = 1
@export var operator: int = 1

func _get_uid() -> String:
	return "Pet"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_PTF)
	if not agent:
		return false
	var pet: bool = Context.is_pet(agent)
	return pet if operator == 1 else not pet

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_PTF, &"target")
	add_combo(row, 150, OPERATOR_LIST, &"operator")
	return row
