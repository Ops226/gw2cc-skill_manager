extends Window

## The Skill Set Editor: picks the skill one rotation step fires.
##
## GW2Minion listed every palette it knew as its own tile (sm_skill.lua:117-194),
## which on a revenant or an engineer ran to a dozen icons with no hint of what
## was behind them. The column here is cut down to what a player thinks in: the
## two land weapon sets, the aquatic sets only while an underwater weapon is
## equipped, and one "Skills" category that gathers heal, utilities, elite and
## the profession mechanics -- attunements, shroud, legends, kits -- under
## sub-headings. Every row still remembers the palette it came from, which is
## what the runner needs in order to swap to it.

const Style := preload("res://plugins/skill_manager/ui/Style.gd")
const Palette := preload("res://plugins/skill_manager/runtime/palettes/Palette.gd")
const PaletteRegistry := preload("res://plugins/skill_manager/runtime/palettes/PaletteRegistry.gd")
const WeaponSetPalette := preload("res://plugins/skill_manager/runtime/palettes/WeaponSetPalette.gd")
const ProfessionStatePalette := preload("res://plugins/skill_manager/runtime/palettes/ProfessionStatePalette.gd")
const TransformPalette := preload("res://plugins/skill_manager/runtime/palettes/TransformPalette.gd")
const UtilityPalette := preload("res://plugins/skill_manager/runtime/palettes/UtilityPalette.gd")
const WeaponTypePalette := preload("res://plugins/skill_manager/runtime/palettes/WeaponTypePalette.gd")
const Skill := preload("res://plugins/skill_manager/resources/Skill.gd")
const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")

const WINDOW_SIZE := Vector2i(440, 600)
const CATEGORY_COLUMN_WIDTH := 140
const CATEGORY_BUTTON_HEIGHT := 44
const SKILL_ICON := 30
const BUTTON_STRIP_HEIGHT := 25

const SKILLS_CATEGORY := "Skills"
const SKILLS_TIP := "Every heal, utility, elite and profession mechanic of every specialization, plus attunements, shroud, legends and kits. Skills not on the bar wait until they are slotted."
const WEAPONS_CATEGORY := "Weapons"
const WEAPONS_TIP := "Every weapon the profession can wield, equipped or not. A skill picked here follows the weapon to whichever set it is on."

## Sub-headings the Common palette is split into, in display order.
const SECTION_HEAL := "Heal"
const SECTION_UTILITY := "Utility"
const SECTION_ELITE := "Elite"
const SECTION_PROFESSION := "Profession"
const SECTION_OTHER := "Other"
const COMMON_SECTION_ORDER: Array[String] = [
	SECTION_HEAL, SECTION_UTILITY, SECTION_ELITE, SECTION_PROFESSION, SECTION_OTHER,
]

## Emitted once the user confirms a pick; the target link now carries the skill.
signal skill_chosen(link: Resource)
## Emitted when the window is dismissed without picking anything.
signal cancelled(link: Resource)


## One entry of the left column.
class Category:
	var key: String = ""
	var label: String = ""
	var tip: String = ""
	## Ordered `{title: String, palette: RefCounted, skills: Array}` blocks. A
	## weapon set has one untitled block; the Skills category has one per
	## sub-heading.
	var sections: Array[Dictionary] = []


var _link: Resource = null
var _category_list: VBoxContainer = null
var _skill_list: VBoxContainer = null
var _select: Button = null

var _categories: Array[Category] = []
var _current_category: Category = null
var _current_palette: RefCounted = null
var _current_skill: AbilityDef = null
var _category_buttons: Dictionary[String, Button] = {}
## A skill can sit in more than one section of the Skills category -- the
## toolbelt shows under Profession and again inside every attunement -- so the
## rows are tracked by button, not by skill id.
var _skill_buttons: Array[Button] = []
var _selected_button: Button = null
var _confirmed: bool = false


func _ready() -> void:
	size = WINDOW_SIZE
	wrap_controls = false
	close_requested.connect(_on_close)
	_build()
	Style.fit_to_contents(self, WINDOW_SIZE)


## Shows the picker for one link of a combo chain.
func open(link: Resource) -> void:
	_link = link
	_confirmed = false
	_current_category = null
	_current_palette = null
	_current_skill = null
	_selected_button = null
	_build_categories()
	_populate_categories()
	# Land in the first weapon set, so the common case is one click shorter.
	if not _categories.is_empty():
		_on_category_picked(_categories[0])
	else:
		_populate_skills()
	_refresh_select()
	popup_centered()


