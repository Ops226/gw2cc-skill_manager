extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Alive.txt.
##
## The Lua tested `state ~= nil`, so the condition reported "alive" for anything
## it could read at all, including corpses. Fixed here to test the value.

const OPERATOR_LIST: Array[String] = ["Alive", "Not Alive"]

@export var target: int = 1
@export var operator: int = 1

func _get_uid() -> String:
	return "Alive"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_PTF)
	if not agent:
		return false
	var alive: bool = Context.is_alive(agent)
	return alive if operator == 1 else not alive

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_PTF, &"target")
	add_combo(row, 150, OPERATOR_LIST, &"operator")
	return row
