extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Distance.txt.

const TARGET_LIST: Array[String] = ["Enemy", "Friend"]

@export var target: int = 1
@export var operator: int = 1
@export var value: float = 500.0

func _get_uid() -> String:
	return "Distance"

func _evaluate(skill: Resource, context: RefCounted) -> bool:
	# A combo continuation ignores range so the first skill of the chain decides
	# it, and the rest can still fire once the chain is in flight.
	if skill and skill.is_combo:
		return true

	var agent: Agent = context.target_for(target, Context.ORDER_EF)
	if not agent or not context.player:
		return false
	var distance: float = Context.edge_distance(context.player, agent)
	if distance < 0.0:
		return false
	return compare(operator, distance, value)

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGET_LIST, &"target")
	add_label(row, " Distance is")
	add_combo(row, 50, OPERATORS, &"operator")
	add_distance(row, 120, &"value", 0.0, 10000.0)
	return row
