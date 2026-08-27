extends Resource

## One entry of a profile action list, the port of `sm_skill.lua`.
##
## Combo and flip skills form a linked list through [member skill_next]; the back
## reference is rebuilt at load time and never serialized, same as the Lua.

const Context := preload("res://plugins/skill_manager/runtime/Context.gd")
const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")
const ScriptSandbox := preload("res://plugins/skill_manager/runtime/ScriptSandbox.gd")
const PaletteRegistry := preload("res://plugins/skill_manager/runtime/palettes/PaletteRegistry.gd")

## Fictional slot for the non-skill actions, kept at the Lua value so old
## profiles keep meaning the same thing (sm_skill.lua:388).
const SLOT_SYNTHETIC := 555
## Synthetic action ids on [constant SLOT_SYNTHETIC].
const SYNTHETIC_DODGE := 10
const SYNTHETIC_WEAPON_SWAP := 20

@export var id: int = 0
@export var skillpaletteuid: String = ""
@export var slot: int = SkillBar.SKILL_BAR_SLOT_NONE
@export var setsattackrange: bool = false
@export var requireslos: bool = true
@export var activationtime: float = 0.0
@export var instantcast: bool = false
@export var condition_code: String = "return true"
@export var conditions: Array[Resource] = []
@export var skill_next: Resource = null

## Back reference into the combo chain. Runtime only.
var skill_prev: Resource = null

## Verdict of the last [method update] pass.
var cancast: bool = false
## Set when this link of a combo chain is castable as a flip skill.
var cancast_flip_combo: bool = false
## Cast target chosen by the condition group that passed, 0 when none did.
var cast_target: int = 0
## Anti-spam guard, a msec timestamp.
var internal_cd: int = 0
## True while this skill is being evaluated as a combo continuation.
var is_combo: bool = false

var _compiled: RefCounted = null
var _compile_failed: bool = false


func is_synthetic() -> bool:
	return slot == SLOT_SYNTHETIC


func ability() -> AbilityDef:
	if is_synthetic():
		return null
	return SkillState.by_id(id)


func display_name() -> String:
	if is_synthetic():
		return "Dodge" if id == SYNTHETIC_DODGE else "Swap Weaponset"
	var skill: AbilityDef = ability()
	return skill.skill_name if skill else "<unknown %d>" % id


func icon_texture() -> Texture2D:
	var skill: AbilityDef = ability()
	if not skill or skill.icon == 0:
		return null
	var path := ContentService.get_asset_path(skill.icon)
	if path.is_empty() or path.ends_with("/Unknown/0"):
		return null
	return load(path) as Texture2D


## Rebuilds [member skill_prev] down the chain after a load.
func relink() -> void:
	var link: Resource = self
	while link and link.skill_next:
		link.skill_next.skill_prev = link
		link = link.skill_next


## Every link of the combo chain, starting at this one.
func chain() -> Array[Resource]:
	var links: Array[Resource] = []
	var link: Resource = self
	while link:
		links.append(link)
		link = link.skill_next
	return links


func invalidate_script() -> void:
	_compiled = null
	_compile_failed = false


# --- evaluation ---------------------------------------------------------------

func palette() -> RefCounted:
	if skillpaletteuid.is_empty():
		return null
	return PaletteRegistry.get_palette(skillpaletteuid)


## The slot this skill would occupy, preferring the live bar over the palette so
## heal and utility skills follow the player moving them around.
func live_slot(context: RefCounted) -> int:
	if is_synthetic():
		return SLOT_SYNTHETIC
	var player: AgentChar = context.player
	if player and player.has_component(SkillBar):
		var bar: Array = player.skill_bar.skills
		for index in bar.size():
			if bar[index] and bar[index].id == id:
				return index
	var owner: RefCounted = palette()
	if owner:
		return owner.slot_of(id)
	return slot


## Port of `sm_skill:IsEquipped` (sm_skill.lua:730-768). Flip skills only count
## when their palette is active and they are actually sitting in their slot.
func is_equipped(context: RefCounted) -> bool:
	if is_synthetic():
		return true
	var owner: RefCounted = palette()
	if not owner:
		return false
	var player: AgentChar = context.player
	if not player or not player.has_component(SkillBar):
		return false

	var bar: Array = player.skill_bar.skills
	var palette_slot: int = owner.slot_of(id)

	if palette_slot in SkillConstants.WEAPON_SKILL_BAR:
		if not owner.is_flip(id):
			return true
		if not owner.is_active(context):
			return false
		return palette_slot < bar.size() and bar[palette_slot] and bar[palette_slot].id == id

	if not owner.is_active(context):
		return false
	for sibling: int in _sibling_slots(palette_slot):
		if sibling < bar.size() and bar[sibling] and bar[sibling].id == id:
			return true
	return false


