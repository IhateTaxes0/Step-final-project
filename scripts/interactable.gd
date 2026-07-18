extends Area2D

@onready var highlight = $Highlight 
@export_enum("PC", "Bed", "Bathroom", "Bookshelf", "Exit", "Sink", "Altar", "MazeEnemy", "DreamlandExit") var object_type: String
@export var custom_prompt: String = "" 
@export_file("*.tscn") var target_scene_path: String = ""
@export var door_name: String = ""

var is_player_near = false
var is_waiting = false

func _ready():
	highlight.hide()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _trigger_menu_prompt():
	is_waiting = true
	
	# 1. SEPARATE THE LOCKS FOR THE BOOKSHELF
	var bookshelf_read_locked = false
	var bookshelf_code_locked = false
	if object_type == "Bookshelf":
		bookshelf_read_locked = ("Bookshelf" in GameManager.used_objects_today)
		bookshelf_code_locked = ("Bookshelf_Code" in GameManager.used_objects_today)
	
	# 2. Check if the object is completely locked for the day
	var is_already_used = false
	if object_type == "Bookshelf":
		if bookshelf_read_locked and bookshelf_code_locked:
			is_already_used = true
	# --- add the bed to the exemtion list ---
	elif object_type != "Exit" and object_type != "Bathroom" and object_type != "DreamlandExit" and object_type != "Bed":
		if object_type in GameManager.used_objects_today:
			is_already_used = true
			
	var final_text = custom_prompt
	if final_text == "":
		final_text = 'use "' + object_type + '"?'
		
	# If completely locked, stop here.
	if is_already_used:
		ActionMenu.show_message("I already did that today.")
		await ActionMenu.choice_made 
		is_waiting = false
		return 
		
	# 3. Determine if system should show the Mystery button
	var show_mystery = false
	if object_type == "Sink" and GameManager.sanity < 30 and not is_already_used:
		show_mystery = true
		
	# Bookshelf shows the code button as long as they haven't failed it today!
	if object_type == "Bookshelf" and not bookshelf_code_locked and not GameManager.has_rosari:
		show_mystery = true
		
	ActionMenu.open(final_text, show_mystery)
	var choice = await ActionMenu.choice_made
	
	# 4. Handle choice safely
	if choice == "yes":
		if object_type == "Bookshelf":
			if bookshelf_read_locked:
				ActionMenu.show_message("I already read enough for today.")
				await ActionMenu.choice_made
			else:
				GameManager.used_objects_today.append("Bookshelf")
				await trigger_interaction() 
		else:
			# --- THE FIX: ADD THE BED TO THE MEMORY EXEMPTION ---
			if object_type != "Exit" and object_type != "Bathroom" and object_type != "Bed":
				GameManager.used_objects_today.append(object_type)
				
			await trigger_interaction()
			
	elif choice == "mystery":
		if object_type == "Bookshelf":
			GameManager.used_objects_today.append("Bookshelf_Code")
			await trigger_mystery_event() # <--- ADDED AWAIT
		elif object_type != "Exit" and object_type != "Bathroom":
			GameManager.used_objects_today.append(object_type)
			await trigger_mystery_event() # <--- ADDED AWAIT
			
	is_waiting = false
			
	
func _input(event):
	if is_player_near and event.is_action_pressed("ui_accept") and not is_waiting and not GameManager.is_interacting and not SceneTransition.is_transitioning:
		_trigger_menu_prompt()

func _on_area_entered(area):
	if area.name == "InteractionArea":
		highlight.show()
		is_player_near = true 
		
		# Auto-trigger for Exit doors (shows menu)
		if (object_type == "Exit" or object_type == "DreamlandExit") and not is_waiting and not GameManager.is_interacting and not SceneTransition.is_transitioning:
			_trigger_menu_prompt()
			
		# INSTANT trigger for Enemies (no menu, just fight)
		elif object_type == "MazeEnemy" and not SceneTransition.is_transitioning:
			trigger_interaction()

func _on_area_exited(area):
	if area.name == "InteractionArea":
		if is_instance_valid(highlight): 
			highlight.hide()
		is_player_near = false
		
