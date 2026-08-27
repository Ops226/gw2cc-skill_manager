extends "res://plugins/skill_manager/resources/Condition.gd"

const SkillCatalog := preload("res://plugins/skill_manager/runtime/SkillCatalog.gd")

## Port of conditions/sm_condition_Casting_Name.txt.
##
## Identical to Casting (ID) apart from the picker, which offers skills by name
## instead of asking for a raw id. It wrote the same field in the Lua too.

@export var target: int = 1
@export var skillid: int = 1

func _get_uid() -> String:
	return "Casting (Name)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	if not agent:
		return false
	return Context.casting_id(agent) == skillid

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	add_label(row, "is casting ")
	var lists: Array = SkillCatalog.name_and_id_lists()
	add_value_combo(row, 250, lists[0], lists[1], &"skillid")
	return row
