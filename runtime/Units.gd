extends RefCounted

## Which units distances are shown and typed in.
##
## The engine works in Godot units; GW2, and therefore GW2Minion and every
## profile written against it, works in units 32 times smaller. Profiles keep
## storing the GW2 figure so an old profile still means what it always meant --
## only the presentation changes, so flipping this setting can never alter how a
## rotation behaves.

const Context := preload("res://plugins/skill_manager/runtime/Context.gd")

enum Mode {
	## The engine's own units. One of these is 32 GW2 units.
	GODOT,
	## What GW2Minion showed: raw GW2 range, the numbers on the wiki.
	MMOMINION,
}

const MODE_NAMES: Array[String] = ["Godot units", "MMOMinion units"]

const GODOT_SUFFIX := "u"
const MMOMINION_SUFFIX := "gw2"

## What the up and down arrows move by.
const GODOT_ARROW_STEP := 0.25
const MMOMINION_ARROW_STEP := 1.0

## What a typed value is rounded to. A Godot unit is worth 32 GW2 units, so
## snapping to the arrow step would round 500 GW2 (15.625u) up to 504.
const GODOT_SNAP := 0.001
const MMOMINION_SNAP := 1.0

## Presentation only, so it is held here rather than read from storage. The
## plugin root restores it on load and writes it back when it changes, alongside
## the other settings.
static var _mode: Mode = Mode.GODOT


static func mode() -> Mode:
	return _mode


static func set_mode(value: Mode) -> void:
	_mode = value


## A stored GW2 distance as the user should see it.
static func to_display(game_units: float) -> float:
	if mode() == Mode.MMOMINION:
		return game_units
	return game_units / Context.GAME_UNITS_PER_WORLD_UNIT


## A distance the user typed, back to the stored GW2 figure.
static func from_display(shown: float) -> float:
	if mode() == Mode.MMOMINION:
		return shown
	return shown * Context.GAME_UNITS_PER_WORLD_UNIT


static func suffix() -> String:
	return MMOMINION_SUFFIX if mode() == Mode.MMOMINION else GODOT_SUFFIX


## The increment the spin arrows apply.
static func arrow_step() -> float:
	return MMOMINION_ARROW_STEP if mode() == Mode.MMOMINION else GODOT_ARROW_STEP


## The precision a typed value keeps. Must be fine enough that a whole GW2 range
## survives the trip through the field unchanged.
static func snap_step() -> float:
	return MMOMINION_SNAP if mode() == Mode.MMOMINION else GODOT_SNAP


## A read-only distance rendered with its unit, for the detail grid.
static func format(game_units: float) -> String:
	var shown := to_display(game_units)
	if mode() == Mode.MMOMINION:
		return "%d %s" % [int(round(shown)), MMOMINION_SUFFIX]
	return "%.3f %s" % [shown, GODOT_SUFFIX]


## The same, for a distance the engine already gave us in Godot units.
static func format_world(world_units: float) -> String:
	return format(world_units * Context.GAME_UNITS_PER_WORLD_UNIT)
