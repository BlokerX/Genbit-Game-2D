extends RigidBody2D
class_name ThrowablePhysics

@export_category("Ustawienia Obiektu")
@export var destroy_on_impact: bool = false 
@export var activation_delay: float = 0.0 ## Opóźnienie (w sekundach) przed faktycznym wyzwoleniem efektu wybuchu/aktywacji.
@export var activate_on_trigger: bool = true ## Czy uruchamia swoje główne działanie po trafieniu czystym TriggerEffect (np. śnieżką)?
@export var activate_on_damage: bool = false ## Czy uruchamia swoje główne działanie pod wpływem obrażeń (DamageEffect)?
@export var friendly_fire: bool = false 
@export var lifetime: float = 3.0 
@export var is_infinite: bool = false 
@export var arming_delay: float = 0.4 
@export var can_be_knocked_back: bool = true ## True: Fala wybuchu odpycha obiekt. False: Obiekt jest zakotwiczony (np. Mina).

@export_category("Obszar Działania (Opcjonalne)")
@export var aoe_area: Area2D

var shooter: Node2D = null
var current_velocity: Vector2 = Vector2.ZERO
var friction: float = 0.0
var effects_to_apply: Array[Effect] = []
var _time_alive: float = 0.0

func _ready() -> void:
	add_to_group("Hazard")
	gravity_scale = 0.0
	linear_damp = friction / 100.0
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_body_entered)

	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()
		apply_central_impulse(current_velocity)

	if shooter != null and shooter is CollisionObject2D:
		add_collision_exception_with(shooter)
		if arming_delay > 0.0:
			get_tree().create_timer(arming_delay).timeout.connect(func():
				if is_instance_valid(self) and is_instance_valid(shooter):
					remove_collision_exception_with(shooter)
			)

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if not is_infinite and _time_alive >= lifetime:
		trigger_effect(null)
		return

func _on_body_entered(body: Node) -> void:
	if not destroy_on_impact: 
		return
		
	var body_2d = body as Node2D
	if body_2d != null:
		trigger_effect(body_2d)

func trigger_effect(direct_hit: Node2D) -> void:
	if direct_hit == shooter:
		if not friendly_fire or _time_alive < 0.1:
			return

	# --- ZABEZPIECZENIE PRZED DUPLIKACJĄ ---
	if is_queued_for_deletion() or has_meta("is_triggered"):
		return
	set_meta("is_triggered", true)

	# --- ZMIANA GRAFIKI ---
	if "main_sprite" in self and "activated_texture" in self and get("main_sprite") != null and get("activated_texture") != null:
		get("main_sprite").texture = get("activated_texture")

	# --- 1. ODLICZANIE ZAPALNIKA (Oczekiwanie na wybuch) ---
	if activation_delay > 0.0 and direct_hit == null:
		await get_tree().create_timer(activation_delay).timeout
		
		if not is_inside_tree():
			return

	# --- 2. BUM! (Faktyczny wybuch i rozesłanie fali uderzeniowej) ---
	var targets: Array[Node2D] = []
	
	if aoe_area != null:
		targets.append_array(aoe_area.get_overlapping_bodies())
		for area in aoe_area.get_overlapping_areas():
			if not targets.has(area):
				targets.append(area)
	else:
		push_warning("BŁĄD: ThrowablePhysics wybuchła, ale nie ma przypisanego 'aoe_area' w Inspektorze!")
		
	if direct_hit != null and not targets.has(direct_hit):
		targets.append(direct_hit)
		
	for body in targets:
		# Zabezpieczamy się sprawdzając czy shooter nadal istnieje
		if is_instance_valid(shooter) and body == shooter and not friendly_fire:
			continue
			
		# Zabezpieczenie sojuszników przed friendly fire!
		if not friendly_fire and _is_ally(body):
			continue
			
		if body.has_method("receive_effect"):
			for effect in effects_to_apply:
				if "source_position" in effect:
					effect.source_position = self.global_position
					
				# --- KLUCZOWA POPRAWKA PROWOKACJI I BŁĘDU CRASHU ---
				if "source_entity" in effect:
					effect.source_entity = shooter if is_instance_valid(shooter) else null
					
				body.receive_effect(effect)

	# --- 3. USUNIĘCIE OBIEKTU PO WYBUCHU ---
	queue_free()

func receive_effect(effect: Effect) -> bool:
	if effect is TriggerEffect:
		if activate_on_trigger and not is_queued_for_deletion():
			trigger_effect(null) 
		return true 
		
	if effect is DamageEffect:
		if activate_on_damage and not is_queued_for_deletion():
			trigger_effect(null)
		return true 
		
	if effect is KnockbackEffect:
		if not can_be_knocked_back:
			return true 
		return effect.apply_effect(self)
		
	return effect.apply_effect(self)

## Sprawdza FactionComponent by zweryfikować czy cele są po tej samej stronie
func _is_ally(body: Node2D) -> bool:
	if not is_instance_valid(shooter) or not is_instance_valid(body): 
		return false
		
	# Pobierz frakcję strzelca
	var my_faction = shooter.get_node_or_null("FactionComponent")
	if not my_faction:
		return false
		
	# Sprawdź czy ofiara MA jakikolwiek FactionComponent (Duck Typing zamiast Class checking)
	if body.has_node("FactionComponent"):
		return my_faction.get_disposition_toward(body) == FactionComponent.Disposition.FRIENDLY
		
	return false
