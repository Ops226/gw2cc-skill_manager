extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_CombatState.txt.
##
## "In combat" means something different per target, exactly as in the Lua: the
## player reports its own flag, an enemy also counts as engaged when it is below
## full health, and a friend likewise.

const OPERATOR_LIST: Array[String] = ["In Combat", "Not In Combat"]

@export var target: int = 1
@export var operator: int = 1

func _get_uid() -> String:
	return "CombatState"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_PTF)
	if not agent:
		return false

	var engaged: bool = false
	match target:
		1:
			engaged = Context.in_combat(agent)
		2:
			engaged = Context.has_aggro(agent) or Context.in_combat(agent) or _hurt(agent)
		3:
			engaged = Context.in_combat(agent) or _hurt(agent)

	return engaged if operator == 1 else not engaged

static func _hurt(agent: Agent) -> bool:
	var percent: float = Context.hp_percent(agent)
	return percent >= 0.0 and percent < 100.0

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_PTF, &"target")
	add_combo(row, 150, OPERATOR_LIST, &"operator")
	return row
