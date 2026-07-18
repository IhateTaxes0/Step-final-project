extends Node2D

@onready var health_bar = $HealthBar
@onready var sprite = $sprite

# --- ENEMY STATS ---
var enemy_name: String = "Domlr" 
var attack_damage: int = 10      
var max_health: int = 250 
var current_health: int = 250

var is_defending: bool = false 

var idle_position = Vector2(631.0, 347.0)
var attack_position = Vector2(633.0, 321.0)

func _ready():
	health_bar.max_value = max_health
	health_bar.value = current_health
	play_animation("idle")

func play_animation(anim_name: String):
	if anim_name == "attack":
		sprite.scale = Vector2(1.0, 1.0)
		sprite.position = attack_position 
		sprite.modulate = Color(0.816, 0.353, 0.816, 1.0)
	else:
		sprite.scale = Vector2(2.0, 2.0) 
		sprite.position = idle_position
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.play(anim_name)

# --- THE NEW AI BRAIN ---
func perform_turn() -> Dictionary:
	is_defending = false
	
	var rng = randi() % 5
	
	if rng == 3:
		play_animation("attack")
		# Attack doesn't loop, so this await is perfectly safe!
		await sprite.animation_finished 
		play_animation("idle")
		return {"action": "attack", "damage": attack_damage}
		
	elif rng == 2:
		play_animation("attack")
		# Attack doesn't loop, so this await is perfectly safe!
		await sprite.animation_finished 
		play_animation("idle")
		return {"action": "attack", "damage": attack_damage}
		
	elif rng == 1:
		is_defending = true
		return {"action": "defend", "damage": 0}
		
	else:
		return {
			"action": "talk", 
			"damage": 0, 
			"text": "A brilliant maneuver, my king, Let us continue!",
			"speaker": enemy_name
		}

# --- DAMAGE AND HIT REACTIONS ---
func take_damage(amount: int):
	var actual_damage = amount
	
	if is_defending:
		# Multiplies damage by 0.70 to apply exactly a 30% reduction
		actual_damage = int(actual_damage * 0.70)
		print(enemy_name + " blocked! Damage reduced to: ", actual_damage)
		
	current_health -= actual_damage
	health_bar.value = current_health
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.1)
	tween.parallel().tween_property(sprite, "position:x", idle_position.x + 20, 0.1)
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "position:x", idle_position.x, 0.1)
	
	await tween.finished

func is_dead() -> bool:
	return current_health <= 0

	
