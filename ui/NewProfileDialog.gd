extends Window

## Port of the NewSMProfile modal (sm_mgr.lua:303-355).
##
## Profiles live under user:// now rather than at an arbitrary path, so the
## original "File Path" field shows that directory read-only instead of letting
## the user type somewhere the client cannot write.

const Style := preload("res://plugins/skill_manager/ui/Style.gd")
const Profile := preload("res://plugins/skill_manager/resources/Profile.gd")

const DIALOG_SIZE := Vector2i(600, 230)
const BUTTON_SIZE := Vector2(80, 30)

signal accepted_name(file_base: String)

var _name_edit: LineEdit = null
var _badge: Button = null
var _ok: Button = null


func _ready() -> void:
	Style.fit_to_contents(self, DIALOG_SIZE)
	size = DIALOG_SIZE
	transient = true
	exclusive = true
	close_requested.connect(queue_free)
	_build()
	_validate()


func _build() -> void:
	var root: VBoxContainer = Style.chrome(self, "Create new SkillManager Profile")
	root.add_theme_constant_override("separation", 6)

	var path_label := Label.new()
	path_label.text = "File Path:"
	root.add_child(path_label)

	var path_edit := LineEdit.new()
	path_edit.text = ProjectSettings.globalize_path(Profile.PROFILE_DIR)
	path_edit.editable = false
	root.add_child(path_edit)

	var name_label := Label.new()
	name_label.text = "File Name:"
	root.add_child(name_label)

	var name_row := HBoxContainer.new()
	root.add_child(name_row)

	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(_text: String) -> void: _validate())
	_name_edit.text_submitted.connect(func(_text: String) -> void: _accept())
	name_row.add_child(_name_edit)

	_badge = Button.new()
	_badge.disabled = true
	_badge.custom_minimum_size.x = 70
	_badge.visible = false
	Style.tint(_badge, Style.INVALID, Style.INVALID, Style.INVALID)
	name_row.add_child(_badge)

	root.add_child(HSeparator.new())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 120)
	root.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = BUTTON_SIZE
	cancel.pressed.connect(queue_free)
	buttons.add_child(cancel)

	_ok = Button.new()
	_ok.text = "Ok"
	_ok.custom_minimum_size = BUTTON_SIZE
	_ok.pressed.connect(_accept)
	buttons.add_child(_ok)

	_name_edit.grab_focus()


## The name may only contain the characters the original sanitizer let through,
## and it may not collide with a profile that already exists.
func _validate() -> void:
	var file_base := _sanitize(_name_edit.text)

	if file_base.is_empty():
		_show_badge("INVALID")
		return
	if Profile.exists(file_base):
		_show_badge("DUPLICATE")
		return

	_badge.visible = false
	_ok.disabled = false


func _show_badge(text: String) -> void:
	_badge.text = text
	_badge.visible = true
	_ok.disabled = true


const _ALLOWED_PUNCTUATION: Array[String] = [" ", "-", "_", "+", "."]

static func _sanitize(raw: String) -> String:
	var cleaned := ""
	for character in raw.strip_edges():
		var code := character.unicode_at(0)
		var alphanumeric := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122)
		if alphanumeric or character in _ALLOWED_PUNCTUATION:
			cleaned += character
	return cleaned.strip_edges()


func _accept() -> void:
	var file_base := _sanitize(_name_edit.text)
	if file_base.is_empty() or Profile.exists(file_base):
		return
	accepted_name.emit(file_base)
	queue_free()
