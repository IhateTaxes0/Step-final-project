extends CanvasLayer

@onready var btn_resume = $PanelContainer/VBoxContainer/BtnResume
@onready var btn_save = $PanelContainer/VBoxContainer/BtnSave
@onready var btn_load = $PanelContainer/VBoxContainer/BtnLoad
@onready var btn_option = $PanelContainer/VBoxContainer/BtnOption
@onready var btn_main_menu = $PanelContainer/VBoxContainer/BtnMainMenu
@onready var btn_desktop = $PanelContainer/VBoxContainer/BtnDesktop

# 1. Add a reference to the Save/Load menu!
# Make sure the node name matches exactly what it's called in your Scene Tree
@onready var save_load_ui = $SaveLoadUI 

func _ready():
	hide()
	btn_resume.pressed.connect(resume_game)
	# 2. We actually connect the save button now!
	btn_save.pressed.connect(_on_save_pressed) 
	btn_load.pressed.connect(_on_load_pressed)
	btn_option.pressed.connect(open_options)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_desktop.pressed.connect(_on_desktop_pressed)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		var current_scene_name = get_tree().current_scene.name
		if current_scene_name == "intro":
			return
			
		if visible:
			resume_game()
		else:
			pause_game()

func pause_game():
	show()
	get_tree().paused = true 
	
	if get_tree().root.has_node("CombatOverlay"):
		btn_save.disabled = true
	else:
		btn_save.disabled = false

func resume_game():
	hide()
	get_tree().paused = false 

# 3. Replace the old load function with this:
func _on_save_pressed():
	hide()
	if save_load_ui:
		save_load_ui.open_menu(false)

func _on_load_pressed():
	hide()
	if save_load_ui:
		save_load_ui.open_menu(true)

func open_options():
	print("Option settings not decided yet")

func _on_main_menu_pressed():
	resume_game() 
	SceneTransition.change_scene("res://world/intro.tscn")

func _on_desktop_pressed():
	get_tree().quit()
