extends CanvasLayer

# ------------------------------------------------------------------
#  ENUMS & CONSTANTS
# ------------------------------------------------------------------

# Represents the possible colors of an orb slot.
enum OrbColor { RED, BLUE, YELLOW, PURPLE, EMPTY, NONE }

# Stores the original scale of each orb sprite for resetting animations.
var sprite_base_scales = []

# ------------------------------------------------------------------
#  UI NODE REFERENCES
# ------------------------------------------------------------------

# THE FIX: Added VBoxContainer to the path to match your exact node tree!
@onready var skill_panel = $MarginContainer/VBoxContainer/SkillPanel
@onready var btn_mana_regen = $MarginContainer/VBoxContainer/SkillPanel/HBoxContainer/BtnManaRegen
@onready var btn_vertical_slash = $MarginContainer/VBoxContainer/SkillPanel/HBoxContainer/BtnVerticalSlash
@onready var btn_back = $MarginContainer/VBoxContainer/SkillPanel/HBoxContainer/BtnBack

@onready var slot_box = $MarginContainer/VBoxContainer/SlotBox
@onready var slots = [
	$MarginContainer/VBoxContainer/SlotBox/Slot1,
	$MarginContainer/VBoxContainer/SlotBox/Slot2,
	$MarginContainer/VBoxContainer/SlotBox/Slot3,
	$MarginContainer/VBoxContainer/SlotBox/Slot4
]
@onready var btn_box = $MarginContainer/VBoxContainer/ButtonBox
@onready var btn_attack = $MarginContainer/VBoxContainer/ButtonBox/BtnAttack
@onready var btn_defense = $MarginContainer/VBoxContainer/ButtonBox/BtnDefense
@onready var btn_skill = $MarginContainer/VBoxContainer/ButtonBox/BtnSkill
var active_attack_mode: String = "attack"
# ------------------------------------------------------------------
#  EXTERNAL NODE REFERENCES (Player, Enemy, VFX, etc.)
# ------------------------------------------------------------------

var enemy: Node2D 
@onready var player = $"../Player" 

# --- VFX NODES ---
@onready var attack_vfx = $"../basic_attack"
@onready var skill_vfx = $"../vertical_slash"
@onready var attack_vfx2 = $"../basic_attack2" # NEW: Quick Hand VFX 1
@onready var attack_vfx3 = $"../basic_attack3" # NEW: Quick Hand VFX 2
@onready var enemy_vfx = $"../enemy_vfx" 

@onready var turn_indicator = $"../tainer/TurnIndicator"
@onready var enemy_spawn_point = $"../EnemySpawnPoint" 

# ------------------------------------------------------------------
#  STATE TRACKING
# ------------------------------------------------------------------

# Base probability weights for each orb color (used for RNG rolls)
var base_weights = { OrbColor.RED: 25, OrbColor.BLUE: 25, OrbColor.YELLOW: 25, OrbColor.EMPTY: 20, OrbColor.PURPLE: 10 }
var current_weights = {}

var slot_colors = [OrbColor.NONE, OrbColor.NONE, OrbColor.NONE, OrbColor.NONE]
var slot_multipliers = [1, 1, 1, 1]
var slot_locked = [false, false, false, false]

var current_turn: int = 1

# ------------------------------------------------------------------
#  _ready() – Initialization
# ------------------------------------------------------------------

