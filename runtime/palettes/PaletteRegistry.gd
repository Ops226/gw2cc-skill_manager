extends RefCounted

## Builds the palette set for the current character.
##
## The Lua addon shipped 217 hardcoded palettes. Here they are derived instead:
## a speculative [CharacterState] is handed to [method SkillManager.compute_skill_bar]
## with `virtual = true`, which answers "what would my bar look like on that weapon
## set / in that attunement" without touching the real bar. Everything the editor
## offers is therefore always in sync with the game.

const Palette := preload("res://plugins/skill_manager/runtime/palettes/Palette.gd")
const WeaponSetPalette := preload("res://plugins/skill_manager/runtime/palettes/WeaponSetPalette.gd")
const ProfessionStatePalette := preload("res://plugins/skill_manager/runtime/palettes/ProfessionStatePalette.gd")
const TransformPalette := preload("res://plugins/skill_manager/runtime/palettes/TransformPalette.gd")
const UtilityPalette := preload("res://plugins/skill_manager/runtime/palettes/UtilityPalette.gd")

const TOOLBELT_SLOTS: Array[int] = [
	SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillBar.SKILL_BAR_SLOT_PROF_2,
	SkillBar.SKILL_BAR_SLOT_PROF_3,
	SkillBar.SKILL_BAR_SLOT_PROF_4,
	SkillBar.SKILL_BAR_SLOT_PROF_5,
	SkillBar.SKILL_BAR_SLOT_PROF_6,
	SkillBar.SKILL_BAR_SLOT_PROF_7,
]

const WEAPON_SET_NAMES: Dictionary[int, String] = {
	ItemStorage.WEAPON_SET_LAND_1: "Weapon Set 1",
	ItemStorage.WEAPON_SET_LAND_2: "Weapon Set 2",
	ItemStorage.WEAPON_SET_AQUATIC_1: "Aquatic Set 1",
	ItemStorage.WEAPON_SET_AQUATIC_2: "Aquatic Set 2",
}

## The two underwater weapon sets, called out in the editor so a harpoon gun set
## is not mistaken for a land set.
const AQUATIC_WEAPON_SETS: Array[int] = [
	ItemStorage.WEAPON_SET_AQUATIC_1,
	ItemStorage.WEAPON_SET_AQUATIC_2,
]

## Which profession bar slot switches into which profession state. States that are
## reached passively, such as warrior adrenaline, are deliberately absent: they
## still register as palettes so their skills can be picked, they just cannot be
## activated on demand.
const STATE_ENTRY_SLOT: Dictionary[int, int] = {
	SkillConstants.ProfessionState.AttunementFire: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.AttunementWater: SkillBar.SKILL_BAR_SLOT_PROF_2,
	SkillConstants.ProfessionState.AttunementAir: SkillBar.SKILL_BAR_SLOT_PROF_3,
	SkillConstants.ProfessionState.AttunementEarth: SkillBar.SKILL_BAR_SLOT_PROF_4,
	SkillConstants.ProfessionState.NecromancerShroud: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.LegendaryDragonStance: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.LegendaryAssassinStance: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.LegendaryDwarfStance: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.LegendaryDemonStance: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.LegendaryRenegadeStance: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.LegendaryCentaurStance: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.LegendaryAllianceStance: SkillBar.SKILL_BAR_SLOT_PROF_1,
	SkillConstants.ProfessionState.LegendaryEntityStance: SkillBar.SKILL_BAR_SLOT_PROF_1,
}

const PROFESSION_STATES: Dictionary[int, Array] = {
	ProfessionDef.PROFESSION_ELEMENTALIST: [
		SkillConstants.ProfessionState.AttunementFire,
		SkillConstants.ProfessionState.AttunementWater,
		SkillConstants.ProfessionState.AttunementAir,
		SkillConstants.ProfessionState.AttunementEarth,
	],
	ProfessionDef.PROFESSION_NECROMANCER: [
		SkillConstants.ProfessionState.NecromancerShroud,
	],
	ProfessionDef.PROFESSION_WARRIOR: [
		SkillConstants.ProfessionState.WarriorPowerLevel1,
		SkillConstants.ProfessionState.WarriorPowerLevel2,
		SkillConstants.ProfessionState.WarriorPowerLevel3,
	],
	ProfessionDef.PROFESSION_REVENANT: [
		SkillConstants.ProfessionState.LegendaryDragonStance,
		SkillConstants.ProfessionState.LegendaryAssassinStance,
		SkillConstants.ProfessionState.LegendaryDwarfStance,
		SkillConstants.ProfessionState.LegendaryDemonStance,
		SkillConstants.ProfessionState.LegendaryRenegadeStance,
		SkillConstants.ProfessionState.LegendaryCentaurStance,
		SkillConstants.ProfessionState.LegendaryAllianceStance,
		SkillConstants.ProfessionState.LegendaryEntityStance,
	],
}

