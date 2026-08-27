extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Buff_Count.txt: how many distinct buffs of a
## given family sit on the target.

const BUFF_TYPES: Array[String] = [
	"Boons",
	"Conditions",
	"SpeedBoons",
	"SlowConditions",
	"ImmobilizeConditions",
]

## GW2Minion read these three lists from its host globals. The ids are spelled
## out here so the condition depends on nothing outside the plugin.
const SPEED_BOON_IDS: Array[int] = [719, 5974]
const SLOW_CONDITION_IDS: Array[int] = [722, 721, 26766]
const IMMOBILIZE_CONDITION_IDS: Array[int] = [727]

@export var target: int = 1
@export var operator: int = 1
@export var value: int = 1
@export var bufftype: int = 1

func _get_uid() -> String:
	return "Buffs (Count)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	var count: int = 0
	if agent:
		match bufftype:
			1:
				count = Context.count_named_buffs(agent, SkillConstants.BOONS)
			2:
				count = Context.count_named_buffs(agent, SkillConstants.CONDITIONS)
			3:
				count = Context.count_id_buffs(agent, SPEED_BOON_IDS)
			4:
				count = Context.count_id_buffs(agent, SLOW_CONDITION_IDS)
			5:
				count = Context.count_id_buffs(agent, IMMOBILIZE_CONDITION_IDS)
	return compare(operator, count, value)

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_HAS, &"target")
	add_combo(row, 50, OPERATORS, &"operator")
	add_int(row, 100, &"value", 1, 0)
	add_combo(row, 175, BUFF_TYPES, &"bufftype")
	return row
