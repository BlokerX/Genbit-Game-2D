extends RigidBody2D
class_name ThrowablePhysics

const DAMP_DIVISOR: float = 100.0
const SELF_HIT_GRACE_TIME_SEC: float = 0.1
const MAX_REPORTED_CONTACTS: int = 5

@export_category("Ustawienia Obiektu")
@export var destroy_on_impact: bool = false 
@export var activation_delay: float = 0.0 ## Opóźnienie (w sekundach) przed faktycznym wyzwoleniem efektu wybuchu/aktywacji.
@export var activate_on_trigger: bool = true ## Czy uruchamia swoje główne działanie po trafieniu czystym TriggerEffect?
@export var activate_on_damage: bool = false ## Czy uruchamia swoje główne działanie pod wpływem obrażeń (DamageEffect)?
@export var friendly_fire: bool = false 
@export var lifetime: float = 3.0 
@export var is_infinite: bool = false 
@export var arming_delay: float = 0.4 
@export var can_be_knocked_back: bool = true ## True: Fala wybuchu odpycha obiekt. False: Obiekt jest zakotwiczony (np. Mina).

@export_category("Obszar Działania (Opcjonalne)")
@export var aoe_area: Area2D

var shooter: Node2D = null
var _shooter_faction_name: StringName = &""

var current_velocity: Vector2 = Vector2.ZERO
var friction: float = 0.0
var effects_to_apply: Array[Effect] = []

var _time_alive: float = 0.0
var _is_fuse_lit: bool = false
var _fuse_timer: float = 0.0
var _direct_hit_ref: Node2D = null

func _ready() -> void:
	add_to_group("Hazard")
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	gravity_scale = 0.0
	linear_damp = friction / DAMP_DIVISOR
	contact_monitor = true
	max_contacts_reported = MAX_REPORTED_CONTACTS
	body_entered.connect(_on_body_entered)

	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()
		apply_central_impulse(current_velocity)

	if is_instance_valid(shooter):
		var my_faction = shooter.get_node_or_null("FactionComponent")
		if my_faction:
			_shooter_faction_name = my_faction.faction_name

	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		add_collision_exception_with(shooter)
		# NAPRAWA: Przywracamy kolizję ze strzelcem po arming_delay TYLKO wtedy, gdy friendly_fire == true!
		# Dzięki temu strzelec nie potyka się fizycznie o własne miny/granaty, gdy friendly_fire jest wyłączone.
		if friendly_fire and arming_delay > 0.0:
			get_tree().create_timer(arming_delay).timeout.connect(func():
				if not is_inside_tree():
					return
				if is_instance_valid(self) and is_instance_valid(shooter):
					remove_collision_exception_with(shooter)
			)

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if not is_infinite and _time_alive >= lifetime:
		trigger_effect(null)
		return

	if _is_fuse_lit:
		_fuse_timer += delta
		if _fuse_timer >= activation_delay:
			_is_fuse_lit = false
			_execute_explosion(_direct_hit_ref)

func _on_body_entered(body: Node) -> void:
	if not destroy_on_impact: 
		return
	var body_2d = body as Node2D
	if body_2d != null:
		trigger_effect(body_2d)

func trigger_effect(direct_hit: Node2D) -> void:
	if is_instance_valid(shooter) and direct_hit == shooter:
		if not friendly_fire or _time_alive < SELF_HIT_GRACE_TIME_SEC:
			return

	if is_queued_for_deletion() or has_meta("is_triggered"):
		return
	set_meta("is_triggered", true)

	if "main_sprite" in self and "activated_texture" in self and get("main_sprite") != null and get("activated_texture") != null:
		get("main_sprite").texture = get("activated_texture")

	if activation_delay > 0.0 and direct_hit == null:
		_is_fuse_lit = true
		_fuse_timer = 0.0
		_direct_hit_ref = direct_hit
	else:
		_execute_explosion(direct_hit)

func _execute_explosion(direct_hit: Node2D) -> void:
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
		if is_instance_valid(shooter) and body == shooter and not friendly_fire:
			continue
		if not friendly_fire and _is_ally(body):
			continue

		if body.has_method("receive_effect"):
			for effect in effects_to_apply:
				var cloned_eff: Effect = effect.duplicate(true)
				cloned_eff.source_position = self.global_position
				cloned_eff.source_entity = shooter if is_instance_valid(shooter) else null
				body.receive_effect(cloned_eff)

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
	if not is_instance_valid(body):
		return false
	if is_instance_valid(shooter) and body == shooter:
		return true
	if not body.has_node("FactionComponent"): 
		return false

	var target_faction = body.get_node("FactionComponent")

	if is_instance_valid(shooter):
		var my_faction = shooter.get_node_or_null("FactionComponent")
		if my_faction:
			return my_faction.get_disposition_toward(body) == FactionComponent.Disposition.FRIENDLY

	elif _shooter_faction_name != &"":
		if target_faction.faction_name == _shooter_faction_name and target_faction.friendly_to_same_faction:
			return true
		if target_faction.faction_relations.has(_shooter_faction_name):
			if target_faction.faction_relations[_shooter_faction_name] == FactionComponent.Disposition.FRIENDLY:
				return true

	return false
