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
const TEXT_DISABLED := Color(0.718, 0.741, 0.788, 0.45)

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

## Focus ring for the code editors, the one place a lit border is wanted.
const PANEL_ACCENT_BORDER := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)

static var _theme: Theme = null

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


## Removes a tint previously applied by [method tint].
static func untint(button: Button) -> void:
	for slot in ["normal", "hover", "pressed", "focus"]:
		button.remove_theme_stylebox_override(slot)


## A bordered child region, the equivalent of ImGui BeginChild(..., border = true).
static func bordered_panel() -> StyleBoxFlat:
	var box := surface(PANEL_BG)
	box.set_content_margin_all(6)
	return box


## The plugin theme: the house theme with the light parchment buttons swapped for
## the same inset surface LineEdit already uses, and the text flipped to suit.
## Applied to each window root so every child inherits it.
static func build_theme() -> Theme:
	if _theme:
		return _theme

	_theme = Theme.new()
	for type_name in ["Button", "OptionButton", "MenuButton"]:
		_theme.set_stylebox("normal", type_name, surface(SURFACE_BG))
		_theme.set_stylebox("hover", type_name, surface(SURFACE_HOVER))
		_theme.set_stylebox("pressed", type_name, surface(SURFACE_PRESSED))
		_theme.set_stylebox("hover_pressed", type_name, surface(SURFACE_PRESSED))
		_theme.set_stylebox("disabled", type_name, surface(SURFACE_DISABLED))
		_theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		_theme.set_color("font_color", type_name, TEXT)
		_theme.set_color("font_focus_color", type_name, TEXT)
		_theme.set_color("font_hover_color", type_name, ACCENT)
		_theme.set_color("font_pressed_color", type_name, ACCENT)
		_theme.set_color("font_hover_pressed_color", type_name, ACCENT)
		_theme.set_color("font_disabled_color", type_name, TEXT_DISABLED)

	# A check box is its own tick mark. Giving it a filled surface turns the row
	# into a wide empty bar, so it only gets the text colour.
	for slot in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_theme.set_stylebox(slot, "CheckBox", StyleBoxEmpty.new())
	_theme.set_color("font_color", "CheckBox", TEXT)
	_theme.set_color("font_hover_color", "CheckBox", ACCENT)
	_theme.set_color("font_pressed_color", "CheckBox", ACCENT)

	_theme.set_stylebox("panel", "PanelContainer", surface(PANEL_BG))
	_theme.set_color("font_color", "Label", TEXT)

	for type_name in ["TextEdit", "CodeEdit"]:
		_theme.set_stylebox("normal", type_name, surface(SURFACE_BG))
		_theme.set_stylebox("focus", type_name, surface(SURFACE_BG, PANEL_ACCENT_BORDER))
		_theme.set_stylebox("read_only", type_name, surface(SURFACE_DISABLED))
		_theme.set_color("font_color", type_name, TEXT)
		_theme.set_color("font_readonly_color", type_name, TEXT_DISABLED)

	return _theme


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


## Gives a window the plugin theme. Controls inherit it from their window root.
static func apply(window: Window) -> void:
	window.theme = build_theme()


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
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
