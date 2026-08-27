extends "res://plugins/skill_manager/runtime/palettes/Palette.gd"

## The always-available skills: heal, the three utilities, elite, the engineer
## toolbelt, and the two non-skill actions. This is the equivalent of the Lua
## `common` palette file, which was registered with profession 0 and copied into
## every profession.

const UID := "Common"


func is_active(_context: RefCounted) -> bool:
	return true


func can_activate(_context: RefCounted) -> bool:
	return true


func activate(_context: RefCounted) -> void:
	pass


func deactivate(_context: RefCounted) -> bool:
	return false
