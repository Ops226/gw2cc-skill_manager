extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_SwimState.txt.
##
## Only two targets, unlike every other target list in the addon.

const TARGET_LIST: Array[String] = ["Player is", "Target is"]
const OPERATOR_LIST: Array[String] = ["Not in Water", "Diving", "Swimming"]

@export var target: int = 1
@export var operator: int = 1

func _get_uid() -> String:
	return "SwimState"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_PTF)
	if not agent:
		return false
	var state: int = Context.swim_state(agent)
	match operator:
		1:
			return state == Context.SWIM_NONE
		2:
			return state == Context.SWIM_DIVING
		3:
			return state == Context.SWIM_SWIMMING
	return false

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGET_LIST, &"target")
	add_combo(row, 150, OPERATOR_LIST, &"operator")
	return row
