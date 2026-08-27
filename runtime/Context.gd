extends RefCounted

## Per-tick snapshot of the game state, replacing the Lua `profile.temp.context`
## table (sm_profile.lua:52-277). Rebuilt once per evaluation tick and handed to
## every condition, so no condition ever touches the engine directly.

## Cast target selectors, matching the 1-based values stored in profiles.
const CAST_ENEMY := 1
const CAST_PLAYER := 2
const CAST_FRIEND := 3

## `targets` list order used by most conditions: Target / Player / Friend.
const ORDER_TPF := 0
## `targets` list order used by Alive, Clone, CombatState, Downed, Pet, SwimState:
## Player is / Target is / Friend is.
const ORDER_PTF := 1
## `targets` list order used by Distance: Enemy / Friend.
const ORDER_EF := 2

## The engine works in world units; GW2 -- and therefore every range typed into a
## profile -- works in game units. One world unit is 32 game units, which is what
## TargetFilter.max_distance and AgentUtils.SPEED_FORWARD both encode.
const GAME_UNITS_PER_WORLD_UNIT := 32.0

## Swim states, matching GW2.SWIMSTATE.
const SWIM_NONE := 0
const SWIM_DIVING := 1
const SWIM_SWIMMING := 2

var player: AgentChar = null
var attack_target: Agent = null
var heal_target: Agent = null

var skillbar: Array = []
var actionlist: Array = []

var friends_nearby: Array[Agent] = []
var enemies_nearby: Array[Agent] = []

var now: int = 0

var weaponset: int = 0
var transformid: int = 0
var lasttransformid: int = 0
var canswapweaponset: bool = false
var swimming: int = SWIM_NONE
var endurance: float = 0.0
var power: float = 0.0
var power2: float = 0.0

var mainhand: int = 0
var mainhand_alt: int = 0
var offhand: int = 0
var offhand_alt: int = 0
var aquatic: int = 0
var aquatic_alt: int = 0

## Skill id each agent was last seen casting, so `Casting (Last ...)` has
## something to read. GW2Minion got this from castinfo.lastskillid.
var last_cast_by_agent: Dictionary[int, int] = {}

## Result of the condition-group evaluation for the skill currently being tested.
var cast_target: int = CAST_ENEMY


## Resolves a 1-based combo index against the given list order.
func target_for(index: int, order: int) -> Agent:
	match order:
		ORDER_TPF:
			if index == 1:
				return attack_target
			if index == 2:
				return player
			if index == 3:
				return heal_target
		ORDER_PTF:
			if index == 1:
				return player
			if index == 2:
				return attack_target
			if index == 3:
				return heal_target
		ORDER_EF:
			if index == 1:
				return attack_target
			if index == 2:
				return heal_target
	return null


func cast_target_agent() -> Agent:
	match cast_target:
		CAST_ENEMY:
			return attack_target
		CAST_PLAYER:
			return player
		CAST_FRIEND:
			return heal_target
	return null


# --- static accessors, so conditions never touch the engine API directly -------

static func hp_percent(agent: Agent) -> float:
	if not agent or not agent.has_component(HealthBar):
		return -1.0
	var bar := agent.health_bar
	if bar.health_max <= 0.0:
		return -1.0
	return bar.health_curr / bar.health_max * 100.0


static func hp_current(agent: Agent) -> float:
	if not agent or not agent.has_component(HealthBar):
		return -1.0
	return agent.health_bar.health_curr


static func hp_max(agent: Agent) -> float:
	if not agent or not agent.has_component(HealthBar):
		return -1.0
	return agent.health_bar.health_max


static func is_alive(agent: Agent) -> bool:
	if not agent or not agent.has_component(HealthBar):
		return false
	return agent.health_bar.dead_state != HealthBar.DEAD_STATE_DEAD


static func is_downed(agent: Agent) -> bool:
	if not agent or not agent.has_component(HealthBar):
		return false
	return agent.health_bar.dead_state == HealthBar.DEAD_STATE_DOWNED


static func in_combat(agent: Agent) -> bool:
	if not agent or agent is not AgentChar:
		return false
	return (agent as AgentChar).in_combat


static func is_moving(agent: Agent) -> bool:
	if not agent:
		return false
	return agent.speed > 0.0


## True when the agent holds aggro, the engine's own equivalent of the Lua
## `isaggro` flag.
static func has_aggro(agent: Agent) -> bool:
	if not agent or agent is not AgentChar:
		return false
	return (agent as AgentChar).aggro != 0