func _ready():
	self.layer = 105
	
	# --- THE FIX: Hide the UI instantly so the screen is empty! ---
	self.hide() 
	
	btn_attack.pressed.connect(_on_attack_pressed)
	btn_defense.pressed.connect(_on_defense_pressed) 
	btn_skill.pressed.connect(_on_skill_pressed) 
	btn_mana_regen.pressed.connect(_on_mana_regen_pressed)
	btn_vertical_slash.pressed.connect(_on_vertical_slash_pressed) # RENAMED!
	btn_back.pressed.connect(_on_back_pressed)
	
	if skill_vfx: skill_vfx.hide()
	if enemy_vfx: enemy_vfx.hide()
	if attack_vfx: attack_vfx.hide() 
	if attack_vfx2: attack_vfx2.hide() 
	if attack_vfx3: attack_vfx3.hide() 
	
	skill_panel.hide()
	slot_box.show()
	
	turn_indicator.text = "Player's Turn | Turn " + str(current_turn)
	
	if GameManager.current_enemy_path == "":
		GameManager.current_enemy_path = "res://world/enemies/agis.tscn"
		
	var enemy_scene = load(GameManager.current_enemy_path)
	var spawned_enemy = enemy_scene.instantiate()
	enemy_spawn_point.add_child(spawned_enemy)
	spawned_enemy.position = Vector2.ZERO
	enemy = spawned_enemy

	for slot in slots:
		var sprite = slot.get_node("CenterPoint/OrbSprite")
		sprite_base_scales.append(sprite.scale)
		sprite.hide()
		slot.get_node("MultiplierText").text = ""
	
	btn_attack.disabled = true
	btn_defense.disabled = true
	btn_skill.disabled = true
	
	# --- Defer the adding of the child ---
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	get_parent().call_deferred("add_child", fade_rect)

	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.4)
	await tween.finished
	fade_rect.queue_free()

	# NOW SHOW THE UI!
	self.show()
	# ---------------------------------
	
	if GameManager.is_slot_system_unlocked == false and enemy.enemy_name == "Domlr":
		await play_tutorial_intro()
	
	btn_attack.disabled = false
	btn_defense.disabled = false
	btn_skill.disabled = false
# ------------------------------------------------------------------
#  BUTTON HANDLERS
# ------------------------------------------------------------------

func _on_skill_pressed():
	if GameManager.is_skill_system_unlocked == false:
		turn_indicator.text = "Skills are locked!"
		await get_tree().create_timer(1.0).timeout
		turn_indicator.text = "Player's Turn"
		return
		
	btn_attack.disabled = true
	btn_defense.disabled = true
	btn_skill.disabled = true
	btn_box.hide()
	slot_box.hide()
	skill_panel.show()

func _on_back_pressed():
	skill_panel.hide()
	slot_box.show()
	btn_box.show()
	btn_attack.disabled = false
	btn_defense.disabled = false
	btn_skill.disabled = false

func _on_mana_regen_pressed():
	skill_panel.hide()
	btn_box.show()
	slot_box.show() 
	turn_indicator.text = "Regenerating Mana..."
	
	await player.play_mana_vfx()
	player.gain_mana(100) 
	await get_tree().create_timer(0.5).timeout
	trigger_enemy_turn() 

func _on_vertical_slash_pressed():
	if player.use_mana(100) == false:
		turn_indicator.text = "Not enough Mana!"
		await get_tree().create_timer(1.0).timeout
		turn_indicator.text = "Player's Turn"
		_on_back_pressed() 
		return
		
	skill_panel.hide()
	slot_box.show()
	btn_box.show()
	_start_attack_sequence("vertical_slash")

func _on_defense_pressed():
	btn_attack.disabled = true
	btn_defense.disabled = true
	btn_skill.disabled = true 
	
	turn_indicator.text = "Player Guards!"
	await player.defend() 
	await get_tree().create_timer(0.5).timeout
	trigger_enemy_turn()

# ------------------------------------------------------------------
#  UNIFIED ATTACK SYSTEM
# ------------------------------------------------------------------

func _on_attack_pressed():
	_start_attack_sequence("normal")

func _start_attack_sequence(mode: String):
	active_attack_mode = mode 
	
	btn_attack.disabled = true
	btn_defense.disabled = true
	btn_skill.disabled = true
	player.reset_defense() 
	
	if GameManager.is_slot_system_unlocked == false:
		await get_tree().create_timer(0.5).timeout
		var current_damage = GameManager.get_player_damage()
		if active_attack_mode == "vertical_slash":
			current_damage += 100
		apply_damage_to_enemy(current_damage)
		return
	
	if GameManager.get_equipped_weapon() == "Rosari":
		current_weights = { OrbColor.RED: 0, OrbColor.BLUE: 0, OrbColor.YELLOW: 0, OrbColor.EMPTY: 25, OrbColor.PURPLE: 50 }
	else:
		current_weights = base_weights.duplicate()
		
	for i in range(slots.size()):
		slot_colors[i] = OrbColor.NONE
		slot_multipliers[i] = 1
		slot_locked[i] = false
		slots[i].get_node("MultiplierText").text = ""
	
	var board_settled = false
	while not board_settled:
		await trigger_spin_phase()
		var combos_made = await trigger_combo_phase()
		if combos_made == 0:
			board_settled = true
			
	calculate_final_damage()

