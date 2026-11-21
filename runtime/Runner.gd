extends CombatManager.CombatRoutine

## The SkillManager cast loop, the port of `sm_profile:Cast` (sm_profile.lua:289-488).
##
## [method process_tick] is the idiomatic entry point, but CombatManager only
## calls it while auto-combat is on and an attack target exists. GW2Minion had no
## such gate and happily fired self-heals with nothing targeted, so the plugin
## also drives [method tick] directly when "Run without a target" is enabled.
## Both paths run the same code.

const Context := preload("res://plugins/skill_manager/runtime/Context.gd")
const Skill := preload("res://plugins/skill_manager/resources/Skill.gd")
const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")
const PaletteRegistry := preload("res://plugins/skill_manager/runtime/palettes/PaletteRegistry.gd")

const SETTINGS_SECTION := "SkillManager"

## Evaluation rate. The Lua throttled to 50 ms in two places, once for the
## context refresh and once for the cast loop.
const TICK_INTERVAL_MS := 50
## How long to wait for a palette swap to land before giving up on it.
const PALETTE_SWAP_TIMEOUT_MS := 300
## Fallback follow-up window for a combo skill with no declared cast time.
const DEFAULT_COMBO_WINDOW_MS := 750
## Multiplier the Lua applied to the declared cast time when arming the internal
## cooldown, giving every skill a 1% margin over its own animation.
const CAST_TIME_MARGIN := 1010.0

## Emitted after every evaluation pass so the editor can repaint action tiles.
signal evaluated(context: RefCounted)

var profile: Resource = null:
	set = set_profile

## Mirrors the "Swap Weapons" combo: 1 automatic, 2 manual.
var weapon_swap_mode: int = 1
## Mirrors the "Network Latency" slider, in milliseconds.
var network_latency: int = 0

var context: RefCounted = null

var _last_tick: int = 0
var _next_cast: int = 0
var _last_cast: int = 0

var _pending_activate: RefCounted = null
var _pending_activate_at: int = 0
var _pending_deactivate: RefCounted = null
var _pending_deactivate_at: int = 0

var _combo_follow_up: Resource = null
var _combo_deadline: int = 0

var _paused: bool = false

static var _logger := ScopedLogger.create("SkillManager")


func set_profile(value: Resource) -> void:
	profile = value
	_reset()


func _reset() -> void:
	_next_cast = 0
	_last_cast = 0
	_pending_activate = null
	_pending_deactivate = null
	_combo_follow_up = null
	_combo_deadline = 0
	if profile:
		for action: Resource in profile.actionlist:
			if action:
				for link: Resource in action.chain():
					link.internal_cd = 0
					link.invalidate_script()


# --- CombatRoutine contract ---------------------------------------------------

func is_available(state: CharacterState) -> bool:
	if not profile:
		return false
	if not state.profession:
		return false
	return state.profession.id == profile.profession


## Activation means "this is the selected routine", not "ready to cast".
## CombatManager restores the saved routine as soon as it is registered and
## again when the combat settings load -- both before the plugin has read a
## profile, which only happens once the character has spawned. Refusing here
## left the routine permanently off, since nothing retried. The loop already
## idles while [member profile] is null, so accepting is safe.
func activate() -> bool:
	_reset()
	if not profile:
		_logger.trace("Activated with no profile loaded yet; idling until one is selected")
	return true


func deactivate() -> void:
	_reset()


func pause(paused: bool) -> void:
	_paused = paused


func exit_combat() -> void:
	_combo_follow_up = null
	_combo_deadline = 0


func process_tick() -> void:
	tick()


# --- the loop -----------------------------------------------------------------

## One evaluation pass. Safe to call with no target and outside combat.
func tick() -> void:
	if _paused or not profile:
		return
	var player: AgentChar = Manager.agent.controlled_character
	if not player or not Context.is_alive(player):
		return

	var now: int = Time.get_ticks_msec()
	if now - _last_tick < TICK_INTERVAL_MS:
		return
	_last_tick = now

	context = Context.build(profile.actionlist, context)
	_refresh_actions()
	evaluated.emit(context)

	if not _palette_swap_settled(now):
		return
	_cast_pass(now)


## Refreshes every action's verdict.
##
## The fight distance and the attitude of what counts as an enemy are not
## decided here: they come from the gw2cc Settings > Combat > Target Filter
## (Manager.combat.default_target_filter), which CombatManager already applies
## when it picks the attack target and which Context applies when it collects
## the nearby enemies. GW2Minion let each profile publish its own range; this
## routine deliberately never writes to the shared filter, so what the user set
## in the menu stays in force.
func _refresh_actions() -> void:
	for action: Resource in profile.actionlist:
		if not action:
			continue
		action.update(context)


