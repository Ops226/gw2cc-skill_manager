extends Resource

## A SkillManager profile: the ordered action list plus the few per-profile
## settings. The port of `sm_profile.lua`, minus the casting loop, which lives in
## [code]runtime/Runner.gd[/code].

const Skill := preload("res://plugins/skill_manager/resources/Skill.gd")

const PROFILE_DIR := "user://plugins/skill_manager/profiles"

## GW2Minion kept a per-profile fight range ("Dynamic" / "Custom"). gw2cc does
## not: the fight distance and target attitude come from Settings > Combat >
## Target Filter, so a profile carries no range of its own. Distances inside
## conditions are still stored in GW2 units; see runtime/Units.gd.

@export var version: int = 1
@export var profession: int = 0
@export var mainmenu_code: String = ""
@export var actionlist: Array[Resource] = []

## Set by any editor change, cleared by [method save]. Drives the orange
## "Save Changes" button.
var modified: bool = false


func file_name() -> String:
	if resource_path.is_empty():
		return ""
	return resource_path.get_file()


func display_name() -> String:
	var file := file_name()
	return file.get_basename() if not file.is_empty() else "<unsaved>"


## Rebuilds the combo back references that are never serialized.
func relink() -> void:
	for action: Resource in actionlist:
		if action:
			action.relink()


func save() -> Error:
	if resource_path.is_empty():
		push_error("SkillManager: cannot save a profile without a path")
		return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(PROFILE_DIR)
	var error := ResourceSaver.save(self, resource_path)
	if error == OK:
		modified = false
	else:
		push_error("SkillManager: could not save %s (%d)" % [resource_path, error])
	return error


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE_DIR)


static func create(file_base: String, for_profession: int) -> Resource:
	ensure_dir()
	var profile: Resource = (load("res://plugins/skill_manager/resources/Profile.gd") as Script).new()
	profile.profession = for_profession
	profile.take_over_path(PROFILE_DIR.path_join(file_base + ".tres"))
	return profile


static func path_for(file_base: String) -> String:
	return PROFILE_DIR.path_join(file_base + ".tres")


static func exists(file_base: String) -> bool:
	return FileAccess.file_exists(path_for(file_base))


## Every profile on disk that matches [param for_profession]. A profile built for
## another class is skipped, not loaded, exactly as in the original.
static func load_all(for_profession: int) -> Array[Resource]:
	ensure_dir()
	var profiles: Array[Resource] = []
	var dir := DirAccess.open(PROFILE_DIR)
	if not dir:
		return profiles

	dir.list_dir_begin()
	while true:
		var file := dir.get_next()
		if file.is_empty():
			break
		if dir.current_is_dir() or file.get_extension() != "tres":
			continue
		var profile: Variant = ResourceLoader.load(PROFILE_DIR.path_join(file), "Resource", ResourceLoader.CACHE_MODE_IGNORE)
		if profile is not Resource or not "actionlist" in profile:
			continue
		if profile.version < 1:
			continue
		if profile.profession != for_profession:
			continue
		profile.relink()
		profiles.append(profile)
	dir.list_dir_end()

	profiles.sort_custom(func(a: Resource, b: Resource) -> bool:
		return a.file_name().naturalnocasecmp_to(b.file_name()) < 0
	)
	return profiles
