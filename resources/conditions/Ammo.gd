extends "res://plugins/skill_manager/resources/Condition.gd"

const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")

## Port of conditions/sm_condition_Ammo.txt. "Ammo" is the charge count.

@export var operator: int = 1
@export var value: int = 1

func _get_uid() -> String:
	return "Ammo"

func _evaluate(skill: Resource, _context: RefCounted) -> bool:
	if not skill:
		return false
	return compare(operator, SkillState.charges(skill.ability()), value)

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Ammo")
	add_combo(row, 50, OPERATORS, &"operator")
	add_int(row, 120, &"value", 1, 0)
	return row
