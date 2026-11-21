extends RefCounted

## Colours and widget helpers for the SkillManager windows.
##
## GW2Minion painted its ImGui tiles in fully saturated primaries: pure red for
## every skill that could not be cast right now, pure green for the ones that
## could. Since most of a rotation is on cooldown most of the time, that meant a
## wall of red. The states here carry the same meaning but let the eye rest:
## unavailable is a dim neutral, and only the things that want attention -- ready,
## casting, selected, unsaved -- take colour. The hues follow the accents the rest
## of GW2CC already uses.

# --- palette ------------------------------------------------------------------

## House accents, shared with the other combat plugins.
const ACCENT := Color(0.659, 0.914, 1.0)
const GOOD := Color(0.271, 0.902, 0.659)
const WARN := Color(1.0, 0.784, 0.341)
const BAD := Color(1.0, 0.420, 0.420)
const MUTED := Color(0.718, 0.741, 0.788)

## Section headings and secondary text.
const HEADING_COLOR := ACCENT
const MUTED_COLOR := MUTED

## The inset surface the house theme already uses for LineEdit. Everything in
## these windows is built from it, so the whole plugin reads as one material.
## Copied from assets/default_theme.tres, LineEdit/styles/normal.
const SURFACE_BG := Color(0.117647, 0.117647, 0.117647, 0.670588)
const SURFACE_BORDER := Color(0.050980, 0.050980, 0.050980, 1.0)
const SURFACE_BORDER_WIDTH := 2

## The same surface lifted for the interactive states.
const SURFACE_HOVER := Color(0.180000, 0.190000, 0.210000, 0.780000)
const SURFACE_PRESSED := Color(0.230000, 0.245000, 0.270000, 0.880000)
const SURFACE_DISABLED := Color(0.117647, 0.117647, 0.117647, 0.400000)

## Nested panels sit lighter so they do not stack into a black hole.
const PANEL_BG := Color(0.117647, 0.117647, 0.117647, 0.380000)

## The house Button style is a light parchment with near-black text. On the dark
## surface used here the text has to go the other way.
const TEXT := Color(0.870, 0.880, 0.900)

# --- skill tile states --------------------------------------------------------

enum State {
	## Nothing to say about it: on cooldown, out of range, conditions unmet.
	IDLE,
	## Every gate passed; this is what the rotation would fire next.
	READY,
	## Being cast right now.
	CASTING,
	## Picked in the editor.
	SELECTED,
}

const IDLE_TINT := Color(0.55, 0.60, 0.68, 0.16)
const IDLE_TINT_HOVER := Color(0.60, 0.66, 0.74, 0.30)
const IDLE_TINT_ACTIVE := Color(0.65, 0.71, 0.80, 0.42)

const READY_TINT := Color(GOOD.r, GOOD.g, GOOD.b, 0.42)
const READY_TINT_HOVER := Color(GOOD.r, GOOD.g, GOOD.b, 0.58)
const READY_TINT_ACTIVE := Color(GOOD.r, GOOD.g, GOOD.b, 0.72)

const CASTING_TINT := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.50)
const CASTING_TINT_HOVER := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.66)
const CASTING_TINT_ACTIVE := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.80)

const SELECTED_TINT := Color(WARN.r, WARN.g, WARN.b, 0.52)
const SELECTED_TINT_HOVER := Color(WARN.r, WARN.g, WARN.b, 0.66)
const SELECTED_TINT_ACTIVE := Color(WARN.r, WARN.g, WARN.b, 0.80)

## Armed half of a two-click delete, and the unsaved-changes button.
const ARMED := Color(BAD.r, BAD.g, BAD.b, 0.45)
const ARMED_HOVER := Color(BAD.r, BAD.g, BAD.b, 0.62)
const ARMED_ACTIVE := Color(BAD.r, BAD.g, BAD.b, 0.78)

const SAVE_DIRTY := Color(WARN.r, WARN.g, WARN.b, 0.40)
const SAVE_DIRTY_HOVER := Color(WARN.r, WARN.g, WARN.b, 0.56)
const SAVE_DIRTY_ACTIVE := Color(WARN.r, WARN.g, WARN.b, 0.70)

## Rejected input in the new-profile dialog.
const INVALID := Color(BAD.r, BAD.g, BAD.b, 0.40)

## Recharge sweep drawn over a tile.
const COOLDOWN_TEXT := Color(1.0, 1.0, 1.0, 1.0)
const COOLDOWN_BG := Color(0.02, 0.03, 0.05, 0.55)
const COOLDOWN_FILL := Color(1.0, 1.0, 1.0, 0.18)

# --- layout -------------------------------------------------------------------

