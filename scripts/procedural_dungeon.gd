# --- TODO list ---
# currently this works perfectly as AStarGrid2D marks every spawned room for make_door() to run on
# need to automatically scan for open door grid, instead of manually inputing the door grid
# path finding sometimes led player too far away to connect rooms
# optimization needed
# credit to: https://youtu.be/yl4YrFRXNpk?si=8PbUdrrOp_PLBPbV
#			 https://youtu.be/8xfuX-fFYhw?si=ee-wv_VP67jvuNCe
#			 https://youtu.be/5vwB5l2nyRg?si=NCBpm1Kg70N82WLw
#for inspiring the math, etc...


extends Node2D
class_name ProceduralDungeon

var tile_size = 64 # pixels x scale
var path_thickness = 2 

# --- CONFIGURABLE DEFAULTS ---
var grass_source_id = 0
var wall_source_id = 2
var chunk_spacing = 45
var do_not_barricade: Array[String] = ["base", "exit"]

# --- INTERNAL BRAIN STATE ---
var grass_variations: Array[Vector2i] = []
var wall_variations: Array[Vector2i] = []

# grid_map is "Sudoku board". It remembers which chunks (e.g., [0,0], [1,0]) have rooms in them.
var grid_map = {}
var placed_rooms = []

var active_path_layer: TileMapLayer
var level_blueprints: Dictionary = {}
var level_pool: Array[String] = []

# ==========================================
# 1. THE DOOR MATH
# ==========================================
# This function calculates the mathematical center of a doorway so the pathfinder 
# knows exactly where to start drawing the grass path.
func make_door(x1: int, x2: int, y1: int, y2: int, dx: int, dy: int) -> Dictionary:
	var tiles = []
	var sum_x = 0.0
	var sum_y = 0.0
	
	#loop through the square of coordinates provided (x1 to x2, y1 to y2)
	for x in range(x1, x2 + 1):
		for y in range(y1, y2 + 1):
			tiles.append(Vector2i(x, y))
			sum_x += x
			sum_y += y
			
	# THE MATH: To find the exact middle of the door, calculate the "average" coordinate.
	# take the sum of all X's and divide by the total number of tiles. Same for Y.
	# round() ensures get a clean whole number for the grid.
	var center = Vector2i(round(sum_x / tiles.size()), round(sum_y / tiles.size()))
	
	# return a package containing the center point, the direction the door faces, and its tiles.
	return {"pos": center, "dir": Vector2i(dx, dy), "tiles": tiles}


# ==========================================
# 2. THE MAIN GENERATOR
# ==========================================
func generate_level(layer: TileMapLayer, blueprints: Dictionary, pool: Array[String]):
	active_path_layer = layer
	level_blueprints = blueprints
	level_pool = pool
	
	# clear previous generation memory in case of reload
	placed_rooms.clear()
	grid_map.clear()
	
	
	build_tileset_arrays()
	execute_smart_dungeon()
	randomize()

# Scans TileSet image to find valid textures so it doesn't draw invisible holes.
func build_tileset_arrays():
	var ts = active_path_layer.tile_set
	if not ts: return
		
	var grass_src = ts.get_source(grass_source_id) as TileSetAtlasSource
	var wall_src = ts.get_source(wall_source_id) as TileSetAtlasSource
	
	if grass_src:
		for x in range(0, 16):
			for y in range(0, 16):
				var coord = Vector2i(x, y)
				# IF the tile physically exists in the image, add it to list of safe variations.
				if grass_src.has_tile(coord) and not grass_variations.has(coord):
					grass_variations.append(coord)
					
	if wall_src:
		for x in range(2, 6):
			for y in range(18, 22):
				var coord = Vector2i(x, y)
				if wall_src.has_tile(coord) and not wall_variations.has(coord):
					wall_variations.append(coord)
					
	if grass_variations.is_empty(): grass_variations = [Vector2i(0, 0)]
	if wall_variations.is_empty(): wall_variations = [Vector2i(2, 18)]


