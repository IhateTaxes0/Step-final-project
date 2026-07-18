extends Node2D

@onready var player = %player 
@onready var bathroom_spawn = $BathroomSpawn
@onready var bed_spawn = $BedSpawn 
@onready var intro_ui = $IntroUI # Grabs the CanvasLayer you just made!
@onready var exit_spawn = $ExitSpawn

func _ready():
	# 1. THE INTRO SEQUENCE
	if GameManager.has_seen_intro == false:
		play_intro_sequence()
	else:
		# If the player already saw the intro, hide the UI immediately
		if intro_ui:
			intro_ui.hide()
			
		# --- THE NEW FIX: DAY 3 WAKE-UP DIALOGUE ---
		# We put this inside the 'else' block so it never accidentally overlaps the first intro!
		if GameManager.day == 3 and not GameManager.has_seen_dreamland_outro:
			play_day_3_outro()
		
	# 2. NORMAL SPAWN LOGIC 
	if GameManager.entrance_door == "bathroom":
		player.global_position = bathroom_spawn.global_position
	elif GameManager.entrance_door == "exit":
		player.global_position = exit_spawn.global_position
	else:
		player.global_position = bed_spawn.global_position
		
	# Clear the memory so it doesn't get stuck!
	GameManager.entrance_door = ""

# --- THE NEW DIALOGUE SEQUENCE ---
func play_day_3_outro():
	# 1. Lock the tracker immediately so it doesn't repeat
	GameManager.has_seen_dreamland_outro = true
	
	# 2. Freeze the player
	GameManager.is_interacting = true
	
	# 3. Wait 1 second for the SceneTransition fade to finish revealing the bedroom
	await get_tree().create_timer(1.0).timeout
	
	# 4. Play the custom text
	ActionMenu.show_message("whats happening to my body...", GameManager.player_name)
	await ActionMenu.choice_made
	
	ActionMenu.show_message("wheres this memory comes from?, i don't remember going to those places..", GameManager.player_name)
	await ActionMenu.choice_made
	
	ActionMenu.show_message("but..", GameManager.player_name)
	await ActionMenu.choice_made
	
	ActionMenu.show_message("i've had a feeling those memories were once belong to me..", GameManager.player_name)
	await ActionMenu.choice_made
	
	# 5. Unfreeze the player and permanently save this event
	GameManager.is_interacting = false
	GameManager.trigger_auto_save()

func play_intro_sequence():
	# Freeze the player and hide the HUD
	GameManager.is_interacting = true 
	GameManager.toggle_hud.emit(false)
	
	# Make sure your custom editor UI is visible and fully opaque
	if intro_ui:
		intro_ui.show()
		# We set the canvas layer's visibility directly
		intro_ui.visible = true 
	
	await get_tree().create_timer(1.0).timeout
	
	# Play the intro
	ActionMenu.show_message("xx/xx/2009")
	await ActionMenu.choice_made
	
	ActionMenu.show_message("why it couldn't be me...", GameManager.player_name)
	await ActionMenu.choice_made
	
	ActionMenu.show_message(".....", GameManager.player_name)
	await ActionMenu.choice_made
	
	ActionMenu.show_message("it's all my fault", GameManager.player_name)
	await ActionMenu.choice_made
	
	ActionMenu.show_message("....", GameManager.player_name)
	await ActionMenu.choice_made
	
	ActionMenu.show_message("i hate myself...", GameManager.player_name)
	await ActionMenu.choice_made
	
	if intro_ui:
		var tween = create_tween()
		tween.set_parallel(true) # Run fades at the same time
		for child in intro_ui.get_children():
			if child is CanvasItem:
				tween.tween_property(child, "modulate:a", 0.0, 2.0) 
		
		await tween.finished
		intro_ui.hide()
	
	# Unfreeze the player, remember the intro was seen, show HUD
	GameManager.has_seen_intro = true
	GameManager.is_interacting = false
	GameManager.toggle_hud.emit(true)