var books = randi() % 3
var pc = randi() % 3
func trigger_interaction():
	match object_type:
		"Bookshelf":
			if books == 1:
				ActionMenu.show_message("You read lightnovel")
				GameManager.advance_time(180)
			if books == 2:
				ActionMenu.show_message("You read psycological book")
				GameManager.advance_time(180)
			if books == 3:
				ActionMenu.show_message("you tried to read but keep thinking about other things")
				GameManager.advance_time(220)
				
			await ActionMenu.choice_made
			GameManager.modify_stats(-5, 5) 
			
		"Sink":
			ActionMenu.show_message("You splash cold water on your face. It helps clear your mind.")
			await ActionMenu.choice_made
			GameManager.modify_stats(-5, 5) 
			GameManager.advance_time(15)
			
		"Bathroom":
			# Bathroom still uses the Inspector variables
			GameManager.entrance_door = door_name 
			if target_scene_path != "":
				GameManager.current_room_path = target_scene_path
				SceneTransition.change_scene(target_scene_path)
			else:
				GameManager.current_room_path = "res://world/bathroom_place.tscn"
				SceneTransition.change_scene("res://world/bathroom_place.tscn")
			
		# --- THE FIX: BULLETPROOF HARDCODED BED LOGIC ---
		"Bed":
			ActionMenu.show_message("You close your eyes and let the exhaustion take over...")
			await ActionMenu.choice_made
			
			# Hardcode the entrance door so when player wake up, it looks for "bedspawn"
			GameManager.entrance_door = "bed" 
			
			var target_dream = ""
			
			# Route based on the day
			if GameManager.day == 1:
				target_dream = "res://world/dreamland1.tscn"
			elif GameManager.day < 5:
				target_dream = "res://world/level 1/dungeon_level1.tscn"
			else:
				pass # Day 5+ logic
				
			if target_dream != "":
				GameManager.current_room_path = target_dream # saving
				SceneTransition.change_scene(target_dream)
			
		"PC":
			if pc == 1:
				ActionMenu.show_message("You browse the internet for a while. It's distracting, but draining.")
				await ActionMenu.choice_made
				GameManager.modify_stats(0, 5)
				GameManager.advance_time(360)
			elif pc == 2:
				ActionMenu.show_message("you played online games, although it give you more stress but thats the only place where you can vent your boredom")
				await ActionMenu.choice_made
				GameManager.modify_stats(10, 10)
				GameManager.advance_time(560)
			else:
				ActionMenu.show_message("you spent time watching online video and social media")
				await ActionMenu.choice_made
				GameManager.modify_stats(5, 10)
				GameManager.advance_time(460)
		"Exit":
			# Check the room player currently standing in
			var current_room = get_tree().current_scene.scene_file_path.to_lower()
			
			if "balcony" in current_room:
				# Advance the time by 5 hours (300 minutes)
				GameManager.advance_time(300)
				GameManager.entrance_door = "exit" 
				
			else:
				# No time advanced when leaving
				GameManager.entrance_door = "exit" 
			
			# Change the scene
			if target_scene_path != "":
				GameManager.current_room_path = target_scene_path 
				SceneTransition.change_scene(target_scene_path)
				
		"Altar":
			GameManager.cutscene_dialogues = [
				{"text": "Welcome back, my king...", "speaker": "Domlr"},
				{"text": "*you are awed at the figure in front of you*", "speaker": GameManager.player_name},
				{"text": "Be not afraid, I am your utmost loyal servant.", "speaker": "Domlr"},
				{"text": "But before that, shall we get you used to your strength?", "speaker": "Domlr"}
			]
			
			var player = get_tree().get_first_node_in_group("player")
			if player:
				GameManager.return_position = player.global_position
				GameManager.return_from_combat = true

			GameManager.cutscene_target_scene = "res://world/CombatArena.tscn" 
			GameManager.current_enemy_path = "res://world/enemies/agis.tscn" 
			
			GameManager.current_room_path = "res://world/blank_dialouge.tscn"
			SceneTransition.change_scene("res://world/blank_dialouge.tscn")
			
		"MazeEnemy":
			var enemy_parent = get_parent()
			var spawn_pos = enemy_parent.get_meta("spawn_pos") if enemy_parent.has_meta("spawn_pos") else enemy_parent.global_position
			var color = enemy_parent.get_meta("mob_color") if enemy_parent.has_meta("mob_color") else Color.WHITE
			
			var enemy_data = {
				"path": "res://world/enemies/dreamland_mob_combat.tscn",
				"pos": spawn_pos,
				"color": color,
				"node": enemy_parent 
			}
			
			GameManager.enemy_combat_queue.append(enemy_data)
			
			if not GameManager.is_transitioning_to_combat:
				GameManager.is_transitioning_to_combat = true
				GameManager.current_enemy_path = enemy_data["path"]
				
				get_tree().current_scene.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
				
				var fade_layer = CanvasLayer.new()
				fade_layer.layer = 120
				fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS 
				var black_screen = ColorRect.new()
				black_screen.color = Color.BLACK
				black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
				fade_layer.add_child(black_screen)
				get_tree().root.add_child(fade_layer)
				
				var existing_overlay = get_tree().root.get_node_or_null("CombatOverlay")
				
				if not existing_overlay:
					var combat_layer = CanvasLayer.new()
					combat_layer.layer = 100
					combat_layer.name = "CombatOverlay"
					var arena = load("res://world/CombatArena.tscn").instantiate()
					combat_layer.add_child(arena)
					get_tree().root.add_child(combat_layer)
				else:
					var arena = load("res://world/CombatArena.tscn").instantiate()
					existing_overlay.add_child(arena)
				
				var tween = fade_layer.create_tween()
				tween.tween_property(black_screen, "modulate:a", 0.0, 1.0)
				await tween.finished
				fade_layer.queue_free()
			
		"DreamlandExit":
			var required_kills = 0
			var current_day = GameManager.day
			
			if current_day <= 3: required_kills = 3
			elif current_day <= 6: required_kills = 5
			elif current_day <= 11: required_kills = 9
			elif current_day <= 16: required_kills = 14
			else: required_kills = 20
			
			if GameManager.monsters_slain >= required_kills:
				ActionMenu.show_message("The neural pathways open. You have escaped.")
				await ActionMenu.choice_made
				
				GameManager.monsters_slain = 0 
				GameManager.start_new_day() 
				
				# --- THE FIX: Hardcode the wake-up marker and target scene! ---
				GameManager.entrance_door = "bed" # Forces the player to the bedspawn marker!
				GameManager.current_room_path = "res://world/main.tscn"
				
				SceneTransition.change_scene("res://world/main.tscn")
			else:
				var remaining = required_kills - GameManager.monsters_slain
				ActionMenu.show_message("The door is locked. The maze demands " + str(remaining) + " more sacrifices.")
				await ActionMenu.choice_made
				
func trigger_mystery_event():
	await get_tree().create_timer(0.1).timeout
	if object_type == "Sink":
		ActionMenu.show_message("The water turns dark. A reflection that isn't yours stares back...")
		await ActionMenu.choice_made
		
		print("SANITY EVENT TRIGGERED: Ready for the video/gif cutscene!")
		GameManager.modify_stats(10, 10)
		
	if object_type == "Bookshelf":
		
		# 1. Ask for the secret code using our new function
		ActionMenu.prompt_input("Enter the secret code:")
		
		# 2. Pause and wait for the player to type and press Enter
		var entered_code = await ActionMenu.input_submitted
		
		# 3. Check if the code is correct! 
		if entered_code == "1234":
			ActionMenu.show_message("i am myself, i don't need to be scared")
			await ActionMenu.choice_made
			
			ActionMenu.show_message("from now on, i will be the one that control my future!")
			await ActionMenu.choice_made
			
			ActionMenu.show_message("mother song: Rosari")
			await ActionMenu.choice_made
			
			# Overrides the sanity weapons permanently!
			GameManager.unlock_rosari()
			GameManager.modify_stats(-100, 100)
		else:
			ActionMenu.show_message("Nothing happened...")
			await ActionMenu.choice_made