# ==========================================
# 3. CHUNK PLACEMENT & PATHFINDING
# ==========================================
func execute_smart_dungeon():
	active_path_layer.clear()
	
	# active_chunks remembers which spots on "Sudoku board" can branch out from.
	# start at the center: [0, 0].
	var active_chunks = [Vector2i(0, 0)]
	
	# Place the base room at [0,0]
	var base_inst = place_room(level_blueprints["base"]["scene"], Vector2i(0, 0))
	var base_footprint = scan_room_footprint(base_inst)
	placed_rooms.append({"id": "base", "instance": base_inst, "tile_pos": Vector2i(0, 0), "doors": level_blueprints["base"]["doors"], "footprint": base_footprint})
	grid_map[Vector2i(0, 0)] = placed_rooms[0]
	
	var used_doors = []
	var final_connections = []
	
	# Loop through every room want to spawn
	for room_id in level_pool:
		active_chunks.shuffle()
		var placed = false
		
		# Look at all existing rooms on the board
		for chunk in active_chunks:
			# Check the 4 tiles immediately surrounding this chunk (Up, Down, Left, Right)
			var neighbors = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
			neighbors.shuffle()
			
			for n in neighbors:
				# target_chunk is the potential new spot (e.g., [0,0] + [1,0] = [1,0])
				var target_chunk = chunk + n
				
				# IF this spot on the board is empty:
				if not grid_map.has(target_chunk):
					# THE MATH: Multiply the grid coordinate by chunk_spacing to get physical map coordinates.
					# Example: Chunk [1, 0] * 45 spacing = Map Tile X: 45, Y: 0.
					var tile_pos = target_chunk * chunk_spacing
					
					# Multiply by 64 (tile_size) to get the exact pixel location to spawn the room.
					var new_inst = place_room(level_blueprints[room_id]["scene"], tile_pos * tile_size)
					
					var new_footprint = scan_room_footprint(new_inst)
					var new_room = {"id": room_id, "instance": new_inst, "tile_pos": tile_pos, "doors": level_blueprints[room_id]["doors"], "footprint": new_footprint}
					
					placed_rooms.append(new_room)
					grid_map[target_chunk] = new_room
					active_chunks.append(target_chunk)
					
					# Find the math center of the two rooms so know which doors face each other
					var r_a = grid_map[chunk]
					var r_b = new_room
					var center_a = r_a["tile_pos"] + (r_a["footprint"]["bounds"].size / 2)
					var center_b = r_b["tile_pos"] + (r_b["footprint"]["bounds"].size / 2)
					
					var door_a = get_best_door(r_a, center_b)
					var door_b = get_best_door(r_b, center_a)
					
					if door_a != null and door_b != null:
						used_doors.append({"r_pos": r_a["tile_pos"], "d_pos": door_a["pos"]})
						used_doors.append({"r_pos": r_b["tile_pos"], "d_pos": door_b["pos"]})
						final_connections.append({"r_a": r_a, "d_a": door_a, "r_b": r_b, "d_b": door_b})
					
					placed = true
					break # Stop checking neighbors, move to the next room in the pool
			if placed: break

	# --- A* PATHFINDING ALGORITHM ---
	# AStarGrid2D calculates the shortest route between two points around obstacles.
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(-2000, -2000, 4000, 4000)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	var room_padding = 4 
	
	for r in placed_rooms:
		var tile_pos = r["tile_pos"]
		
		# 1. Mark every single floor tile inside the room as SOLID so paths don't cut through rooms.
		for cell in r["footprint"]["used_cells"]:
			for px in range(-room_padding, room_padding + 1):
				for py in range(-room_padding, room_padding + 1):
					var p_cell = tile_pos + cell + Vector2i(px, py)
					if astar.is_in_boundsv(p_cell):
						astar.set_point_solid(p_cell, true)
					
		# 2. Carve holes in the solid walls at the doorways so paths can enter.
		for d in r["doors"]:
			var is_used = false
			for ud in used_doors:
				if ud["r_pos"] == tile_pos and ud["d_pos"] == d["pos"]:
					is_used = true
					break
					
			if is_used or r["id"] in do_not_barricade:
				for door_tile in d["tiles"]:
					var global_door_tile = tile_pos + door_tile
					
					# Shoots a straight line out of the door to clear a safe tunnel
					for step in range(-2, room_padding + 3): 
						var carve_pos = global_door_tile + (d["dir"] * step)
						
						if astar.is_in_boundsv(carve_pos):
							astar.set_point_solid(carve_pos, false) 
						
						if not is_tile_used_by_room(carve_pos):
							if active_path_layer.get_cell_source_id(carve_pos) == -1:
								var random_grass = grass_variations.pick_random()
								active_path_layer.set_cell(carve_pos, grass_source_id, random_grass)
			else:
				# If a door isn't being used, wall it off
				for door_tile in d["tiles"]:
					var global_door_tile = tile_pos + door_tile
					if not is_tile_used_by_room(global_door_tile):
						active_path_layer.set_cell(global_door_tile, wall_source_id, wall_variations.pick_random())

	# 3. Ask A* for the shortest path between door A and door B, and paint grass on it
	for conn in final_connections:
		var out_a = conn["r_a"]["tile_pos"] + conn["d_a"]["pos"] + (conn["d_a"]["dir"] * (room_padding + 1))
		var out_b = conn["r_b"]["tile_pos"] + conn["d_b"]["pos"] + (conn["d_b"]["dir"] * (room_padding + 1))
		
		var path = astar.get_id_path(out_a, out_b)
		for point in path:
			paint_safe_grass(point)

	build_safe_walls()

