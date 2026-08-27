extends Resource

## Base class for every SkillManager condition, the port of `sm_condition.lua`.
##
## A condition owns its own editor row so the Condition Builder stays a dumb host,
## exactly like the Lua `Render(id)` contract. Subclasses override
## [method _get_uid], [method _evaluate] and [method _build_editor]. Drop a new
## script in `resources/conditions/` and it shows up in the picker automatically.

const Context := preload("res://plugins/skill_manager/runtime/Context.gd")
const Style := preload("res://plugins/skill_manager/ui/Style.gd")
const Units := preload("res://plugins/skill_manager/runtime/Units.gd")

const CONDITIONS_DIR := "res://plugins/skill_manager/resources/conditions"
## The same directory as the client sees it on disk. A plugin shipped as a folder
## lives outside the pck, so res:// can load its scripts but cannot list them;
## a plugin shipped as a .pcz is mounted into res:// and lists fine there. Trying
## both covers either packaging.
const CONDITIONS_DIR_ON_DISK := "plugins/skill_manager/resources/conditions"

## The five comparison operators shared by every numeric condition.
const OPERATORS: Array[String] = ["<", "<=", "==", ">=", ">"]

## Target lists. The order matters: the saved value is the 1-based index into it.
const TARGETS_TPF: Array[String] = ["Target", "Player", "Friend"]
const TARGETS_PTF: Array[String] = ["Player is", "Target is", "Friend is"]
const TARGETS_HAS: Array[String] = ["Target has", "Player has", "Friend has"]

## The conditions that ship with the plugin.
##
## Discovery normally walks the directory, so dropping a new script in is enough.
## That listing is not available in every packaging, though, and an empty picker
## means no conditions at all -- so the shipped set is also compiled in, and is
## used whenever the walk comes back with nothing.
const SHIPPED: Array[Script] = [
	preload("res://plugins/skill_manager/resources/conditions/Aggro.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Alive.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Ammo.gd"),
	preload("res://plugins/skill_manager/resources/conditions/AmmoBySkillId.gd"),
	preload("res://plugins/skill_manager/resources/conditions/AmmoCooldown.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Breakbar.gd"),
	preload("res://plugins/skill_manager/resources/conditions/BuffId.gd"),
	preload("res://plugins/skill_manager/resources/conditions/BuffIdList.gd"),
	preload("res://plugins/skill_manager/resources/conditions/BuffName.gd"),
	preload("res://plugins/skill_manager/resources/conditions/BuffsCount.gd"),
	preload("res://plugins/skill_manager/resources/conditions/BuffsCountById.gd"),
	preload("res://plugins/skill_manager/resources/conditions/CanSwapWeapons.gd"),
	preload("res://plugins/skill_manager/resources/conditions/CastingId.gd"),
	preload("res://plugins/skill_manager/resources/conditions/CastingIdList.gd"),
	preload("res://plugins/skill_manager/resources/conditions/CastingLastId.gd"),
	preload("res://plugins/skill_manager/resources/conditions/CastingLastName.gd"),
	preload("res://plugins/skill_manager/resources/conditions/CastingName.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Clone.gd"),
	preload("res://plugins/skill_manager/resources/conditions/CombatState.gd"),
	preload("res://plugins/skill_manager/resources/conditions/ContentId.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Cooldown.gd"),
	preload("res://plugins/skill_manager/resources/conditions/CooldownBySkillId.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Distance.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Downed.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Endurance.gd"),
	preload("res://plugins/skill_manager/resources/conditions/EntitiesInRange.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Health.gd"),
	preload("res://plugins/skill_manager/resources/conditions/LastTransformId.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Movement.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Pet.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Positioning.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Power.gd"),
	preload("res://plugins/skill_manager/resources/conditions/Power2.gd"),
	preload("res://plugins/skill_manager/resources/conditions/SwimState.gd"),
	preload("res://plugins/skill_manager/resources/conditions/TransformId.gd"),
	preload("res://plugins/skill_manager/resources/conditions/WeaponSetId.gd"),
]

static var _cache: Dictionary[String, Script] = {}


## Unique identifier, also the label shown in the condition picker.
func _get_uid() -> String:
	return ""


func get_uid() -> String:
	return _get_uid()


@warning_ignore("unused_parameter")
func _evaluate(skill: Resource, context: RefCounted) -> bool:
	return false


func evaluate(skill: Resource, context: RefCounted) -> bool:
	return _evaluate(skill, context)


func _build_editor() -> Control:
	return new_row()


## Builds the one-line editor for this condition.
func build_editor() -> Control:
	return _build_editor()


# --- evaluation helpers -------------------------------------------------------

## Applies one of [constant OPERATORS] by its 1-based index.
static func compare(operator: int, lhs: float, rhs: float) -> bool:
	match operator:
		1:
			return lhs < rhs
		2:
			return lhs <= rhs
		3:
			return is_equal_approx(lhs, rhs)
		4:
			return lhs >= rhs
		5:
			return lhs > rhs
	return false


## Parses the comma separated id lists used by the (ID-List) conditions.
static func parse_id_list(text: String) -> Array[int]:
	var ids: Array[int] = []
	for part in text.split(",", false):
		var trimmed := part.strip_edges()
		if trimmed.is_valid_int():
			ids.append(trimmed.to_int())
	return ids


# --- editor helpers -----------------------------------------------------------

