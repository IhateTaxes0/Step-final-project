extends CharacterBody2D

@export var speed: float = 110
@onready var sprite = $Wandering_knight

var player: Node2D = null
var is_chasing: bool = false
var last_direction: Vector2 = Vector2.DOWN 

var mob_color: Color

func _ready():
	# Generate a random colored aura!
	var color_options = [Color(1,0.2,0.2), Color(0.2,1,0.2), Color(0.2,0.2,1), Color(1,1,0), Color(1,0,1), Color(0.2,1,1)]
	mob_color = color_options.pick_random()
	sprite.modulate = mob_color
	
	# Save it so the combat script can read it later
	self.set_meta("mob_color", mob_color)

	$Detection_zone.body_entered.connect(_on_player_spotted)
	$Detection_zone.body_exited.connect(_on_player_lost)
	sprite.play("idle_front")
	
func _physics_process(_delta):
	# Default to false every frame. We only chase IF we have Line of Sight!
	is_chasing = false 
	
	if player:
		if has_line_of_sight(player):
			is_chasing = true
			
	if is_chasing:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		last_direction = direction 
		
		update_animation(direction, true)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		update_animation(last_direction, false)

# --- LINE OF SIGHT CHECK ---
func has_line_of_sight(target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	var ignored_objects = [self.get_rid()]
	query.exclude = ignored_objects
	
	var pierce_limit = 10 
	var attempts = 0
	
	while attempts < pierce_limit:
		var result = space_state.intersect_ray(query)
		if result:
			if result.collider == target:
				return true 
				
			# --- Only block vision if it hits the room walls ---
			# By removing StaticBody2D, the raycast will pierce through rocks and trees,
			# meaning the mob will NEVER lose player just because the player walked behind an object
			if result.collider is TileMapLayer or result.collider is TileMap:
				return false 
				
			# If it hits a rock/tree, add it to the ignore list and keep the raycast going
			ignored_objects.append(result.rid)
			query.exclude = ignored_objects
			attempts += 1
		else:
			break
	return false

# --- ANIMATION CONTROLLER ---
func update_animation(dir: Vector2, is_moving: bool):
	if abs(dir.x) > abs(dir.y):
		# Moving Left or Right
		if dir.x > 0:
			if is_moving:
				sprite.play("right_walk")
			else:
				sprite.play("idle_right")
		else:
			if is_moving:
				sprite.play("left_walk")
			else:
				sprite.play("idle_left")
	else:
		# Moving Up or Down
		if is_moving:
			sprite.play("walk_front")
		else:
			sprite.play("idle_front")

# --- SENSOR LOGIC ---
func _on_player_spotted(body):
	# We just track who entered the zone. _physics_process decides if they can be seen!
	if body.is_in_group("player"):
		player = body

func _on_player_lost(body):
	# Forget the player when they completely leave the circle
	if body.is_in_group("player"):
		player = null
