extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Health.txt.

const HEALTH_TYPES: Array[String] = ["Current Health", "Max Health", "Health Percent"]

const TYPE_CURRENT := 1
const TYPE_MAX := 2
const TYPE_PERCENT := 3

@export var target: int = 1
@export var operator: int = 1
@export var healthtype: int = TYPE_PERCENT
@export var value: int = 100

func _get_uid() -> String:
	return "Health"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	if not agent:
		return false

	var health: float = -1.0
	match healthtype:
		TYPE_CURRENT:
			health = Context.hp_current(agent)
		TYPE_MAX:
			health = Context.hp_max(agent)
		TYPE_PERCENT:
			health = Context.hp_percent(agent)
	if health < 0.0:
		return false
	return compare(operator, health, value)

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	var types := add_combo(row, 150, HEALTH_TYPES, &"healthtype")
	add_combo(row, 50, OPERATORS, &"operator")
	var amount := add_int(row, 100, &"value", 1, 0, 100)
	# The 0-100 clamp only applies to the percentage reading, matching the Lua.
	var apply_clamp := func() -> void:
		amount.max_value = 100 if healthtype == TYPE_PERCENT else 99999999
	apply_clamp.call()
	types.item_selected.connect(func(_index: int) -> void: apply_clamp.call())
	return row
