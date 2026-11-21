extends Window

## The Skill Manager window. Port of the ImGui window opened by
## `sm_mgr.DrawMenu` (sm_mgr.lua:240-367) plus the body drawn by
## `sm_profile:Render` (sm_profile.lua:491-625).
##
## Every size, label and tooltip below is taken from those two functions.

const Style := preload("res://plugins/skill_manager/ui/Style.gd")
const Profile := preload("res://plugins/skill_manager/resources/Profile.gd")
const Skill := preload("res://plugins/skill_manager/resources/Skill.gd")
const ActionButton := preload("res://plugins/skill_manager/ui/widgets/ActionButton.gd")
const Collapsible := preload("res://plugins/skill_manager/ui/widgets/Collapsible.gd")
const CodeEditorSupport := preload("res://plugins/skill_manager/ui/widgets/CodeEditorSupport.gd")
const NewProfileDialog := preload("res://plugins/skill_manager/ui/NewProfileDialog.gd")
const Units := preload("res://plugins/skill_manager/runtime/Units.gd")
const SkillSetEditorScene := preload("res://plugins/skill_manager/ui/SkillSetEditor.tscn")
const SkillEditorScene := preload("res://plugins/skill_manager/ui/SkillEditor.tscn")
const SkillSetHelperScene := preload("res://plugins/skill_manager/ui/SkillSetHelper.tscn")

const IMPORT_ICON := preload("res://plugins/skill_manager/assets/import.svg")
const REFRESH_ICON := preload("res://plugins/skill_manager/assets/refresh.svg")
const ADD_ICON := preload("res://plugins/skill_manager/assets/add.svg")

## Window widths, folded and unfolded (sm_profile.lua:528, 537).
const WIDTH_FOLDED := 280
const WIDTH_WITH_EDITOR := 650
const START_HEIGHT := 150
## The code editor is a fixed 450 tall (sm_profile.lua:533).
const CODE_EDITOR_HEIGHT := 450
## The action list may not eat more than three fifths of the screen
## (sm_profile.lua:612).
const ACTION_LIST_SCREEN_FRACTION := 0.6

const SWAP_MODES: Array[String] = ["Automatic", "Manual"]

var _plugin: Node = null

var _profile_combo: OptionButton = null
var _save_button: Button = null
var _fight_distance: Label = null
var _swap_mode: OptionButton = null
var _latency: HSlider = null
var _latency_value: Label = null
var _no_target: CheckBox = null
var _distance_units: OptionButton = null
var _code_section: VBoxContainer = null
var _code_editor: CodeEdit = null
var _filter: LineEdit = null
var _action_list: VBoxContainer = null
var _action_panel: PanelContainer = null

var _set_editor: Window = null
var _skill_editor: Window = null
var _helper: Window = null

var _selected_action: Resource = null
var _tiles: Array[Button] = []
var _loading: bool = false


func _enter_tree() -> void:
	ConfigUtils.restore_window_state(self, "SkillManager", "main_window")


func _exit_tree() -> void:
	ConfigUtils.save_window_state(self, "SkillManager", "main_window")


func _ready() -> void:
	size = Vector2i(WIDTH_FOLDED, START_HEIGHT)
	wrap_controls = true
	close_requested.connect(hide)

	_plugin = _find_plugin()
	_build()
	Style.fit_to_contents(self, Vector2i(WIDTH_FOLDED, START_HEIGHT))
	_open_child_windows()

	if _plugin:
		_plugin.profiles_reloaded.connect(_refresh_profile_combo)
		_plugin.profile_changed.connect(_on_profile_changed)
		_plugin.runner_ready.connect(_on_runner_ready)
		if is_instance_valid(_plugin.runner):
			_on_runner_ready(_plugin.runner)

	_load_from_plugin()


## The plugin root is this window's owner button.
func _find_plugin() -> Node:
	var node := get_parent()
	while node:
		if node.has_method("reload_profiles"):
			return node
		node = node.get_parent()
	return null


func profile() -> Resource:
	return _plugin.profile if _plugin else null


func runner() -> CombatManager.CombatRoutine:
	if not _plugin or not is_instance_valid(_plugin.runner):
		return null
	return _plugin.runner


func _on_runner_ready(routine: CombatManager.CombatRoutine) -> void:
	if not routine.evaluated.is_connected(_on_evaluated):
		routine.evaluated.connect(_on_evaluated)
	_load_from_plugin()


# --- construction -------------------------------------------------------------

