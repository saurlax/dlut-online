extends Control

signal editing_finished(resume: bool)
const Rules = preload("res://scripts/shared/chat_rules.gd")
var network: Node
var records: RichTextLabel
var input: LineEdit
var editing := false
var ime_confirming := false

func configure(connection: Node) -> void:
	network = connection
	name = "WorldChat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	records = RichTextLabel.new()
	records.name = "Messages"
	records.bbcode_enabled = false
	records.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	records.scroll_active = false
	records.scroll_following = true
	records.mouse_filter = Control.MOUSE_FILTER_IGNORE
	records.focus_mode = Control.FOCUS_NONE
	records.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	records.add_theme_constant_override("shadow_offset_x", 1)
	records.add_theme_constant_override("shadow_offset_y", 1)
	records.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	records.add_theme_constant_override("outline_size", 4)
	add_child(records)
	input = LineEdit.new()
	input.name = "ChatInput"
	input.max_length = 200
	input.custom_minimum_size.y = 32
	input.expand_to_text_length = false
	input.text_changed.connect(func(value: String): network.chat_draft = value)
	input.text_submitted.connect(_submit)
	add_child(input)
	input.hide()
	network.chat_changed.connect(refresh)
	network.chat_accepted.connect(_accepted)
	network.chat_rejected.connect(func(): input.editable = true)
	network.chat_reset.connect(_reset)
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()

func layout() -> void:
	var viewport := get_viewport_rect().size
	var input_height := 36.0 if editing else 0.0
	var height := minf(200.0, maxf(0.0, viewport.y - 48.0 - input_height))
	size = Vector2(minf(420.0, maxf(0.0, viewport.x - 32.0)), height + input_height)
	position = Vector2(16, viewport.y - 24 - size.y)
	records.size = Vector2(size.x, height)
	input.position = Vector2(0, height + 4)
	input.size = Vector2(size.x, 32)

func refresh() -> void:
	records.clear()
	for i in network.chat_events.size():
		var event: Dictionary = network.chat_events[i]
		if i > 0: records.add_text("\n")
		records.push_color(Color.WHITE if event.kind == "message" else Color.YELLOW)
		records.add_text(Rules.line(event))
		records.pop()
	# Content layout happens after text changes; scroll even with hidden scrollbars.
	_scroll_latest.call_deferred()

func _scroll_latest() -> void:
	if is_instance_valid(records): records.scroll_to_line(maxi(0, records.get_line_count() - 1))

func begin() -> void:
	editing = true
	input.text = network.chat_draft
	input.editable = network.chat_pending == 0
	input.show()
	layout()
	input.grab_focus()
	input.caret_column = input.text.length()

func finish(resume := true) -> void:
	if not editing: return
	editing = false
	input.release_focus()
	input.hide()
	layout()
	editing_finished.emit(resume)

func observe_key(event: InputEventKey) -> void:
	# Leave candidate confirmation to native LineEdit, but do not submit if
	# the platform commits its composition during this same key event.
	ime_confirming = event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not DisplayServer.ime_get_text().is_empty()

func _submit(_value: String) -> void:
	if not editing or ime_confirming or not DisplayServer.ime_get_text().is_empty(): return
	if network.submit_chat(): input.editable = false

func _accepted() -> void:
	input.clear()
	input.editable = true
	finish()

func _reset() -> void:
	input.clear()
	finish(false)
