extends Resource

## One AND-ed set of conditions plus the target the skill is cast at when the set
## passes. Groups are OR-ed by the owning skill; the first group that evaluates
## true wins and its `casttarget` is used (sm_skill.lua:785-800).

const Context := preload("res://plugins/skill_manager/runtime/Context.gd")

## The three entries of the "Cast Spell At" combo, in saved order.
const CAST_TARGETS: Array[String] = ["Enemy", "Player", "Friend"]

@export var casttarget: int = Context.CAST_ENEMY
@export var conditions: Array[Resource] = []


## True when every condition in the group passes. An empty group passes, which is
## what made a skill with no conditions always castable in the original.
func evaluate(skill: Resource, context: RefCounted) -> bool:
	for condition: Resource in conditions:
		if not condition:
			continue
		if not condition.evaluate(skill, context):
			return false
	return true


func duplicate_group() -> Resource:
	var copy: Resource = (load("res://plugins/skill_manager/resources/ConditionGroup.gd") as Script).new()
	copy.casttarget = casttarget
	var copied: Array[Resource] = []
	for condition: Resource in conditions:
		copied.append(condition.duplicate(true) if condition else null)
	copy.conditions = copied
	return copy
