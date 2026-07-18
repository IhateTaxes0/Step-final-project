extends Node2D

@onready var health_bar = $HealthBar
@onready var sprite = $sprite

# --- ENEMY STATS ---
var enemy_name: String = "Wandering Knight" 
var attack_damage: int = 15      
var max_health: int = 150 
var current_health: int = 150
var base_color: Color = Color.WHITE
var is_defending: bool = false 

var idle_position = Vector2(631.0, 347.0)
var attack_position = Vector2(633.0, 321.0)

func _ready():
	# search GameManager how hard the game should be right now
	if GameManager.enemy_combat_queue.size() > 0:
		base_color = GameManager.enemy_combat_queue[0]["color"]
		
	sprite.modulate = base_color
	var difficulty_multiplier = GameManager.get_enemy_stat_multiplier()
	
	# scale the stats
	max_health = int(max_health * difficulty_multiplier)
	current_health = max_health # Ensure they start at the new max health!
	
	attack_damage = int(attack_damage * difficulty_multiplier)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	play_animation("idle")

func play_animation(anim_name: String):
	if anim_name == "attack":
		sprite.scale = Vector2(2.5, 2.5)
		sprite.position = attack_position 
		sprite.modulate = Color(1.0, 0.0, 0.0, 1.0) # Flash Red
	else:
		sprite.scale = Vector2(2.5, 2.5) 
		sprite.position = idle_position
		sprite.modulate = base_color # Return to its random color
	sprite.play(anim_name)

# --- THE AI BRAIN (Domlr Logic) ---
func perform_turn() -> Dictionary:
	is_defending = false
	var rng = randi() % 2
	
	if rng == 0:
		play_animation("attack")
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
			"text": "*The enemy suddenly froze and stares at you, you didn't let your guard down*",
			"speaker": enemy_name
		}

# --- DAMAGE AND HIT REACTIONS ---
func take_damage(amount: int):
	var actual_damage = amount
	
	if is_defending:
		actual_damage = int(actual_damage * 0.70) # 30% damage reduction
		print(enemy_name + " blocked! Damage reduced to: ", actual_damage)
		
	current_health -= actual_damage
	health_bar.value = current_health
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.1) # Flash Red
	tween.parallel().tween_property(sprite, "position:x", idle_position.x + 20, 0.1)
	
	# THE FIX: Flash a brighter version of its base color, then return to base color!
	tween.tween_property(sprite, "modulate", base_color.lightened(0.5), 0.1) 
	tween.tween_property(sprite, "modulate", base_color, 0.1) 
	
	tween.parallel().tween_property(sprite, "position:x", idle_position.x, 0.1)
	
	await tween.finished

func is_dead() -> bool:
	return current_health <= 0
