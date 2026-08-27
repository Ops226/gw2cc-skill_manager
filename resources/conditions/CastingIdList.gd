extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Casting_ID_List.txt.

const TOOLTIP := "Add SkillIDs in a comma separated list! :  2345, 32244, 8764"

@export var target: int = 1
@export var skillids: String = "1"

func _get_uid() -> String:
	return "Casting (ID-List)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	if not agent:
		return false
	var casting: int = Context.casting_id(agent)
	if casting <= 999:
		return false
	return casting in parse_id_list(skillids)

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 80, TARGETS_TPF, &"target")
	add_label(row, "is casting any of the Skill IDs")
	add_text(row, 200, &"skillids", TOOLTIP)
	return row
