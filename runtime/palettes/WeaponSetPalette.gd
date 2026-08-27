extends "res://plugins/skill_manager/runtime/palettes/Palette.gd"

## One equipped weapon set. Replaces every hand-written weapon palette in the Lua
## files, whose bodies all reduced to "am I on this weapon set" plus
## `Player:SwapWeaponSet()`.

var weapon_set: int = ItemStorage.WEAPON_SET_LAND_1


func is_active(context: RefCounted) -> bool:
	var player: AgentChar = context.player
	if not player or not player.has_component(ItemStorage):
		return false
	return player.item_storage.active_weapon_set == weapon_set


func can_activate(context: RefCounted) -> bool:
	if is_active(context):
		return true
	var player: AgentChar = context.player
	if not player or not player.has_component(ItemStorage):
		return false
	if not _is_reachable_by_swap(player.item_storage.active_weapon_set):
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


## A weapon swap only ever toggles between the two sets of the current element,
## so land sets cannot be reached from the water and vice versa.
func _is_reachable_by_swap(current: int) -> bool:
	var land := [ItemStorage.WEAPON_SET_LAND_1, ItemStorage.WEAPON_SET_LAND_2]
	var water := [ItemStorage.WEAPON_SET_AQUATIC_1, ItemStorage.WEAPON_SET_AQUATIC_2]
	if weapon_set in land:
		return current in land
	if weapon_set in water:
		return current in water
	return false
