extends Node

# --- PLAYER IDENTITY ---
var player_name: String = "Me" # default is *me*
var max_hp: int = 500      
var current_hp: int = 500
var max_mana: int = 400    
var current_mana: int = 400
var nightmare_chance: int = 0
var total_nightmares: int = 0 
var monsters_slain: int = 0 
var active_passives: Array[String] = []
var has_seen_dreamland_intro: bool = false
var has_seen_dreamland_outro: bool = false

# --- CUTSCENE & COMBAT MEMORY ---
var dead_enemy_positions: Array[Vector2] = [] 
var engaged_enemy_position: Vector2 = Vector2.ZERO
var enemy_combat_queue: Array = []
var is_transitioning_to_combat: bool = false
var cutscene_dialogues: Array = [] 
var cutscene_target_scene: String = ""     
var current_enemy_path: String = ""
var entrance_door: String = ""
var inventory: Array[String] = ["god_fruit"]
var return_position: Vector2 = Vector2.ZERO          # where to place the player
var return_from_combat: bool = false                # flag to know to use return_position
var load_target_scene: String = "" 
var current_room_path: String = "res://world/main.tscn"
# when a menu is open, player can still change direction
var is_interacting: bool = false
var has_seen_intro: bool = false
# Tracks if the tutorial boss is dead
var is_slot_system_unlocked: bool = false
var is_skill_system_unlocked: bool = false
signal toggle_hud(show_hud: bool)
# Define the signals (like emitting events in Vue/Node)
signal stats_updated(anxiety, sanity)

func is_boss_day() -> bool:
	# Returns true ONLY on day 5, 10, 15, and 20.
	return day % 5 == 0

# Base stats start at 50, max 100
var anxiety: int = 50
var sanity: int = 50


# --- THE MARKER ---
var force_exact_position: bool = false
var exact_load_position: Vector2 = Vector2.ZERO
var exact_load_direction: String = "front"
var teleport_frames: int = 0
var old_scene_instance: Node = null # Remembers the old room!

func _process(_delta):
	if force_exact_position and get_tree().current_scene:
		# 1. Wait until the old room is completely destroyed!
		# This stops the player from visually teleporting before the screen fades out
		if get_tree().current_scene == old_scene_instance:
			return 
			
		# 2. Check if player finally in the newly loaded room
		if get_tree().current_scene.scene_file_path == load_target_scene:
			
			var found_player = null
			for p in get_tree().get_nodes_in_group("player"):
				if not "CombatOverlay" in str(p.get_path()):
					found_player = p
					break
					
			if found_player:
				# 3. Clamp the player to the exact saved spot AND direction
				found_player.global_position = exact_load_position
				if "last_direction" in found_player:
					found_player.last_direction = exact_load_direction
				
				# 4. Hold them frozen endlessly while the screen is fading in
				if SceneTransition.is_transitioning:
					return 
				
				# 5. Hold for 10 frames AFTER the screen reveals to overpower any spawn scripts, then release
				teleport_frames += 1
				if teleport_frames >= 10:
					force_exact_position = false
					teleport_frames = 0
					old_scene_instance = null # Clear the memory
					
# A helper function to modify stats safely so it donent break 100 or drop below 0
func modify_stats(anxiety_change: int, sanity_change: int):
	# Take a snapshot of the stats before making changes
	var old_anxiety = anxiety
	var old_sanity = sanity
	
	# THE GOD-MODE LOCK: If the player has Rosari, lock stats permanently
	if has_rosari:
		anxiety = 0
		sanity = 100
	else:
		# Normal stat changes if the sword is not unlocked
		anxiety = clamp(anxiety + anxiety_change, 0, 100)
		sanity = clamp(sanity + sanity_change, 0, 100)
	
	# --- only trigger the HUD update if the stats changed ---
	if old_anxiety != anxiety or old_sanity != sanity:
		stats_updated.emit(anxiety, sanity)

# --- DAY SYSTEM ---
# Time tracking (9:00 AM = 540 minutes)
var current_time_minutes: int = 540 
var day: int = 1
var daily_seed: int = randi() # Creates a random seed