## The agent that summoned this one, or null when it stands on its own.
static func owner_of(agent: Agent) -> Agent:
	if not agent or not agent.controller or not agent.controller.is_valid():
		return null
	var owner: Agent = agent.controller.get_agent()
	return null if owner == agent else owner


## A ranger pet is the agent its owner's kennel points at. Everything else with
## an owner -- clones, phantasms, minions, turrets -- counts as a clone, which is
## the split GW2Minion drew between its `ispet` and `isclone` flags.
static func is_pet(agent: Agent) -> bool:
	var owner: Agent = owner_of(agent)
	if not owner or not owner.has_component(Kennel):
		return false
	var pet: AgentRef = owner.kennel.pet
	return pet != null and pet.is_valid() and pet.get_agent_id() == agent.id


static func is_clone(agent: Agent) -> bool:
	if not agent or agent is not AgentChar:
		return false
	if (agent as AgentChar).is_player:
		return false
	return owner_of(agent) != null and not is_pet(agent)


static func casting_id(agent: Agent) -> int:
	if not agent:
		return 0
	var info: CastInfo = agent.cast_info
	if not info or not info.skill:
		return 0
	return info.skill.id


## Buff id -> stack count for the agent.
static func buff_stacks(agent: Agent) -> Dictionary:
	var stacks: Dictionary[int, int] = {}
	if not agent or not agent.has_component(BuffMonitor):
		return stacks
	for handle: int in agent.buff_monitor.buffs:
		var buff: Buff = agent.buff_monitor.buffs[handle]
		if not buff.def:
			continue
		stacks[buff.def.id] = stacks.get(buff.def.id, 0) + 1
	return stacks


## Counts distinct buffs on the agent whose name is in `names`.
static func count_named_buffs(agent: Agent, names: Array) -> int:
	if not agent or not agent.has_component(BuffMonitor):
		return 0
	var seen: Dictionary[int, bool] = {}
	for handle: int in agent.buff_monitor.buffs:
		var buff: Buff = agent.buff_monitor.buffs[handle]
		if buff.def and buff.def.skill_name in names:
			seen[buff.def.id] = true
	return seen.size()


## Counts distinct buffs on the agent whose id is in `ids`.
static func count_id_buffs(agent: Agent, ids: Array) -> int:
	if not agent or not agent.has_component(BuffMonitor):
		return 0
	var seen: Dictionary[int, bool] = {}
	for handle: int in agent.buff_monitor.buffs:
		var buff: Buff = agent.buff_monitor.buffs[handle]
		if buff.def and buff.def.id in ids:
			seen[buff.def.id] = true
	return seen.size()


static func swim_state(agent: Agent) -> int:
	if not agent or agent is not AgentChar:
		return SWIM_NONE
	match (agent as AgentChar).motion_state:
		AgentChar.MOTION_STATE_DIVE:
			return SWIM_DIVING
		AgentChar.MOTION_STATE_SWIM:
			return SWIM_SWIMMING
	return SWIM_NONE


## Break bar fill in percent, or -1 when the agent has no break bar. The engine
## stores it as a 0-1 fraction, as the Lua noted about its own reading.
static func breakbar_percent(agent: Agent) -> float:
	if not agent or not agent.has_component(BreakBar):
		return -1.0
	return agent.break_bar.current * 100.0


static func breakbar_state(agent: Agent) -> int:
	if not agent or not agent.has_component(BreakBar):
		return -1
	return agent.break_bar.state


## The content / species id of an agent, the equivalent of the Lua `contentid`.
static func content_id(agent: Agent) -> int:
	if not agent or not agent.has_component(Species):
		return 0
	if not agent.species.def:
		return 0
	return agent.species.def.id


## Centre-to-centre distance minus the target hitbox, in game units, matching the
## Lua `distance - radius` used by the Distance condition.
static func edge_distance(from: Agent, to: Agent) -> float:
	if not from or not to:
		return -1.0
	var world := from.position.distance_to(to.position) - to.collision_radius
	return world * GAME_UNITS_PER_WORLD_UNIT


## Straight centre-to-centre distance in game units.
static func game_distance(from: Vector3, to: Vector3) -> float:
	return from.distance_to(to) * GAME_UNITS_PER_WORLD_UNIT


# --- construction -------------------------------------------------------------

## How far away a friendly can be and still be picked as the heal target, in game
## units. GW2Minion used the same 1200.
const HEAL_TARGET_RANGE := 1200.0

## How long a target stays valid without being refreshed (sm_profile.lua:200).
const TARGET_STALE_MS := 1000


