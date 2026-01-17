extends Control

signal challenge_completed(success: bool)
signal word_submitted(word: String)

var panel: Panel
var prompt_label: Label
var choice_container: GridContainer # For buttons
var input_container: HBoxContainer
var word_input: LineEdit
var submit_button: Button

var correct_word: String = ""

func _ready() -> void:
	# Build UI programmatically to ensure safety
	_setup_ui()
	hide() # Start hidden

func _setup_ui() -> void:
	# Background Dimmer? (Optional, but using Panel as logic container)
	panel = Panel.new()
	panel.layout_mode = 1
	panel.anchors_preset = 8 # Center
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 300)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.layout_mode = 1
	vbox.anchors_preset = 15
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add margins
	var margin_container = MarginContainer.new()
	margin_container.layout_mode = 1
	margin_container.anchors_preset = 15
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	
	panel.add_child(margin_container)
	margin_container.add_child(vbox)
	
	# Prompt
	prompt_label = Label.new()
	prompt_label.text = "Simon Says..."
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(prompt_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Choice Grid (Challenge Mode)
	choice_container = GridContainer.new()
	choice_container.columns = 2
	choice_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(choice_container)
	
	# Input Container (Input Mode)
	input_container = HBoxContainer.new()
	input_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input_container.visible = false
	vbox.add_child(input_container)
	
	word_input = LineEdit.new()
	word_input.placeholder_text = "Type a word..."
	word_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_container.add_child(word_input)
	
	submit_button = Button.new()
	submit_button.text = "OK"
	submit_button.pressed.connect(_on_submit_input)
	input_container.add_child(submit_button)
	
func start_challenge(target_word: String, options: Array[String]) -> void:
	show()
	correct_word = target_word
	
	prompt_label.text = "What was the last word?"
	choice_container.visible = true
	input_container.visible = false
	
	# Clear old buttons
	for child in choice_container.get_children():
		child.queue_free()
		
	# Add buttons
	for opt in options:
		var btn = Button.new()
		btn.text = opt
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _on_choice_selected(opt))
		choice_container.add_child(btn)

func start_input_mode() -> void:
	show()
	prompt_label.text = "Simon Says: Add a new word!"
	choice_container.visible = false
	input_container.visible = true
	word_input.text = ""
	word_input.grab_focus()

func _on_choice_selected(selected_word: String) -> void:
	if selected_word == correct_word:
		challenge_completed.emit(true)
	else:
		challenge_completed.emit(false)
		hide()

func _on_submit_input() -> void:
	var text = word_input.text.strip_edges()
	if text.length() > 0:
		word_submitted.emit(text)
		hide()
