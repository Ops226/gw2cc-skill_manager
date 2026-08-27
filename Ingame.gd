extends PluginButton

## Plugin root. Owns the combat routine, the profile list and the global
## settings, so all of it keeps working whether or not the window has ever been
## opened -- the window itself is an instance placeholder until first use.

const PLUGIN_NAME := "SkillManager"

const Profile := preload("res://plugins/skill_manager/resources/Profile.gd")
const Runner := preload("res://plugins/skill_manager/runtime/Runner.gd")
const PaletteRegistry := preload("res://plugins/skill_manager/runtime/palettes/PaletteRegistry.gd")
const SmImporter := preload("res://plugins/skill_manager/runtime/SmImporter.gd")
const Units := preload("res://plugins/skill_manager/runtime/Units.gd")

const SETTINGS_SECTION := "SkillManager"

## Emitted after the profile list has been re-read from disk.
signal profiles_reloaded()
## Emitted when a different profile becomes the active one.
signal profile_changed(profile: Resource)
## Emitted once the combat routine exists. The window can be built before this
## node finishes its own _ready, so it waits for this rather than assuming.
signal runner_ready(routine: CombatManager.CombatRoutine)

var runner: CombatManager.CombatRoutine = null
var profiles: Array[Resource] = []
var profile: Resource = null

## The profession the list was last built for, so a respawn on the same class
## does not throw away the current selection.
var _loaded_profession: int = -1

## Lets the rotation run with nothing targeted. CombatManager only calls
## process_tick once an attack target exists, but GW2Minion had no such rule and
## profiles rely on self-heals firing out of combat.
var run_without_target: bool = false

static var _logger := ScopedLogger.create(PLUGIN_NAME)


func _init() -> void:
	Profile.ensure_dir()


func _ready() -> void:
	# super() reparents this button into the top menu, and a reparent fires
	# _exit_tree. Register only once that has happened, so the routine is not
	# torn down the moment it is created.
	super()

	runner = Runner.new()
	Manager.combat.register_combat_routine(PLUGIN_NAME, runner)

	load_settings()
	set_physics_process(true)
	runner_ready.emit(runner)

	# Profiles are per profession, and this node is built before the character
	# exists, so the first load has to wait for one. Swapping character fires the
	# same signal, which is what picks up a different class's profiles.
	Manager.agent.controlled_character_spawned.connect(_on_controlled_character_spawned)
	if Manager.agent.controlled_character:
		reload_profiles()


## Give the routine back only when this node is really destroyed.
##
## _exit_tree is not the place for it: leaving the tree also happens on a
## reparent, and PluginButton reparents itself into the top menu during _ready,
## which used to free the runner the instant it was created. PREDELETE fires for
## every destruction path and for none of the reparents.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if not is_instance_valid(runner):
		return
	runner = null
	Manager.combat.unregister_combat_routine(PLUGIN_NAME)


## The no-target half of the tick. CombatManager owns the other half.
func _physics_process(_delta: float) -> void:
	if not run_without_target or not is_instance_valid(runner):
		return
	if Manager.combat.paused or not Manager.combat.auto_combat:
		return
	if Manager.combat.active_combat_routine != runner:
		return
	# With a target in place CombatManager is already calling process_tick.
	if Manager.skill.attack_target:
		return
	runner.tick()


# --- profiles -----------------------------------------------------------------

func current_profession() -> int:
	var character := Manager.agent.controlled_character
	if not character or not character.has_component(CoreStats):
		return -1
	if not character.core_stats.profession_def:
		return -1
	return character.core_stats.profession_def.id


## Re-reads every profile for the current profession and restores the one that
## was last in use.
func _on_controlled_character_spawned(_character: AgentChar) -> void:
	if current_profession() == _loaded_profession:
		return
	reload_profiles()


## Re-reads the profiles for the current profession and picks one: the last one
## used on this class if it is still there, otherwise the first available.
func reload_profiles() -> void:
	var profession := current_profession()
	if profession < 0:
		# No character yet, so there is nothing to match against. Whatever is
		# already loaded stays until one spawns.
		return

	_loaded_profession = profession
	profiles = Profile.load_all(profession)
	profiles_reloaded.emit()

	if profiles.is_empty():
		_logger.trace("No profiles for profession %d" % profession)
		set_profile(null)
		return

	var wanted: String = ConfigService.get_value(SETTINGS_SECTION, "last_profile_%d" % profession, "")
	for candidate: Resource in profiles:
		if candidate.file_name() == wanted:
			set_profile(candidate)
			return

	_logger.trace("No last profile for profession %d, falling back to %s"
		% [profession, profiles[0].file_name()])
	set_profile(profiles[0])


func set_profile(value: Resource) -> void:
	profile = value
	if is_instance_valid(runner):
		runner.profile = value
	if value:
		ConfigService.set_value(SETTINGS_SECTION, "last_profile_%d" % current_profession(), value.file_name())
		ConfigService.save_cfg()
		_logger.trace("Switched to profile " + value.file_name())
	profile_changed.emit(value)


## Creates an empty profile for the current profession and makes it active.
func create_profile(file_base: String) -> Resource:
	var created := Profile.create(file_base, current_profession())
	if created.save() != OK:
		return null
	reload_profiles()
	for candidate: Resource in profiles:
		if candidate.file_name() == created.file_name():
			set_profile(candidate)
			return candidate
	return created


## Converts a GW2Minion `.sm` profile and makes it the active one. Returns the
## importer's report so the caller can say what did not survive.
func import_sm_profile(path: String) -> SmImporter.Result:
	var result := SmImporter.import_file(path)
	if not result.ok():
		_logger.error(result.error)
		return result

	if result.profile.save() != OK:
		result.error = "Could not save the imported profile"
		return result

	_logger.trace("Imported " + path.get_file())
	reload_profiles()
	for candidate: Resource in profiles:
		if candidate.file_name() == result.profile.file_name():
			set_profile(candidate)
			break
	return result


# --- settings -----------------------------------------------------------------

func load_settings() -> void:
	run_without_target = ConfigService.get_value(SETTINGS_SECTION, "run_without_target", false)
	Units.set_mode(ConfigService.get_value(SETTINGS_SECTION, "distance_units", Units.Mode.GODOT))
	if is_instance_valid(runner):
		runner.load_settings()


func set_weapon_swap_mode(value: int) -> void:
	if is_instance_valid(runner):
		runner.weapon_swap_mode = value
	ConfigService.set_value(SETTINGS_SECTION, "weaponswapmode", value)
	ConfigService.save_cfg()


func set_network_latency(value: int) -> void:
	if is_instance_valid(runner):
		runner.network_latency = value
	ConfigService.set_value(SETTINGS_SECTION, "networklatency", value)
	ConfigService.save_cfg()


func set_distance_units(value: Units.Mode) -> void:
	Units.set_mode(value)
	ConfigService.set_value(SETTINGS_SECTION, "distance_units", value)
	ConfigService.save_cfg()


func set_run_without_target(value: bool) -> void:
	run_without_target = value
	ConfigService.set_value(SETTINGS_SECTION, "run_without_target", value)
	ConfigService.save_cfg()
