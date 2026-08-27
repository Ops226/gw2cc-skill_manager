extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_WeaponSetID.txt.

@export var value: int = 1

func _get_uid() -> String:
	return "WeaponSet ID"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	if not context.player:
		return false
	return context.weaponset == value

func _build_editor() -> Control:
	var row := new_row()
	add_label(row, "Weapon Set ID is ")
	add_int(row, 100, &"value", 1, 0, 10)
	return row