# --- WEAPON SYSTEM ---
var has_rosari: bool = false # Tracks if the player unlocked the secret!

var weapons = {
	"Knife": {
		"damage": 130, 
		"skill": "Cut", 
		"effect": "has 30% chance to instant kill", 
		"icon_path": "res://resources/weapons/knife.png"
	},
	"Long Sword": {
		"damage": 50, 
		"skill": "Vertical Slash", # <-- Changed from Horizontal Slash!
		"effect": "None", 
		"icon_path": "res://resources/weapons/long_sword.png"
	},
	"Katana": {
		"damage": 100, 
		"skill": "Quick Draw", 
		"effect": "grant more chance at getting crits", 
		"icon_path": "res://resources/weapons/katana.png"
	},
	"Rosari": {
		"damage": 200, 
		"skill": "mother's rosari", 
		"effect": "change the slot to only purple and empty", 
		"icon_path": "res://resources/weapons/rosari.png"
	}
}

# Checks the sanity stat, BUT prioritizes the secret sword if unlocked!
func get_equipped_weapon() -> String:
	if has_rosari == true:
		return "Rosari"
		
	# Normal sanity logic below:
	if sanity >= 70:
		return "Katana"
	elif sanity <= 25:
		return "Knife"
	else:
		return "Long Sword"
		
func unlock_rosari():
	has_rosari = true
	is_slot_system_unlocked = true
	print("Obtained Rosari! Slot system unlocked!")
	
# The UI calls this to pull the damage for combat!
func get_player_damage() -> int:
	var current_weapon = get_equipped_weapon()
	if weapons.has(current_weapon):
		return weapons[current_weapon]["damage"]
	else:
		return 30 # Safe fallback just in case

#Memory List, will remembers what the player interacts today.
var used_objects_today: Array[String] = []

signal time_advanced(new_time, new_day)

var max_passives: int = 1 
var passive_stacks: Dictionary = {} # tracks level/stacks

func consume_fruit(fruit_name: String):
	var fn = fruit_name.to_lower().replace(" ", "_")
	
	if fn == "apple":
		modify_stats(-10, 10)
		return
		
	if fn == "god_fruit":
		if max_passives < 2: # 1 time only, unlocks the 2nd slot!
			max_passives += 1
			print("Max passives increased to ", max_passives)
		else:
			print("You have already reached the maximum of 2 passive slots.")
		return
		
	# Handle passive fruits
	var passives_list = ["quick_hand", "iron_body", "combat_master", "proficiency"]
	if fn in passives_list:
		if passive_stacks.has(fn):
			# Upgrade existing passive!
			passive_stacks[fn] += 1
			print("Upgraded passive: ", fn, " to level ", passive_stacks[fn])
		else:
			# It's a brand new passive. Check if we have room!
			var current_keys = passive_stacks.keys()
			if current_keys.size() >= max_passives:
				# Oh no! Slots are full. Forget a random one!
				var random_key = current_keys[randi() % current_keys.size()]
				passive_stacks.erase(random_key)
				print("Forgot passive: ", random_key)
			
			passive_stacks[fn] = 1
			print("Learned new passive: ", fn)
# Helper to format minutes into a readable clock (e.g., 9:30 AM)
func get_formatted_time() -> String:
	var hours = current_time_minutes / 60
	var mins = current_time_minutes % 60
	var am_pm = "AM" if hours < 12 else "PM"
	
	# Convert 13:00 to 1:00 PM
	if hours > 12:
		hours -= 12
	elif hours == 0:
		hours = 12
		
	return str(hours) + ":" + ("%02d" % mins) + " " + am_pm

func advance_time(minutes_to_add: int):
	current_time_minutes += minutes_to_add
	
	if current_time_minutes >= 1320:
		modify_stats(5, -5)
		start_new_day() # Call new helper function
		print("Passed out! It is now Day: ", day)
		
	time_advanced.emit(get_formatted_time(), day)

