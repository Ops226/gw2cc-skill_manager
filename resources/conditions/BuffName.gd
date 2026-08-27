extends "res://plugins/skill_manager/resources/Condition.gd"

## Port of conditions/sm_condition_Buff_Name.txt.
##
## The Lua read a field that was never assigned, so this condition could never
## return true. Fixed here; the id-to-name table is copied verbatim, duplicate
## names and all.

const OPERATOR_LIST: Array[String] = ["has", "has not"]

const BUFF_NAMES: Array[String] = [
	"Bleeding", "Blind", "Burning", "Chilled", "Confusion", "Crippled", "Fear",
	"Immobilized", "Vulnerability", "Weakness", "Poison", "Taunt", "Slow", "Torment",
	"Aegis", "Aegis", "Fury", "Might", "Protection", "Quickness", "Regeneration",
	"Regeneration", "Resistance", "Retaliation", "Stability", "Swiftness", "Vigor",
	"Determined", "Super Speed", "Mist form", "Signet of the Hunt",
	"Signet of Shadows", "Signet of Air", "Signet of the Locust",
	"Leader of the Pact I", "Leader of the Pact II", "Leader of the Pact III",
	"Ichor", "Stun", "Daze", "Petrified 1", "Petrified 2", "Trapped", "Frostbite",
	"Stealth", "Stealth2",
]

const BUFF_IDS: Array[int] = [
	736, 720, 737, 722, 861, 721, 791,
	727, 738, 742, 723, 27705, 26766, 19426,
	743, 17675, 725, 740, 717, 1187, 718,
	17674, 26980, 873, 1122, 719, 726,
	762, 5974, 5543, 12542,
	13060, 5572, 10612,
	33843, 32675, 33611,
	18621, 872, 833, 15090, 16963, 25181, 37211,
	13017, 26142,
]

@export var target: int = 1
@export var operator: int = 1
@export var buff: int = 743

func _get_uid() -> String:
	return "Buff (Name)"

func _evaluate(_skill: Resource, context: RefCounted) -> bool:
	var agent: Agent = context.target_for(target, Context.ORDER_TPF)
	var present: bool = agent != null and AgentUtils.has_buff_by_id(agent, buff)
	return present if operator == 1 else not present

func _build_editor() -> Control:
	var row := new_row()
	add_combo(row, 100, TARGETS_TPF, &"target")
	add_combo(row, 100, OPERATOR_LIST, &"operator")
	add_value_combo(row, 200, BUFF_NAMES, BUFF_IDS, &"buff")
	return row
