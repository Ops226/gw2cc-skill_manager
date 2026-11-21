extends "res://plugins/skill_manager/runtime/palettes/Palette.gd"

## Every skill one weapon type gives the profession, equipped or not. This is
## what GW2Minion's weapon palettes actually were -- "Greatsword", "Dagger",
## "Focus" -- as opposed to the equipped-set palettes, which answer "what is on
## set 1 right now". A profile built from these keeps working when the weapon
## moves to the other set, and can be written before the weapon is even owned.
##
## Activation is the same weapon swap as a set palette: active when the weapon
## is on the current set, reachable when it is on the other set of the same
## element.

const NO_WEAPON := -1

var weapon_type: int = -1


func is_active(context: RefCounted) -> bool:
	return weapon_type in _types_on(context, _active_set(context))


func can_activate(context: RefCounted) -> bool:
	if is_active(context):
		return true
	var current: int = _active_set(context)
	if current < 0:
		return false
	if weapon_type not in _types_on(context, _other_set(current)):
		return false
	return SkillUtils.can_weapon_swap()


func activate(_context: RefCounted) -> void:
	Manager.character_controller.cycle_active_weapon_set()


func deactivate(context: RefCounted) -> bool:
	if not is_active(context):
		return false
	if not SkillUtils.can_weapon_swap():
		return false
	Manager.character_controller.cycle_active_weapon_set()
	return true


static func _active_set(context: RefCounted) -> int:
	var player: AgentChar = context.player
	if not player or not player.has_component(ItemStorage):
		return -1
	return player.item_storage.active_weapon_set


## The set a weapon swap lands on from [param current]: the other land set, or
## the other aquatic set.
static func _other_set(current: int) -> int:
	match current:
		ItemStorage.WEAPON_SET_LAND_1:
			return ItemStorage.WEAPON_SET_LAND_2
		ItemStorage.WEAPON_SET_LAND_2:
			return ItemStorage.WEAPON_SET_LAND_1
		ItemStorage.WEAPON_SET_AQUATIC_1:
			return ItemStorage.WEAPON_SET_AQUATIC_2
		ItemStorage.WEAPON_SET_AQUATIC_2:
			return ItemStorage.WEAPON_SET_AQUATIC_1
	return -1


## The weapon types held on a set, read from the context's cached snapshot. An
## empty hand reports [constant Context.NO_WEAPON], never a real type.
static func _types_on(context: RefCounted, weapon_set: int) -> Array:
	match weapon_set:
		ItemStorage.WEAPON_SET_LAND_1:
			return [context.mainhand, context.offhand]
		ItemStorage.WEAPON_SET_LAND_2:
			return [context.mainhand_alt, context.offhand_alt]
		ItemStorage.WEAPON_SET_AQUATIC_1:
			return [context.aquatic]
		ItemStorage.WEAPON_SET_AQUATIC_2:
			return [context.aquatic_alt]
	return []
