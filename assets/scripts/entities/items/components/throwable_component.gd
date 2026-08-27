class_name ThrowableComponent extends ItemComponent

@export_category("Ustawienia Rzutu")
## Scena fizycznego obiektu, który ma się pojawić (np. live_bomb.tscn, mine.tscn, shuriken.tscn)
@export var entity_scene: PackedScene
## Prędkość/Siła rzutu. Ustaw 0 dla min i pułapek, >0 dla noży i bomb.
@export var throw_force: float = 400.0
## Jak szybko obiekt zwalnia (tarcie). Ustaw 0 dla shurikenów (lecą prosto), >0 dla toczących się bomb.
@export var friction: float = 150.0 
@export var use_cooldown: float = 0.5
## Efekty, które rzucany obiekt zaaplikuje przy trafieniu/wybuchu (np. DamageEffect, StunEffect)
@export var effects: Array[Effect] = []

func execute(actor: Node2D, _target: Node2D, item_instance: ItemInstance) -> void:
	if entity_scene == null:
		push_error("ThrowableComponent: Brak przypisanej sceny!")
		return

	# Odpalamy cooldown dla gracza
	var stats = actor.get("interaction_and_attack_stats_script")
	if stats:
		stats.change_item_cooldown(use_cooldown)
		stats.reset_cooldown()

	# 1. Określanie kierunku i pozycji startowej
	var spawn_pos = actor.global_position
	var throw_dir = Vector2.DOWN
	
	# Jeśli rzucamy (siła > 0), wyliczamy kierunek na podstawie skanera/myszki
	if throw_force > 0.0 and actor.has_node("AimController"):
		var aim_ctrl = actor.get_node("AimController")
		var target_pos = aim_ctrl.aim_scanner.global_position
		
		if actor.get("is_using_mouse"):
			target_pos = actor.get_global_mouse_position()
			
		throw_dir = actor.global_position.direction_to(target_pos).normalized()
		# Lekki offset, żeby obiekt nie pojawiał się wewnątrz gracza
		spawn_pos += throw_dir * 35.0 

	# 2. Tworzenie fizycznego bytu
	var entity = entity_scene.instantiate()
	
	# Wstrzykujemy parametry do fizycznego obiektu
	if "shooter" in entity:
		entity.shooter = actor
	if "current_velocity" in entity:
		entity.current_velocity = throw_dir * throw_force
	if "friction" in entity:
		entity.friction = friction
	if "effects_to_apply" in entity:
		# Duplikujemy efekty, żeby nie nadpisać oryginalnego zasobu!
		var cloned_effects: Array[Effect] = []
		for eff in effects:
			if eff != null:
				cloned_effects.append(eff.duplicate(true))
		entity.effects_to_apply = cloned_effects

	# 3. Zgłoszenie prośby o spawn (korzystamy z Twojego sygnału w graczu!)
	if actor.has_signal("entity_spawn_requested"):
		actor.emit_signal("entity_spawn_requested", entity, spawn_pos)

	# 4. Zużycie 1 sztuki przedmiotu i posprzątanie ekwipunku
	item_instance.consume_amount(1)
	if actor.has_method("get_inventory"):
		var inv = actor.get_inventory()
		inv.clean_dead_items()
		inv.inventory_updated.emit()
