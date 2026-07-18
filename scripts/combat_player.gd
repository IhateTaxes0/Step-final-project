extends AnimatedSprite2D

@onready var health_bar = $"../Player/PlayerHealthBar"
@onready var defense_shield = $"../DefenseShield" 
@onready var defense_aura = $"../DefenseAura"     
@onready var mana_bar = $"../Player/PlayerManaBar"
@onready var mana_aura = $"../ManaAura" 
@onready var mana_shield = $"../ManaShield" 
@onready var hit_vfx = $"../Hit" 

# DELETED: local health and mana variables!
var is_defending: bool = false

func _ready():
	# Now pulling directly from the global stats!
	health_bar.max_value = GameManager.max_hp
	health_bar.value = GameManager.current_hp
	if mana_bar:
		mana_bar.max_value = GameManager.max_mana
		mana_bar.value = GameManager.current_mana
		
	if mana_aura: mana_aura.hide()
	if mana_shield: mana_shield.hide()
	if hit_vfx: hit_vfx.hide()	
	play("idle")
	
	if defense_shield:
		defense_shield.hide()
	if defense_aura:
		defense_aura.hide()

func perform_attack():
	play("attack")
	await animation_finished
	play("idle")

# --- THE DUAL-VFX DEFENSE SEQUENCE ---
func defend():
	is_defending = true
	
	play("defense")
	await animation_finished 
	
	pause()
	frame = 2
	
	if defense_shield and defense_aura:
		defense_shield.show()
		defense_aura.show()
		
		defense_shield.play("shield") 
		defense_aura.play("aura")
		
		await defense_shield.animation_finished
		
		defense_shield.hide()
		defense_aura.hide()

func reset_defense():
	is_defending = false
	play("idle") 

func take_damage(base_amount: int):
	var actual_damage = base_amount
	
	if is_defending:
		actual_damage = int(actual_damage / 2.0)
		print("Player guarded! Damage reduced to: ", actual_damage)
	else:
		print("Player takes damage: ", actual_damage)
		
	# Updating the Global Memory!
	GameManager.current_hp -= actual_damage
	health_bar.value = GameManager.current_hp
	
	modulate = Color(1, 0, 0)
	
	if hit_vfx:
		hit_vfx.show()
		hit_vfx.play("default") 
		await hit_vfx.animation_finished
		hit_vfx.hide()
	else:
		await get_tree().create_timer(0.2).timeout
		
	modulate = Color(1, 1, 1)

func is_dead() -> bool:
	return GameManager.current_hp <= 0
	
func gain_mana(amount: int):
	GameManager.current_mana = clamp(GameManager.current_mana + amount, 0, GameManager.max_mana)
	if mana_bar: mana_bar.value = GameManager.current_mana

func use_mana(amount: int) -> bool:
	if GameManager.current_mana >= amount:
		GameManager.current_mana -= amount
		if mana_bar: mana_bar.value = GameManager.current_mana
		return true
	return false

func perform_skill_attack():
	play("vertical_slash")
	await animation_finished
	play("idle")
	
func play_mana_vfx():
	if mana_aura and mana_shield:
		mana_aura.show()
		mana_shield.show()
		mana_aura.play("aura") 
		mana_shield.play("shield")
		
		await mana_shield.animation_finished
		
		mana_aura.hide()
		mana_shield.hide()
