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
const WeaponTypePalette := preload("res://plugins/skill_manager/runtime/palettes/WeaponTypePalette.gd")

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

## SkillPaletteSkill.mainhand_item_type / offhand_item_type sentinels, mirrored
## from SkillManager.gd: anything below these is a real ItemConstants.WeaponType.
const _ITEM_TYPE_IGNORED := 24
const _ITEM_TYPE_EMPTY := 25

const _WEAPON_SLOT_TYPES: Array[int] = [
	SkillConstants.SkillPaletteSlotType.SLOT_TYPE_WEAPON_1,
	SkillConstants.SkillPaletteSlotType.SLOT_TYPE_WEAPON_2,
	SkillConstants.SkillPaletteSlotType.SLOT_TYPE_WEAPON_3,
	SkillConstants.SkillPaletteSlotType.SLOT_TYPE_WEAPON_4,
	SkillConstants.SkillPaletteSlotType.SLOT_TYPE_WEAPON_5,
]
const _MAINHAND_SLOT_TYPES: Array[int] = [
	SkillConstants.SkillPaletteSlotType.SLOT_TYPE_WEAPON_1,
	SkillConstants.SkillPaletteSlotType.SLOT_TYPE_WEAPON_2,
	SkillConstants.SkillPaletteSlotType.SLOT_TYPE_WEAPON_3,
]

## The placeholder the content uses for an unfilled variant.
const _LOCKED_SKILL_NAME := "Locked"

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
	_build_all_weapons(character)
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
		var state: CharacterState = _state_for_set(character, weapon_set)
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


## A snapshot holding exactly the weapons of one set. update_weapon_set only
## overwrites the hands that set fills, so the active set's weapons would leak
## into an empty set without the reset.
static func _state_for_set(character: AgentChar, weapon_set: int) -> CharacterState:
	var state: CharacterState = CharacterState.from_agent(character)
	state.mainhand_palette = null
	state.offhand_palette = null
	state.update_weapon_set(character, weapon_set)
	return state


## Every weapon the profession can wield, one palette per weapon type, whether
## or not it is equipped. GW2Minion's weapon palettes worked this way, and it
## is what lets a profile be written for a weapon before it is on the bar.
##
## The content lists weapon skills as palette slots whose variants name the
## weapon they need, so the weapon type comes off the variant rather than off
## an item.
static func _build_all_weapons(character: AgentChar) -> void:
	var profession: ProfessionDef = character.core_stats.profession_def
	var by_type: Dictionary[int, RefCounted] = {}

	for palette_def: SkillPaletteDef in _profession_palette_defs(profession):
		if palette_def.palette_type == _PALETTE_TYPE_TRANSFORM:
			continue
		for slot: SkillPaletteSlot in palette_def.skills:
			if not slot or slot.slot_type not in _WEAPON_SLOT_TYPES:
				continue
			if slot.profession and slot.profession != profession.id:
				continue
			var bar_slot: int = SkillConstants.palette_slot_to_skillbar_slot(slot.slot_type)
			for variant: SkillPaletteSkill in slot.skill_variants:
				var weapon_type := _variant_weapon_type(variant, slot.slot_type)
				if weapon_type < 0:
					continue
				var label := _weapon_label(weapon_type)
				if label.is_empty():
					continue
				var skill: Variant = variant.ability.get_def() if variant.ability else null
				if skill is not AbilityDef or skill.skill_name == _LOCKED_SKILL_NAME:
					continue

				var palette: RefCounted = by_type.get(weapon_type)
				if not palette:
					palette = WeaponTypePalette.new()
					palette.weapon_type = weapon_type
					palette.uid = "Weapon: " + label
					palette.display_name = label
					by_type[weapon_type] = palette
				palette.add_skill(skill, bar_slot)
				_note_specialization(palette, variant, skill)

	var types: Array = by_type.keys()
	types.sort()
	for weapon_type: int in types:
		_add(by_type[weapon_type])


