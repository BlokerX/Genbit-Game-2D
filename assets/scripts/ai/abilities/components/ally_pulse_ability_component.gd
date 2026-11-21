extends AbilityComponent
class_name AllyPulseAbilityComponent
## Komponent zdolności AI nakładający wybraną listę efektów na pobliskich sojuszników (SOLID - SRP / OCP).
## Może zostać podpięty do dowolnego archetypu zdolności w pliku .tres (np. Promieniowanie Gamma, Fala Wsparcia).

## Moment cyklu życia zdolności, w którym sojusznicy otrzymują efekty.
enum TriggerPhase {
	ON_CAST_START,    ## Natychmiast w chwili rozpoczęcia ładowania zdolności.
	ON_AREA_DETONATED ## Dopiero w chwili detonacji/wybuchu głównego obszaru zdolności.
}

const DEFAULT_FALLBACK_RADIUS_PX: float = 250.0
const PULSE_VFX_DURATION_SEC: float = 0.42
const PULSE_VFX_FILL_ALPHA: float = 0.14

@export_group("Wsparcie Sojuszników")
## Określa, w którym momencie rzucania zdolności efekty zostaną nałożone na sojuszników.
@export var trigger_phase: TriggerPhase = TriggerPhase.ON_CAST_START
## Otwarta lista efektów nakładanych na sojuszników w zasięgu (np. RegenerationBuffEffect + StunEffect pacyfikujący).
@export var ally_effects: Array[Effect] = []
## Własny promień działania na sojuszników (w pikselach). Wartość 0.0 automatycznie pobiera promień samej zdolności.
@export_range(0.0, 2000.0, 10.0) var override_radius: float = 0.0
## Czy sam rzucający ma również otrzymać efekty z tablicy ally_effects?
@export var include_caster: bool = false

@export_group("Wizualizacja Impulsu i Diagnostyka")
## Czy wyświetlić falę uderzeniową w kolorze wsparcia, gdy co najmniej jeden sojusznik otrzymał efekt?
@export var spawn_pulse_vfx: bool = true
## Kolor fali wizualnej generowanej przy aktywacji efektów sojuszniczych.
@export var pulse_vfx_color: Color = Color(0.32, 0.98, 0.55, 0.85)
## Jeśli true, wypisuje w konsoli liczbę znalezionych i uleczonych/wzmocnionych sojuszników.
@export var debug_log: bool = false

func on_cast_started(ability: Resource, attacker: CharacterEntity, _target: Variant) -> void:
	if trigger_phase != TriggerPhase.ON_CAST_START:
		return
	var effective_radius: float = _resolve_radius(ability, DEFAULT_FALLBACK_RADIUS_PX)
	_apply_to_allies(attacker, attacker.global_position, effective_radius, true)

func on_area_detonated(ability: Resource, attacker: CharacterEntity, origin_pos: Vector2, radius: float) -> void:
	if trigger_phase != TriggerPhase.ON_AREA_DETONATED:
		return
	var effective_radius: float = _resolve_radius(ability, radius)
	var is_centered_on_caster: bool = is_instance_valid(attacker) and origin_pos.is_equal_approx(attacker.global_position)
	_apply_to_allies(attacker, origin_pos, effective_radius, is_centered_on_caster)

func _resolve_radius(ability: Resource, fallback_radius: float) -> float:
	if override_radius > 0.0:
		return override_radius
	if ability != null and "blast_radius" in ability:
		return float(ability.get("blast_radius"))
	if fallback_radius > 0.0:
		return fallback_radius
	if ability != null and "max_range" in ability:
		return float(ability.get("max_range"))
	return DEFAULT_FALLBACK_RADIUS_PX

func _apply_to_allies(
	attacker: CharacterEntity,
	origin_pos: Vector2,
	radius: float,
	use_caster_edge_distance: bool
) -> void:
	if ally_effects.is_empty() or not AIAbility.is_caster_active(attacker):
		if debug_log:
			print("[AllyPulse] Pominięto: pusta lista ally_effects lub nieaktywny rzucający.")
		return

	var affected_count: int = 0
	for char_node in attacker.get_tree().get_nodes_in_group("Character"):
		var ally: CharacterEntity = char_node as CharacterEntity
		if ally == null or ally.is_dead:
			continue
		if not AIAbility.can_affect_target(attacker, ally, true, false, include_caster):
			continue

		var edge_dist: float
		if use_caster_edge_distance:
			edge_dist = AIAbility.get_edge_distance(attacker, ally)
		else:
			var ally_rad: float = CharacterEntity.get_effective_radius_of(ally)
			edge_dist = maxf(0.0, origin_pos.distance_to(ally.global_position) - ally_rad)

		if edge_dist <= radius:
			if AIAbility.apply_effects_to_target(attacker, ally, ally_effects, origin_pos):
				affected_count += 1
				if debug_log:
					print("[AllyPulse] Nałożono %d efektów na sojusznika: %s (dystans: %.1f / %.1f)" % [ally_effects.size(), ally.name, edge_dist, radius])

	if debug_log and affected_count == 0:
		print("[AllyPulse] Nie znaleziono żadnych sojuszników w promieniu %.1f px wokół %s." % [radius, attacker.name])

	if affected_count > 0 and spawn_pulse_vfx:
		CombatVFXHelper.spawn_shockwave(
			attacker,
			origin_pos,
			radius,
			pulse_vfx_color,
			PULSE_VFX_DURATION_SEC,
			GameLayers.FX,
			PULSE_VFX_FILL_ALPHA
		)