# --- construction -------------------------------------------------------------

func _build() -> void:
	var root: VBoxContainer = Style.chrome(self, "Skill Set Editor")

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 4)
	root.add_child(columns)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", Style.bordered_panel())
	left.custom_minimum_size.x = CATEGORY_COLUMN_WIDTH
	columns.add_child(left)

	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)

	_category_list = VBoxContainer.new()
	_category_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_list.add_theme_constant_override("separation", 4)
	left_scroll.add_child(_category_list)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", Style.bordered_panel())
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	# Horizontal scrolling stays enabled on purpose: with it disabled a
	# ScrollContainer takes its minimum width from its content, so one long
	# skill name would widen the column, push the title bar past the window
	# edge and take the close button with it.
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(right_scroll)

	_skill_list = VBoxContainer.new()
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list.add_theme_constant_override("separation", 2)
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


# --- categories ---------------------------------------------------------------

## Folds the registry's palettes into the short list the column shows.
func _build_categories() -> void:
	_categories.clear()

	var common: Array[Dictionary] = []
	var states: Array[Dictionary] = []
	var kits: Array[Dictionary] = []
	var weapons: Array[Dictionary] = []

	var palettes: Dictionary = PaletteRegistry.palettes()
	for uid: String in palettes:
		var palette: RefCounted = palettes[uid]
		if palette is WeaponSetPalette:
			_categories.append(_weapon_set_category(palette))
		elif palette is WeaponTypePalette:
			weapons.append(_section(palette.display_name, palette, palette.skills))
		elif palette is UtilityPalette:
			common = _split_common(palette)
		elif palette is ProfessionStatePalette:
			states.append(_section(palette.display_name, palette, palette.skills))
		elif palette is TransformPalette:
			kits.append(_section(palette.uid, palette, palette.skills))

	var skills := Category.new()
	skills.key = SKILLS_CATEGORY
	skills.label = SKILLS_CATEGORY
	skills.tip = SKILLS_TIP
	skills.sections = common + states + kits
	if not skills.sections.is_empty():
		_categories.append(skills)

	weapons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["title"]).naturalnocasecmp_to(str(b["title"])) < 0
	)
	var all_weapons := Category.new()
	all_weapons.key = WEAPONS_CATEGORY
	all_weapons.label = WEAPONS_CATEGORY
	all_weapons.tip = WEAPONS_TIP
	all_weapons.sections = weapons
	if not all_weapons.sections.is_empty():
		_categories.append(all_weapons)


## The registry only builds a weapon set that has a weapon in it, so an aquatic
## category shows up exactly when an underwater weapon is equipped.
func _weapon_set_category(palette: RefCounted) -> Category:
	var category := Category.new()
	category.key = palette.uid
	category.label = _weapon_set_caption(palette)
	category.tip = palette.tooltip()
	category.sections.append(_section("", palette, palette.skills))
	return category


## "Weapon Set 1" over the equipped weapons, so the tile says both which set
## it is and what is in it.
static func _weapon_set_caption(palette: RefCounted) -> String:
	var aquatic: bool = palette.weapon_set in PaletteRegistry.AQUATIC_WEAPON_SETS
	var first: bool = palette.weapon_set in [ItemStorage.WEAPON_SET_LAND_1, ItemStorage.WEAPON_SET_AQUATIC_1]
	var caption := ("Aquatic Set " if aquatic else "Weapon Set ") + ("1" if first else "2")
	var weapons: String = palette.display_name.trim_suffix(" (aquatic)")
	if weapons.is_empty() or weapons == palette.uid:
		return caption
	return caption + "\n" + weapons


## Splits the Common palette by the bar slot each skill occupies.
static func _split_common(palette: RefCounted) -> Array[Dictionary]:
	var groups: Dictionary[String, Array] = {}
	for skill: AbilityDef in palette.skills:
		var group := _slot_group(palette.slot_of(skill.id))
		if not groups.has(group):
			groups[group] = []
		groups[group].append(skill)

	var sections: Array[Dictionary] = []
	for title: String in COMMON_SECTION_ORDER:
		if groups.has(title):
			sections.append(_section(title, palette, groups[title]))
	return sections


static func _slot_group(slot: int) -> String:
	if slot in SkillConstants.HEAL_SKILL_BAR:
		return SECTION_HEAL
	if slot in SkillConstants.UTILITY_SKILL_BAR:
		return SECTION_UTILITY
	if slot in SkillConstants.ELITE_SKILL_BAR:
		return SECTION_ELITE
	if slot in PaletteRegistry.TOOLBELT_SLOTS:
		return SECTION_PROFESSION
	return SECTION_OTHER