## Label column offsets of the Skill Editor detail grid (sm_skill.lua:323-349).
const GRID_LABEL_LEFT := 0
const GRID_VALUE_LEFT := 125
const GRID_LABEL_RIGHT := 300
const GRID_VALUE_RIGHT := 425

## Label / control columns of the main window settings block (sm_profile.lua:494-517).
const SETTINGS_CONTROL_X := 150
const SETTINGS_CONTROL_W := 120

## Icon button sizes. GW2Minion drew these at 13 to 15 pixels, which is fine in
## ImGui and uncomfortably small here. Nudged up to something clickable without
## turning the profile row into a toolbar.
const ICON_SMALL := 16
const ICON_MEDIUM := 20
const ICON_LARGE := 26

const CORNER_RADIUS := 4

# --- window chrome ------------------------------------------------------------
#
# The shell every SkillManager window sits in, the same one the Valkyrie
# Luminary plugin uses: a borderless, transparent Window holding one panel on
# the gw2cc dark / light theme, a draggable title bar with a theme toggle and a
# close button, a separator, then the content.

const DARK_THEME: Theme = preload("res://assets/themes/gw2cc_dark_theme.tres")
const LIGHT_THEME: Theme = preload("res://assets/themes/gw2cc_light_theme.tres")
const TitleBar := preload("res://assets/themes/DraggableTitleBar.gd")
const ResizeGrip := preload("res://plugins/skill_manager/ui/widgets/ResizeGrip.gd")

## Shared with GW2CCThemeManager, so one toggle moves every window that uses it.
const THEME_SECTION := "GW2CC_Theme"
const THEME_KEY := "dark_mode"

const TITLE_BAR_HEIGHT := 20
const TITLE_BUTTON_SIZE := 20
const CONTENT_MARGIN := 6
const CHROME_SEPARATION := 4
const RESIZE_GRIP_SIZE := 16


static var _themed_panels: Array = []
static var _title_bars: Array = []


static func is_dark_mode() -> bool:
	return ConfigService.get_value(THEME_SECTION, THEME_KEY, true)


## The theme in force right now. For the stock dialogs -- FileDialog,
## ConfirmationDialog -- that build their own contents and cannot take the
## shell: give them this so they match the windows they open from.
static func current_theme() -> Theme:
	return DARK_THEME if is_dark_mode() else LIGHT_THEME


static func set_dark_mode(dark: bool) -> void:
	ConfigService.set_value(THEME_SECTION, THEME_KEY, dark)
	ConfigService.save_cfg()
	_repaint(dark)


static func _repaint(dark: bool) -> void:
	var theme: Theme = DARK_THEME if dark else LIGHT_THEME
	_themed_panels = _themed_panels.filter(func(node: Variant) -> bool: return is_instance_valid(node))
	_title_bars = _title_bars.filter(func(node: Variant) -> bool: return is_instance_valid(node))
	for panel: PanelContainer in _themed_panels:
		panel.theme = theme
	for bar: Variant in _title_bars:
		bar.set_theme_icon(dark)


## Dresses [param window] in the shared shell and returns the column the
## caller builds its content into. The title bar's close button raises the
## window's own close_requested, so whatever the window already does on close
## keeps happening.
static func chrome(window: Window, title: String) -> VBoxContainer:
	window.title = title
	window.borderless = true
	window.transparent_bg = true

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.theme = current_theme()
	window.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", CHROME_SEPARATION)
	panel.add_child(column)

	var bar := HBoxContainer.new()
	bar.name = "TitleBar"
	bar.custom_minimum_size.y = TITLE_BAR_HEIGHT
	bar.add_theme_constant_override("separation", CHROME_SEPARATION)

	var label := Label.new()
	label.name = "TitleLabel"
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)

	var toggle := Button.new()
	toggle.name = "ThemeToggle"
	toggle.text = "🌙" if is_dark_mode() else "☀️"
	toggle.custom_minimum_size = Vector2(TITLE_BUTTON_SIZE, TITLE_BUTTON_SIZE)
	toggle.tooltip_text = "Toggle Dark/Light Theme"
	bar.add_child(toggle)

	var close := Button.new()
	close.name = "CloseButton"
	close.text = "✕"
	close.custom_minimum_size = Vector2(TITLE_BUTTON_SIZE, TITLE_BUTTON_SIZE)
	close.tooltip_text = "Close"
	bar.add_child(close)

	# DraggableTitleBar looks its children up in _ready, so the script goes on
	# before the bar enters the tree.
	bar.set_script(TitleBar)
	bar.set("title_text", title)
	column.add_child(bar)
	bar.connect("theme_toggle_requested", func() -> void: set_dark_mode(not is_dark_mode()))
	bar.connect("close_requested", func() -> void: window.close_requested.emit())

	column.add_child(HSeparator.new())

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, CONTENT_MARGIN)
	column.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", CHROME_SEPARATION)
	margin.add_child(content)

	# The grip is a child of the window, not of the panel, so the container
	# does not stretch it; it anchors itself to the corner.
	var grip: Control = ResizeGrip.new()
	grip.window = window
	grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grip.offset_left = -RESIZE_GRIP_SIZE
	grip.offset_top = -RESIZE_GRIP_SIZE
	window.add_child(grip)

	_themed_panels.append(panel)
	_title_bars.append(bar)
	return content