# ==========================================
# 4. THE OMNI-SCANNER
# ==========================================
func get_all_tilemap_layers(node: Node, arr: Array):
	if node.get_class() == "TileMapLayer" or node is TileMapLayer:
		arr.append(node)
	for child in node.get_children():
		get_all_tilemap_layers(child, arr)

# This scans a room and creates a "bounding box" (Rect2) around its floor plan.
func scan_room_footprint(instance: Node2D) -> Dictionary:
	var tms = []
	get_all_tilemap_layers(instance, tms)
	
	var used_cells = []
	
	# set min values impossibly high, and max values impossibly low.
	var min_x = 999999; var max_x = -999999
	var min_y = 999999; var max_y = -999999
	
	for tm in tms:
		for cell in tm.get_used_cells():
			if not used_cells.has(cell):
				used_cells.append(cell)
				
			# THE MATH: As it checks every tile, it stretches the min/max box to fit.
			# If it finds a tile further left than min_x, that tile becomes the new min_x.
			if cell.x < min_x: min_x = cell.x
			if cell.x > max_x: max_x = cell.x
			if cell.y < min_y: min_y = cell.y
			if cell.y > max_y: max_y = cell.y
			
	var bounds = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	return {"bounds": bounds, "used_cells": used_cells}

# ==========================================
# 5. UTILITY & DRAWING
# ==========================================

# Checks if a specific tile coordinate overlaps with any room's scanned footprint
func is_tile_used_by_room(global_cell: Vector2i) -> bool:
	for r in placed_rooms:
		var local_cell = global_cell - r["tile_pos"]
		if r["footprint"]["used_cells"].has(local_cell):
			return true
	return false

func place_room(room_scene: PackedScene, pixel_position: Vector2i) -> Node2D:
	var instance = room_scene.instantiate()
	add_child(instance)
	instance.global_position = pixel_position
	return instance

# Uses the Pythagorean theorem (.distance_to) to find the door mathematically closest to the target
func get_best_door(room_data: Dictionary, target_pos: Vector2i):
	var best_door = null
	var min_dist = 9999999.0
	for d in room_data["doors"]:
		var global_door = room_data["tile_pos"] + d["pos"]
		var dist = global_door.distance_to(target_pos)
		if dist < min_dist:
			min_dist = dist
			best_door = d
	return best_door

# Paints a thick line of grass by painting a 2-tile radius square around the center point
func paint_safe_grass(center_tile: Vector2i):
	for x in range(-path_thickness, path_thickness + 1):
		for y in range(-path_thickness, path_thickness + 1):
			var current_cell = center_tile + Vector2i(x, y)
			
			if not is_tile_used_by_room(current_cell):
				if active_path_layer.get_cell_source_id(current_cell) == -1:
					var random_grass = grass_variations.pick_random()
					active_path_layer.set_cell(current_cell, grass_source_id, random_grass)

# Wraps paths in walls. 
func build_safe_walls():
	var used_cells = active_path_layer.get_used_cells() 
	# The 8 coordinates around a center point (N, S, E, W, and the 4 diagonals)
	var neighbors = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	
	# Loop through every piece of grass painted.
	for cell in used_cells:
		for n in neighbors:
			var check_pos = cell + n
			
			# IF the space next to the grass is completely empty (no grass, no wall yet)
			if active_path_layer.get_cell_source_id(check_pos) == -1:
				# And IF it's not inside a room footprint...
				if can_build_wall(check_pos):
					# ...build a wall there
					var random_wall = wall_variations.pick_random()
					active_path_layer.set_cell(check_pos, wall_source_id, random_wall)

func can_build_wall(global_cell: Vector2i) -> bool:
	for r in placed_rooms:
		var local = global_cell - r["tile_pos"]
		if r["footprint"]["used_cells"].has(local):
			return false
	return true
