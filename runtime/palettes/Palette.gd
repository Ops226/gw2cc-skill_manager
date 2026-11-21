extends RefCounted

## A swappable source of skills, the port of `sm_skillpalette.lua`.
##
## GW2Minion hardcoded 217 of these across ten Lua files, each with its own
## IsActive / CanActivate / Activate / Deactivate body. Here the skill membership
## comes from the live SkillPaletteDef data and only the activation behaviour is
## written by hand, which collapses those 217 into four families.

const Context := preload("res://plugins/skill_manager/runtime/Context.gd")

## Stable identifier stored in profiles. Must not change between sessions.
var uid: String = ""
## Label shown under the palette icon in the Skill Set Editor.
var display_name: String = ""
## Skills this palette makes reachable, in bar order.
var skills: Array[AbilityDef] = []
## Skill id to the [enum SkillBar.SkillBarSlot] it occupies while active.
var slots: Dictionary[int, int] = {}
## Skill ids that are flip or chain continuations rather than the skill the slot
## starts on. The Lua palettes flagged these with a `parent` field.
var flips: Dictionary[int, bool] = {}
## Icon shown in the palette column.
var icon: Texture2D = null
## Skill id to the name of the elite specialization that unlocks it, for the
## skills that need one. Shown as a note in the Skill Set Editor.
var specializations: Dictionary[int, String] = {}


func has_skill(skill_id: int) -> bool:
	return slots.has(skill_id)


func slot_of(skill_id: int) -> int:
	return slots.get(skill_id, SkillBar.SKILL_BAR_SLOT_NONE)


## True for flip and chain skills, which are only ever on the bar as the
## continuation of another skill.
func is_flip(skill_id: int) -> bool:
	return flips.has(skill_id)


## True when the palette's skills are on the bar right now.
@warning_ignore("unused_parameter")
func is_active(context: RefCounted) -> bool:
	return false


## True when the palette could be switched to from the current state.
@warning_ignore("unused_parameter")
func can_activate(context: RefCounted) -> bool:
	return false


## Switches to this palette. Called at most once per hold window.
@warning_ignore("unused_parameter")
func activate(context: RefCounted) -> void:
	pass


## Switches away from this palette. Returns true when it actually did something,
## which is what makes the runner wait for the swap to land.
@warning_ignore("unused_parameter")
func deactivate(context: RefCounted) -> bool:
	return false


## Adds one skill at the bar slot it would occupy. A skill already present
## keeps its first slot.
func add_skill(skill: AbilityDef, slot: int) -> void:
	if not skill or slots.has(skill.id):
		return
	slots[skill.id] = slot
	skills.append(skill)


## Populates [member skills] and [member slots] from a computed skill bar.
func absorb_skill_bar(skill_bar: Array, wanted_slots: Array) -> void:
	for slot: int in wanted_slots:
		if slot < 0 or slot >= skill_bar.size():
			continue
		var skill: AbilityDef = skill_bar[slot]
		if not skill:
			continue
		if slots.has(skill.id):
			continue
		slots[skill.id] = slot
		skills.append(skill)


## Adds the flip and chain skills reachable from the skills already collected, so
## the Skill Set Editor can offer them the way the Lua palettes listed `parent`
## skills explicitly.
func absorb_followups() -> void:
	var queue: Array[AbilityDef] = skills.duplicate()
	while not queue.is_empty():
		var skill: AbilityDef = queue.pop_front()
		var slot: int = slots.get(skill.id, SkillBar.SKILL_BAR_SLOT_NONE)
		for reference: Variant in skill.flip_skills:
			if not reference:
				continue
			var flip: Variant = reference.get_def()
			if flip is not AbilityDef or slots.has(flip.id):
				continue
			slots[flip.id] = slot
			flips[flip.id] = true
			skills.append(flip)
			queue.append(flip)


## Label plus the underlying set name, so two similar looking weapon sets can
## still be told apart on hover.
func tooltip() -> String:
	if display_name == uid:
		return uid
	return "%s\n%s" % [display_name, uid]


func first_icon() -> Texture2D:
	if icon:
		return icon
	for skill in skills:
		var texture := skill_icon(skill)
		if texture:
			return texture
	return null


static func skill_icon(skill: AbilityDef) -> Texture2D:
	if not skill or skill.icon == 0:
		return null
	var path := ContentService.get_asset_path(skill.icon)
	if path.is_empty() or path.ends_with("/Unknown/0"):
		return null
	return load(path) as Texture2D
