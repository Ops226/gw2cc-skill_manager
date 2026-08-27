extends RefCounted

## The id-to-name skill list the Casting (Name) conditions pick from, replacing
## the Lua `SkillManager.skilllist` that was flattened out of the hardcoded
## palette files (sm_mgr.lua:82-97).
##
## It is drawn from the palettes of the current character rather than the whole
## skill chunk, which is both what the original listed and a few hundred entries
## instead of tens of thousands.

const PaletteRegistry := preload("res://plugins/skill_manager/runtime/palettes/PaletteRegistry.gd")

static var _names: Array[String] = []
static var _ids: Array[int] = []
static var _signature: int = 0


## Parallel name and id lists for a combo box, sorted by name.
static func name_and_id_lists() -> Array:
	_rebuild_if_stale()
	return [_names, _ids]


static func _rebuild_if_stale() -> void:
	var palettes: Dictionary = PaletteRegistry.palettes()
	var signature: int = palettes.size()
	if signature == _signature and not _names.is_empty():
		return
	_signature = signature

	var by_id: Dictionary[int, String] = {}
	for uid: String in palettes:
		var palette: RefCounted = palettes[uid]
		for skill: AbilityDef in palette.skills:
			if skill and not skill.skill_name.is_empty():
				by_id[skill.id] = skill.skill_name

	var ids: Array[int] = by_id.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return by_id[a].naturalnocasecmp_to(by_id[b]) < 0
	)

	_names = []
	_ids = []
	for skill_id: int in ids:
		_names.append(by_id[skill_id])
		_ids.append(skill_id)
