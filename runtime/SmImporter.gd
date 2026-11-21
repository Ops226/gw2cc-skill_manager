extends RefCounted

## Reads a GW2Minion `.sm` profile and turns it into one of ours.
##
## A `.sm` file is a Lua chunk whose whole body is one table literal, in a small
## enough subset -- identifier keys, numbers, strings, booleans, nested tables --
## that it can be read directly rather than through a Lua runtime.
##
## Two things do not survive verbatim. Palette names were GW2Minion's own
## ("Thief_shortbow"), so a skill is placed by looking up which of our derived
## palettes actually contains its id. And `condition_luacode` is Lua, so anything
## beyond the default is preserved as a comment for the author to port rather
## than silently dropped or left to fail compilation.

const Profile := preload("res://plugins/skill_manager/resources/Profile.gd")
const Skill := preload("res://plugins/skill_manager/resources/Skill.gd")
const ConditionGroup := preload("res://plugins/skill_manager/resources/ConditionGroup.gd")
const Condition := preload("res://plugins/skill_manager/resources/Condition.gd")
const PaletteRegistry := preload("res://plugins/skill_manager/runtime/palettes/PaletteRegistry.gd")

static var _logger := ScopedLogger.create("SkillManager")

## What a failed import reports back.
class Result:
	extends RefCounted
	var profile: Resource = null
	var error: String = ""
	## Conditions named in the file that this build does not have.
	var unknown_conditions: Array[String] = []
	## Skills whose palette could not be identified, placed in Common instead.
	var unplaced_skills: Array[int] = []
	## True when a snippet was carried across as a comment rather than as code.
	var carried_lua: bool = false

	func ok() -> bool:
		return profile != null