static func _section(title: String, palette: RefCounted, skills: Array) -> Dictionary:
	return {"title": title, "palette": palette, "skills": skills}


func _populate_categories() -> void:
	for child in _category_list.get_children():
		child.queue_free()
	_category_buttons.clear()

	for category: Category in _categories:
		var button := Button.new()
		button.text = category.label
		button.tooltip_text = category.tip
		button.custom_minimum_size.y = CATEGORY_BUTTON_HEIGHT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.clip_text = true
		Style.state_tint(button, Style.State.IDLE)
		button.pressed.connect(_on_category_picked.bind(category))
		_category_list.add_child(button)
		_category_buttons[category.key] = button


func _on_category_picked(category: Category) -> void:
	_current_category = category
	_current_palette = null
	_current_skill = null
	_selected_button = null
	_refresh_category_tints()
	_populate_skills()
	_refresh_select()


func _refresh_category_tints() -> void:
	for key: String in _category_buttons:
		var button: Button = _category_buttons[key]
		if _current_category and key == _current_category.key:
			Style.state_tint(button, Style.State.SELECTED)
		else:
			Style.state_tint(button, Style.State.IDLE)


# --- skills -------------------------------------------------------------------

func _populate_skills() -> void:
	for child in _skill_list.get_children():
		child.queue_free()
	_skill_buttons.clear()
	if not _current_category:
		return

	for section: Dictionary in _current_category.sections:
		var title: String = section["title"]
		if not title.is_empty():
			_skill_list.add_child(Style.heading(title))
		var palette: RefCounted = section["palette"]
		var ordered: Array = _bar_order(section["skills"], palette)
		var duplicates := _duplicate_names(ordered)
		for skill: AbilityDef in ordered:
			_skill_list.add_child(_skill_row(skill, palette, duplicates))


## Skills in the order they sit on the bar, so a weapon set reads 1 to 5 and a
## chain stays next to the skill that starts it. The order the palette collected
## them in is kept as the tie breaker.
static func _bar_order(skills: Array, palette: RefCounted) -> Array:
	var indexed: Array = []
	for index in skills.size():
		indexed.append([palette.slot_of(skills[index].id), index, skills[index]])
	indexed.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1]
	)
	var ordered: Array = []
	for entry: Array in indexed:
		ordered.append(entry[2])
	return ordered


func _skill_row(skill: AbilityDef, palette: RefCounted, duplicates: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var button: Button = Style.icon_button(
		Palette.skill_icon(skill), SKILL_ICON, "%s  [%d]" % [skill.skill_name, skill.id])
	Style.state_tint(button, Style.State.IDLE)
	button.pressed.connect(_on_skill_picked.bind(skill, palette, button))
	row.add_child(button)

	var label := Label.new()
	label.text = skill.skill_name
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)

	# Several skills in a section can share a name -- the land and underwater
	# halves of a weapon, or the stages of a chain. Show the id only for those,
	# so the common case stays uncluttered.
	var notes: Array[String] = []
	if skill.skill_name in duplicates:
		notes.append("[%d]" % skill.id)
	if SkillState.is_aquatic_only(skill):
		notes.append("(aquatic)")
	if palette.specializations.has(skill.id):
		notes.append("(%s)" % palette.specializations[skill.id])
	if not notes.is_empty():
		var note := Label.new()
		note.text = " ".join(notes)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(Style.dim(note))

	_skill_buttons.append(button)
	return row


## The names carried by more than one skill of the section.
static func _duplicate_names(skills: Array) -> Dictionary[String, bool]:
	var seen: Dictionary[String, bool] = {}
	var repeated: Dictionary[String, bool] = {}
	for skill: AbilityDef in skills:
		if seen.has(skill.skill_name):
			repeated[skill.skill_name] = true
		seen[skill.skill_name] = true
	return repeated


func _on_skill_picked(skill: AbilityDef, palette: RefCounted, button: Button) -> void:
	_current_skill = skill
	_current_palette = palette
	_selected_button = button
	for candidate: Button in _skill_buttons:
		if not is_instance_valid(candidate):
			continue
		if candidate == button:
			Style.state_tint(candidate, Style.State.SELECTED)
		else:
			Style.state_tint(candidate, Style.State.IDLE)
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