func start_new_day():
	current_time_minutes = 540
	day += 1
	used_objects_today.clear() 
	dead_enemy_positions.clear()
	current_hp = max_hp
	current_mana = max_mana
	enemy_combat_queue.clear()
	is_transitioning_to_combat = false
	
	# THE FIX: Prevents the Dreamland spawn from breaking!
	return_from_combat = false 
	
	randomize()
	daily_seed = randi()

# --- DYNAMIC DIFFICULTY SCALING ---
func get_enemy_stat_multiplier() -> float:
	var sanity_mod: float = 0.0
	var anxiety_mod: float = 0.0

	# 1. Sanity Check
	if sanity > 50:
		# +6% harder for every point above 50
		sanity_mod = (sanity - 50) * 0.06 
	elif sanity < 50:
		# -1% easier for every point below 50 
		sanity_mod = (sanity - 50) * 0.01 

	# 2. Anxiety Check (Inverted logic: Lower anxiety = harder)
	if anxiety < 50:
		# +6% harder for every point below 50
		anxiety_mod = (50 - anxiety) * 0.06 
	elif anxiety > 50:
		# -1% easier for every point above 50 
		anxiety_mod = (50 - anxiety) * 0.01 

	# 3. Combine modifiers
	var total_mod = sanity_mod + anxiety_mod

	# 4. Enforce the hard caps
	# Max decrease is -50% (-0.50). Max increase is +600% (+6.0).
	total_mod = clamp(total_mod, -0.50, 6.0)

	# Return the final multiplier (Base 100% + the calculated modifier)
	return 1.0 + total_mod
	
# --- MULTI-SLOT SAVE SYSTEM ---
var game_folder_name = "Step" # Name updated here!

# Slot 0 = Auto Save, Slots 1-4 = Manual Saves
func get_save_path(slot_id: int) -> String:
	var filename = "auto_save.json" if slot_id == 0 else "save_slot_" + str(slot_id) + ".json"
	var save_path = "user://" + filename 
	
	if OS.get_name() == "Windows":
		var local_app_data = OS.get_environment("LOCALAPPDATA")
		var game_dir = local_app_data + "/" + game_folder_name
		if not DirAccess.dir_exists_absolute(game_dir):
			DirAccess.make_dir_recursive_absolute(game_dir)
		save_path = game_dir + "/" + filename
		
	return save_path

# Reads just enough data to display the preview button
func get_save_info(slot_id: int) -> String:
	var path = get_save_path(slot_id)
	
	if not FileAccess.file_exists(path):
		# says "- Empty -" when no save file exists
		if slot_id == 0:
			return "Auto Save: - Empty -"
		else:
			return "Slot " + str(slot_id) + ": - Empty -"
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.data
		var s_day = str(data.get("day", "?"))
		var s_time = data.get("formatted_time", "??:??")
		var s_date = data.get("real_date", "Unknown Date")
		
		var prefix = "Auto Save" if slot_id == 0 else "Slot " + str(slot_id)
		return prefix + " | Day " + s_day + " | " + s_time + " | Saved: " + s_date
		
	return "Slot Corrupted"

