extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Buff_Count_ID.txt: the stack count of one buff.

@export var target: int = 1
@export var operator: int = 1
@export var value: int = 1
@export var buffid: int = 743

func _get_uid() -> String:
	return "Buffs (Count by ID)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	var stacks: int = 0
	if agent:
		stacks = Context.buff_stacks(agent).get(buffid, 0)
	return compare(operator, stacks, value)

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_HAS, &"target")
	add_combo(row, 50, OPERATORS, &"operator")
	add_int(row, 100, &"value", 1, 0)
	add_int(row, 175, &"buffid", 1, 0)
	return row
