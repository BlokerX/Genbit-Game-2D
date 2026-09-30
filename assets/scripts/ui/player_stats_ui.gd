extends VBoxContainer

@export var player: PlayerCharacter
var stats_text_label: Label

func _ready() -> void:
	# Tworzymy jeden elastyczny tekst na wszystkie statystyki
	stats_text_label = Label.new()
	add_child(stats_text_label)
	
	# Ukrywamy stare, sztywne etykiety z edytora, by nie śmieciły na ekranie
	for child in get_children():
		if child != stats_text_label and child.name != "StatsHeader":
			child.hide()

	if player:
		if player.inventory:
			player.inventory.inventory_updated.connect(update_stats_display)
		# Opcjonalnie podpinamy się pod zmianę Max HP (jeśli potrzebujesz live-update na ekranie)
		if player.get("health_stats_script"):
			player.health_stats_script.max_health_changed.connect(func(_val): update_stats_display())
			
		update_stats_display()

func update_stats_display() -> void:
	if not is_instance_valid(player): return
	
	var atk_stats = player.get("interaction_and_attack_stats_script")
	var hp_stats = player.get("health_stats_script")
	var move_stats = player.get("movement_universal_script")
	
	var text = ""
	
	# --- ZDROWIE I PANCERZ ---
	if hp_stats:
		text += "MAX HP: " + str(hp_stats.max_health) + "\n"
		
		# Wyciąganie pancerza (jeśli wprowadzisz odpowiednie funkcje/zmienne)
		var armor = 0.0
		if hp_stats.has_method("get_total_armor"):
			armor = hp_stats.get_total_armor()
		elif "armor_adder" in hp_stats:
			armor = hp_stats.armor_adder
		text += "ARMOR: " + str(armor) + "\n\n"
		
	# --- STATYSTYKI BOJOWE ---
	if atk_stats:
		text += "DMG: " + str(atk_stats.get_total_damage()) + "\n"
		text += "CRIT RATE: %.1f%%\n" % (atk_stats.get_total_critical_rate() * 100.0)
		
		# Obliczanie Mocy Krytyka
		var crit_dmg = 0.0
		if atk_stats.has_method("get_total_critical_damage"):
			crit_dmg = atk_stats.get_total_critical_damage()
		elif atk_stats.get("actual_attack_data") != null:
			var base_cdmg = atk_stats.actual_attack_data.critical_damage
			var adder = atk_stats.get("critical_damage_adder", 0.0)
			var mult = atk_stats.get("critical_damage_multiplier", 1.0)
			crit_dmg = (base_cdmg + adder) * mult
		text += "CRIT DMG: +" + str(crit_dmg) + "\n"
		
		# Prędkość ataku (Cooldown)
		var cooldown = atk_stats.get_total_actual_cooldown() if atk_stats.has_method("get_total_actual_cooldown") else 0.0
		text += "ATK SPEED: %.2fs\n" % cooldown
		
		text += "RANGE: " + str(atk_stats.get_total_range()) + "\n"
		
		# Czas Ogłuszenia (Stun)
		var stun = 0.0
		if atk_stats.has_method("get_total_stun"):
			stun = atk_stats.get_total_stun()
		elif atk_stats.get("actual_attack_data") != null:
			var base_stun = atk_stats.actual_attack_data.stun_time
			var adder = atk_stats.get("stun_adder", 0.0)
			var mult = atk_stats.get("stun_multiplier", 1.0)
			stun = (base_stun + adder) * mult
			
		if stun > 0.0:
			text += "STUN TIME: %.2fs\n" % stun
			
		text += "\n"
			
	# --- RUCH ---
	if move_stats and "moveSpeed" in move_stats:
		text += "MOVE SPEED: " + str(move_stats.moveSpeed) + "\n"
		
	stats_text_label.text = text