## Builds the snapshot for this tick. `carry` is the previous context, used to
## keep the last-cast bookkeeping and the sticky heal target alive across ticks.
static func build(actions: Array, carry: RefCounted = null) -> RefCounted:
	var context: RefCounted = (load("res://plugins/skill_manager/runtime/Context.gd") as Script).new()
	context.now = Time.get_ticks_msec()
	context.actionlist = actions

	if carry:
		context.last_cast_by_agent = carry.last_cast_by_agent

	var player: AgentChar = Manager.agent.controlled_character
	if not player:
		return context
	context.player = player

	if player.has_component(SkillBar):
		context.skillbar = player.skill_bar.skills

	context.weaponset = player.item_storage.active_weapon_set if player.has_component(ItemStorage) else 0
	context.canswapweaponset = SkillUtils.can_weapon_swap()
	context.swimming = swim_state(player)
	context.endurance = endurance_percent(player)
	context.power = profession_resource_percent(player)
	context.power2 = secondary_resource(player)

	context.transformid = player.profession_state
	# The previous state only advances when the current one actually changed, so
	# "last transform" keeps meaning the state we came from.
	if not carry:
		context.lasttransformid = player.profession_state
	elif carry.transformid != player.profession_state:
		context.lasttransformid = carry.transformid
	else:
		context.lasttransformid = carry.lasttransformid

	_collect_weapon_types(context, player)
	_collect_nearby(context, player)

	context.attack_target = Manager.skill.attack_target
	context.heal_target = _pick_heal_target(context, player)

	_track_casts(context)
	return context


## Equipment does not change mid-fight, and each reading costs a full
## CharacterState build, so the four of them are cached and refreshed on a timer
## rather than every tick.
const WEAPON_TYPE_CACHE_MS := 1000

static var _weapon_types: Array[int] = []
static var _weapon_types_at: int = -WEAPON_TYPE_CACHE_MS


## A snapshot with nothing but the player filled in.
##
## Palette activation only ever asks about the player, so the editor can answer
## "is this set active" without paying for the agent sweep and the four
## CharacterState builds a full snapshot costs.
static func minimal() -> RefCounted:
	var context: RefCounted = (load("res://plugins/skill_manager/runtime/Context.gd") as Script).new()
	context.now = Time.get_ticks_msec()
	context.player = Manager.agent.controlled_character
	return context


static func _collect_weapon_types(context: RefCounted, player: AgentChar) -> void:
	if not player.has_component(ItemStorage):
		return

	var now := Time.get_ticks_msec()
	if _weapon_types.size() == 6 and now - _weapon_types_at < WEAPON_TYPE_CACHE_MS:
		context.mainhand = _weapon_types[0]
		context.offhand = _weapon_types[1]
		context.mainhand_alt = _weapon_types[2]
		context.offhand_alt = _weapon_types[3]
		context.aquatic = _weapon_types[4]
		context.aquatic_alt = _weapon_types[5]
		return
	_weapon_types_at = now

	var primary: CharacterState = CharacterState.from_agent(player)
	primary.update_weapon_set(player, ItemStorage.WEAPON_SET_LAND_1)
	context.mainhand = primary.mainhand_weapon_type
	context.offhand = primary.offhand_weapon_type

	var alternate: CharacterState = CharacterState.from_agent(player)
	alternate.update_weapon_set(player, ItemStorage.WEAPON_SET_LAND_2)
	context.mainhand_alt = alternate.mainhand_weapon_type
	context.offhand_alt = alternate.offhand_weapon_type

	var water: CharacterState = CharacterState.from_agent(player)
	water.update_weapon_set(player, ItemStorage.WEAPON_SET_AQUATIC_1)
	context.aquatic = water.mainhand_weapon_type

	var water_alt: CharacterState = CharacterState.from_agent(player)
	water_alt.update_weapon_set(player, ItemStorage.WEAPON_SET_AQUATIC_2)
	context.aquatic_alt = water_alt.mainhand_weapon_type

	_weapon_types = [
		context.mainhand, context.offhand,
		context.mainhand_alt, context.offhand_alt,
		context.aquatic, context.aquatic_alt,
	]


## One sweep over the agent list, split by attitude. The Lua did the same and
## explicitly noted it was to avoid hitting the engine six times per condition.
static func _collect_nearby(context: RefCounted, player: AgentChar) -> void:
	for agent: Agent in Manager.agent.agents.values():
		if not agent or agent == player or not agent.is_spawned:
			continue
		if not is_alive(agent):
			continue
		match agent.attitude:
			Agent.ATTITUDE_FRIENDLY:
				context.friends_nearby.append(agent)
			Agent.ATTITUDE_HOSTILE, Agent.ATTITUDE_NEUTRAL:
				context.enemies_nearby.append(agent)


