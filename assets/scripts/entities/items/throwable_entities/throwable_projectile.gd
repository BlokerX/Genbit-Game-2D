extends Area2D
class_name ThrowableProjectile

@export_category("Ustawienia Obiektu")
@export var destroy_on_impact: bool = true
@export var activation_delay: float = 0.0 ## Opóźnienie (w sekundach) przed faktycznym wyzwoleniem efektu wybuchu/aktywacji.
@export var activate_on_trigger: bool = true ## Czy uruchamia swoje główne działanie po trafieniu czystym TriggerEffect (np. śnieżką)?
@export var activate_on_damage: bool = false ## Czy uruchamia swoje główne działanie pod wpływem obrażeń (DamageEffect)?
@export var friendly_fire: bool = false 
@export var lifetime: float = 3.0 
@export var is_infinite: bool = false
@export var can_be_knocked_back: bool = true ## True: Fala wybuchu odpycha obiekt. False: Obiekt jest zakotwiczony (np. Mina).

@export_category("Obszar Działania (Opcjonalne)")
@export var aoe_area: Area2D

var shooter: Node2D = null
var current_velocity: Vector2 = Vector2.ZERO
var friction: float = 0.0
var effects_to_apply: Array[Effect] = []
var _time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if not is_infinite and _time_alive >= lifetime:
		trigger_effect(null) 
		return

	if current_velocity.length() > 0:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
		
	var move_vector = current_velocity * delta

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + move_vector)
	query.collision_mask = collision_mask 
	if shooter != null and shooter is CollisionObject2D:
		query.exclude = [shooter.get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		global_position = result.position
		current_velocity = Vector2.ZERO
		if destroy_on_impact:
			trigger_effect(result.collider as Node2D)
	else:
		global_position += move_vector

func _on_body_entered(body: Node2D) -> void:
	if not destroy_on_impact: 
		return
		
	trigger_effect(body)

func trigger_effect(direct_hit: Node2D) -> void:
	if direct_hit == shooter:
		if not friendly_fire or _time_alive < 0.1:
			return

	# --- ZABEZPIECZENIE PRZED DUPLIKACJĄ ---
	if is_queued_for_deletion() or has_meta("is_triggered"):
		return
	set_meta("is_triggered", true)

	# TODO zapalnik animacja tu

	# --- 1. ODLICZANIE ZAPALNIKA (Oczekiwanie na wybuch) ---
	# Odliczamy czas opóźnienia ZANIM obiekt roześle efekty do otoczenia.
	# Nie chowamy grafiki, mina po prostu fizycznie czeka na detonację.
	if activation_delay > 0.0 and direct_hit == null:
		await get_tree().create_timer(activation_delay).timeout
		
		# Upewniamy się, że obiekt nie zniknął podczas odliczania
		if not is_inside_tree():
			return

	# TODO wybuch animacja tu

	# --- 2. BUM! (Faktyczny wybuch i rozesłanie fali uderzeniowej) ---
	var targets: Array[Node2D] = []
	
	if aoe_area != null:
		targets.append_array(aoe_area.get_overlapping_bodies())
		for area in aoe_area.get_overlapping_areas():
			if not targets.has(area):
				targets.append(area)
	elif self is Area2D and not destroy_on_impact:
		targets.append_array(get_overlapping_bodies())
		for area in get_overlapping_areas():
			if not targets.has(area):
				targets.append(area)
		
	if direct_hit != null and not targets.has(direct_hit):
		targets.append(direct_hit)
		
	for body in targets:
		if body == shooter and not friendly_fire:
			continue
			
		if body.has_method("receive_effect"):
			for effect in effects_to_apply:
				# UNIWERSALNE WSTRZYKIWANIE (Obejmuje odrzut, przyciąganie itp.)
				if "source_position" in effect:
					effect.source_position = self.global_position
					
				body.receive_effect(effect)

	# --- 3. USUNIĘCIE OBIEKTU PO WYBUCHU ---
	queue_free()

## Odbieranie efektów (zarządzanie tym, co aktywuje ten obiekt)
func receive_effect(effect: Effect) -> bool:
	
	# 1. Reakcja na czysty sygnał aktywacji (TriggerEffect)
	if effect is TriggerEffect:
		if activate_on_trigger and not is_queued_for_deletion():
			trigger_effect(null) # Uruchamiamy główną funkcję (cokolwiek ten obiekt robi)
		return true # Obiekt poprawnie przyjął sygnał
		
	# 2. Reakcja na obrażenia (DamageEffect)
	if effect is DamageEffect:
		if activate_on_damage and not is_queued_for_deletion():
			trigger_effect(null)
		return true # Obiekt przyjął obrażenia (np. pancerna skrzynka, która nie pęka)
	
	# 3. Reakcja na odrzut (KnockbackEffect)
	if effect is KnockbackEffect:
		if not can_be_knocked_back:
			return true # Obiekt pochłania efekt (nie wyskakuje błąd), ale ignoruje ruch.
		return effect.apply_effect(self)
	
	# 3. Reszta efektów (np. fizyczny KnockbackEffect, zamrożenie, spowolnienie) 
	# działa normalnie, modyfikując stan obiektu (lot/przesunięcie).
	return effect.apply_effect(self)
