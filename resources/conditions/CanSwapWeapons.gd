extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_CanSwapWeapons.txt.

const OPERATOR_LIST: Array[String] = ["Player can swap Weapons", "Player cannot swap Weapons"]

@export var operator: int = 1

func _get_uid() -> String:
	return "Can Swap Weapons"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	if not context.player:
		return false
	return context.canswapweaponset if operator == 1 else not context.canswapweaponset

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 150, OPERATOR_LIST, &"operator")
	return row
