extends RefCounted

## Autocomplete and highlighting for the two snippet editors.
##
## The options are reflected out of the real scripts and the engine's own
## ClassDB rather than typed into a list, so `context.` offers whatever Context
## actually has today, and `context.player.` offers whatever AgentChar actually
## has. Chains resolve as deep as the type information goes.

const Skill := preload("res://plugins/skill_manager/resources/Skill.gd")
const Context := preload("res://plugins/skill_manager/runtime/Context.gd")
const Profile := preload("res://plugins/skill_manager/resources/Profile.gd")
const Style := preload("res://plugins/skill_manager/ui/Style.gd")

## The roots a per-skill condition snippet is evaluated against.
const CONDITION_ROOTS: Dictionary[String, String] = {
	"skill": "res://plugins/skill_manager/resources/Skill.gd",
	"context": "res://plugins/skill_manager/runtime/Context.gd",
}

## The roots the profile level Main Menu snippet is evaluated against.
const MAIN_MENU_ROOTS: Dictionary[String, String] = {
	"host": "VBoxContainer",
	"profile": "res://plugins/skill_manager/resources/Profile.gd",
	"context": "res://plugins/skill_manager/runtime/Context.gd",
}

const KEYWORDS: Array[String] = [
	"and", "break", "continue", "elif", "else", "false", "for", "if", "in",
	"is", "match", "not", "null", "or", "pass", "return", "true", "var", "while",
]

## Members whose name starts with one of these are implementation detail.
const HIDDEN_PREFIXES: Array[String] = ["_", "@"]


## Turns a plain CodeEdit into the snippet editor: completion, highlighting and
## bracket matching. [param roots] maps the identifiers in scope to either a
## script path or an engine class name.
static func attach(editor: CodeEdit, roots: Dictionary) -> void:
	editor.code_completion_enabled = true
	editor.code_completion_prefixes = ["."]
	editor.auto_brace_completion_enabled = true
	editor.indent_automatic = true
	editor.syntax_highlighter = build_highlighter(roots)

	editor.code_completion_requested.connect(_on_requested.bind(editor, roots))
	editor.text_changed.connect(_on_text_changed.bind(editor))


static func _on_text_changed(editor: CodeEdit) -> void:
	# Offer options while a word is being typed, not only after a dot.
	var typed := _text_before_caret(editor)
	if typed.is_empty():
		return
	var last := typed[typed.length() - 1]
	if last == "." or _is_word_char(last):
		editor.request_code_completion(true)


static func _on_requested(editor: CodeEdit, roots: Dictionary) -> void:
	for option in options_for(_text_before_caret(editor), roots):
		editor.add_code_completion_option(
			option["kind"],
			option["display"],
			option["insert"],
			Style.TEXT)
	editor.update_code_completion_options(false)


static func _text_before_caret(editor: CodeEdit) -> String:
	var line := editor.get_line(editor.get_caret_line())
	return line.substr(0, editor.get_caret_column())


static func _is_word_char(character: String) -> bool:
	var code := character.unicode_at(0)
	return (code >= 48 and code <= 57) \
		or (code >= 65 and code <= 90) \
		or (code >= 97 and code <= 122) \
		or character == "_"


# --- the actual completion ----------------------------------------------------

## Options for a caret sitting at the end of [param text]. Pure, so it can be
## exercised without a window.
static func options_for(text: String, roots: Dictionary) -> Array[Dictionary]:
	var chain := _chain_before_caret(text)
	var partial: String = chain.pop_back()

	if chain.is_empty():
		return _root_options(partial, roots)

	var owner: Variant = _resolve(chain, roots)
	if owner == null:
		return []
	return _member_options(owner, partial)


## Splits the identifier chain the caret is sitting in. The final entry is the
## part already typed, which may be empty right after a dot.
static func _chain_before_caret(text: String) -> Array[String]:
	var tail := ""
	for index in range(text.length() - 1, -1, -1):
		var character := text[index]
		if _is_word_char(character) or character == ".":
			tail = character + tail
			continue
		break
	var chain: Array[String] = []
	for part in tail.split("."):
		chain.append(part)
	return chain


