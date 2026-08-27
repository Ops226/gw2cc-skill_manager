extends "res://plugins/skill_manager/runtime/palettes/Palette.gd"

## An engineer kit, a bundle, or any other transformation that replaces the bar.
## Replaces the kit palettes of the Lua files, whose Activate cast the utility
## slot holding the kit and whose Deactivate swapped weapons to drop it.

## The SkillPaletteDef the transformation installs.
var palette_def: SkillPaletteDef = null
## The equipped skill that grants the transformation.
var grant_skill: AbilityDef = null
## The bar slot [member grant_skill] sits in.
var grant_slot: int = SkillBar.SKILL_BAR_SLOT_NONE


func is_active(context: RefCounted) -> bool:
	var player: AgentChar = context.player
	if not player:
		return false
	for transformation: Variant in player.transformations:
		if not transformation:
			continue
		if transformation.weapon is not TransformationWeapon:
			continue
		if not transformation.weapon.skill_palette:
			continue
		if transformation.weapon.skill_palette.get_def() == palette_def:
			return true
	return false


func can_activate(context: RefCounted) -> bool:
	if is_active(context):
		return true
	return _ready_grant_skill(context) != null


func activate(context: RefCounted) -> void:
	var skill := _ready_grant_skill(context)
	if not skill:
		return
	Manager.combat.queue_skill(grant_slot, skill)


func deactivate(context: RefCounted) -> bool:
	if not is_active(context):
		return false
	if not SkillUtils.can_weapon_swap():
		return false
	Manager.character_controller.cycle_active_weapon_set()
	return true


func _ready_grant_skill(context: RefCounted) -> AbilityDef:
	if not grant_skill or grant_slot == SkillBar.SKILL_BAR_SLOT_NONE:
		return null
	var player: AgentChar = context.player
	if not player or not player.has_component(SkillBar):
		return null
	var bar: Array = player.skill_bar.skills
	if grant_slot >= bar.size() or bar[grant_slot] != grant_skill:
		return null
	if not SkillUtils.skill_cd_ready(grant_skill):
		return null
	if not SkillUtils.check_resources(grant_skill):
		return null
	return grant_skill
