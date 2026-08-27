extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Buff_ID.txt.

const OPERATOR_LIST: Array[String] = ["has Buff ID", "has not Buff ID"]

@export var target: int = 1
@export var operator: int = 1
@export var buffid: int = 743

func _get_uid() -> String:
	return "Buff (ID)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	var present: bool = agent != null and AgentUtils.has_buff_by_id(agent, buffid)
	return present if operator == 1 else not present

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	add_combo(row, 175, OPERATOR_LIST, &"operator")
	add_int(row, 100, &"buffid", 1, 0)
	return row
