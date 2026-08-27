extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Buff_ID_List.txt.

const OPERATOR_LIST: Array[String] = [
	"has one of the Buff IDs",
	"has all of the Buff IDs",
	"has none of the Buff IDs",
]
const TOOLTIP := "Add BuffIDs in a comma separated list! :  2345, 32244, 8764"

@export var target: int = 1
@export var operator: int = 1
@export var buffids: String = "743"

func _get_uid() -> String:
	return "Buff (ID-List)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	if not agent:
		return false

	var wanted: Array[int] = parse_id_list(buffids)
	if wanted.is_empty():
		return false
	var present: Dictionary = Context.buff_stacks(agent)

	match operator:
		1:
			for buff_id in wanted:
				if present.has(buff_id):
					return true
			return false
		2:
			for buff_id in wanted:
				if not present.has(buff_id):
					return false
			return true
		3:
			for buff_id in wanted:
				if present.has(buff_id):
					return false
			return true
	return false

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	add_combo(row, 185, OPERATOR_LIST, &"operator")
	add_text(row, 200, &"buffids", TOOLTIP)
	return row