func new_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func add_label(row: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return label


## The read-only text box a few conditions use in place of a label
## (Endurance, Power, Power2).
func add_readonly(row: Control, text: String, width: int, tip: String = "") -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.editable = false
	edit.custom_minimum_size.x = width
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.tooltip_text = tip
	row.add_child(edit)
	return edit


## A combo bound to a 1-based integer property.
func add_combo(row: Control, width: int, items: Array, property: StringName, tip: String = "") -> OptionButton:
	var combo := OptionButton.new()
	combo.custom_minimum_size.x = width
	combo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	combo.clip_text = true
	combo.tooltip_text = tip
	for item: String in items:
		combo.add_item(item)
	var current: int = int(get(property)) - 1
	if current >= 0 and current < combo.item_count:
		combo.selected = current
	combo.item_selected.connect(func(index: int) -> void:
		set(property, index + 1)
		emit_changed()
	)
	Style.bound_popup(combo)
	row.add_child(combo)
	return combo


## A combo bound to an integer property holding an arbitrary value, selected via
## a parallel list of values. Used by the Casting (Name) conditions.
func add_value_combo(row: Control, width: int, labels: Array, values: Array, property: StringName) -> OptionButton:
	var combo := OptionButton.new()
	combo.custom_minimum_size.x = width
	combo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	combo.clip_text = true
	for i in labels.size():
		combo.add_item(str(labels[i]))
		combo.set_item_metadata(i, values[i])
	var current: Variant = get(property)
	for i in values.size():
		if values[i] == current:
			combo.selected = i
			break
	combo.item_selected.connect(func(index: int) -> void:
		set(property, combo.get_item_metadata(index))
		emit_changed()
	)
	Style.bound_popup(combo)
	row.add_child(combo)
	return combo


## An integer spin box bound to a property, with the clamps the Lua applied.
func add_int(row: Control, width: int, property: StringName, step: int = 1,
		min_value: int = -99999999, max_value: int = 99999999, tip: String = "") -> SpinBox:
	var spin := SpinBox.new()
	spin.custom_minimum_size.x = width
	spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.tooltip_text = tip
	spin.value = float(get(property))
	spin.value_changed.connect(func(value: float) -> void:
		set(property, int(value))
		emit_changed()
	)
	row.add_child(spin)
	return spin


## A distance field. The property holds GW2 units whatever the display setting
## says, so the stored profile never changes meaning when the setting flips.
func add_distance(row: Control, width: int, property: StringName,
		min_game_units: float = 0.0, max_game_units: float = 10000.0,
		tip: String = "") -> SpinBox:
	var spin := SpinBox.new()
	spin.custom_minimum_size.x = width
	spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spin.min_value = Units.to_display(min_game_units)
	spin.max_value = Units.to_display(max_game_units)
	spin.step = Units.snap_step()
	spin.custom_arrow_step = Units.arrow_step()
	spin.suffix = Units.suffix()
	spin.tooltip_text = tip
	spin.value = Units.to_display(float(get(property)))
	spin.value_changed.connect(func(shown: float) -> void:
		set(property, Units.from_display(shown))
		emit_changed()
	)
	row.add_child(spin)
	return spin


## A free text field bound to a string property.
func add_text(row: Control, width: int, property: StringName, tip: String = "") -> LineEdit:
	var edit := LineEdit.new()
	edit.custom_minimum_size.x = width
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.text = str(get(property))
	edit.tooltip_text = tip
	edit.text_changed.connect(func(value: String) -> void:
		set(property, value)
		emit_changed()
	)
	row.add_child(edit)
	return edit


# --- discovery ----------------------------------------------------------------

## Every condition script in [constant CONDITIONS_DIR], keyed by uid and sorted by
## it, for the condition picker. Mirrors the Lua registry built by
## `SkillManager:AddCondition`.
static func get_available_conditions() -> Dictionary[String, Script]:
	if not _cache.is_empty():
		return _cache

	for script in _discover():
		_register(script)

	if _cache.is_empty():
		# Either the directory could not be listed or nothing in it registered.
		for script in SHIPPED:
			_register(script)

	_cache.sort()
	return _cache


## The condition scripts found by walking the directory, so a script dropped in
## is picked up without touching [constant SHIPPED].
static func _discover() -> Array[Script]:
	var scripts: Array[Script] = []

	var dir := DirAccess.open(CONDITIONS_DIR)
	if not dir:
		dir = DirAccess.open(CONDITIONS_DIR_ON_DISK)
	if not dir:
		return scripts

	dir.list_dir_begin()
	while true:
		var file := dir.get_next()
		if file.is_empty():
			break
		if file.begins_with("."):
			continue
		if file.get_extension() != "gd" and file.get_extension() != "gdc":
			continue
		# The listing may have come off the disk, but loading always goes through
		# the resource system.
		var script: Script = load(CONDITIONS_DIR + "/" + file.get_basename() + ".gd")
		if script:
			scripts.append(script)
	dir.list_dir_end()
	return scripts


static func _register(script: Script) -> void:
	if not script or not script.can_instantiate():
		return
	var instance: Variant = script.new()
	if instance is not Resource or not instance.has_method("get_uid"):
		return
	var uid: String = instance.get_uid()
	if uid.is_empty() or _cache.has(uid):
		return
	_cache[uid] = script


## Instantiates a condition by uid, or null when it is not registered.
static func create(uid: String) -> Resource:
	var conditions := get_available_conditions()
	if not conditions.has(uid):
		push_error("SkillManager: unknown condition " + uid)
		return null
	return conditions[uid].new()