# ------------------------------------------------------------------
#  SPIN & COMBO MECHANICS
# ------------------------------------------------------------------

func trigger_spin_phase():
	var tweens_running = 0
	var rolling_indices = []
	for i in range(slots.size()):
		if not slot_locked[i] and slot_colors[i] == OrbColor.NONE:
			rolling_indices.append(i)
			
	var forced_purples = []
	if GameManager.get_equipped_weapon() == "Rosari" and rolling_indices.size() >= 2:
		rolling_indices.shuffle()
		forced_purples.append(rolling_indices.pop_back())
		forced_purples.append(rolling_indices.pop_back())
			
	for i in range(slots.size()):
		if not slot_locked[i] and slot_colors[i] == OrbColor.NONE:
			var rolled_color
			if i in forced_purples:
				rolled_color = OrbColor.PURPLE
			else:
				rolled_color = roll_weighted_rng()
				
			slot_colors[i] = rolled_color
			
			if rolled_color == OrbColor.PURPLE or rolled_color == OrbColor.EMPTY:
				slot_locked[i] = true
				
			animate_spin_appear(i, rolled_color)
			tweens_running += 1
			
	if tweens_running > 0:
		await get_tree().create_timer(0.6).timeout

func trigger_combo_phase() -> int:
	var combos_made = 0
	for left_idx in range(slots.size()):
		if slot_locked[left_idx] or slot_colors[left_idx] == OrbColor.EMPTY or slot_colors[left_idx] == OrbColor.NONE:
			continue
			
		for right_idx in range(left_idx + 1, slots.size()):
			if slot_locked[right_idx] or slot_colors[right_idx] == OrbColor.EMPTY or slot_colors[right_idx] == OrbColor.NONE:
				continue
				
			if slot_colors[left_idx] == slot_colors[right_idx]:
				slot_multipliers[left_idx] += slot_multipliers[right_idx]
				await animate_combo_dissolve(right_idx, left_idx)
				
				slot_colors[right_idx] = OrbColor.NONE
				slot_multipliers[right_idx] = 1
				slots[right_idx].get_node("MultiplierText").text = "" 
				adjust_rng_weights()
				combos_made += 1
				
	return combos_made

# ------------------------------------------------------------------
#  FINAL DAMAGE CALCULATION & OFFENSIVE PASSIVES
# ------------------------------------------------------------------

