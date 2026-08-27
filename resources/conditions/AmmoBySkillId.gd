extends "res://plugins/skill_manager/resources/Condition.gd"

const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")

## Port of conditions/sm_condition_Ammo_By_ID.txt.

@export var skillid: int = 1175
@export var operator: int = 1
@export var value: int = 3

func _get_uid() -> String:
	return "Ammo - by Skill ID"

func _evaluate(_skill: Resource, _context: RefCounted) -> bool:
	if skillid <= 1000 or skillid >= 99999:
		return false
	var other: AbilityDef = SkillState.by_id(skillid)
	if not other:
		return false
	return compare(operator, SkillState.charges(other), value)

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Ammo of Skill ID")
	add_int(row, 100, &"skillid", 1, 1001, 99998)
	add_combo(row, 50, OPERATORS, &"operator")
	add_int(row, 120, &"value", 1)
	return row
