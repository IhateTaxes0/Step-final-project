extends CanvasLayer

signal choice_made(choice_string) 
signal input_submitted(typed_text)
@onready var name_label = %NameLabel 
@onready var prompt_label = %PromptText
@onready var yes_button = %YesButton
@onready var no_button = %NoButton
@onready var mystery_button = %MysteryButton 
@onready var option_panel = %OptionPanel
@onready var option_panel2 = %OptionPanel_texture # Kept your duplicate panel!
@onready var code_input = $CodeInput
 
var is_typing: bool = false
var is_message_only: bool = false 
var current_tween: Tween

func _ready():
	hide()
	code_input.hide()
	yes_button.pressed.connect(_on_yes_button_pressed)
	no_button.pressed.connect(_on_no_button_pressed)
	mystery_button.pressed.connect(_on_mystery_button_pressed) 
	code_input.text_submitted.connect(_on_text_submitted)
	yes_button.mouse_entered.connect(yes_button.grab_focus)
	no_button.mouse_entered.connect(no_button.grab_focus)
	mystery_button.mouse_entered.connect(mystery_button.grab_focus) 

func _unhandled_input(event):
	# Create a variable that checks if the player pressed Enter/Space OR Left Clicked
	var is_confirm_action = event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	
	if is_confirm_action:
		# 1. If it is currently typing, skip the animation
		if is_typing:
			if current_tween and current_tween.is_running():
				current_tween.kill()
			prompt_label.visible_ratio = 1.0 
			_finish_typing()
			
		# 2. Only close the message box if the text is 100% completely finished
		# This blocks the Ghost Click from instantly closing the menu.
		elif is_message_only and not is_typing and prompt_label.visible_ratio >= 1.0:
			hide()
			GameManager.is_interacting = false 
			is_message_only = false
			choice_made.emit("closed")
			
	
func open(prompt_text: String, show_mystery: bool = false):
	GameManager.is_interacting = true 
	option_panel.hide()
	if option_panel2:
		option_panel2.hide()
		
	# Crucial: Reset this to false when opening normal menus!
	is_message_only = false 
	
	if show_mystery:
		mystery_button.show()
		option_panel.size = Vector2(123, 162)
		if option_panel2:
			option_panel2.size = Vector2(123, 162)
	else:
		mystery_button.hide()
		option_panel.size = Vector2(123, 123)
		if option_panel2:
			option_panel2.size = Vector2(123, 123)
	
	prompt_label.text = prompt_text
	prompt_label.visible_ratio = 0.0 
	show()
	
	await get_tree().process_frame 
	is_typing = true
	
	current_tween = create_tween()
	current_tween.tween_property(prompt_label, "visible_ratio", 1.0, 0.5)
	
	await current_tween.finished
	
	if is_typing:
		_finish_typing()
		
func show_message(prompt_text: String, speaker_name: String = ""):
	GameManager.is_interacting = true 
	option_panel.hide()
	if option_panel2:
		option_panel2.hide()
		
	is_message_only = true 
	
	# --- THE NAME TAG LOGIC ---
	if name_label:
		if speaker_name != "":
			name_label.text = speaker_name
			name_label.show()
		else:
			name_label.hide()
	# --------------------------
	
	prompt_label.text = prompt_text
	prompt_label.visible_ratio = 0.0 
	show()
	
	await get_tree().process_frame 
	is_typing = true
	
	current_tween = create_tween()
	current_tween.tween_property(prompt_label, "visible_ratio", 1.0, 0.5)
	
	await current_tween.finished
	
	if is_typing:
		is_typing = false

func _finish_typing():
	is_typing = false
	
	# BUG FIX: Only show the buttons if this is an actual choice, NOT a message!
	if not is_message_only:
		option_panel.show() 
		if option_panel2:
			option_panel2.show()
		yes_button.call_deferred("grab_focus")

func _on_yes_button_pressed():
	hide()
	GameManager.is_interacting = false 
	choice_made.emit("yes") 

func _on_no_button_pressed():
	hide()
	GameManager.is_interacting = false 
	choice_made.emit("no") 

func _on_mystery_button_pressed():
	hide()
	GameManager.is_interacting = false 
	choice_made.emit("mystery")
# This opens the menu specifically for typing
func prompt_input(prompt_text: String):
	GameManager.is_interacting = true 
	option_panel.hide()
	if option_panel2:
		option_panel2.hide()
		
	prompt_label.text = prompt_text
	prompt_label.visible_ratio = 1.0 
	show()
	
	code_input.text = "" # Clear old text
	code_input.show()
	code_input.grab_focus() # Automatically puts the blinking cursor in the box!

# This fires when the player presses "Enter" on their keyboard
func _on_text_submitted(new_text: String):
	code_input.hide()
	hide()
	GameManager.is_interacting = false 
	input_submitted.emit(new_text) # Sends what they typed back to the interactable script!