const _PALETTE_TYPE_TRANSFORM := 11

## Rebuilding means several speculative skill-bar computations, and the signature
## that decides whether to rebuild is itself not cheap. Skill.palette() is called
## many times per action per tick, so the check is rate limited: equipment does
## not change mid-rotation.
const STALENESS_CHECK_INTERVAL_MS := 1000

static var _palettes: Dictionary[String, RefCounted] = {}
static var _signature: String = ""
static var _checked_at: int = -STALENESS_CHECK_INTERVAL_MS
static var _logger := ScopedLogger.create("SkillManager")


## The palettes reachable by the current character, keyed by uid.
static func palettes() -> Dictionary[String, RefCounted]:
	rebuild_if_stale()
	return _palettes


static func get_palette(uid: String) -> RefCounted:
	return palettes().get(uid, null)


## Discards the cache so the next access rebuilds. Call after an equipment or
## build change that the signature cannot see.
static func invalidate() -> void:
	_signature = ""
	_checked_at = -STALENESS_CHECK_INTERVAL_MS


static func rebuild_if_stale() -> void:
	var now := Time.get_ticks_msec()
	if not _palettes.is_empty() and now - _checked_at < STALENESS_CHECK_INTERVAL_MS:
		return
	_checked_at = now

	var character := Manager.agent.controlled_character
	if not character:
		return
	var signature: String = _build_signature(character)
	if signature == _signature and not _palettes.is_empty():
		return
	_signature = signature
	_rebuild(character)


static func _rebuild(character: AgentChar) -> void:
	_palettes = {}
	if not character.has_component(CoreStats) or not character.core_stats.profession_def:
		return

	_build_weapon_sets(character)
	_build_profession_states(character)
	_build_transforms(character)
	_build_common(character)

	_logger.trace("Built %d skill palettes" % _palettes.size())


static func _add(palette: RefCounted) -> void:
	if palette.skills.is_empty():
		return
	palette.absorb_followups()
	_palettes[palette.uid] = palette


static func _build_weapon_sets(character: AgentChar) -> void:
	if not character.has_component(ItemStorage):
		return

	# A character with only one set equipped still reports weapons in both:
	# CharacterState deliberately mirrors them so they show on either bar. Taken
	# at face value that produces two identical entries in the palette column, so
	# a set that offers nothing new is dropped.
	var seen: Dictionary[String, String] = {}

	for weapon_set: int in WEAPON_SET_NAMES:
		var state: CharacterState = CharacterState.from_agent(character)
		state.update_weapon_set(character, weapon_set)
		if not state.mainhand_palette and not state.offhand_palette:
			continue
		var bar: Array = Manager.skill.compute_skill_bar(state, true)

		var palette: RefCounted = WeaponSetPalette.new()
		palette.weapon_set = weapon_set
		palette.uid = WEAPON_SET_NAMES[weapon_set]
		palette.display_name = _weapon_set_label(state, WEAPON_SET_NAMES[weapon_set])
		if weapon_set in AQUATIC_WEAPON_SETS:
			palette.display_name += " (aquatic)"
		palette.absorb_skill_bar(bar, SkillConstants.WEAPON_SKILL_BAR)

		var signature := _skill_signature(palette)
		if seen.has(signature):
			continue
		seen[signature] = palette.uid
		_add(palette)


## The skills a palette offers, as a comparable key.
static func _skill_signature(palette: RefCounted) -> String:
	var ids: Array[int] = palette.slots.keys()
	ids.sort()
	var parts: Array[String] = []
	for id: int in ids:
		parts.append(str(id))
	return ",".join(parts)


static func _build_profession_states(character: AgentChar) -> void:
	var profession: int = character.core_stats.profession_def.id
	if not PROFESSION_STATES.has(profession):
		return
	for profession_state: int in PROFESSION_STATES[profession]:
		var state: CharacterState = CharacterState.from_agent(character)
		state.profession_state = profession_state
		state.secondary_profession_state = profession_state
		var bar: Array = Manager.skill.compute_skill_bar(state, true)

		var palette: RefCounted = ProfessionStatePalette.new()
		palette.profession_state = profession_state
		palette.entry_slot = STATE_ENTRY_SLOT.get(profession_state, SkillBar.SKILL_BAR_SLOT_NONE)
		palette.uid = "State: " + _state_label(profession_state)
		palette.display_name = _state_label(profession_state)
		palette.absorb_skill_bar(bar, SkillConstants.WEAPON_SKILL_BAR)
		palette.absorb_skill_bar(bar, TOOLBELT_SLOTS)
		_add(palette)


