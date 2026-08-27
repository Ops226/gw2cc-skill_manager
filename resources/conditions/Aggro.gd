extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Aggro.txt.

const OPERATOR_LIST: Array[String] = ["has Aggro", "has no Aggro"]

@export var target: int = 1
@export var operator: int = 1

func _get_uid() -> String:
	return "Aggro"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	var has_aggro: bool = Context.has_aggro(agent)
	return has_aggro if operator == 1 else not has_aggro

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	add_combo(row, 100, OPERATOR_LIST, &"operator")
	return row