## The weapon a variant needs, or -1 when it is not a weapon skill. Skills 1 to
## 3 belong to the mainhand; 4 and 5 to the offhand, or to a two-handed
## mainhand when the offhand requirement is not a weapon.
static func _variant_weapon_type(variant: SkillPaletteSkill, slot_type: int) -> int:
	var mainhand: int = variant.mainhand_item_type
	var offhand: int = variant.offhand_item_type
	if slot_type in _MAINHAND_SLOT_TYPES:
		return mainhand if _is_weapon_type(mainhand) else -1
	if _is_weapon_type(offhand):
		return offhand
	if _is_weapon_type(mainhand):
		return mainhand
	return -1


static func _is_weapon_type(item_type: int) -> bool:
	return item_type >= 0 and item_type < _ITEM_TYPE_IGNORED


## Every skill palette the profession's content refers to: the ones listed on
## the profession itself plus the ones each of its skills belongs to. Together
## they cover every weapon, heal, utility, elite and mechanic of every
## specialization, not only what is equipped.
static func _profession_palette_defs(profession: ProfessionDef) -> Array:
	var seen: Dictionary[int, SkillPaletteDef] = {}
	for reference: Variant in profession.skill_palettes:
		var definition: Variant = reference.get_def() if reference else null
		if definition is SkillPaletteDef:
			seen[definition.id] = definition
	for entry: Variant in profession.skills:
		if not entry or not entry.skill_def:
			continue
		var skill: Variant = entry.skill_def.get_def()
		if skill is not AbilityDef:
			continue
		for reference: Variant in skill.palettes:
			var definition: Variant = reference.get_def() if reference else null
			if definition is SkillPaletteDef:
				seen[definition.id] = definition
	return seen.values()


## Adds every heal, utility, elite and profession skill of the profession to the
## common palette, equipped or not, so a profile can be written for a build
## before it is slotted. The bar slot recorded is the one the content assigns;
## Skill.is_equipped accepts any sibling slot at run time.
static func _absorb_profession_skills(palette: RefCounted, character: AgentChar) -> void:
	var profession: ProfessionDef = character.core_stats.profession_def
	for palette_def: SkillPaletteDef in _profession_palette_defs(profession):
		if palette_def.palette_type == _PALETTE_TYPE_TRANSFORM:
			continue
		for slot: SkillPaletteSlot in palette_def.skills:
			if not slot:
				continue
			if slot.profession and slot.profession != profession.id:
				continue
			var bar_slot: int = SkillConstants.palette_slot_to_skillbar_slot(slot.slot_type)
			if not _is_common_slot(bar_slot):
				continue
			for variant: SkillPaletteSkill in slot.skill_variants:
				var skill: Variant = variant.ability.get_def() if variant.ability else null
				if skill is not AbilityDef or skill.skill_name == _LOCKED_SKILL_NAME:
					continue
				palette.add_skill(skill, bar_slot)
				_note_specialization(palette, variant, skill)


static func _is_common_slot(bar_slot: int) -> bool:
	return bar_slot in SkillConstants.HEAL_SKILL_BAR \
		or bar_slot in SkillConstants.UTILITY_SKILL_BAR \
		or bar_slot in SkillConstants.ELITE_SKILL_BAR \
		or bar_slot in TOOLBELT_SLOTS


static func _note_specialization(palette: RefCounted, variant: SkillPaletteSkill, skill: AbilityDef) -> void:
	if not variant.specialization or palette.specializations.has(skill.id):
		return
	var spec: Variant = variant.specialization.get_def()
	if spec is SpecializationDef:
		palette.specializations[skill.id] = spec.specialization_name


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
	# What is on the bar comes first, so it keeps its live slot; every other
	# heal, utility, elite and mechanic of the profession follows.
	_absorb_profession_skills(palette, character)
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
			var state: CharacterState = _state_for_set(character, weapon_set)
			parts.append("%d:%d" % [
				state.mainhand_weapon_type if state.mainhand_palette else -1,
				state.offhand_weapon_type if state.offhand_palette else -1])
	if character.has_component(SkillBar):
		for skill: Variant in character.skill_bar.skills:
			parts.append(str(skill.id) if skill else "0")
	return "|".join(parts)
