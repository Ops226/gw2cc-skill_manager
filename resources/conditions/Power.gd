extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Power.txt. Reads the profession resource --
## initiative, life force, adrenaline and so on -- as a percentage.

@export var operator: int = 1
@export var value: int = 100

func _get_uid() -> String:
	return "Power"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	if not context.player:
		return false
	return compare(operator, context.power, value)

func _build_editor() -> Control:
	var row := new_row()
	add_readonly(row, "Player Power Percent", 200)
	add_combo(row, 50, OPERATORS, &"operator")
	add_int(row, 100, &"value", 1, 0, 100)
	return row
