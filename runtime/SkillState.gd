extends RefCounted

## Live per-skill numbers, in the units the Lua conditions were written against.
##
## GW2Minion reported cooldowns in milliseconds and charges as "ammo"; GW2CC keeps
## cooldowns in seconds and splits charges across a CooldownInfo. Converting here
## keeps every saved profile threshold meaning the same thing it used to.

static func by_id(skill_id: int) -> AbilityDef:
	if skill_id <= 0:
		return null
	# Content is not there until the client finishes loading it, and both the
	# editor and the runner ask for definitions by id on every refresh.
	if not ContentService.is_loaded():
		return null
	return SkillUtils.get_abilitydef_by_skillid(skill_id)


static func _cooldown_info(skill: AbilityDef) -> Variant:
	if not skill:
		return null
	var character := Manager.agent.controlled_character
	if not character or not character.has_component(SkillBar):
		return null
	var cooldowns: Dictionary = character.skill_bar.cooldowns
	if not cooldowns.has(skill.id):
		return null
	return cooldowns[skill.id]


## Remaining recharge in milliseconds, 0 when the skill is ready.
static func cooldown_ms(skill: AbilityDef) -> float:
	var info: Variant = _cooldown_info(skill)
	if not info:
		return 0.0
	return float(info.cooldown) * 1000.0


## Full recharge in milliseconds.
static func cooldown_max_ms(skill: AbilityDef) -> float:
	if not skill:
		return 0.0
	return SkillUtils.get_effective_recharge(skill) * 1000.0


## Charges currently available.
static func charges(skill: AbilityDef) -> int:
	if not skill:
		return 0
	var maximum := SkillUtils.get_effective_count(skill)
	if maximum <= 0:
		return 0
	var info: Variant = _cooldown_info(skill)
	if not info:
		return maximum
	return maxi(0, maximum - info.charge_cooldowns.size())


static func charges_max(skill: AbilityDef) -> int:
	if not skill:
		return 0
	return SkillUtils.get_effective_count(skill)


## Remaining recharge of the next charge, in milliseconds.
static func charge_cooldown_ms(skill: AbilityDef) -> float:
	var info: Variant = _cooldown_info(skill)
	if not info:
		return 0.0
	var pending: Array = info.charge_cooldowns
	if pending.is_empty():
		return 0.0
	var shortest: float = INF
	for entry: Variant in pending:
		var value := float(entry)
		if value < shortest:
			shortest = value
	if shortest == INF:
		return 0.0
	return shortest * 1000.0


static func charge_cooldown_max_ms(skill: AbilityDef) -> float:
	if not skill:
		return 0.0
	return SkillUtils.get_effective_count_recharge(skill) * 1000.0


static func is_ground_targeted(skill: AbilityDef) -> bool:
	if not skill:
		return false
	return (skill.flags & SkillConstants.SkillFlags.SKILL_FLAG_GROUND_TARGETED) != 0


static func needs_no_target(skill: AbilityDef) -> bool:
	if not skill:
		return false
	return (skill.flags & SkillConstants.SkillFlags.SKILL_FLAG_NO_TARGET_AGENT) != 0


## True when the skill works on land.
static func is_land(skill: AbilityDef) -> bool:
	if not skill:
		return false
	return (skill.flags & SkillConstants.SkillFlags.SKILL_FLAG_LAND) != 0


## True when the skill works underwater.
static func is_aquatic(skill: AbilityDef) -> bool:
	if not skill:
		return false
	return (skill.flags & SkillConstants.SkillFlags.SKILL_FLAG_AQUATIC) != 0


## True for skills that only exist underwater, which is what earns the "(aquatic)"
## marker in the Skill Set Editor.
static func is_aquatic_only(skill: AbilityDef) -> bool:
	return is_aquatic(skill) and not is_land(skill)


## True when the skill cannot be used while diving, the equivalent of the Lua
## `nounderwater` palette flag.
static func no_underwater(skill: AbilityDef) -> bool:
	return is_land(skill) and not is_aquatic(skill)