## Holds the loop while a palette swap is in flight, giving up after
## [constant PALETTE_SWAP_TIMEOUT_MS] so a refused swap cannot wedge the rotation.
func _palette_swap_settled(now: int) -> bool:
	if _pending_deactivate:
		if not _pending_deactivate.is_active(context):
			_pending_deactivate = null
		elif now - _pending_deactivate_at > PALETTE_SWAP_TIMEOUT_MS:
			_pending_deactivate = null
		else:
			return false

	if _pending_activate:
		if _pending_activate.is_active(context):
			_pending_activate = null
		elif now - _pending_activate_at > PALETTE_SWAP_TIMEOUT_MS:
			_pending_activate = null
		else:
			return false

	return true


## Walks the action list in priority order and fires the first action that can.
func _cast_pass(now: int) -> void:
	var skip_non_instant := false

	for entry: Resource in profile.actionlist:
		var action: Resource = _resolve_action(entry, now)
		if not action:
			continue

		if not action.cancast:
			if _combo_follow_up:
				return
			continue
		if action.is_casting(context) and not action.instantcast:
			continue
		if skip_non_instant and not action.instantcast:
			continue

		var globally_free: bool = _next_cast == 0 or now >= _next_cast
		if not globally_free and not action.instantcast:
			continue
		if not action.is_cast_target_valid(context):
			continue

		var palette: RefCounted = action.palette()
		if palette and not palette.is_active(context):
			if weapon_swap_mode != 1:
				continue
			if _swap_to(palette, now):
				return
			skip_non_instant = true
			continue

		if _fire(action, now):
			return

		if _combo_follow_up:
			return


## Substitutes a pending combo follow-up for the action the loop is looking at,
## and drops it once its window has closed.
func _resolve_action(entry: Resource, now: int) -> Resource:
	if not _combo_follow_up:
		return entry
	if now - _combo_deadline > PALETTE_SWAP_TIMEOUT_MS:
		_combo_follow_up = null
		_combo_deadline = 0
		return entry
	return _combo_follow_up


## Deactivates whatever else is active first, then activates the wanted palette.
## Returns true when the caller should stop the pass.
func _swap_to(palette: RefCounted, now: int) -> bool:
	for other: RefCounted in PaletteRegistry.palettes().values():
		if other == palette or not other.is_active(context):
			continue
		if not other.deactivate(context):
			continue
		_logger.debug("Deactivating skill set " + other.uid)
		_pending_deactivate = other
		_pending_deactivate_at = now
		return false

	if not palette.can_activate(context):
		return false

	_logger.debug("Activating skill set " + palette.uid)
	palette.activate(context)
	_pending_activate = palette
	_pending_activate_at = now
	return true


## Issues the cast. Returns true when something was actually sent.
func _fire(action: Resource, now: int) -> bool:
	var target: Agent = action.cast_target_agent(context)
	if not target:
		return false

	if action.is_synthetic():
		if not _fire_synthetic(action):
			return false
	else:
		if not _fire_skill(action, target):
			return false

	_logger.debug("Casting %s at %s" % [action.display_name(), AgentUtils.get_agent_name(target)])
	_arm_cooldowns(action, now)
	return true


func _fire_synthetic(action: Resource) -> bool:
	match action.id:
		Skill.SYNTHETIC_DODGE:
			Manager.character_controller.move_evade(CharacterController.EVADE_FORWARD)
			return true
		Skill.SYNTHETIC_WEAPON_SWAP:
			Manager.character_controller.cycle_active_weapon_set()
			return true
	return false


func _fire_skill(action: Resource, target: Agent) -> bool:
	var skill: AbilityDef = action.ability()
	if not skill:
		return false
	var slot: int = action.live_slot(context)
	if slot == SkillBar.SKILL_BAR_SLOT_NONE:
		return false

	if not SkillState.is_ground_targeted(skill):
		Manager.skill.target = target
	Manager.combat.queue_skill(slot, skill)
	return true


## Reproduces the Lua timing model: a per-skill guard always, a global busy
## window only for skills that actually occupy the cast bar, and the combo
## follow-up armed behind both.
func _arm_cooldowns(action: Resource, now: int) -> void:
	var cast_time: int = int(action.activationtime * CAST_TIME_MARGIN) + network_latency
	action.internal_cd = now + cast_time

	if not action.instantcast:
		_next_cast = now + cast_time
		_last_cast = now

	if action.skill_next:
		var window: int = int(action.skill_next.activationtime * 1000.0)
		if window == 0:
			window = DEFAULT_COMBO_WINDOW_MS
		_combo_follow_up = action.skill_next
		_combo_deadline = now + cast_time + window
	else:
		_combo_follow_up = null
		_combo_deadline = 0


# --- settings -----------------------------------------------------------------

func load_settings() -> void:
	weapon_swap_mode = ConfigService.get_value(SETTINGS_SECTION, "weaponswapmode", 1)
	network_latency = ConfigService.get_value(SETTINGS_SECTION, "networklatency", 0)