# --- helpers ------------------------------------------------------------------

## One surface panel. Every stylebox in the plugin comes from here.
static func surface(bg: Color, border: Color = SURFACE_BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(SURFACE_BORDER_WIDTH)
	box.border_blend = true
	box.set_corner_radius_all(CORNER_RADIUS)
	return box


static func _box(color: Color) -> StyleBoxFlat:
	var box := surface(color)
	box.set_content_margin_all(2)
	return box


## Applies a three-state button tint.
static func tint(button: Button, base: Color, hover: Color, active: Color) -> void:
	button.add_theme_stylebox_override("normal", _box(base))
	button.add_theme_stylebox_override("hover", _box(hover))
	button.add_theme_stylebox_override("pressed", _box(active))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Paints a skill tile for one of the four states it can be in.
static func state_tint(button: Button, state: State) -> void:
	match state:
		State.READY:
			tint(button, READY_TINT, READY_TINT_HOVER, READY_TINT_ACTIVE)
		State.CASTING:
			tint(button, CASTING_TINT, CASTING_TINT_HOVER, CASTING_TINT_ACTIVE)
		State.SELECTED:
			tint(button, SELECTED_TINT, SELECTED_TINT_HOVER, SELECTED_TINT_ACTIVE)
		_:
			tint(button, IDLE_TINT, IDLE_TINT_HOVER, IDLE_TINT_ACTIVE)


## Returns a button to the plain surface look. Icon buttons must not fall back
## to the theme's Button style: its 8 px content margins leave a 20 px button
## with 4 px for the icon.
static func untint(button: Button) -> void:
	tint(button, SURFACE_BG, SURFACE_HOVER, SURFACE_PRESSED)


## A bordered child region, the equivalent of ImGui BeginChild(..., border = true).
static func bordered_panel() -> StyleBoxFlat:
	var box := surface(PANEL_BG)
	box.set_content_margin_all(6)
	return box


## How many rows a dropdown shows before it starts scrolling. The condition list
## is 36 long, the buff list 46, and the skill name list runs to hundreds -- all
## of which render as one enormous menu unless they are capped.
const POPUP_MAX_VISIBLE := 12
## Rough row height. The popup scrolls once its contents pass the cap, so being a
## little out only shifts how many rows are visible.
const POPUP_ROW_HEIGHT := 26


## Caps a dropdown's height so long lists scroll rather than covering the screen.
static func bound_popup(combo: OptionButton, max_visible: int = POPUP_MAX_VISIBLE) -> void:
	var popup := combo.get_popup()
	# A zero axis means unconstrained, so only the height is pinned.
	popup.max_size = Vector2i(0, max_visible * POPUP_ROW_HEIGHT)


## Stops a window being sized below what its contents need.
##
## These windows do not grow to fit, so without a floor they can be dragged --
## or restored from a saved geometry -- narrow enough to cut the right hand
## column and the row buttons clean off. The floor is whatever the contents
## actually ask for, never below the design size and never past the screen.
static func fit_to_contents(window: Window, design: Vector2i) -> void:
	await window.get_tree().process_frame

	var needed := window.get_contents_minimum_size()
	var floor_size := Vector2i(
		maxi(design.x, int(ceil(needed.x))),
		maxi(design.y, int(ceil(needed.y))))

	# Never demand more than the screen can show. A headless display reports a
	# zero size, which must not be mistaken for a screen with no room on it.
	var screen := DisplayServer.screen_get_size()
	if screen.x > 0 and screen.y > 0:
		floor_size.x = mini(floor_size.x, screen.x)
		floor_size.y = mini(floor_size.y, screen.y)

	window.min_size = floor_size
	window.size = Vector2i(
		maxi(window.size.x, floor_size.x),
		maxi(window.size.y, floor_size.y))


## Square texture button used for all the chrome icons (refresh, add, delete, ...).
static func icon_button(texture: Texture2D, size: int, tip: String = "") -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(size, size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.icon = texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tip
	untint(button)
	return button


## A section heading, in the accent colour.
static func heading(text: String, tip: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.tooltip_text = tip
	label.add_theme_color_override("font_color", HEADING_COLOR)
	return label


## Secondary text, dimmed so it reads as annotation rather than content.
static func dim(label: Label) -> Label:
	label.add_theme_color_override("font_color", MUTED_COLOR)
	return label