## The slots a skill of this kind is allowed to drift between. Heal, utility and
## elite skills can be reordered by the player, and the Lua accepted any of them.
static func _sibling_slots(palette_slot: int) -> Array:
	if palette_slot in SkillConstants.HEAL_SKILL_BAR:
		return SkillConstants.HEAL_SKILL_BAR
	if palette_slot in SkillConstants.UTILITY_SKILL_BAR:
		return SkillConstants.UTILITY_SKILL_BAR
	if palette_slot in SkillConstants.ELITE_SKILL_BAR:
		return SkillConstants.ELITE_SKILL_BAR
	if palette_slot in SkillConstants.PROFESSION_BAR:
		return SkillConstants.PROFESSION_BAR
	return [palette_slot]


## True when the engine would let the skill fire: off cooldown and affordable.
func engine_ready(context: RefCounted) -> bool:
	if is_synthetic():
		return _synthetic_ready(context)
	var skill: AbilityDef = ability()
	if not skill:
		return false
	return SkillUtils.skill_cd_ready(skill) and SkillUtils.check_resources(skill)


func _synthetic_ready(context: RefCounted) -> bool:
	var player: AgentChar = context.player
	if not player:
		return false
	if id == SYNTHETIC_DODGE:
		if not player.has_component(Endurance):
			return false
		return player.endurance.current >= 50.0
	if id == SYNTHETIC_WEAPON_SWAP:
		return SkillUtils.can_weapon_swap()
	return false


## Port of `sm_skill:CanCast` (sm_skill.lua:771-839). Evaluation order is load
## bearing: palette, internal cooldown, water, condition groups, custom code, LoS.
func can_cast(context: RefCounted) -> bool:
	cast_target = 0
	if id == 0:
		return false

	var owner: RefCounted = palette()
	if not owner:
		return false
	if not engine_ready(context):
		return false
	if not owner.is_active(context) and not owner.can_activate(context):
		return false

	if internal_cd > 0 and context.now < internal_cd:
		return false

	if context.swimming == Context.SWIM_DIVING and SkillState.no_underwater(ability()):
		return false

	# Groups are OR-ed, conditions inside a group are AND-ed. An action with no
	# groups is always castable at the enemy, which is what the Lua did too.
	cast_target = Context.CAST_ENEMY
	for group: Resource in conditions:
		if not group:
			continue
		if group.evaluate(self, context):
			cast_target = group.casttarget
			break
		cast_target = 0

	if cast_target == 0:
		return false

	context.cast_target = cast_target
	if not _run_custom_condition(context):
		cast_target = 0
		return false
	cast_target = context.cast_target

	if requireslos and cast_target != Context.CAST_PLAYER:
		var target: Agent = context.cast_target_agent()
		if target and not _has_line_of_sight(context.player, target):
			cast_target = 0
			return false

	return cast_target != 0


func _run_custom_condition(context: RefCounted) -> bool:
	if condition_code.strip_edges().is_empty():
		return true
	if _compile_failed:
		return true
	if not _compiled:
		_compiled = ScriptSandbox.compile_predicate(condition_code, "skill " + str(id))
		if not _compiled:
			_compile_failed = true
			return true
	var result: Variant = _compiled.evaluate(self, context)
	return result == null or bool(result)


static func _has_line_of_sight(from: AgentChar, to: Agent) -> bool:
	if not from or not to:
		return false
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = Layers.PHYSICS_LAYER_ENVIRONMENT
	query.from = from.global_transform.origin + Vector3(0.0, 2.25, 0.0)
	query.to = to.global_transform.origin + Vector3(0.0, 2.25, 0.0)
	var result: Dictionary = from.get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.collider == to


## Refreshes [member cancast] for this link and everything below it in the combo
## chain. Port of `sm_skill:UpdateData` (sm_skill.lua:376-481).
func update(context: RefCounted, combo: bool = false) -> bool:
	is_combo = combo
	cancast_flip_combo = false

	if skill_next:
		cancast = skill_next.update(context, true)

	var verdict: bool = can_cast(context)
	if cancast or not skill_next:
		var owner: RefCounted = palette()
		cancast_flip_combo = combo and verdict and owner != null and owner.is_flip(id)
		cancast = verdict and is_equipped(context)

	return cancast or cancast_flip_combo


func is_cast_target_valid(context: RefCounted) -> bool:
	return _target_for(cast_target, context) != null


func cast_target_agent(context: RefCounted) -> Agent:
	return _target_for(cast_target, context)


func _target_for(which: int, context: RefCounted) -> Agent:
	match which:
		Context.CAST_ENEMY:
			return context.attack_target
		Context.CAST_PLAYER:
			return context.player
		Context.CAST_FRIEND:
			return context.heal_target
	return null


## True while the player is casting this exact skill.
func is_casting(context: RefCounted) -> bool:
	if is_synthetic():
		return false
	return Context.casting_id(context.player) == id
