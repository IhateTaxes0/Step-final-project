extends CanvasLayer

# 0 = Saving Mode, 1 = Loading Mode
var current_mode: int = 0 

@onready var title_label = $BackgroundPanel/MarginContainer/VBoxContainer/HBoxContainer/TitleLabel
@onready var btn_close = $BackgroundPanel/MarginContainer/VBoxContainer/BtnClose
@onready var pause_menu = $"/root/PauseMenu" 
@onready var slot_buttons = [
	$BackgroundPanel/MarginContainer/VBoxContainer/BtnSlot0,
	$BackgroundPanel/MarginContainer/VBoxContainer/BtnSlot1,
	$BackgroundPanel/MarginContainer/VBoxContainer/BtnSlot2,
	$BackgroundPanel/MarginContainer/VBoxContainer/BtnSlot3,
	$BackgroundPanel/MarginContainer/VBoxContainer/BtnSlot4
]

func _ready():
	hide()
	btn_close.pressed.connect(_on_close_pressed)
	
	# Dynamically connect all 5 buttons
	for i in range(slot_buttons.size()):
		slot_buttons[i].pressed.connect(func(): _on_slot_pressed(i))

# Your pause menu or main menu calls this function!
func open_menu(is_loading: bool):
	current_mode = 1 if is_loading else 0
	title_label.text = "Load Game" if is_loading else "Save Game"
	
	refresh_button_text()
	show()
	
	# Auto-focus the Auto Save slot for keyboard/controller navigation
	slot_buttons[0].grab_focus()

func refresh_button_text():
	for i in range(slot_buttons.size()):
		slot_buttons[i].text = GameManager.get_save_info(i)
		
		# If saving, prevent the player from overwriting the Auto Save slot!
		if current_mode == 0 and i == 0:
			slot_buttons[i].disabled = true
			slot_buttons[i].text = "Auto Save (System Only) | " + GameManager.get_save_info(0)
		else:
			slot_buttons[i].disabled = false
			
		# If loading, disable empty slots
		if current_mode == 1 and "Empty" in slot_buttons[i].text:
			slot_buttons[i].disabled = true

func _on_slot_pressed(slot_id: int):
	if current_mode == 0: # SAVING
		GameManager.save_game(slot_id)
		refresh_button_text() 
		
	elif current_mode == 1: # LOADING
		if GameManager.load_game(slot_id):
			hide()
			
			get_tree().paused = false
			
			if ActionMenu.visible:
				ActionMenu.hide()
				
			var overlay = get_tree().root.get_node_or_null("CombatOverlay")
			if overlay:
				get_tree().current_scene.process_mode = Node.PROCESS_MODE_INHERIT
				overlay.queue_free()
			
			# --- THIS BLOCK IS CRITICAL ---
			if GameManager.load_target_scene != "":
				SceneTransition.change_scene(GameManager.load_target_scene)
			else:
				SceneTransition.change_scene("res://world/main.tscn")

func _on_close_pressed():
	hide()
	pause_menu.get_tree().paused = false
