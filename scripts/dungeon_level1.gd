extends ProceduralDungeon

@onready var path_layer = $TileMapLayer

@export var base_room: PackedScene
@export var room_1: PackedScene
@export var room_2: PackedScene
@export var room_3: PackedScene
@export var room_4: PackedScene
@export var room_5: PackedScene
@export var exit_room: PackedScene

# MOVED FROM THE MATH AI!
@export var enemy_scene: PackedScene 

func _ready():
	# LOCK THE SEED
	seed(GameManager.daily_seed)
	
	grass_source_id = 0
	wall_source_id = 2
	chunk_spacing = 45
	do_not_barricade = ["base", "exit", "r2", "r4"]
	
	var my_blueprints: Dictionary = {
		"base": {"scene": base_room, "doors": [make_door(12, 21, -1, -1, 0, -1)]}, 
		"exit": {"scene": exit_room, "doors": [make_door(5, 15, 17, 17, 0, 1)]},
		"r1": {"scene": room_1, "doors": [make_door(9, 18, -3, -3, 0, -1), make_door(10, 21, 18, 18, 0, 1)]},
		"r2": {"scene": room_2, "doors": [make_door(28, 28, 0, 7, 1, 0)]},
		"r3": {"scene": room_3, "doors": [
			make_door(16, 28, 2, 2, 0, -1),
			make_door(16, 26, 31, 31, 0, 1),
			make_door(-1, -1, 11, 20, -1, 0),
			make_door(42, 42, 11, 18, 1, 0)
		]},
		"r4": {"scene": room_4, "doors": [make_door(11, 12, 24, 24, 0, 1)]},
		"r5": {"scene": room_5, "doors": [make_door(-2, -2, 2, 9, -1, 0), make_door(23, 23, 2, 9, 1, 0)]}
	}
	
	var my_pool: Array[String] = ["r1", "r1", "r2", "r2", "r3", "r3", "r4", "r4", "r5", "r5", "r3"]
	
	# Because the seed is locked, this will now shuffle the EXACT same way every time!
	my_pool.shuffle() 
	my_pool.append("exit") 
	
	generate_level(path_layer, my_blueprints, my_pool)
	
	# The enemies will now roll the exact same random colors every time!
	spawn_enemies()
	setup_player(placed_rooms[0]["instance"])
	
	# UNLOCK THE SEED NOW THAT EVERYTHING IS BUILT
	randomize()
	if not GameManager.has_seen_dreamland_intro:
		play_dreamland_intro()
		
# --- intro dialouge upon visiting the place ---
func play_dreamland_intro():
	GameManager.has_seen_dreamland_intro = true
	
	# Wait 1 second for the SceneTransition black screen to fade out
	await get_tree().create_timer(1.0).timeout
	
	# Freeze the player so they can't walk around during dialogue
	GameManager.is_interacting = true
	
	ActionMenu.show_message("... (Custom intro dialogue 1) ...")
	await ActionMenu.choice_made
	
	ActionMenu.show_message("... (Custom intro dialogue 2) ...")
	await ActionMenu.choice_made
	
	# Unfreeze the player and save the game!
	GameManager.is_interacting = false
	GameManager.trigger_auto_save()
# --- ENTITY SPAWNING ---
func spawn_enemies():
	if not enemy_scene: return
	var skip = ["base", "exit"]
	for r in placed_rooms:
		if r["id"] in skip: continue
		var room_instance = r["instance"]
		var safe_floor_cells = []
		var tms = []
		get_all_tilemap_layers(room_instance, tms)
		for cell in r["footprint"]["used_cells"]:
			var is_solid = false
			var has_tile = false
			for tm in tms:
				var data = tm.get_cell_tile_data(cell)
				if data:
					has_tile = true
					var ts = tm.tile_set
					if ts and ts.get_physics_layers_count() > 0:
						if data.get_collision_polygons_count(0) > 0:
							is_solid = true
							break
			if has_tile and not is_solid:
				safe_floor_cells.append(cell)
		if safe_floor_cells.is_empty(): continue
		var enemies_to_spawn = randi_range(2, 4)
		var placed_cells = []
		for e in range(enemies_to_spawn):
			var valid_cell = false
			var chosen_cell = Vector2i.ZERO
			var attempts = 0
			while not valid_cell and attempts < 20:
				chosen_cell = safe_floor_cells.pick_random()
				valid_cell = true
				for pc in placed_cells:
					if Vector2(chosen_cell).distance_to(Vector2(pc)) < 3.0: 
						valid_cell = false
						break
				attempts += 1
			if valid_cell:
				placed_cells.append(chosen_cell)
				var global_cell_pos = r["tile_pos"] + chosen_cell
				var final_spawn_pos = (Vector2(global_cell_pos) * tile_size) + Vector2(tile_size / 2.0, tile_size / 2.0)
				var is_dead = false
				for dead_pos in GameManager.dead_enemy_positions:
					if final_spawn_pos.distance_to(dead_pos) < 10.0: 
						is_dead = true
						break
				if not is_dead:
					var enemy = enemy_scene.instantiate()
					add_child(enemy)
					enemy.global_position = final_spawn_pos
					enemy.set_meta("spawn_pos", final_spawn_pos)
				
func setup_player(base_room_instance: Node2D):
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	if GameManager.return_from_combat:
		player.global_position = GameManager.return_position
		GameManager.return_from_combat = false 
	else:
		var spawn_point = base_room_instance.get_node_or_null("PlayerSpawn")
		if spawn_point:
			player.global_position = spawn_point.global_position
		else:
			player.global_position = base_room_instance.global_position + (Vector2(16, 12) * tile_size)
