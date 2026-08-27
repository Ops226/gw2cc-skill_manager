extends "res://plugins/skill_manager/runtime/palettes/Palette.gd"

## One profession state: an elementalist attunement, the necromancer shroud, a
## revenant legend, a ranger avatar. Replaces the attunement / legend / shroud
## palettes of the Lua files.

const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")

## The [enum SkillConstants.ProfessionState] this palette represents.
var profession_state: int = 0
## The profession bar slot whose skill switches into this state, or
## [constant SkillBar.SKILL_BAR_SLOT_NONE] when the state cannot be entered on
## demand (warrior adrenaline, for instance, is built by attacking).
var entry_slot: int = SkillBar.SKILL_BAR_SLOT_NONE


func is_active(context: RefCounted) -> bool:
	var player: AgentChar = context.player
	if not player:
		return false
	return player.profession_state == profession_state


func can_activate(context: RefCounted) -> bool:
	if is_active(context):
		return true
	return _entry_skill(context) != null


func activate(context: RefCounted) -> void:
	var skill := _entry_skill(context)
	if not skill:
		return
	Manager.combat.queue_skill(entry_slot, skill)


func deactivate(_context: RefCounted) -> bool:
	# Leaving a profession state always happens by entering another one, so there
	# is nothing to undo here. The Lua palettes behaved the same way.
	return false


func _entry_skill(context: RefCounted) -> AbilityDef:
	if entry_slot == SkillBar.SKILL_BAR_SLOT_NONE:
		return null
	var player: AgentChar = context.player
	if not player or not player.has_component(SkillBar):
		return null
	var bar: Array = player.skill_bar.skills
	if entry_slot >= bar.size():
		return null
	var skill: AbilityDef = bar[entry_slot]
	if not skill:
		return null
	if not SkillUtils.skill_cd_ready(skill):
		return null
	if not SkillUtils.check_resources(skill):
		return null
	return skill
