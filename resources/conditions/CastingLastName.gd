extends "res://plugins/skill_manager/resources/Condition.gd"

const SkillCatalog := preload("res://plugins/skill_manager/runtime/SkillCatalog.gd")

## Port of conditions/sm_condition_Casting_Last_Name.txt. The name-picker twin of
## Casting (Last ID).

@export var target: int = 1
@export var skillid: int = 1

func _get_uid() -> String:
	return "Casting (Last Name)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	if not agent:
		return false
	return context.last_cast_by_agent.get(agent.id, 0) == skillid

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	add_label(row, "was casting ")
	var lists: Array = SkillCatalog.name_and_id_lists()
	add_value_combo(row, 250, lists[0], lists[1], &"skillid")
	return row
