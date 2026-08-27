extends RefCounted

## Compiles the user snippets typed into the two code editors.
##
## GW2Minion evaluated Lua here. The GDScript equivalent wraps the snippet in a
## method and compiles it once, caching both the success and the failure so a
## broken snippet is reported a single time instead of once per frame -- the same
## guard the Lua had with its `condition_luacode_bugged` flag.

static var _logger := ScopedLogger.create("SkillManager")


## Wraps `body` in `func evaluate(skill, context)` and compiles it.
## Returns the instance to call `evaluate` on, or null when it does not compile.
static func compile_predicate(body: String, label: String) -> Object:
	return _compile("evaluate(skill, context)", body, label)


## Wraps `body` in `func render(host, profile, context)` and compiles it. Used by
## the profile level Main Menu Code Editor.
static func compile_renderer(body: String, label: String) -> Object:
	return _compile("render(host, profile, context)", body, label)


static func _compile(signature: String, body: String, label: String) -> Object:
	var source := "extends RefCounted\nfunc " + signature + ":\n"
	if body.strip_edges().is_empty():
		source += "\tpass\n"
	else:
		for line in body.split("\n"):
			source += "\t" + line + "\n"

	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		_logger.error("Custom code in %s failed to compile." % label)
		return null
	return script.new()