func calculate_final_damage():
	var total_red = 0; var total_blue = 0; var total_yellow = 0; var total_purple = 0
	
	for i in range(slots.size()):
		match slot_colors[i]:
			OrbColor.RED: total_red += slot_multipliers[i]
			OrbColor.BLUE: total_blue += slot_multipliers[i]
			OrbColor.YELLOW: total_yellow += slot_multipliers[i]
			OrbColor.PURPLE: total_purple += 1  
			
	var mana_gain = 0
	if total_blue >= 1: mana_gain += 10
	if total_blue >= 2: mana_gain += 5
	if total_blue >= 3: mana_gain += 5
	if total_blue == 4: mana_gain = 30   
	var blue_bonus = mana_gain   
	
	var red_multiplier = 0.0
	if total_red >= 4:
		red_multiplier = 0.50   
	else:
		red_multiplier = min(total_red * 0.10, 1.0)
		
	var crit_chance = min(total_yellow * 0.20, 1.0)
	var crit_multiplier = 1.0
	var crit_damage_base = 2.0   
	
	if total_yellow >= 5:
		var extra_yellow = total_yellow - 4
		crit_damage_base = min(2.0 + (extra_yellow * 0.25), 3.0)
		
	if randf() <= crit_chance:
		crit_multiplier = crit_damage_base
		
	var purple_multiplier = 1.0
	if total_purple == 4: 
		purple_multiplier = 30.0
	elif total_purple >= 2: 
		purple_multiplier = 10.0
		
	var current_damage = GameManager.get_player_damage()
	if active_attack_mode == "vertical_slash":
		current_damage += 100
		
	# Base formula before passives
	var final_damage = ((current_damage + blue_bonus) * (1.0 + red_multiplier)) * crit_multiplier * purple_multiplier
	var final_mana = mana_gain * purple_multiplier
	
	# --- PROFICIENCY PASSIVE ---
	if active_attack_mode == "vertical_slash" and GameManager.passive_stacks.has("proficiency"):
		var prof_level = GameManager.passive_stacks["proficiency"]
		var prof_mult = min(0.20 * prof_level, 0.60) # Max 60%
		final_damage += (final_damage * prof_mult)
		
	# --- QUICK HAND PASSIVE ---
	var is_quick_hand = false
	if GameManager.passive_stacks.has("quick_hand"):
		if randf() <= 0.30: # 30% Chance
			final_damage *= 2.0
			is_quick_hand = true
			turn_indicator.text = "Quick Hand! Double Damage!"
			await get_tree().create_timer(1.0).timeout
	
	# Apply mana gain and damage
	player.gain_mana(final_mana) 
	
	# Pass the is_quick_hand flag to our animation handler!
	apply_damage_to_enemy(int(final_damage), is_quick_hand)

# ------------------------------------------------------------------
#  RANDOM NUMBER GENERATION & WEIGHT ADJUSTMENT
# ------------------------------------------------------------------

func roll_weighted_rng() -> int:
	var total_weight = 0
	for color in current_weights:
		total_weight += current_weights[color]
		
	var random_roll = randi_range(0, total_weight - 1)
	var current_step = 0
	
	for color in current_weights:
		current_step += current_weights[color]
		if random_roll < current_step:
			return color
			
	return OrbColor.EMPTY 

func adjust_rng_weights():
	if current_weights[OrbColor.EMPTY] > 5:
		current_weights[OrbColor.EMPTY] -= 5
		current_weights[OrbColor.RED] += 1
		current_weights[OrbColor.BLUE] += 1
		current_weights[OrbColor.YELLOW] += 1

# ------------------------------------------------------------------
#  ANIMATION HELPERS
# ------------------------------------------------------------------

func animate_spin_appear(index: int, color: int):
	var slot_node = slots[index]
	var center_point = slot_node.get_node("CenterPoint")
	var orb_sprite = center_point.get_node("OrbSprite")
	
	center_point.position = slot_node.size / 2.0 
	orb_sprite.position = Vector2.ZERO 
	orb_sprite.scale = sprite_base_scales[index]
	orb_sprite.modulate.a = 1.0
	orb_sprite.show()
	
	var prefix = get_color_prefix(color)
	orb_sprite.play(prefix + "_appear")
	await orb_sprite.animation_finished
	orb_sprite.play(prefix + "_loop")