func save_game(slot_id: int):
	var time_dict = Time.get_datetime_dict_from_system()
	var real_date_str = "%04d-%02d-%02d %02d:%02d" % [time_dict.year, time_dict.month, time_dict.day, time_dict.hour, time_dict.minute]
	
	var save_scene_path = current_room_path
	if get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
		save_scene_path = get_tree().current_scene.scene_file_path
		
	var px = 0.0
	var py = 0.0
	var p_dir = "front" # Default direction
	var found_player = null
	
	for p in get_tree().get_nodes_in_group("player"):
		if not "CombatOverlay" in str(p.get_path()):
			found_player = p
			break
			
	if found_player:
		px = found_player.global_position.x
		py = found_player.global_position.y
		# --- THE FIX: Save the exact facing direction ---
		if "last_direction" in found_player:
			p_dir = found_player.last_direction
		
	var serialized_dead_enemies = []
	for pos in dead_enemy_positions:
		serialized_dead_enemies.append({"x": pos.x, "y": pos.y})
	
	var save_data = {
		"day": day,
		"anxiety": anxiety,
		"sanity": sanity,
		"time": current_time_minutes,
		"formatted_time": get_formatted_time(), 
		"real_date": real_date_str,             
		"inventory": inventory,
		"has_rosari": has_rosari,
		"daily_seed": daily_seed,
		"has_seen_intro": has_seen_intro,
		"used_objects_today": used_objects_today,
		"is_slot_system_unlocked": is_slot_system_unlocked,
		"is_skill_system_unlocked": is_skill_system_unlocked,
		"passive_stacks": passive_stacks,
		"active_passives": active_passives,
		"max_passives": max_passives,
		"monsters_slain": monsters_slain,
		
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_mana": current_mana,
		"max_mana": max_mana,
		"nightmare_chance": nightmare_chance,
		"total_nightmares": total_nightmares,
		
		"dead_enemy_positions": serialized_dead_enemies,
		
		"saved_scene": save_scene_path,
		"player_x": px,
		"player_y": py,
		"player_dir": p_dir, # The new saved direction!
		"has_seen_dreamland_intro": has_seen_dreamland_intro,
		"has_seen_dreamland_outro": has_seen_dreamland_outro
	}
	
	var file = FileAccess.open(get_save_path(slot_id), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Saved to slot ", slot_id)

func load_game(slot_id: int) -> bool:
	var path = get_save_path(slot_id)
	if not FileAccess.file_exists(path):
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error == OK:
		var data = json.data
		day = data.get("day", 1)
		anxiety = data.get("anxiety", 50)
		sanity = data.get("sanity", 50)
		current_time_minutes = data.get("time", 540)
		inventory.assign(data.get("inventory", []))
		has_rosari = data.get("has_rosari", false)
		daily_seed = data.get("daily_seed", randi())
		has_seen_intro = data.get("has_seen_intro", false)
		used_objects_today.assign(data.get("used_objects_today", []))
		
		is_slot_system_unlocked = data.get("is_slot_system_unlocked", false)
		is_skill_system_unlocked = data.get("is_skill_system_unlocked", false)
		passive_stacks = data.get("passive_stacks", {})
		active_passives.assign(data.get("active_passives", []))
		max_passives = data.get("max_passives", 1)
		monsters_slain = data.get("monsters_slain", 0)
		
		current_hp = data.get("current_hp", max_hp)
		max_hp = data.get("max_hp", 500)
		current_mana = data.get("current_mana", max_mana)
		max_mana = data.get("max_mana", 400)
		nightmare_chance = data.get("nightmare_chance", 0)
		total_nightmares = data.get("total_nightmares", 0)
		has_seen_dreamland_intro = data.get("has_seen_dreamland_intro", false)
		has_seen_dreamland_outro = data.get("has_seen_dreamland_outro", false)
		dead_enemy_positions.clear()
		var saved_dead_enemies = data.get("dead_enemy_positions", [])
		for dict in saved_dead_enemies:
			dead_enemy_positions.append(Vector2(dict["x"], dict["y"]))
		
		if has_rosari:
			is_slot_system_unlocked = true
			
		load_target_scene = data.get("saved_scene", "res://world/main.tscn")
		current_room_path = load_target_scene 
		entrance_door = "" 
		
		var px = data.get("player_x", 0.0)
		var py = data.get("player_y", 0.0)
		
		# --- Read the saved direction ---
		var p_dir = data.get("player_dir", "front")
		
		exact_load_position = Vector2(px, py)
		exact_load_direction = p_dir 
		
		# Take a photograph of the room we are standing in right now
		old_scene_instance = get_tree().current_scene 
		
		force_exact_position = true 
		teleport_frames = 0         
		# -----------------------------------------
		
		is_interacting = false
		is_transitioning_to_combat = false
		enemy_combat_queue.clear()
		dead_enemy_positions.clear()
		
		stats_updated.emit(anxiety, sanity)
		print("Loaded slot ", slot_id)
		return true
	return false
	
# Call this right after a boss fight or ending a day!
func trigger_auto_save():
	save_game(0)
