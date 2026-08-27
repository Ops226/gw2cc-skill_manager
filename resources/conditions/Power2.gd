extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Power2.txt.

@export var operator: int = 1
@export var value: int = 100

func _get_uid() -> String:
	return "Power2"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	if not context.player:
		return false
	return compare(operator, context.power2, value)

func _build_editor() -> Control:
	var row := new_row()
	add_readonly(row, "Player Power2 Value", 200, "This Power 2 is for Necro Sand Shades or Thief Malice.")
	add_combo(row, 50, OPERATORS, &"operator")
	add_int(row, 100, &"value", 1, 0, 100)
	return row
