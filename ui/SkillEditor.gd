extends Window

## Port of the Skill Editor (sm_skill.lua:197-295). Four stacked regions: the
## combo strip, the read-only detail grid with its four editable fields, the
## two-click delete, and the condition builder with the custom code editor under
## it.

const Style := preload("res://plugins/skill_manager/ui/Style.gd")
const Skill := preload("res://plugins/skill_manager/resources/Skill.gd")
const Condition := preload("res://plugins/skill_manager/resources/Condition.gd")
const ConditionGroup := preload("res://plugins/skill_manager/resources/ConditionGroup.gd")
const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")
const Context := preload("res://plugins/skill_manager/runtime/Context.gd")
const Units := preload("res://plugins/skill_manager/runtime/Units.gd")
const Collapsible := preload("res://plugins/skill_manager/ui/widgets/Collapsible.gd")
const ConditionRow := preload("res://plugins/skill_manager/ui/widgets/ConditionRow.gd")
const CodeEditorSupport := preload("res://plugins/skill_manager/ui/widgets/CodeEditorSupport.gd")

const ADD_ICON := preload("res://plugins/skill_manager/assets/add.svg")
const NEXT_ICON := preload("res://plugins/skill_manager/assets/next.svg")
const DELETE_ICON := preload("res://plugins/skill_manager/assets/delete.svg")
const INFO_ICON := preload("res://plugins/skill_manager/assets/info.svg")

const WINDOW_SIZE := Vector2i(600, 600)
const COMBO_STRIP_SIZE := Vector2(585, 85)
const COMBO_ICON := 40
const ARROW_SIZE := Vector2(8, 40)
const DELETE_SIZE := Style.ICON_SMALL
const INFO_SIZE := Style.ICON_SMALL
const ADD_TO_GROUP_SIZE := Style.ICON_SMALL
const ADD_GROUP_SIZE := Style.ICON_LARGE
const CODE_EDITOR_MIN_HEIGHT := 300
const PICKER_SIZE := Vector2i(380, 170)

## How often the live readings (CanCast, cooldowns, ammo, set state) repaint.
## The runner evaluates every 50 ms; repainting the grid that often made the
## whole client stutter while this window was up, and nobody reads a cooldown
## at 20 Hz.
const LIVE_REFRESH_MS := 250

const CONTEXT_REFERENCE := """Additional GDScript, deciding whether this skill may be cast. Must return true or false.

Available on `skill`: id, activationtime, instantcast, requireslos, setsattackrange,
cancast, cast_target, is_combo; skill.ability() for the AbilityDef.

Available on `context`: player, attack_target, heal_target, skillbar, actionlist,
friends_nearby, enemies_nearby, weaponset, transformid, lasttransformid,
canswapweaponset, swimming, endurance, power, power2, mainhand, mainhand_alt,
offhand, offhand_alt, aquatic, aquatic_alt, now, last_cast_by_agent.
attack_target and enemies_nearby follow the gw2cc Settings > Combat > Target
Filter (attitude, players / NPCs / gadgets, fight distance).

Write to context.cast_target to override the target chosen by the condition
groups above (1 = Enemy, 2 = Player, 3 = Friend)."""

signal changed()
signal wants_skill_picker(link: Resource)
signal action_deleted(action: Resource)
signal closed()

var _action: Resource = null
var _current: Resource = null
## The runner's most recent snapshot. The editor never builds one itself: doing
## so cost a full agent sweep per refresh, and any error inside it aborted the
## rest of the refresh, which is what used to leave the condition list empty.
var _context: RefCounted = null
var _last_live_refresh: int = 0

var _strip: HBoxContainer = null
var _details: GridContainer = null
var _detail_values: Dictionary[String, Label] = {}
var _sets_attack_range: CheckBox = null
var _requires_los: CheckBox = null
var _cast_time: SpinBox = null
var _instant_cast: CheckBox = null
var _delete: Button = null
var _delete_armed: bool = false
var _groups_box: VBoxContainer = null
var _code_section: VBoxContainer = null
var _code_editor: CodeEdit = null
var _loading: bool = false


func _ready() -> void:
	size = WINDOW_SIZE
	wrap_controls = false
	Style.fit_to_contents(self, WINDOW_SIZE)
	close_requested.connect(_on_close)
	_build()


