extends Control

@onready var margin_container = $MarginContainer
@onready var btn_start = $MarginContainer/VBoxContainer/BtnStart
@onready var btn_load = $MarginContainer/VBoxContainer/BtnLoad
@onready var btn_option = $MarginContainer/VBoxContainer/BtnOption
@onready var btn_exit = $MarginContainer/VBoxContainer/BtnExit
@onready var save_load_ui = $SaveLoadUI 

func _ready():
	btn_start.pressed.connect(_on_start_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_option.pressed.connect(_on_option_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)

# THE FIX: Stop the Escape key from leaking into the Pause Menu!
func _input(event):
	if event.is_action_pressed("ui_cancel"): # The Escape Key
		if save_load_ui and save_load_ui.visible:
			save_load_ui.hide()
			
			# get_viewport().set_input_as_handled() destroys the input 
			# so the PauseMenu Autoload never hears it!
			get_viewport().set_input_as_handled()

func _on_start_pressed():
	# THE FIX: Completely obliterate old save data in memory!
	GameManager.reset_new_game()
	
	SceneTransition.change_scene("res://world/main.tscn")

func _on_load_pressed():
	save_load_ui.open_menu(true)

func _on_option_pressed():
	PauseMenu.open_options()

func _on_exit_pressed():
	get_tree().quit()