func _build() -> void:
	var root: VBoxContainer = Style.chrome(self, "Skill Manager")

	_build_profile_bar(root)
	root.add_child(HSeparator.new())
	_build_settings(root)
	_build_code_editor(root)
	root.add_child(HSeparator.new())
	_build_action_list(root)


func _build_profile_bar(root: VBoxContainer) -> void:
	root.add_child(Style.heading("Current Profile"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	root.add_child(row)

	_profile_combo = OptionButton.new()
	_profile_combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_combo.clip_text = true
	_profile_combo.item_selected.connect(_on_profile_selected)
	row.add_child(_profile_combo)

	var refresh: Button = Style.icon_button(REFRESH_ICON, Style.ICON_MEDIUM, "Refresh Profile List")
	refresh.pressed.connect(_on_refresh)
	row.add_child(refresh)

	var create: Button = Style.icon_button(ADD_ICON, Style.ICON_MEDIUM, "Create New Profile")
	create.pressed.connect(_on_new_profile)
	row.add_child(create)

	var import_button: Button = Style.icon_button(
		IMPORT_ICON, Style.ICON_MEDIUM, "Import a GW2Minion .sm Profile")
	import_button.pressed.connect(_on_import)
	row.add_child(import_button)

	_save_button = Button.new()
	_save_button.text = "Save Changes"
	_save_button.custom_minimum_size.y = 20
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_button.visible = false
	Style.tint(_save_button, Style.SAVE_DIRTY, Style.SAVE_DIRTY_HOVER, Style.SAVE_DIRTY_ACTIVE)
	_save_button.pressed.connect(_on_save)
	root.add_child(_save_button)


func _build_settings(root: VBoxContainer) -> void:
	# The fight distance and target attitude are gw2cc settings, shared with
	# every other combat routine. This row only reports what is in force.
	_fight_distance = Label.new()
	_fight_distance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_fight_distance()
	root.add_child(_setting_row(
		"Fight Distance:",
		_fight_distance,
		"Read from gw2cc Settings > Combat > Target Filter (Max Distance). Change it there; the attitude and player / NPC / gadget filters set there apply as well."))

	_swap_mode = OptionButton.new()
	_fill(_swap_mode, SWAP_MODES)
	_swap_mode.item_selected.connect(_on_swap_mode)
	root.add_child(_setting_row(
		"Swap Weapons:",
		_swap_mode,
		"'Automatic'- Automatically switches Weapons/Kits/Stances. 'Manual'-You switch Weapons/Kits/Stances."))

	var latency_box := HBoxContainer.new()
	_latency = HSlider.new()
	_latency.min_value = 0
	_latency.max_value = 1000
	_latency.step = 1
	_latency.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_latency.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_latency.value_changed.connect(_on_latency)
	latency_box.add_child(_latency)
	_latency_value = Label.new()
	_latency_value.custom_minimum_size.x = 36
	latency_box.add_child(_latency_value)
	root.add_child(_setting_row(
		"Network Latency:",
		latency_box,
		"This value (in ms) is added to the duration of each Skill that is cast. If you have a high Ping / network latency, increasing this will reduce the Bot from interrupting Skills."))

	_no_target = CheckBox.new()
	_no_target.toggled.connect(_on_no_target)
	root.add_child(_setting_row(
		"Run without a target:",
		_no_target,
		"Keeps the rotation running when nothing is targeted, so self-heals and buffs still fire out of combat."))

	_distance_units = OptionButton.new()
	_fill(_distance_units, Units.MODE_NAMES)
	_distance_units.item_selected.connect(_on_distance_units)
	root.add_child(_setting_row(
		"Distance Units:",
		_distance_units,
		"Which units ranges are shown and typed in. Profiles always store the GW2 figure, so switching this cannot change how a rotation behaves."))

	var helper := Button.new()
	helper.text = "Skill Set Helper"
	helper.tooltip_text = "Opens the developer window that dumps the current bar as a skill table."
	helper.pressed.connect(func() -> void: _helper.visible = not _helper.visible)
	root.add_child(helper)


## Label pinned to the left column, control starting at x = 150, both matching
## the SameLine(150) / PushItemWidth(120) pair the Lua used.
func _setting_row(text: String, control: Control, tip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var label := Label.new()
	label.text = text
	label.tooltip_text = tip
	label.custom_minimum_size.x = Style.SETTINGS_CONTROL_X
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	control.custom_minimum_size.x = Style.SETTINGS_CONTROL_W
	control.tooltip_text = tip
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


func _build_code_editor(root: VBoxContainer) -> void:
	var section: VBoxContainer = Collapsible.new()
	section.setup(
		"Main Menu Code Editor",
		"GDScript which gets executed from the Main Bot Menu, to render Profile Settings etc. there.",
		false)
	section.toggled_open.connect(_on_code_section_toggled)
	root.add_child(section)
	_code_section = section

	_code_editor = CodeEdit.new()
	_code_editor.custom_minimum_size.y = CODE_EDITOR_HEIGHT
	_code_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_editor.text_changed.connect(_on_code_changed)
	CodeEditorSupport.attach(_code_editor, CodeEditorSupport.MAIN_MENU_ROOTS)
	section.body().add_child(_code_editor)


func _build_action_list(root: VBoxContainer) -> void:
	_action_panel = PanelContainer.new()
	_action_panel.add_theme_stylebox_override("panel", Style.bordered_panel())
	_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_action_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_action_panel.add_child(column)

	var filter_row := HBoxContainer.new()
	var filter_label := Label.new()
	filter_label.text = "Filter"
	filter_row.add_child(Style.dim(filter_label))
	_filter = LineEdit.new()
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.tooltip_text = "To filter the List of Skills below. You cannot drag / drop / sort the list while this filter is active!"
	_filter.text_changed.connect(func(_text: String) -> void: _rebuild_action_list())
	filter_row.add_child(_filter)
	column.add_child(filter_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_action_list = VBoxContainer.new()
	_action_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_action_list)

	var add: Button = Style.icon_button(ADD_ICON, Style.ICON_LARGE, "Add a new Skill.")
	add.pressed.connect(_on_add_action)
	column.add_child(add)


func _open_child_windows() -> void:
	_set_editor = SkillSetEditorScene.instantiate()
	_set_editor.visible = false
	add_child(_set_editor)
	_set_editor.skill_chosen.connect(_on_skill_chosen)
	_set_editor.cancelled.connect(_on_set_editor_cancelled)

	_skill_editor = SkillEditorScene.instantiate()
	_skill_editor.visible = false
	add_child(_skill_editor)
	_skill_editor.changed.connect(_mark_modified)
	_skill_editor.wants_skill_picker.connect(_on_wants_skill_picker)
	_skill_editor.action_deleted.connect(_on_action_deleted)
	_skill_editor.closed.connect(_on_skill_editor_closed)

	_helper = SkillSetHelperScene.instantiate()
	_helper.visible = false
	add_child(_helper)


static func _fill(combo: OptionButton, items: Array) -> void:
	for item: String in items:
		combo.add_item(item)


# --- state in and out ---------------------------------------------------------

func _load_from_plugin() -> void:
	if not _plugin:
		return
	_loading = true
	_refresh_profile_combo()
	var routine := runner()
	if routine:
		_swap_mode.selected = routine.weapon_swap_mode - 1
		_latency.value = routine.network_latency
		_latency_value.text = str(routine.network_latency)
	_no_target.button_pressed = _plugin.run_without_target
	_distance_units.selected = Units.mode()
	_refresh_fight_distance()
	_loading = false
	_on_profile_changed(_plugin.profile)


func _refresh_profile_combo() -> void:
	if not _plugin:
		return
	var was_loading := _loading
	_loading = true
	_profile_combo.clear()
	for index in _plugin.profiles.size():
		var candidate: Resource = _plugin.profiles[index]
		_profile_combo.add_item(candidate.file_name())
		if candidate == _plugin.profile:
			_profile_combo.selected = index
	_loading = was_loading


func _on_profile_changed(value: Resource) -> void:
	_selected_action = null
	_skill_editor.visible = false
	_set_editor.visible = false

	_loading = true
	if value:
		_code_editor.text = value.mainmenu_code
	else:
		_code_editor.text = ""
	_loading = false

	_refresh_profile_combo()
	_rebuild_action_list()
	_refresh_save_button()


func _mark_modified() -> void:
	var current: Resource = profile()
	if not current:
		return
	current.modified = true
	_refresh_save_button()


func _refresh_save_button() -> void:
	var current: Resource = profile()
	_save_button.visible = current != null and current.modified


# --- action list --------------------------------------------------------------

func _rebuild_action_list() -> void:
	for child in _action_list.get_children():
		child.queue_free()
	_tiles.clear()

	var current: Resource = profile()
	if not current:
		return

	var needle: String = _filter.text.to_lower()
	var dragging_allowed: bool = needle.is_empty()

	for index in current.actionlist.size():
		var action: Resource = current.actionlist[index]
		if not action or action.id == 0:
			continue
		if not needle.is_empty() and not action.display_name().to_lower().contains(needle):
			continue
		_action_list.add_child(_build_action_row(action, index, dragging_allowed))

	_clamp_action_list_height()


func _build_action_row(action: Resource, index: int, dragging_allowed: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var links: Array[Resource] = action.chain()
	for position in links.size():
		var link: Resource = links[position]
		if link.id == 0:
			continue
		var tile: Button = ActionButton.new()
		tile.setup(link, index, position > 0)
		tile.drag_enabled = dragging_allowed
		tile.set_selected(link == _selected_action)
		tile.picked.connect(_on_action_picked)
		tile.reordered.connect(_on_action_reordered)
		row.add_child(tile)
		_tiles.append(tile)

	# A standalone action carries its name; a combo chain is identified by its
	# icons alone, as in the original.
	if links.size() == 1:
		var label := Label.new()
		label.text = action.display_name()
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)

	return row


## The window sizes itself to its content, so the Lua's rule that the action list
## may not grow past three fifths of the screen becomes a cap on the window.
## Past that point the list scrolls instead.
func _clamp_action_list_height() -> void:
	await get_tree().process_frame
	var cap: int = int(DisplayServer.screen_get_size().y * ACTION_LIST_SCREEN_FRACTION)
	if size.y > cap:
		size.y = cap


func _on_evaluated(context: RefCounted) -> void:
	if _skill_editor.visible:
		_skill_editor.set_context(context)
	if not visible:
		return
	for tile: Button in _tiles:
		if is_instance_valid(tile):
			tile.refresh()


# --- handlers -----------------------------------------------------------------

func _on_profile_selected(index: int) -> void:
	if _loading or not _plugin:
		return
	if index < 0 or index >= _plugin.profiles.size():
		return
	_plugin.set_profile(_plugin.profiles[index])


func _on_refresh() -> void:
	if _plugin:
		_plugin.reload_profiles()


func _on_new_profile() -> void:
	var dialog: Window = NewProfileDialog.new()
	add_child(dialog)
	dialog.accepted_name.connect(func(file_base: String) -> void:
		if _plugin:
			_plugin.create_profile(file_base)
	)
	dialog.popup_centered()


func _on_import() -> void:
	var chooser := FileDialog.new()
	chooser.title = "Import a GW2Minion Profile"
	chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	chooser.access = FileDialog.ACCESS_FILESYSTEM
	chooser.add_filter("*.sm", "SkillManager Profile")
	chooser.size = Vector2i(760, 520)
	# A FileDialog builds its own contents, so it takes the theme directly
	# rather than the shell.
	chooser.theme = Style.current_theme()
	add_child(chooser)
	chooser.file_selected.connect(_on_import_chosen)
	chooser.canceled.connect(chooser.queue_free)
	chooser.popup_centered()


func _on_import_chosen(path: String) -> void:
	if not _plugin:
		return
	var result: RefCounted = _plugin.import_sm_profile(path)
	_report_import(path, result)


## Says plainly what came across and what did not, rather than leaving the user
## to notice a missing condition later.
func _report_import(path: String, result: RefCounted) -> void:
	var file := path.get_file()
	if not result.ok():
		SceneManager.ui.show_error("Import failed", result.error)
		return

	var notes: Array[String] = ["%d actions" % result.profile.actionlist.size()]
	if not result.unknown_conditions.is_empty():
		notes.append("skipped unknown conditions: " + ", ".join(result.unknown_conditions))
	if not result.unplaced_skills.is_empty():
		notes.append("%d skills had no matching skill set" % result.unplaced_skills.size())
	if result.carried_lua:
		notes.append("custom Lua was kept as comments and needs porting")

	var profession: int = _plugin.current_profession()
	if result.profile.profession != profession:
		SceneManager.ui.show_warning(
			"Imported " + file,
			"This profile is for another profession, so it will not appear until you play that class. "
			+ ", ".join(notes))
		return

	SceneManager.ui.show_notification("Imported " + file, ", ".join(notes))


func _on_save() -> void:
	var current: Resource = profile()
	if current:
		current.save()
	_refresh_save_button()


## Distances are stored in GW2 units, so switching the display unit only rebuilds
## the fields that render one.
func _on_distance_units(index: int) -> void:
	if _loading:
		return
	if _plugin:
		_plugin.set_distance_units(index as Units.Mode)
	else:
		Units.set_mode(index as Units.Mode)
	_refresh_fight_distance()
	_skill_editor.refresh_units()


## Shows the gw2cc fight distance in the chosen display units.
## TargetFilter.max_distance reads back in GW2 units, which is what Units.format
## takes.
func _refresh_fight_distance() -> void:
	if not _fight_distance:
		return
	if not Manager.combat:
		_fight_distance.text = "-"
		return
	var filter: TargetFilter = Manager.combat.default_target_filter
	_fight_distance.text = Units.format(filter.max_distance) + "  (set in gw2cc Settings > Combat)"


func _on_swap_mode(index: int) -> void:
	if _loading or not _plugin:
		return
	_plugin.set_weapon_swap_mode(index + 1)


func _on_latency(value: float) -> void:
	_latency_value.text = str(int(value))
	if _loading or not _plugin:
		return
	_plugin.set_network_latency(int(value))


func _on_no_target(pressed: bool) -> void:
	if _loading or not _plugin:
		return
	_plugin.set_run_without_target(pressed)


func _on_code_changed() -> void:
	if _loading:
		return
	var current: Resource = profile()
	if not current:
		return
	# text_changed also arrives, deferred, after the profile load wrote the text.
	if _code_editor.text == current.mainmenu_code:
		return
	current.mainmenu_code = _code_editor.text
	_mark_modified()


## Unfolding the code editor widens the window and folding it narrows it again,
## the behaviour of sm_profile.lua:528 / 537.
func _on_code_section_toggled(is_open: bool) -> void:
	size.x = WIDTH_WITH_EDITOR if is_open else WIDTH_FOLDED


func _on_add_action() -> void:
	var current: Resource = profile()
	if not current:
		return
	var action: Resource = Skill.new()
	current.actionlist.append(action)
	_selected_action = action
	_mark_modified()
	_rebuild_action_list()
	_show_editor_for(action)


func _on_action_picked(action: Resource) -> void:
	_selected_action = action
	for tile: Button in _tiles:
		if is_instance_valid(tile):
			tile.set_selected(tile.action == action)
	_show_editor_for(_root_of(action))


func _on_action_reordered(from_index: int, to_index: int) -> void:
	var current: Resource = profile()
	if not current:
		return
	if from_index < 0 or from_index >= current.actionlist.size():
		return
	if to_index < 0 or to_index >= current.actionlist.size():
		return
	var moved: Resource = current.actionlist[from_index]
	current.actionlist.remove_at(from_index)
	current.actionlist.insert(to_index, moved)
	_mark_modified()
	_rebuild_action_list()


func _root_of(action: Resource) -> Resource:
	var link := action
	while link and link.skill_prev:
		link = link.skill_prev
	return link


## An action with no skill picked yet goes straight to the palette browser, the
## branch at sm_skill.lua:103-114.
func _show_editor_for(action: Resource) -> void:
	if not action:
		return
	for link: Resource in action.chain():
		if link.id == 0:
			_open_set_editor(link)
			return
	var routine := runner()
	_skill_editor.set_context(routine.context if routine else null)
	_skill_editor.open(action)


func _open_set_editor(link: Resource) -> void:
	_skill_editor.visible = false
	_set_editor.open(link)


func _on_wants_skill_picker(link: Resource) -> void:
	_open_set_editor(link)


func _on_skill_chosen(link: Resource) -> void:
	_mark_modified()
	_rebuild_action_list()
	_show_editor_for(_root_of(link))


## Closing the picker with the X restores the skill that was being replaced, or
## drops the action when there was nothing to restore.
func _on_set_editor_cancelled(link: Resource) -> void:
	if link.id != 0:
		_show_editor_for(_root_of(link))
		return
	_remove_action(_root_of(link))


func _on_action_deleted(action: Resource) -> void:
	_remove_action(action)


func _remove_action(action: Resource) -> void:
	var current: Resource = profile()
	if not current:
		return
	current.actionlist.erase(action)
	_selected_action = null
	_skill_editor.visible = false
	_mark_modified()
	_rebuild_action_list()


func _on_skill_editor_closed() -> void:
	_selected_action = null
	for tile: Button in _tiles:
		if is_instance_valid(tile):
			tile.set_selected(false)