## Lowest-health friendly in range, party and squad first, matching
## sm_profile.lua:149-193.
static func _pick_heal_target(context: RefCounted, player: AgentChar) -> Agent:
	var party_ids: Array[String] = _party_member_ids()

	var best: Agent = null
	var best_score := INF

	for agent: Agent in context.friends_nearby:
		if game_distance(player.position, agent.position) > HEAL_TARGET_RANGE:
			continue
		var health: float = hp_percent(agent)
		if health < 0.0:
			continue
		# Party members sort ahead of strangers regardless of health, then the
		# lowest health wins inside each band.
		var in_party: bool = agent.has_component(Player) and agent.player.uuid.to_upper() in party_ids
		var score: float = health if in_party else health + 1000.0
		if score >= best_score:
			continue
		best = agent
		best_score = score

	if best:
		return best
	# Fall back to whatever the player has selected, if it is friendly.
	var selected: Agent = Manager.skill.target
	if selected and selected.attitude == Agent.ATTITUDE_FRIENDLY:
		return selected
	return player


static func _party_member_ids() -> Array[String]:
	var ids: Array[String] = []
	if not Manager.party.current_party:
		return ids
	for member: ChannelMember in Manager.party.current_party.members:
		ids.append(member.user.user_id.to_upper())
	return ids


## Remembers what each agent was last seen casting, which is what the
## Casting (Last ...) conditions read.
static func _track_casts(context: RefCounted) -> void:
	for agent: Agent in context.enemies_nearby + context.friends_nearby:
		var casting: int = casting_id(agent)
		if casting != 0:
			context.last_cast_by_agent[agent.id] = casting
	if context.player:
		var own: int = casting_id(context.player)
		if own != 0:
			context.last_cast_by_agent[context.player.id] = own


## Endurance as a percentage. The engine reports it in absolute points, while
## every threshold typed into a profile is a percentage.
static func endurance_percent(player: AgentChar) -> float:
	if not player or not player.has_component(Endurance):
		return 0.0
	var bar: Endurance = player.endurance
	if bar.max <= 0:
		return 0.0
	return float(bar.current) / float(bar.max) * 100.0


## The primary profession resource as a percentage of its maximum.
static func profession_resource_percent(player: AgentChar) -> float:
	var current := -1.0
	var maximum := -1.0
	if player.has_component(ProfessionElementalist):
		current = player.profession_elementalist.charge_current
		maximum = player.profession_elementalist.charge_max
	elif player.has_component(ProfessionEngineer):
		current = player.profession_engineer.heat_bar_current
		maximum = player.profession_engineer.heat_bar_max
	elif player.has_component(ProfessionGuardian):
		current = player.profession_guardian.tome_pages_current
		maximum = player.profession_guardian.tome_pages_max
	elif player.has_component(ProfessionMesmer):
		current = player.profession_mesmer.charge_current
		maximum = player.profession_mesmer.charge_max
	elif player.has_component(ProfessionNecromancer):
		current = player.profession_necromancer.life_force_current
		maximum = player.profession_necromancer.life_force_max
	elif player.has_component(ProfessionRanger):
		current = player.profession_ranger.astral_force_current
		maximum = player.profession_ranger.astral_force_max
	elif player.has_component(ProfessionRevenant):
		current = player.profession_revenant.energy_current
		maximum = player.profession_revenant.energy_max
	elif player.has_component(ProfessionThief):
		current = player.profession_thief.initiative_current
		maximum = player.profession_thief.initiative_max
	elif player.has_component(ProfessionWarrior):
		current = player.profession_warrior.adrenaline_current
		maximum = player.profession_warrior.adrenaline_max

	if current < 0.0 or maximum <= 0.0:
		return 0.0
	return current / maximum * 100.0


## The "Power2" reading. The Lua described it as "Necro Sand Shades or Thief
## Malice"; the client exposes deadeye malice and specter shadow force, but no
## shade count, so a necromancer reports zero here.
static func secondary_resource(player: AgentChar) -> float:
	if not player.has_component(ProfessionThief):
		return 0.0
	var thief: ProfessionThief = player.profession_thief
	if thief.deadeye_malice_current > 0:
		return float(thief.deadeye_malice_current)
	return thief.specter_shadow_force_current
