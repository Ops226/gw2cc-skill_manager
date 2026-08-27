extends Button

## One tile of the action list. Port of `sm_skill:RenderActionButton`
## (sm_skill.lua:623-700): a skill icon tinted by its live verdict, with a
## cooldown sweep drawn over it and a name tag for standalone actions.

const Style := preload("res://plugins/skill_manager/ui/Style.gd")
const Context := preload("res://plugins/skill_manager/runtime/Context.gd")
const SkillState := preload("res://plugins/skill_manager/runtime/SkillState.gd")

const ROOT_SIZE := 35
const COMBO_SIZE := 25

signal picked(action: Resource)
signal reordered(from_index: int, to_index: int)

var action: Resource = null
## Index of the owning action in the profile list, used by drag and drop.
var index: int = 0
## True for links after the first in a combo chain: smaller, no name tag, and
## never a drag source.
var combo_child: bool = false
## Drag and drop is suppressed while the filter box has text, exactly as the
## original warned in its tooltip.
var drag_enabled: bool = true

var _selected: bool = false
var _cooldown: ProgressBar = null


func setup(new_action: Resource, new_index: int, is_combo_child: bool) -> void:
	action = new_action
	index = new_index
	combo_child = is_combo_child

	var size: int = COMBO_SIZE if combo_child else ROOT_SIZE
	custom_minimum_size = Vector2(size, size)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	expand_icon = true
	icon = action.icon_texture()
	if not icon:
		text = action.display_name().left(2)
	tooltip_text = "%s  [%d]" % [action.display_name(), action.id]

	_build_cooldown(size)
	refresh()


func set_selected(value: bool) -> void:
	_selected = value
	refresh()


## Repaints the tint and the cooldown sweep from the action's current verdict.
func refresh() -> void:
	if not action:
		return

	if _selected:
		Style.state_tint(self, Style.State.SELECTED)
	elif _is_casting():
		Style.state_tint(self, Style.State.CASTING)
	elif action.cancast or (action.cancast_flip_combo and combo_child):
		Style.state_tint(self, Style.State.READY)
	else:
		Style.state_tint(self, Style.State.IDLE)

	# Unavailable skills also dim, so a long rotation reads as a few lit tiles
	# rather than a wall of colour.
	modulate.a = 1.0 if _selected or action.cancast else 0.72

	_refresh_cooldown()


func _is_casting() -> bool:
	var player: AgentChar = Manager.agent.controlled_character
	if not player or not action:
		return false
	return Context.casting_id(player) == action.id


func _build_cooldown(size: int) -> void:
	# Combo links are too small to carry a readable sweep, and the Lua skipped
	# them for the same reason.
	if combo_child:
		return
	_cooldown = ProgressBar.new()
	_cooldown.show_percentage = false
	_cooldown.fill_mode = ProgressBar.FILL_TOP_TO_BOTTOM
	_cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown.custom_minimum_size = Vector2(size + 2, size + 4)
	_cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cooldown.min_value = 0.0
	_cooldown.max_value = 1.0

	var background := StyleBoxFlat.new()
	background.bg_color = Style.COOLDOWN_BG
	var fill := StyleBoxFlat.new()
	fill.bg_color = Style.COOLDOWN_FILL
	_cooldown.add_theme_stylebox_override("background", background)
	_cooldown.add_theme_stylebox_override("fill", fill)
	_cooldown.add_theme_color_override("font_color", Style.COOLDOWN_TEXT)
	add_child(_cooldown)


func _refresh_cooldown() -> void:
	if not _cooldown:
		return
	var skill: AbilityDef = action.ability()
	if not skill:
		_cooldown.visible = false
		return
	var remaining: float = SkillState.cooldown_ms(skill)
	var total: float = SkillState.cooldown_max_ms(skill)
	if remaining <= 0.0 or total <= 0.0:
		_cooldown.visible = false
		return
	_cooldown.visible = true
	_cooldown.value = clampf(remaining / total, 0.0, 1.0)


func _pressed() -> void:
	picked.emit(action)


# --- drag and drop reordering -------------------------------------------------

func _get_drag_data(_position: Vector2) -> Variant:
	if not drag_enabled or combo_child:
		return null

	var preview := TextureRect.new()
	preview.texture = icon
	preview.custom_minimum_size = Vector2(30, 30)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_drag_preview(preview)

	# The source tile fades while it is being dragged, as it did in ImGui.
	modulate.a = 0.2
	return {"skill_manager_action_index": index}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not drag_enabled or combo_child:
		return false
	return data is Dictionary and data.has("skill_manager_action_index")


func _drop_data(_position: Vector2, data: Variant) -> void:
	var from: int = data["skill_manager_action_index"]
	if from != index:
		reordered.emit(from, index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		refresh()
