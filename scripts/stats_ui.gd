extends CanvasLayer

@onready var stats_border = $StatsBorder

# Top Stats
@onready var label_hp = $StatsBorder/MarginContainer/VBoxContainer/LabelHP
@onready var label_mana = $StatsBorder/MarginContainer/VBoxContainer/LabelMana
@onready var label_nightmare = $StatsBorder/MarginContainer/VBoxContainer/LabelNightmare
@onready var label_monsters = $StatsBorder/MarginContainer/VBoxContainer/LabelMonsters

# Passives
@onready var label_passive_1 = $StatsBorder/MarginContainer/VBoxContainer/PassivesMargin/VBoxContainer/LabelPassive1
@onready var label_passive_2 = $StatsBorder/MarginContainer/VBoxContainer/PassivesMargin/VBoxContainer/LabelPassive2

# Weapon Box
@onready var weapon_icon = $StatsBorder/MarginContainer/VBoxContainer/CenterContainer/PanelContainer/MarginContainer/WeaponIcon
@onready var label_damage = $StatsBorder/MarginContainer/VBoxContainer/WeaponStatsBox/MarginContainer/VBoxContainer/LabelDamage
@onready var label_skill = $StatsBorder/MarginContainer/VBoxContainer/WeaponStatsBox/MarginContainer/VBoxContainer/LabelSkill
@onready var label_effect = $StatsBorder/MarginContainer/VBoxContainer/WeaponStatsBox/MarginContainer/VBoxContainer/LabelEffect

func _ready():
	stats_border.hide()

func _unhandled_input(event):
	if event.is_action_pressed("toggle_stats"):
		if stats_border.visible:
			stats_border.hide()
			GameManager.is_interacting = false 
		else:
			update_display()
			stats_border.show()
			GameManager.is_interacting = true 

func update_display():
	# 1. Update Top Stats
	label_hp.text = "HP: " + str(GameManager.current_hp) + "/" + str(GameManager.max_hp)
	label_mana.text = "Mana: " + str(GameManager.current_mana) + "/" + str(GameManager.max_mana)
	label_nightmare.text = "nightmare: " + str(GameManager.nightmare_chance) + "%   |   total: " + str(GameManager.total_nightmares)
	label_monsters.text = "monster slain: " + str(GameManager.monsters_slain)
	
	# 2. Update Passives
	label_passive_1.text = "passive 1: None"
	label_passive_2.text = "passive 2: None"
	
	# --- THE FIX: Pull directly from the passive_stacks Dictionary ---
	var passives = GameManager.passive_stacks.keys()
	
	if passives.size() > 0:
		label_passive_1.text = "passive 1: " + passives[0] + " (Lv. " + str(GameManager.passive_stacks[passives[0]]) + ")"
	if passives.size() > 1:
		label_passive_2.text = "passive 2: " + passives[1] + " (Lv. " + str(GameManager.passive_stacks[passives[1]]) + ")"
		
	# 3. Update Weapon Data
	var weapon_name = GameManager.get_equipped_weapon()
	
	if GameManager.weapons.has(weapon_name):
		var w_data = GameManager.weapons[weapon_name]
		
		label_damage.text = "Damage: " + str(w_data.get("damage", 0))
		label_skill.text = "Skill: " + w_data.get("skill", "None")
		label_effect.text = "Special effect: " + w_data.get("effect", "None")
		
		var path = w_data.get("icon_path", "")
		if ResourceLoader.exists(path):
			weapon_icon.texture = load(path)
		else:
			weapon_icon.texture = null
	else:
		label_damage.text = "Damage: ???"
		label_skill.text = "Skill: ???"
		label_effect.text = "Special effect: ???"
		weapon_icon.texture = null
