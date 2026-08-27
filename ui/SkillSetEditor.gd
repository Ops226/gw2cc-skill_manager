extends Window

## Port of the Skill Set Editor (sm_skill.lua:117-194): palettes down the left in
## a 120 wide column two icons per row, that palette's skills on the right, and a
## Select Skill button pinned to the bottom right corner.

const Style := preload("res://plugins/skill_manager/ui/Style.gd")
const Palette := preload("res://plugins/skill_manager/runtime/palettes/Palette.gd")
const PaletteRegistry := preload("res://plugins/skill_manager/runtime/palettes/PaletteRegistry.gd")
const Skill := preload("res://plugins/skill_manager/resources/Skill.gd")
const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")

const WINDOW_SIZE := Vector2i(400, 600)
const PALETTE_COLUMN_WIDTH := 120
const PALETTE_ICON := 40
const SKILL_ICON := 30
const PALETTES_PER_ROW := 2
const BUTTON_STRIP_HEIGHT := 25

## Emitted once the user confirms a pick; the target link now carries the skill.
signal skill_chosen(link: Resource)
## Emitted when the window is dismissed without picking anything.
signal cancelled(link: Resource)

var _link: Resource = null
var _palette_grid: GridContainer = null
var _skill_list: VBoxContainer = null
var _select: Button = null

var _current_palette: RefCounted = null
var _current_skill: AbilityDef = null
var _palette_buttons: Dictionary[String, Button] = {}
var _skill_buttons: Dictionary[int, Button] = {}
var _confirmed: bool = false


func _ready() -> void:
	title = "Skill Set Editor"
	Style.apply(self)
	size = WINDOW_SIZE
	wrap_controls = false
	Style.fit_to_contents(self, WINDOW_SIZE)
	close_requested.connect(_on_close)
	_build()


## Shows the picker for one link of a combo chain.
func open(link: Resource) -> void:
	_link = link
	_confirmed = false
	_current_palette = null
	_current_skill = null
	_populate_palettes()
	_populate_skills()
	_refresh_select()
	popup_centered()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var root := VBoxContainer.new()
	margin.add_child(root)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 4)
	root.add_child(columns)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", Style.bordered_panel())
	left.custom_minimum_size.x = PALETTE_COLUMN_WIDTH
	columns.add_child(left)

	var left_scroll := ScrollContainer.new()
	left.add_child(left_scroll)

	_palette_grid = GridContainer.new()
	_palette_grid.columns = PALETTES_PER_ROW
	left_scroll.add_child(_palette_grid)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", Style.bordered_panel())
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(right_scroll)

	_skill_list = VBoxContainer.new()
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_skill_list)

	var strip := HBoxContainer.new()
	strip.custom_minimum_size.y = BUTTON_STRIP_HEIGHT
	strip.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(strip)

	_select = Button.new()
	_select.text = "Select Skill"
	_select.custom_minimum_size.x = 200
	_select.pressed.connect(_on_select)
	strip.add_child(_select)


func _populate_palettes() -> void:
	for child in _palette_grid.get_children():
		child.queue_free()
	_palette_buttons.clear()

	for uid: String in PaletteRegistry.palettes():
		var palette: RefCounted = PaletteRegistry.palettes()[uid]
		var button: Button = Style.icon_button(palette.first_icon(), PALETTE_ICON, palette.tooltip())
		if not button.icon:
			button.text = palette.display_name.left(3)
		Style.state_tint(button, Style.State.IDLE)
		button.pressed.connect(_on_palette_picked.bind(palette))
		_palette_grid.add_child(button)
		_palette_buttons[uid] = button


func _on_palette_picked(palette: RefCounted) -> void:
	_current_palette = palette
	_current_skill = null
	_refresh_palette_tints()
	_populate_skills()
	_refresh_select()


func _refresh_palette_tints() -> void:
	for uid: String in _palette_buttons:
		var button: Button = _palette_buttons[uid]
		if _current_palette and uid == _current_palette.uid:
			Style.state_tint(button, Style.State.SELECTED)
		else:
			Style.state_tint(button, Style.State.IDLE)


func _populate_skills() -> void:
	for child in _skill_list.get_children():
		child.queue_free()
	_skill_buttons.clear()
	if not _current_palette:
		return

	var sorted: Array = _current_palette.skills.duplicate()
	sorted.sort_custom(func(a: AbilityDef, b: AbilityDef) -> bool:
		return a.skill_name.naturalnocasecmp_to(b.skill_name) < 0
	)

	var duplicates := _duplicate_names(sorted)

	for skill: AbilityDef in sorted:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var button: Button = Style.icon_button(
			Palette.skill_icon(skill), SKILL_ICON, "%s  [%d]" % [skill.skill_name, skill.id])
		button.pressed.connect(_on_skill_picked.bind(skill))
		row.add_child(button)

		var label := Label.new()
		label.text = skill.skill_name
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)

		# Several skills in a palette can share a name -- the land and underwater
		# halves of a weapon, or the stages of a chain. Show the id only for
		# those, so the common case stays uncluttered.
		var notes: Array[String] = []
		if skill.skill_name in duplicates:
			notes.append("[%d]" % skill.id)
		if SkillState.is_aquatic_only(skill):
			notes.append("(aquatic)")
		if not notes.is_empty():
			var note := Label.new()
			note.text = " ".join(notes)
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(Style.dim(note))

		_skill_list.add_child(row)
		_skill_buttons[skill.id] = button


## The names carried by more than one skill of the palette.
static func _duplicate_names(skills: Array) -> Dictionary[String, bool]:
	var seen: Dictionary[String, bool] = {}
	var repeated: Dictionary[String, bool] = {}
	for skill: AbilityDef in skills:
		if seen.has(skill.skill_name):
			repeated[skill.skill_name] = true
		seen[skill.skill_name] = true
	return repeated


func _on_skill_picked(skill: AbilityDef) -> void:
	_current_skill = skill
	for skill_id: int in _skill_buttons:
		var button: Button = _skill_buttons[skill_id]
		if skill_id == skill.id:
			Style.state_tint(button, Style.State.SELECTED)
		else:
			Style.state_tint(button, Style.State.IDLE)
	_refresh_select()


func _refresh_select() -> void:
	_select.visible = _current_skill != null


## Copies the palette data into the link, the way sm_skill.lua:161-183 did.
func _on_select() -> void:
	if not _link or not _current_skill or not _current_palette:
		return

	_link.id = _current_skill.id
	_link.skillpaletteuid = _current_palette.uid
	_link.slot = _current_palette.slot_of(_current_skill.id)
	_link.activationtime = Manager.skill.calculate_skill_timing(_current_skill)
	_link.instantcast = SkillUtils.is_instant_cast(_current_skill)
	_link.requireslos = true
	# Weapon skills define the bot's engagement range; utilities do not.
	_link.setsattackrange = _link.slot in SkillConstants.WEAPON_SKILL_BAR
	_link.invalidate_script()

	_confirmed = true
	hide()
	skill_chosen.emit(_link)


func _on_close() -> void:
	hide()
	if not _confirmed and _link:
		cancelled.emit(_link)