static func _root_options(partial: String, roots: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for name: String in roots:
		if _matches(name, partial):
			options.append({"display": name, "insert": name, "kind": CodeEdit.KIND_VARIABLE})
	for keyword in KEYWORDS:
		if _matches(keyword, partial):
			options.append({"display": keyword, "insert": keyword, "kind": CodeEdit.KIND_PLAIN_TEXT})
	return options


## Walks the chain to whatever it names: a Script, or an engine class name.
static func _resolve(chain: Array[String], roots: Dictionary) -> Variant:
	if chain.is_empty() or not roots.has(chain[0]):
		return null

	var current: Variant = _root_type(roots[chain[0]])
	for index in range(1, chain.size()):
		if current == null:
			return null
		current = _member_type(current, chain[index])
	return current


static func _root_type(descriptor: String) -> Variant:
	if descriptor.begins_with("res://"):
		return load(descriptor)
	return descriptor


## The type of one member of a Script or an engine class, or null when it is not
## an object and so cannot be walked into.
static func _member_type(owner: Variant, member: String) -> Variant:
	for property in _properties(owner):
		if property["name"] != member:
			continue
		var class_of: String = str(property.get("class_name", ""))
		return class_of if not class_of.is_empty() else null
	return null


static func _member_options(owner: Variant, partial: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var seen: Dictionary[String, bool] = {}

	for property in _properties(owner):
		var name: String = property["name"]
		if seen.has(name) or _is_hidden(name) or not _matches(name, partial):
			continue
		seen[name] = true
		options.append({"display": name, "insert": name, "kind": CodeEdit.KIND_MEMBER})

	for method in _methods(owner):
		var name: String = method["name"]
		if seen.has(name) or _is_hidden(name) or not _matches(name, partial):
			continue
		seen[name] = true
		options.append({"display": name + "()", "insert": name + "(", "kind": CodeEdit.KIND_FUNCTION})

	# Constants go last: they are the least likely thing being reached for, and
	# alphabetically they would otherwise sit on top of every member.
	for constant in _constants(owner):
		if seen.has(constant) or _is_hidden(constant) or not _matches(constant, partial):
			continue
		seen[constant] = true
		options.append({"display": constant, "insert": constant, "kind": CodeEdit.KIND_CONSTANT})

	return options


## Property lists are interleaved with category and group headings, which are not
## members and must not be offered.
const _NOT_A_MEMBER := PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP


static func _properties(owner: Variant) -> Array:
	var raw: Array = []
	if owner is Script:
		var script: Script = owner
		while script:
			raw.append_array(script.get_script_property_list())
			script = script.get_base_script()
	elif owner is String and ClassDB.class_exists(owner):
		raw = ClassDB.class_get_property_list(owner)

	var members: Array = []
	for property: Dictionary in raw:
		if int(property.get("usage", 0)) & _NOT_A_MEMBER:
			continue
		if str(property.get("name", "")).contains("/"):
			continue
		members.append(property)
	return members


## Where to stop walking up an engine class. Object and friends contribute
## `connect`, `set_script`, `NOTIFICATION_*` and so on, which bury the members
## anyone is actually reaching for.
const _PLUMBING: Array[String] = ["Object", "RefCounted", "Resource"]


static func _methods(owner: Variant) -> Array:
	if owner is Script:
		var collected: Array = []
		var script: Script = owner
		while script:
			collected.append_array(script.get_script_method_list())
			script = script.get_base_script()
		return collected
	if owner is String and ClassDB.class_exists(owner):
		var methods: Array = []
		for cls in _class_chain(owner):
			methods.append_array(ClassDB.class_get_method_list(cls, true))
		return methods
	return []


static func _constants(owner: Variant) -> Array:
	if owner is Script:
		var names: Array = []
		var constants: Dictionary = (owner as Script).get_script_constant_map()
		for name: String in constants:
			# `const Foo := preload(...)` is a private import, not a member worth
			# offering.
			var value: Variant = constants[name]
			if value is Script or value is Resource:
				continue
			names.append(name)
		return names
	if owner is String and ClassDB.class_exists(owner):
		var collected: Array = []
		for cls in _class_chain(owner):
			collected.append_array(ClassDB.class_get_integer_constant_list(cls, true))
		return collected
	return []


## The class and its ancestors, stopping before the engine plumbing.
static func _class_chain(start: String) -> Array[String]:
	var chain: Array[String] = []
	var cls := start
	while not cls.is_empty() and cls not in _PLUMBING:
		chain.append(cls)
		cls = ClassDB.get_parent_class(cls)
	return chain


static func _is_hidden(name: String) -> bool:
	for prefix in HIDDEN_PREFIXES:
		if name.begins_with(prefix):
			return true
	return false


static func _matches(candidate: String, partial: String) -> bool:
	if partial.is_empty():
		return true
	return candidate.to_lower().begins_with(partial.to_lower())


# --- highlighting -------------------------------------------------------------

static func build_highlighter(roots: Dictionary) -> CodeHighlighter:
	var highlighter := CodeHighlighter.new()
	highlighter.number_color = Style.WARN
	highlighter.symbol_color = Style.MUTED
	highlighter.function_color = Style.ACCENT
	highlighter.member_variable_color = Style.TEXT

	for keyword in KEYWORDS:
		highlighter.add_keyword_color(keyword, Style.GOOD)
	for name: String in roots:
		highlighter.add_member_keyword_color(name, Style.ACCENT)

	highlighter.add_color_region("#", "", Style.MUTED, true)
	highlighter.add_color_region("\"", "\"", Style.WARN)
	highlighter.add_color_region("\'", "\'", Style.WARN)
	return highlighter