## Reads `path` and builds a profile from it. [param resolve_palette] takes a
## skill id and returns `[palette_uid, slot]`; the default asks the registry, and
## tests can pass their own.
static func import_file(path: String, resolve_palette: Callable = Callable()) -> Result:
	var result := Result.new()

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		result.error = "Could not read " + path
		return result

	var parsed: Variant = parse(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		result.error = "Not a SkillManager profile: " + path.get_file()
		return result

	return build(parsed, path.get_file().get_basename(), resolve_palette)


# --- turning the table into our resources -------------------------------------

## Builds a profile from an already parsed `.sm` table.
static func build(data: Dictionary, file_base: String, resolve_palette: Callable = Callable()) -> Result:
	var result := Result.new()
	if not resolve_palette.is_valid():
		resolve_palette = _registry_resolver

	var profile: Resource = Profile.create(file_base, int(data.get("profession", 0)))
	# `fightrangetype` / `fixedfightrange` are deliberately not carried over: the
	# fight distance is a gw2cc setting (Settings > Combat > Target Filter), not
	# a per-profile one.

	var menu_code := str(data.get("botmainmenu_luacode", ""))
	if not menu_code.strip_edges().is_empty():
		profile.mainmenu_code = _carry_lua(menu_code, "")
		result.carried_lua = true

	var actions: Array[Resource] = []
	for entry: Variant in _ordered(data.get("actionlist", {})):
		if entry is not Dictionary:
			continue
		var action := _build_skill(entry, result, resolve_palette)
		if action:
			actions.append(action)
	profile.actionlist = actions
	profile.modified = true

	result.profile = profile
	return result


static func _build_skill(entry: Dictionary, result: Result, resolve_palette: Callable) -> Resource:
	var skill: Resource = Skill.new()
	skill.id = int(entry.get("id", 0))
	if skill.id == 0:
		return null

	skill.activationtime = float(entry.get("activationtime", 0.0))
	skill.instantcast = bool(entry.get("instantcast", false))
	skill.requireslos = bool(entry.get("requireslos", true))
	skill.setsattackrange = bool(entry.get("setsattackrange", false))

	var placement: Array = resolve_palette.call(skill.id)
	skill.skillpaletteuid = placement[0]
	skill.slot = placement[1]
	if placement.size() > 2 and not placement[2]:
		result.unplaced_skills.append(skill.id)

	var lua := str(entry.get("condition_luacode", "return true"))
	skill.condition_code = _carry_lua(lua, "return true")
	if skill.condition_code != "return true":
		result.carried_lua = true

	var groups: Array[Resource] = []
	for raw_group: Variant in _ordered(entry.get("conditions", {})):
		if raw_group is not Dictionary:
			continue
		var group := _build_group(raw_group, result)
		if group:
			groups.append(group)
	skill.conditions = groups

	var following: Variant = entry.get("skill_next")
	if following is Dictionary:
		var next_link := _build_skill(following, result, resolve_palette)
		if next_link:
			skill.skill_next = next_link
			next_link.skill_prev = skill

	return skill


static func _build_group(raw: Dictionary, result: Result) -> Resource:
	var group: Resource = ConditionGroup.new()
	group.casttarget = int(raw.get("casttarget", 1))

	var conditions: Array[Resource] = []
	for raw_condition: Variant in _ordered(raw):
		if raw_condition is not Dictionary:
			continue
		var condition := _build_condition(raw_condition, result)
		if condition:
			conditions.append(condition)
	group.conditions = conditions
	return group


static func _build_condition(raw: Dictionary, result: Result) -> Resource:
	var uid := str(raw.get("uid", ""))
	if uid.is_empty():
		return null

	var condition: Resource = Condition.create(uid)
	if not condition:
		if uid not in result.unknown_conditions:
			result.unknown_conditions.append(uid)
		return null

	# The field names were carried across unchanged, so they assign straight over.
	for key: Variant in raw:
		if key is not String or key == "uid":
			continue
		if key in condition:
			condition.set(key, raw[key])
	return condition


## The array part of a Lua table, in order. Named keys are skipped, which is what
## separates a group's conditions from its `casttarget`.
static func _ordered(table: Variant) -> Array:
	var values: Array = []
	if table is not Dictionary:
		return values
	var index := 1
	while table.has(index):
		values.append(table[index])
		index += 1
	return values


## Keeps an imported Lua snippet without letting it break compilation.
static func _carry_lua(lua: String, fallback: String) -> String:
	var trimmed := lua.strip_edges()
	if trimmed.is_empty() or trimmed == fallback:
		return fallback

	var out := "# Imported from GW2Minion. This was Lua and needs porting to GDScript.\n"
	for line in lua.split("\n"):
		out += "# " + line + "\n"
	if not fallback.is_empty():
		out += fallback
	return out


## Places a skill by asking which of our derived palettes actually holds it,
## since GW2Minion's palette names are not ours. Returns
## `[palette_uid, slot, placed]`.
static func _registry_resolver(skill_id: int) -> Array:
	# The two non-skill actions kept their GW2Minion ids.
	if skill_id == Skill.SYNTHETIC_DODGE or skill_id == Skill.SYNTHETIC_WEAPON_SWAP:
		return ["Common", Skill.SLOT_SYNTHETIC, true]

	for uid: String in PaletteRegistry.palettes():
		var palette: RefCounted = PaletteRegistry.palettes()[uid]
		if palette.has_skill(skill_id):
			return [uid, palette.slot_of(skill_id), true]

	_logger.warn("Imported skill %d is not in any palette of this build" % skill_id)
	return ["Common", SkillBar.SKILL_BAR_SLOT_NONE, false]


# --- the Lua table reader -----------------------------------------------------

## Reads the first table literal in [param text]. Returns a Dictionary, with
## array entries keyed 1, 2, 3 the way Lua numbers them, or null on a malformed
## file.
static func parse(text: String) -> Variant:
	var cursor := _Cursor.new(text)
	cursor.skip_to_table()
	if cursor.at_end():
		return null
	return cursor.read_value()


class _Cursor:
	extends RefCounted

	var _text: String
	var _at: int = 0

	func _init(text: String) -> void:
		_text = text

	func at_end() -> bool:
		return _at >= _text.length()

	func skip_to_table() -> void:
		while not at_end() and _text[_at] != "{":
			_at += 1

	func _peek() -> String:
		return "" if at_end() else _text[_at]

	func _skip_space() -> void:
		while not at_end():
			var character := _text[_at]
			if character == "-" and _at + 1 < _text.length() and _text[_at + 1] == "-":
				while not at_end() and _text[_at] != "\n":
					_at += 1
				continue
			if character == " " or character == "\t" or character == "\n" or character == "\r":
				_at += 1
				continue
			return

	func read_value() -> Variant:
		_skip_space()
		if at_end():
			return null
		var character := _peek()
		if character == "{":
			return _read_table()
		if character == "\"" or character == "'":
			return _read_string()
		return _read_word()

	func _read_table() -> Dictionary:
		var table: Dictionary = {}
		var next_index := 1
		_at += 1  # past the brace

		while true:
			_skip_space()
			if at_end():
				break
			if _peek() == "}":
				_at += 1
				break
			if _peek() == ",":
				_at += 1
				continue

			var key: Variant = _read_key()
			if key == null:
				# No `name =` in front of it, so it is an array entry.
				table[next_index] = read_value()
				next_index += 1
			else:
				table[key] = read_value()

		return table

	## Reads `name =` or `["name"] =` if one is there, leaving the cursor alone
	## when the entry has no key.
	func _read_key() -> Variant:
		_skip_space()
		var start := _at

		var key: Variant = null
		if _peek() == "[":
			_at += 1
			key = read_value()
			_skip_space()
			if _peek() != "]":
				_at = start
				return null
			_at += 1
		else:
			var word := ""
			while not at_end() and _is_name_char(_text[_at]):
				word += _text[_at]
				_at += 1
			if word.is_empty():
				return null
			key = word

		_skip_space()
		if _peek() != "=":
			_at = start
			return null
		_at += 1
		return key

	func _read_string() -> String:
		var quote := _text[_at]
		_at += 1
		var out := ""
		while not at_end():
			var character := _text[_at]
			if character == "\\" and _at + 1 < _text.length():
				out += _unescape(_text[_at + 1])
				_at += 2
				continue
			if character == quote:
				_at += 1
				break
			out += character
			_at += 1
		return out

	static func _unescape(character: String) -> String:
		match character:
			"n":
				return "\n"
			"t":
				return "\t"
			"r":
				return "\r"
		return character

	## A bare word: a number, true, false or nil.
	func _read_word() -> Variant:
		var word := ""
		while not at_end() and _is_word_char(_text[_at]):
			word += _text[_at]
			_at += 1
		if word == "true":
			return true
		if word == "false":
			return false
		if word == "nil" or word.is_empty():
			return null
		if word.is_valid_int():
			return word.to_int()
		if word.is_valid_float():
			return word.to_float()
		return word

	static func _is_name_char(character: String) -> bool:
		var code := character.unicode_at(0)
		return (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or character == "_"

	static func _is_word_char(character: String) -> bool:
		return _is_name_char(character) or character == "." or character == "-" or character == "+"
