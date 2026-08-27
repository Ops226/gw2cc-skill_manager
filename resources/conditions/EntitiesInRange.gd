extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Entities_In_Range.txt.

const TYPE_LIST: Array[String] = ["Enemies", "Friends"]

@export var type: int = 1
@export var count: int = 1
@export var target: int = 1
@export var operator: int = 1
@export var distance: float = 500.0

func _get_uid() -> String:
	return "Entities In Range"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var origin: Agent = context.target_for(target, Context.ORDER_TPF)
	if not origin:
		return false

	var pool: Array[Agent] = context.enemies_nearby if type == 1 else context.friends_nearby
	var in_range: int = 0
	for agent: Agent in pool:
		if Context.game_distance(origin.position, agent.position) < distance:
			in_range += 1

	return compare(operator, in_range, count)

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 40, OPERATORS, &"operator")
	add_int(row, 75, &"count", 1, 0)
	add_combo(row, 125, TYPE_LIST, &"type")
	add_label(row, "within")
	add_distance(row, 90, &"distance", 0.0, 10000.0)
	add_label(row, "near")
	add_combo(row, 100, TARGETS_TPF, &"target")
	return row
