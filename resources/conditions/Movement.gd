extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Movement.txt.

const OPERATOR_LIST: Array[String] = ["Is Moving", "Is Not Moving"]

@export var target: int = 1
@export var operator: int = 1

func _get_uid() -> String:
	return "Movement"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	if not agent:
		return false
	var moving: bool = Context.is_moving(agent)
	return moving if operator == 1 else not moving

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	add_combo(row, 150, OPERATOR_LIST, &"operator")
	return row
