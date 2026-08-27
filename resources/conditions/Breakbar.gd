extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Breakbar.txt.

const STATE_LIST: Array[String] = ["Breaking", "Recharging"]

@export var operator: int = 1
@export var value: int = 50
@export var state: int = 1

func _get_uid() -> String:
	return "Breakbar"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var target: Agent = context.attack_target
	if not target:
		return false

	var wanted := AgentConstants.BreakBarState.BREAK_BAR_STATE_ACTIVE
	if state == 2:
		wanted = AgentConstants.BreakBarState.BREAK_BAR_STATE_REGENERATING
	if Context.breakbar_state(target) != wanted:
		return false

	var percent: float = Context.breakbar_percent(target)
	if percent < 0.0:
		return false
	return compare(operator, percent, value)

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Target's Breakbar is")
	add_combo(row, 50, OPERATORS, &"operator")
	add_int(row, 70, &"value", 1, 0, 100)
	add_label(row, "Percent and ")
	add_combo(row, 100, STATE_LIST, &"state")
	return row