func open(action: Resource) -> void:
	_action = action
	_current = action
	_delete_armed = false
	_refresh_all()
	popup_centered()


## Hands the editor the runner's latest evaluation, so the live readings in the
## detail grid track the rotation instead of being sampled once on open.
## Rebuilds everything that renders a distance, after the unit setting changed.
func refresh_units() -> void:
	if _current:
		_refresh_all()


func set_context(context: RefCounted) -> void:
	_context = context
	if not visible or not _current:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_live_refresh < LIVE_REFRESH_MS:
		return
	_last_live_refresh = now
	_refresh_live()


# --- construction -------------------------------------------------------------

func _build() -> void:
	var root: VBoxContainer = Style.chrome(self, "Skill Editor")

	_build_combo_strip(root)
	_build_details(root)
	_build_conditions(root)
	_build_code_editor(root)


func _build_combo_strip(root: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = COMBO_STRIP_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 4)
	scroll.add_child(_strip)


func _build_details(root: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	root.add_child(header)

	_details = GridContainer.new()
	_details.columns = 4
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("h_separation", 0)
	_details.add_theme_constant_override("v_separation", 2)
	header.add_child(_details)

	_delete = Style.icon_button(DELETE_ICON, DELETE_SIZE, "Delete this Skill.")
	_delete.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_delete.pressed.connect(_on_delete)
	header.add_child(_delete)

	# The read-only rows, laid out label / value / label / value to reproduce the
	# x0 / x125 / x300 / x425 grid of the original.
	_detail_row("Name:", "ID:")
	_detail_row("Set:", "IsActiveSet:")
	_detail_row("CanCast:", "CanActivateSet:")
	_detail_row("MinRange:", "MaxRange:")
	_detail_row("Radius:", "Req.Power:")
	_detail_row("Cooldown:", "AmmoCooldown:")
	_detail_row("GroundTargeted:", "Ammo:")

	_sets_attack_range = CheckBox.new()
	_sets_attack_range.toggled.connect(_on_sets_attack_range)
	_requires_los = CheckBox.new()
	_requires_los.toggled.connect(_on_requires_los)
	_editable_row(
		"Set AttackRange:", _sets_attack_range,
		"If Enabled, this Skill is included in defining the maximum Attackrange of the bot.",
		"Requires LoS:", _requires_los,
		"If Enabled, this Skill will only be cast at the target if it is in Line of Sight.")

	_cast_time = SpinBox.new()
	_cast_time.min_value = 0.0
	_cast_time.max_value = 30.0
	_cast_time.step = 0.1
	_cast_time.custom_minimum_size.x = 150
	_cast_time.value_changed.connect(_on_cast_time)
	_instant_cast = CheckBox.new()
	_instant_cast.toggled.connect(_on_instant_cast)
	_editable_row(
		"Cast Time:", _cast_time,
		"The Duration this Skill is cast. Setting this too low, can result in the Bot interrupting other Skills.",
		"Instant Cast:", _instant_cast,
		"If this is Enabled, the Skill can be cast instantly 'without interrupting' the currently cast Skill.")


func _detail_row(left: String, right: String) -> void:
	_detail_cell(left)
	_detail_cell(right)


func _detail_cell(label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = Style.GRID_VALUE_LEFT
	_details.add_child(label)

	var value := Label.new()
	value.custom_minimum_size.x = Style.GRID_LABEL_RIGHT - Style.GRID_VALUE_LEFT
	_details.add_child(Style.dim(value))
	_detail_values[label_text] = value


func _editable_row(left: String, left_control: Control, left_tip: String,
		right: String, right_control: Control, right_tip: String) -> void:
	var left_label := Label.new()
	left_label.text = left
	left_label.tooltip_text = left_tip
	left_label.custom_minimum_size.x = Style.GRID_VALUE_LEFT
	_details.add_child(left_label)
	left_control.tooltip_text = left_tip
	_details.add_child(left_control)

	var right_label := Label.new()
	right_label.text = right
	right_label.tooltip_text = right_tip
	right_label.custom_minimum_size.x = Style.GRID_LABEL_RIGHT - Style.GRID_VALUE_LEFT
	_details.add_child(right_label)
	right_control.tooltip_text = right_tip
	_details.add_child(right_control)


func _build_conditions(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.bordered_panel())
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	panel.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	scroll.add_child(column)

	column.add_child(Style.heading(
		"Conditions",
		"This Skill can be cast, when all conditions of at least one 'Group' are 'true'."))

	_groups_box = VBoxContainer.new()
	_groups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_box.add_theme_constant_override("separation", 4)
	column.add_child(_groups_box)

	var add_group: Button = Style.icon_button(ADD_ICON, ADD_GROUP_SIZE, "Add a new Condition.")
	add_group.pressed.connect(_on_add_group)
	column.add_child(add_group)


func _build_code_editor(root: VBoxContainer) -> void:
	var section: VBoxContainer = Collapsible.new()
	section.setup("CUSTOM CONDITION CODE EDITOR", CONTEXT_REFERENCE, false)
	root.add_child(section)
	_code_section = section

	var header := HBoxContainer.new()
	section.body().add_child(header)
	var info: Button = Style.icon_button(INFO_ICON, INFO_SIZE, CONTEXT_REFERENCE)
	info.disabled = true
	header.add_child(info)

	_code_editor = CodeEdit.new()
	_code_editor.custom_minimum_size.y = CODE_EDITOR_MIN_HEIGHT
	_code_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_editor.text_changed.connect(_on_code_changed)
	CodeEditorSupport.attach(_code_editor, CodeEditorSupport.CONDITION_ROOTS)
	section.body().add_child(_code_editor)


# --- refresh ------------------------------------------------------------------

## Groups and code come first: they are what the user edits, and they must not
## depend on the live readings being available.
func _refresh_all() -> void:
	_refresh_strip()
	_refresh_groups()
	_refresh_code()
	_refresh_details()


func _refresh_strip() -> void:
	for child in _strip.get_children():
		child.queue_free()
	if not _action:
		return

	var links: Array[Resource] = _action.chain()
	for position in links.size():
		var link: Resource = links[position]
		if link.id == 0:
			continue

		var group := VBoxContainer.new()
		var tile: Button = Style.icon_button(link.icon_texture(), COMBO_ICON, link.display_name())
		if not tile.icon:
			tile.text = link.display_name().left(2)
		if link == _current:
			Style.state_tint(tile, Style.State.SELECTED)
		tile.pressed.connect(_on_link_selected.bind(link))
		group.add_child(tile)

		var change := Button.new()
		change.text = "Change"
		change.pressed.connect(_on_change_link.bind(link))
		group.add_child(change)
		_strip.add_child(group)

		if link.skill_next and link.skill_next.id != 0:
			var arrow := TextureRect.new()
			arrow.texture = NEXT_ICON
			arrow.custom_minimum_size = ARROW_SIZE
			arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_strip.add_child(arrow)

	var tail: Resource = links[links.size() - 1]
	if not tail.skill_next:
		var add: Button = Style.icon_button(ADD_ICON, COMBO_ICON, "Add another Combo-Skill.")
		add.pressed.connect(_on_add_combo.bind(tail))
		_strip.add_child(add)


## The whole grid: the static facts about the skill plus the editable fields,
## then the live readings. Runs when the skill being edited changes.
func _refresh_details() -> void:
	if not _current:
		return
	var skill: AbilityDef = _current.ability()

	_set_detail("Name:", _current.display_name())
	_set_detail("ID:", str(_current.id))
	_set_detail("Set:", _current.skillpaletteuid)
	_set_detail("MinRange:", Units.format_world(0.0))
	_set_detail("MaxRange:", Units.format_world(skill.range if skill else 0.0))
	_set_detail("Radius:", Units.format_world(skill.radius if skill else 0.0))
	_set_detail("Req.Power:", str(skill.cost) if skill else "0")
	_set_detail("GroundTargeted:", str(SkillState.is_ground_targeted(skill)))

	_loading = true
	_sets_attack_range.button_pressed = _current.setsattackrange
	_requires_los.button_pressed = _current.requireslos
	_cast_time.value = _current.activationtime
	_instant_cast.button_pressed = _current.instantcast
	_loading = false

	_last_live_refresh = Time.get_ticks_msec()
	_refresh_live()


## Only the cells that change while the rotation runs. This is what every
## runner tick pays for, so it touches nothing else.
func _refresh_live() -> void:
	if not _current:
		return
	var skill: AbilityDef = _current.ability()
	var palette: RefCounted = _current.palette()

	# CanCast is the routine's own verdict, so it only means something once the
	# routine has actually run.
	_set_detail("CanCast:", str(_current.cancast) if _context else "-")

	# The palette questions do not need a full snapshot, so they are answered
	# even when the rotation is idle.
	var probe: RefCounted = _context if _context else Context.minimal()
	if palette and probe.player:
		_set_detail("IsActiveSet:", str(palette.is_active(probe)))
		_set_detail("CanActivateSet:", str(palette.can_activate(probe)))
	else:
		_set_detail("IsActiveSet:", "-")
		_set_detail("CanActivateSet:", "-")
	_set_detail("Cooldown:", "%d/%d" % [SkillState.cooldown_ms(skill), SkillState.cooldown_max_ms(skill)])
	_set_detail("AmmoCooldown:", "%d/%d" % [SkillState.charge_cooldown_ms(skill), SkillState.charge_cooldown_max_ms(skill)])
	_set_detail("Ammo:", "%d/%d" % [SkillState.charges(skill), SkillState.charges_max(skill)])


## Writes a cell only when its text actually differs: a Label re-shapes its text
## and invalidates the layout on every assignment, even an identical one.
func _set_detail(key: String, value: String) -> void:
	var label: Label = _detail_values.get(key)
	if label and label.text != value:
		label.text = value


func _refresh_groups() -> void:
	for child in _groups_box.get_children():
		child.queue_free()
	if not _current:
		return

	for index in _current.conditions.size():
		_groups_box.add_child(_build_group(index, _current.conditions[index]))


func _build_group(index: int, group: Resource) -> Control:
	var section: VBoxContainer = Collapsible.new()
	section.setup("Group %d" % (index + 1), "", true)

	var target_row := HBoxContainer.new()
	var target_label := Label.new()
	target_label.text = "Cast Spell At:"
	target_label.tooltip_text = "If this Condition group evaluates to 'true', the spell will be cast at the selected target.\n(Enemy == context.attack_target, Player == context.player, Friend == context.heal_target)"
	target_row.add_child(target_label)

	var target := OptionButton.new()
	target.custom_minimum_size.x = 100
	for name: String in ConditionGroup.CAST_TARGETS:
		target.add_item(name)
	target.selected = group.casttarget - 1
	target.item_selected.connect(func(selected: int) -> void:
		group.casttarget = selected + 1
		changed.emit()
	)
	target_row.add_child(target)
	section.body().add_child(target_row)

	for condition: Resource in group.conditions:
		section.body().add_child(_build_condition_row(group, condition))

	var add: Button = Style.icon_button(ADD_ICON, ADD_TO_GROUP_SIZE, "Add another Condition to this Group.")
	add.pressed.connect(_on_add_condition.bind(group))
	section.body().add_child(add)
	return section


func _build_condition_row(group: Resource, condition: Resource) -> Control:
	var row: HBoxContainer = ConditionRow.new()
	row.setup(condition)
	row.changed.connect(func() -> void: changed.emit())
	# The original kept a single armed slot, so arming one delete disarmed the
	# one before it.
	row.armed.connect(func() -> void: _disarm_other_conditions(row))
	row.deleted.connect(func() -> void:
		group.conditions.erase(condition)
		if group.conditions.is_empty():
			_current.conditions.erase(group)
		changed.emit()
		_refresh_groups()
	)
	return row


## Clears the armed state of every condition delete except [param keep].
func _disarm_other_conditions(keep: Control) -> void:
	for group_section in _groups_box.get_children():
		for row in group_section.body().get_children():
			if row != keep and row.has_method("disarm"):
				row.disarm()


func _refresh_code() -> void:
	if not _current:
		return
	_loading = true
	_code_editor.text = _current.condition_code
	_loading = false


# --- handlers -----------------------------------------------------------------

func _on_link_selected(link: Resource) -> void:
	_current = link
	_delete_armed = false
	Style.untint(_delete)
	_refresh_all()


func _on_change_link(link: Resource) -> void:
	link.id = 0
	changed.emit()
	wants_skill_picker.emit(link)


func _on_add_combo(tail: Resource) -> void:
	var link: Resource = Skill.new()
	link.skill_prev = tail
	tail.skill_next = link
	changed.emit()
	wants_skill_picker.emit(link)


## Two-click delete, then the chain is relinked around the removed link.
func _on_delete() -> void:
	if not _delete_armed:
		_delete_armed = true
		Style.tint(_delete, Style.ARMED, Style.ARMED_HOVER, Style.ARMED_ACTIVE)
		return

	_delete_armed = false
	Style.untint(_delete)
	if not _current:
		return

	var previous: Resource = _current.skill_prev
	var following: Resource = _current.skill_next

	if previous:
		previous.skill_next = following
		if following:
			following.skill_prev = previous
		_current = previous
		changed.emit()
		_refresh_all()
		return

	# Deleting the head either promotes the next link or drops the whole action.
	if following:
		following.skill_prev = null
		_action.skill_next = following.skill_next
		_action.id = following.id
		_action.skillpaletteuid = following.skillpaletteuid
		_action.slot = following.slot
		_action.activationtime = following.activationtime
		_action.instantcast = following.instantcast
		_action.requireslos = following.requireslos
		_action.setsattackrange = following.setsattackrange
		_action.conditions = following.conditions
		_action.condition_code = following.condition_code
		_action.relink()
		_current = _action
		changed.emit()
		_refresh_all()
		return

	hide()
	action_deleted.emit(_action)


func _on_sets_attack_range(pressed: bool) -> void:
	if _loading or not _current:
		return
	_current.setsattackrange = pressed
	changed.emit()


func _on_requires_los(pressed: bool) -> void:
	if _loading or not _current:
		return
	_current.requireslos = pressed
	changed.emit()


func _on_cast_time(value: float) -> void:
	if _loading or not _current:
		return
	_current.activationtime = value
	changed.emit()


func _on_instant_cast(pressed: bool) -> void:
	if _loading or not _current:
		return
	_current.instantcast = pressed
	changed.emit()


func _on_code_changed() -> void:
	if _loading or not _current:
		return
	# TextEdit emits text_changed (deferred) for a programmatic `text =` too, by
	# which time _loading has been cleared. Loading a skill must neither mark the
	# profile dirty nor throw away its compiled snippet.
	if _code_editor.text == _current.condition_code:
		return
	_current.condition_code = _code_editor.text
	_current.invalidate_script()
	changed.emit()


func _on_add_group() -> void:
	if not _current:
		return
	var group: Resource = ConditionGroup.new()
	_current.conditions.append(group)
	_prompt_for_condition(group)


func _on_add_condition(group: Resource) -> void:
	_prompt_for_condition(group)


## The condition type picker: a combo of every registered uid plus an Add button,
## exactly the pair `sm_skill:RenderConditionComboBox` drew.
func _prompt_for_condition(group: Resource) -> void:
	var picker := ConfirmationDialog.new()
	picker.title = "Add Condition"
	picker.ok_button_text = "Add"
	picker.min_size = PICKER_SIZE
	# The theme sits on this window's panel, not on the window, so a child
	# dialog does not inherit it.
	picker.theme = Style.current_theme()
	add_child(picker)

	# The dialog stretches its single child, so the combo goes inside a column
	# rather than being blown up into a full-height box.
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	picker.add_child(body)
	body.add_child(Style.heading("Condition type"))

	var combo := OptionButton.new()
	combo.custom_minimum_size = Vector2(PICKER_SIZE.x - 40, 0)
	combo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	combo.fit_to_longest_item = false
	combo.clip_text = true
	var uids: Array[String] = []
	for uid: String in Condition.get_available_conditions():
		combo.add_item(uid)
		uids.append(uid)
	# Without this the combo opens on nothing selected, and Add silently does
	# nothing -- which is exactly how it used to fail.
	if combo.item_count > 0:
		combo.selected = 0
	Style.bound_popup(combo)
	body.add_child(combo)

	var tip := Label.new()
	tip.text = "Conditions in a group must all pass."
	body.add_child(Style.dim(tip))

	picker.confirmed.connect(func() -> void:
		if combo.selected < 0 or combo.selected >= uids.size():
			return
		var condition: Resource = Condition.create(uids[combo.selected])
		if not condition:
			return
		group.conditions.append(condition)
		changed.emit()
		_refresh_groups()
	)
	picker.canceled.connect(func() -> void:
		# Backing out of the picker must not leave an empty group behind.
		if group.conditions.is_empty():
			_current.conditions.erase(group)
			_refresh_groups()
	)
	picker.confirmed.connect(picker.queue_free)
	picker.canceled.connect(picker.queue_free)
	picker.popup_centered()


func _on_close() -> void:
	hide()
	closed.emit()
