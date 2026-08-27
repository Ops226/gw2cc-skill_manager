extends "res://plugins/skill_manager/resources/Condition.gd"

const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")

## Port of conditions/sm_condition_Cooldown.txt. The value stays in milliseconds
## so thresholds carried over from GW2Minion profiles keep their meaning.

@export var operator: int = 1
@export var value: int = 50

func _get_uid() -> String:
	return "Cooldown"

func _evaluate(skill: Resource, _context: RefCounted) -> bool:
	if not skill:
		return false
	return compare(operator, SkillState.cooldown_ms(skill.ability()), value)

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Cooldown")
	add_combo(row, 50, OPERATORS, &"operator")
	add_int(row, 120, &"value", 1)
	add_label(row, "ms.")
	return row