static func _build_transforms(character: AgentChar) -> void:
	var base: CharacterState = CharacterState.from_agent(character)
	var bar: Array = Manager.skill.compute_skill_bar(base, true)
	var granting_slots: Array = SkillConstants.HEAL_SKILL_BAR + SkillConstants.UTILITY_SKILL_BAR + SkillConstants.ELITE_SKILL_BAR

	for slot: int in granting_slots:
		if slot >= bar.size():
			continue
		var grant: AbilityDef = bar[slot]
		if not grant:
			continue
		for reference: Variant in grant.palettes:
			if not reference or reference.palette_type != _PALETTE_TYPE_TRANSFORM:
				continue
			var definition: Variant = reference.get_def()
			if definition is not SkillPaletteDef:
				continue

			var state: CharacterState = CharacterState.from_agent(character)
			state.transformation_skills = [definition as SkillPaletteDef]
			var transformed: Array = Manager.skill.compute_skill_bar(state, true)

			var palette: RefCounted = TransformPalette.new()
			palette.palette_def = definition
			palette.grant_skill = grant
			palette.grant_slot = slot
			palette.uid = "Kit: " + grant.skill_name
			palette.display_name = grant.skill_name
			palette.icon = Palette.skill_icon(grant)
			palette.absorb_skill_bar(transformed, SkillConstants.WEAPON_SKILL_BAR)
			palette.absorb_skill_bar(transformed, TOOLBELT_SLOTS)
			_add(palette)


static func _build_common(character: AgentChar) -> void:
	var state: CharacterState = CharacterState.from_agent(character)
	var bar: Array = Manager.skill.compute_skill_bar(state, true)

	var palette: RefCounted = UtilityPalette.new()
	palette.uid = UtilityPalette.UID
	palette.display_name = "Common"
	palette.absorb_skill_bar(bar, SkillConstants.HEAL_SKILL_BAR)
	palette.absorb_skill_bar(bar, SkillConstants.UTILITY_SKILL_BAR)
	palette.absorb_skill_bar(bar, SkillConstants.ELITE_SKILL_BAR)
	palette.absorb_skill_bar(bar, TOOLBELT_SLOTS)
	palette.absorb_skill_bar(bar, SkillConstants.EXTRA_BAR)
	# The common palette always exists, even on a character with an empty bar,
	# because it also carries dodge and weapon swap.
	palette.absorb_followups()
	_palettes[palette.uid] = palette


static func _weapon_set_label(state: CharacterState, fallback: String) -> String:
	var mainhand: String = _weapon_label(state.mainhand_weapon_type)
	var offhand: String = _weapon_label(state.offhand_weapon_type)
	if mainhand.is_empty() and offhand.is_empty():
		return fallback
	if offhand.is_empty() or offhand == mainhand:
		return mainhand
	if mainhand.is_empty():
		return offhand
	return mainhand + " / " + offhand


static func _weapon_label(weapon_type: int) -> String:
	for key: String in ItemConstants.WeaponType.keys():
		if ItemConstants.WeaponType[key] != weapon_type:
			continue
		return key.trim_prefix("WEAPON_TYPE_").capitalize()
	return ""


static func _state_label(profession_state: int) -> String:
	for key: String in SkillConstants.ProfessionState.keys():
		if SkillConstants.ProfessionState[key] != profession_state:
			continue
		return key.capitalize()
	return "State %d" % profession_state


## Cheap fingerprint of everything that changes which palettes exist. Profession
## state is deliberately excluded: attuning should not rebuild the registry.
static func _build_signature(character: AgentChar) -> String:
	var parts: Array[String] = []
	if character.has_component(CoreStats) and character.core_stats.profession_def:
		parts.append(str(character.core_stats.profession_def.id))
	if character.has_component(Player) and character.player.specializations[2].def:
		parts.append(str(character.player.specializations[2].def.id))
	if character.has_component(ItemStorage):
		for weapon_set: int in WEAPON_SET_NAMES:
			var state: CharacterState = CharacterState.from_agent(character)
			state.update_weapon_set(character, weapon_set)
			parts.append("%d:%d" % [state.mainhand_weapon_type, state.offhand_weapon_type])
	if character.has_component(SkillBar):
		for skill: Variant in character.skill_bar.skills:
			parts.append(str(skill.id) if skill else "0")
	return "|".join(parts)
