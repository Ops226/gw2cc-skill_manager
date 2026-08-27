extends Window

## Port of the Skill Set Helper (sm_mgr.lua:580-660). A developer aid that dumps
## the live bar as a table you can paste into a rotation. The original had no way
## to open it at all; here the main window offers a button.

const Style := preload("res://plugins/skill_manager/ui/Style.gd")

const WINDOW_SIZE := Vector2i(300, 500)
const OUTPUT_SIZE := Vector2(280, 450)

## The slot groups the original offered under its 0..16 combo.
const GROUPS: Array[String] = [
	"Weapon skills",
	"Heal, utilities and elite",
	"Profession skills",
	"Everything",
]

var _group: OptionButton = null
var _output: TextEdit = null


func _ready() -> void:
	title = "Skill Set Helper"
	Style.apply(self)
	size = WINDOW_SIZE
	wrap_controls = false
	Style.fit_to_contents(self, WINDOW_SIZE)
	close_requested.connect(hide)
	_build()
	visibility_changed.connect(func() -> void:
		if visible:
			_refresh()
	)


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

	_group = OptionButton.new()
	for name: String in GROUPS:
		_group.add_item(name)
	_group.item_selected.connect(func(_index: int) -> void: _refresh())
	root.add_child(_group)

	root.add_child(HSeparator.new())

	_output = TextEdit.new()
	_output.custom_minimum_size = OUTPUT_SIZE
	_output.editable = false
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_output)

	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.pressed.connect(_refresh)
	root.add_child(refresh)


func _refresh() -> void:
	var player: AgentChar = Manager.agent.controlled_character
	if not player or not player.has_component(SkillBar):
		_output.text = "No character."
		return

	var lines: Array[String] = []
	for slot: int in _slots_for(_group.selected):
		var bar: Array = player.skill_bar.skills
		if slot >= bar.size() or not bar[slot]:
			continue
		var skill: AbilityDef = bar[slot]
		lines.append("%d: # %s (slot %d, cast %.2fs)" % [
			skill.id,
			skill.skill_name,
			slot,
			Manager.skill.calculate_skill_timing(skill),
		])

	_output.text = "\n".join(lines) if not lines.is_empty() else "Nothing on that part of the bar."


static func _slots_for(group: int) -> Array:
	match group:
		0:
			return SkillConstants.WEAPON_SKILL_BAR
		1:
			return SkillConstants.HEAL_SKILL_BAR + SkillConstants.UTILITY_SKILL_BAR + SkillConstants.ELITE_SKILL_BAR
		2:
			return SkillConstants.PROFESSION_BAR
	return SkillConstants.WEAPON_SKILL_BAR \
		+ SkillConstants.HEAL_SKILL_BAR \
		+ SkillConstants.UTILITY_SKILL_BAR \
		+ SkillConstants.ELITE_SKILL_BAR \
		+ SkillConstants.PROFESSION_BAR