func animate_combo_dissolve(from_idx: int, to_idx: int):
	var dissolving_sprite = slots[from_idx].get_node("CenterPoint/OrbSprite")
	var target_label = slots[to_idx].get_node("MultiplierText")
	
	target_label.text = str(slot_multipliers[to_idx])
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(dissolving_sprite, "scale", Vector2(0, 0), 0.3)
	tween.tween_property(dissolving_sprite, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	dissolving_sprite.hide()

func get_color_prefix(color: int) -> String:
	match color:
		OrbColor.RED: return "red"
		OrbColor.BLUE: return "blue"
		OrbColor.YELLOW: return "yellow"
		OrbColor.PURPLE: return "purple"
		OrbColor.EMPTY: return "empty"
	return ""

# ------------------------------------------------------------------
#  COMBAT ANIMATION FLOW
# ------------------------------------------------------------------

func apply_damage_to_enemy(damage_amount: int, is_quick_hand: bool = false):
	# 1. Knife self-damage
	if GameManager.get_equipped_weapon() == "Knife":
		turn_indicator.text = "The Knife demands blood!"
		await player.take_damage(100) 
		
		if player.is_dead():
			set_process_input(false)
			set_process(false)
			turn_indicator.text = "Defeat..."
			await get_tree().create_timer(2.0).timeout
			
			var fade_layer = CanvasLayer.new()
			fade_layer.layer = 120
			fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
			var black_screen = ColorRect.new()
			black_screen.color = Color(0, 0, 0, 0)
			black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
			fade_layer.add_child(black_screen)
			get_tree().root.add_child(fade_layer)
			
			var tween = fade_layer.create_tween()
			tween.tween_property(black_screen, "modulate:a", 1.0, 1.0)
			await tween.finished
			
			self.hide()
			
			var overlay = get_tree().root.get_node_or_null("CombatOverlay")
			if overlay:
				overlay.name = "DeletedOverlay"
				overlay.queue_free()
			
			fade_layer.queue_free() 
			
			GameManager.enemy_combat_queue.clear()
			GameManager.is_transitioning_to_combat = false
			get_tree().current_scene.process_mode = Node.PROCESS_MODE_INHERIT
			
			SceneTransition.change_scene("res://world/dreamland1.tscn")
			return # Stop processing if the player died!
			
	# 2. --- THE NEW ANIMATION LOGIC ---
	if is_quick_hand:
		# Step 1: Play standard attack with standard VFX[cite: 19]
		await player.perform_attack()
		if attack_vfx:
			attack_vfx.show()
			attack_vfx.play("attack") 
			await attack_vfx.animation_finished
			attack_vfx.hide()
			
		# Step 2: Follow up with the skill attack and its 2 VFX[cite: 19]
		await player.perform_skill_attack() 
		
		if attack_vfx2 and attack_vfx3:
			# 1st. basic_attack2 plays quick_hand
			attack_vfx2.show()
			attack_vfx2.play("quick_hand")
			await attack_vfx2.animation_finished
			
			# 2nd. basic_attack2 & basic_attack3 play "default" concurrently
			attack_vfx2.play("default")
			attack_vfx3.show()
			attack_vfx3.play("default")
			
			# Wait for the simultaneous explosion to finish
			await attack_vfx2.animation_finished
			
			attack_vfx2.hide()
			attack_vfx3.hide()
			
	elif active_attack_mode == "vertical_slash":
		turn_indicator.text = "Vertical Slash!"
		await player.perform_skill_attack()
		
		if skill_vfx:
			skill_vfx.show()
			skill_vfx.play("vertical_slash") # Plays the vertical_slash animation[cite: 19]
			await skill_vfx.animation_finished
			skill_vfx.hide()
			
	else:
		# Standard Attack
		await player.perform_attack()
		if attack_vfx:
			attack_vfx.show()
			attack_vfx.play("attack") 
			await attack_vfx.animation_finished
			attack_vfx.hide()
	
	# 3. --- apply the damage ---
	await enemy.take_damage(damage_amount) 
	
	if enemy.is_dead():
		trigger_victory()
	else:
		trigger_enemy_turn()

# ------------------------------------------------------------------
#  ENEMY TURN & DEFENSIVE PASSIVES
# ------------------------------------------------------------------

func trigger_enemy_turn():
	turn_indicator.text = "Enemy's Turn | Turn " + str(current_turn)
	await get_tree().create_timer(1.0).timeout
	
	var turn_data = await enemy.perform_turn()
	
	if turn_data["action"] == "attack":
		var incoming_dmg = turn_data["damage"]
		var attack_nullified = false
		
		# --- COMBAT MASTER PASSIVE ---
		if GameManager.passive_stacks.has("combat_master"):
			var cm_level = GameManager.passive_stacks["combat_master"]
			var cm_chance = min(0.20 + ((cm_level - 1) * 0.10), 0.40) 
			
			if randf() <= cm_chance:
				attack_nullified = true
				turn_indicator.text = "Combat Master! Nullified & Countered!"
				await get_tree().create_timer(1.0).timeout
				
				var counter_dmg = GameManager.get_player_damage()
				await enemy.take_damage(counter_dmg)
				
				if enemy.is_dead():
					trigger_victory()
					return
					
		if not attack_nullified:
			# --- IRON BODY PASSIVE ---
			if GameManager.passive_stacks.has("iron_body"):
				var ib_level = GameManager.passive_stacks["iron_body"]
				var ib_values = [0.0, 0.10, 0.25, 0.40, 0.55, 0.60]
				var safe_level = min(ib_level, 5)
				var reduction = ib_values[safe_level]
				
				incoming_dmg -= int(incoming_dmg * reduction)
				
			await player.take_damage(incoming_dmg)
		
	elif turn_data["action"] == "defend":
		turn_indicator.text = "Enemy is guarding!"
		if enemy_vfx:
			enemy_vfx.show() 
			enemy_vfx.play("default")
			await enemy_vfx.animation_finished
			enemy_vfx.hide()
		else:
			await get_tree().create_timer(1.0).timeout
			
	elif turn_data["action"] == "talk":
		self.hide() 
		ActionMenu.show_message(turn_data["text"], turn_data["speaker"])
		await ActionMenu.choice_made 
		self.show()
	
	if player.is_dead():
			set_process_input(false)
			set_process(false)
			turn_indicator.text = "Defeat..."
			await get_tree().create_timer(2.0).timeout
			
			var fade_layer = CanvasLayer.new()
			fade_layer.layer = 120
			fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
			var black_screen = ColorRect.new()
			black_screen.color = Color(0, 0, 0, 0)
			black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
			fade_layer.add_child(black_screen)
			get_tree().root.add_child(fade_layer)
			
			var tween = fade_layer.create_tween()
			tween.tween_property(black_screen, "modulate:a", 1.0, 1.0)
			await tween.finished
			
			# --- THE FIX: Hide UI ---
			self.hide()
			
			var overlay = get_tree().root.get_node_or_null("CombatOverlay")
			if overlay:
				overlay.name = "DeletedOverlay"
				overlay.queue_free()
			
			fade_layer.queue_free() 
			
			# --- THE FIX: Reset logic ONLY right before teleporting ---
			GameManager.enemy_combat_queue.clear()
			GameManager.is_transitioning_to_combat = false
			get_tree().current_scene.process_mode = Node.PROCESS_MODE_INHERIT
			
			SceneTransition.change_scene("res://world/dreamland1.tscn")
	else:
		current_turn += 1
		turn_indicator.text = "Player's Turn | Turn " + str(current_turn)
		
		player.reset_defense() 
		btn_attack.disabled = false
		btn_defense.disabled = false
		btn_skill.disabled = false
# ------------------------------------------------------------------
#  VICTORY & LOOT
# ------------------------------------------------------------------

func trigger_victory():
	turn_indicator.text = "Victory!"
	
	# Disable inputs to prevent double-clicks
	set_process_input(false)
	set_process(false)
	
	var dropped_items = []
	if randf() <= 0.10: dropped_items.append("god_fruit")       
	if randf() <= 0.60: dropped_items.append("quick_hand")      
	if randf() <= 0.60: dropped_items.append("iron_body")       
	if randf() <= 0.30: dropped_items.append("combat_master")   
	if randf() <= 0.30: dropped_items.append("proficiency")     
	
	for item in dropped_items:
		GameManager.inventory.append(item)
		
	if dropped_items.size() > 0:
		turn_indicator.text = "Victory! Found " + str(dropped_items.size()) + " fruit(s)!"
		await get_tree().create_timer(1.5).timeout
	
	if enemy.get("enemy_name") == "Domlr":
		# Domlr still uses the black screen to hide the dialogue swap!
		var fade_layer = CanvasLayer.new()
		fade_layer.layer = 120 
		fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		var black_screen = ColorRect.new()
		black_screen.color = Color(0, 0, 0, 0) 
		black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade_layer.add_child(black_screen)
		get_tree().root.add_child(fade_layer)
		
		var tween = fade_layer.create_tween()
		tween.tween_property(black_screen, "modulate:a", 1.0, 1.0)
		await tween.finished
		
		GameManager.is_slot_system_unlocked = true
		GameManager.is_skill_system_unlocked = true
		GameManager.return_from_combat = false
		
		ActionMenu.show_message("well done, my king", "Domlr")
		await ActionMenu.choice_made
		ActionMenu.show_message("you have grapsed the power of creation and destruction", "Domlr")
		await ActionMenu.choice_made
		
		fade_layer.queue_free() 
		GameManager.start_new_day()
		SceneTransition.change_scene("res://world/main.tscn")
		print("Tutorial complete: Slot & Skill systems unlocked!")
		
	else:
		GameManager.monsters_slain += 1
		
		if GameManager.enemy_combat_queue.size() > 0:
			var defeated_enemy = GameManager.enemy_combat_queue.pop_front()
			GameManager.dead_enemy_positions.append(defeated_enemy["pos"])
			if defeated_enemy.has("node") and is_instance_valid(defeated_enemy["node"]):
				defeated_enemy["node"].queue_free()
		
		if GameManager.enemy_combat_queue.size() > 0:
			# Back-to-Back fights still use the black screen to hide the arena swapping
			var fade_layer = CanvasLayer.new()
			fade_layer.layer = 120 
			fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
			var black_screen = ColorRect.new()
			black_screen.color = Color(0, 0, 0, 0) 
			black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
			fade_layer.add_child(black_screen)
			get_tree().root.add_child(fade_layer)
			
			var tween = fade_layer.create_tween()
			tween.tween_property(black_screen, "modulate:a", 1.0, 1.0)
			await tween.finished
			
			GameManager.current_enemy_path = GameManager.enemy_combat_queue[0]["path"]
			var overlay = get_tree().root.get_node_or_null("CombatOverlay")
			if overlay:
				var new_arena = load("res://world/CombatArena.tscn").instantiate()
				overlay.add_child(new_arena)
				
				self.get_parent().hide() 
				
				var tween2 = fade_layer.create_tween()
				tween2.tween_property(black_screen, "modulate:a", 0.0, 1.0)
				await tween2.finished
				
				fade_layer.queue_free()
				self.get_parent().queue_free() 
			else:
				fade_layer.queue_free()
				get_tree().reload_current_scene()
				
		else:
			# --- THE FIX: NO MORE 2-SECOND PAUSE. Fade out seamlessly! ---
			GameManager.is_transitioning_to_combat = false
			var overlay = get_tree().root.get_node_or_null("CombatOverlay")
			if overlay:
				var arena = self.get_parent()
				
				# Run both the Arena background and CombatUI foreground fades at the exact same time
				var tween = create_tween().set_parallel(true)
				tween.tween_property(arena, "modulate:a", 0.0, 1.0)
				
				# Iterate over all UI elements inside the CanvasLayer to fade them out too
				for child in self.get_children():
					if child is CanvasItem:
						tween.tween_property(child, "modulate:a", 0.0, 1.0)
				
				await tween.finished
				
				get_tree().current_scene.process_mode = Node.PROCESS_MODE_INHERIT
				overlay.queue_free()
			else:
				get_tree().current_scene.process_mode = Node.PROCESS_MODE_INHERIT
				SceneTransition.change_scene("res://world/level 1/dungeon_level1.tscn")

# ------------------------------------------------------------------
#  TUTORIAL DIALOGUE
# ------------------------------------------------------------------

func play_tutorial_intro():
	self.hide() 
	
	ActionMenu.show_message("those time are nostalgic", "Domlr")
	await ActionMenu.choice_made
	
	ActionMenu.show_message("you can control strengh output based on those 4 boxes, i will guide you after this training section ends", "Domlr")
	await ActionMenu.choice_made
	
	self.show()
