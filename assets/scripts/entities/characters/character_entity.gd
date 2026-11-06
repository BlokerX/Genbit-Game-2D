@abstract
extends CharacterBody2D
class_name CharacterEntity

const CharacterEffectsControllerType = preload(
	"res://assets/scripts/entities/characters/character_effects_controller.gd"
)

# --- STAŁE ANIMACJI KIERUNKOWYCH (Brak magicznych liczb) ---
const MIN_DIRECTIONAL_FRAMES_COUNT: int = 8
const DEFAULT_DEATH_FRAME_INDEX: int = 8
const STANDING_DEFAULT_FRAME_INDEX: int = 0

const FRAME_DOWN: int = 0
const FRAME_DOWN_RIGHT: int = 1
const FRAME_RIGHT: int = 2
const FRAME_UP_RIGHT: int = 3
const FRAME_UP: int = 4
const FRAME_UP_LEFT: int = 5
const FRAME_LEFT: int = 6
const FRAME_DOWN_LEFT: int = 7

const DEFAULT_OPAQUE_ALPHA: float = 1.0

#region Signals
## Sygnał służący do spawnowania obiektów (pociski, wyrzucone przedmioty) bez wiedzy o Map
@warning_ignore("unused_signal")
signal entity_spawn_requested(spawned_node: Node2D, global_spawn_position: Vector2)
#endregion

@export var faction_component: FactionComponent
# Zmienne respawnu:
@export var respawnVector := Vector2(512, 360)

# Komponent ruchu i statystyk:
@export var movement_universal_script : MovementComponent
@export var health_stats_script : MonitoredLifeStatsComponent 
@export var interaction_and_attack_stats_script : InteractionAndAttackStatsComponent

# KONFIGURACJA DROPU:
@export_category("System Łupu (Loot)")
@export var drop_from_loot_table: bool = true
## Po śmierci wyrzuca wszystkie przedmioty z ekwipunku i założonego sprzętu.
@export var drop_inventory_on_death: bool = true
@export var loot_drop_script : LootDropComponent

@export_category("Dane Fizyczne i Wizualne")
## Indywidualna grubość postaci do walki ---
@export var combat_radius: float = 40.0
@export var character_sprite : AnimatedSprite2D
@export var effects_collector : Node
@export var destroy_entity_after_die : bool = true
## Docelowy indeks klatki trupa dla postaci 8-kierunkowych (domyślnie 8, czyli 9. klatka).
@export var death_frame_index : int = DEFAULT_DEATH_FRAME_INDEX

# --- TARCZA RESPAWNU ---
var is_respawning: bool = false

# --- Zmienne do kontrolowania zamrożenia i skali bazowej ---
var active_tweens: Array[Tween] = []
var is_frozen: bool = false
var is_dead: bool = false
## Zapamiętana skala bazowa węzła z momentu startu sceny (chroni przed trwałym powiększeniem po skoku).
var base_scale: Vector2 = Vector2.ONE
var _effects_controller: CharacterEffectsControllerType

#region Główne funkcje silnikowe
func _ready():
	_effects_controller = CharacterEffectsControllerType.new()
	base_scale = scale
	set_meta("base_scale", base_scale)

	# Automatyczne ustawienie warstwy i sortowania
	z_index = GameLayers.ENTITIES
	add_to_group("Character") # Wymagane, by AI mogło skanować świat w poszukiwaniu celów

	# AUTO-RESOLVE: Jeśli zapomniałeś podpiąć frakcję w Inspektorze, gra i tak ją znajdzie
	if faction_component == null:
		faction_component = get_node_or_null("FactionComponent")

	# Podłączenie sygnału z komponentu statystyk do funkcji death_sequence
	if health_stats_script:
		if not health_stats_script.died.is_connected(_on_character_died):
			health_stats_script.died.connect(_on_character_died)

func _process(_delta):
	pass

func _physics_process(_delta):
	pass

## Zwraca główny węzeł graficzny postaci (wspólny punkt dla wszystkich efektów wizualnych - DRY).
func get_visual_sprite() -> CanvasItem:
	if character_sprite != null:
		return character_sprite
	if has_node("Sprite2D"):
		return get_node("Sprite2D") as CanvasItem
	if has_node("AnimatedSprite2D"):
		return get_node("AnimatedSprite2D") as CanvasItem
	return null

## Centralnie przelicza kolor i przezroczystość postaci na podstawie aktywnych efektów w effects_collector oraz metadanych.
## Eliminuje konflikty, gdy jednocześnie działają np. pasywne spodnie Ghost Mode oraz potka Immortality.
func refresh_visual_appearance() -> void:
	var sprite := get_visual_sprite()
	if sprite == null:
		return

	var base_color: Color = get_meta("pre_immortal_color") if has_meta("pre_immortal_color") else Color.WHITE
	var target_alpha: float = DEFAULT_OPAQUE_ALPHA

	var active_immortal := has_meta("is_immortal")
	var active_invisible := has_meta("is_invisible")
	var active_ghost := has_meta("is_ghost")

	# Skanujemy również bezpośrednio kontener aktywnych efektów (Single Source of Truth),
	# aby wygaśnięcie jednego efektu nigdy nie nadpisało trwającego efektu pasywnego!
	if is_instance_valid(effects_collector):
		for child in effects_collector.get_children():
			if child.is_queued_for_deletion():
				continue
			var res = child.get("effect_resource")
			if res is ImmortalityEffect and child.is_processing():
				active_immortal = true
				base_color = res.immortal_tint if "immortal_tint" in res else Color(1.5, 1.5, 0.5, 1.0)
			elif res is InvisibilityEffect and child.is_processing():
				active_invisible = true
				var inv_a: float = res.invisible_alpha if "invisible_alpha" in res else 0.15
				target_alpha = minf(target_alpha, inv_a)
			elif res is GhostEffect and child.is_processing():
				active_ghost = true
				var gh_a: float = res.ghost_alpha if "ghost_alpha" in res else 0.4
				target_alpha = minf(target_alpha, gh_a)

	if active_immortal and has_meta("immortal_tint_color"):
		base_color = get_meta("immortal_tint_color")
	if active_invisible and has_meta("invisible_alpha_value"):
		target_alpha = minf(target_alpha, float(get_meta("invisible_alpha_value")))
	if active_ghost and has_meta("ghost_alpha_value"):
		target_alpha = minf(target_alpha, float(get_meta("ghost_alpha_value")))

	base_color.a = target_alpha
	sprite.modulate = base_color

## Bezpiecznie ustawia klatkę animacji, sprawdzając czy mieści się w zakresie dostępnych klatek.
func _set_character_sprite_frame(frame_index: int) -> void:
	if character_sprite == null or character_sprite.sprite_frames == null:
		return

	var animation_name = character_sprite.animation
	if not character_sprite.sprite_frames.has_animation(animation_name):
		return

	var frame_count := character_sprite.sprite_frames.get_frame_count(animation_name)
	if frame_index < 0 or frame_index >= frame_count:
		return

	character_sprite.frame = frame_index

## Ustawia wygląd postaci w chwili śmierci (obsługuje zarówno 8-kierunkowe postacie z klatką 8, jak i rotacyjne np. pająka).
func _apply_death_visuals() -> void:
	if character_sprite == null or character_sprite.sprite_frames == null:
		return
	character_sprite.stop()
	var anim_name := character_sprite.animation
	if character_sprite.sprite_frames.has_animation(&"death"):
		character_sprite.play(&"death")
		return
	if character_sprite.sprite_frames.has_animation(anim_name):
		var frame_count := character_sprite.sprite_frames.get_frame_count(anim_name)
		if death_frame_index >= 0 and death_frame_index < frame_count:
			character_sprite.frame = death_frame_index
		elif frame_count > 0:
			character_sprite.frame = frame_count - 1

## Przywraca prawidłową skalę postaci (uwzględniając aktywne efekty zmiany rozmiaru, jeśli istnieją).
func reset_visual_scale() -> void:
	var target_scale := base_scale
	if has_meta("active_scale_modifiers"):
		var modifiers: Array = get_meta("active_scale_modifiers")
		var total_mult := 1.0
		for mod in modifiers:
			total_mult *= float(mod)
		target_scale = base_scale * total_mult
	scale = target_scale

## Przerywa bieżące tweeny ataku/skoku i bezpiecznie przywraca skalę postaci.
func cancel_current_attack() -> void:
	for t in active_tweens:
		if t and t.is_valid():
			t.kill()
	active_tweens.clear()
	reset_visual_scale()
#endregion

#region Obsługa sygnałów
# Funkcja wywoływana TYLKO gdy postać zginie
func _on_character_died():
	# --- TARCZA NIEŚMIERTELNOŚCI (Immortality) ---
	if has_meta("is_immortal") and get_meta("is_immortal") == true:
		print("Zadziałała NIEŚMIERTELNOŚĆ! Postać odmawia śmierci i zatrzymuje się na 1 HP.")
		is_dead = false
		if health_stats_script:
			# Parametr silent = true zapobiega zielonemu błyskowi ekranu podczas absorpcji śmiertelnego ciosu!
			health_stats_script.heal(LifeStatsComponent.IMMORTALITY_SURVIVAL_HP, true)
		return
	# ---------------------------------------------

	# Zabezpieczenie przed podwójnym wywołaniem śmierci w tej samej klatce
	if is_dead:
		return
	is_dead = true

	# Zmiana wizualna: "Kładziemy" postać na ziemi (bez błędów dla postaci o mniejszej liczbie klatek)
	_apply_death_visuals()

	print(self.name + " zginął! Przetwarzanie łupu...")

	# 1. Źródło: Tabela łupu (LootDropComponent)
	if drop_from_loot_table and loot_drop_script:
		loot_drop_script.perform_drop(self)

	# 2. Źródło: Aktualny Ekwipunek (Upuść wszystko, co trzymał/miał w plecaku)
	if drop_inventory_on_death and has_method("get_inventory"):
		var inv = call("get_inventory")
		if inv and inv.has_method("drop_all_items"):
			inv.drop_all_items(self)
		elif inv:
			push_warning("Ekwipunek postaci nie obsługuje wyrzucania przedmiotów po śmierci: " + name)

	if destroy_entity_after_die:
		self.queue_free()
		print(self.name + " usunięty ze sceny.")
	else:
		call_deferred("respawn_sequence")

# Sekwencja respawnu, uruchomi się, gdy wszystkie efekty (w tym zamrożenie) skończą się nakładać
func respawn_sequence():
	health_stats_script.heal_completely(true)
	position = respawnVector
	velocity.x = 0
	velocity.y = 0
	# przywrócenie domyślnej orientacji i skali
	reset_visual_scale()
	_set_character_sprite_frame(STANDING_DEFAULT_FRAME_INDEX)
	purge_absolutely_everything()

# --- FUNKCJA WYWOŁYWANA PRZEZ MAPĘ (Gdy ekran jest w 100% czarny) ---
func reset_state_for_respawn() -> void:
	health_stats_script.heal_completely(true)
	reset_visual_scale()

	if character_sprite:
		character_sprite.rotation_degrees = 0
		_set_character_sprite_frame(STANDING_DEFAULT_FRAME_INDEX)

	# --- WSKRZESZENIE ---
	is_dead = false
#endregion

#region Obsługa systemu akcji (Effect)
## Standardowa funkcja dla mikstur, pułapek i ataków (Zwykłe efekty, można wyleczyć)
func receive_effect(effect: Effect) -> bool:
	return _effects_controller.receive_effect(self, effect, is_dead, is_respawning)

func _apply_effect(effect: Effect) -> bool:
	return _effects_controller.apply_effect(self, effect)

## Funkcja nakładająca aurę środowiskową (Niewrażliwa na mikstury oczyszczające!)
func receive_environment_effect(effect: Effect) -> bool:
	return _effects_controller.receive_environment_effect(
		self, effects_collector, effect, is_dead, is_respawning
	)

## Wejściowe efekty mapy muszą zostać zastosowane także podczas animowanego respawnu.
func receive_map_entry_effect(effect: Effect, is_environment_aura: bool) -> bool:
	return _effects_controller.receive_map_entry_effect(
		self, effects_collector, effect, is_dead, is_environment_aura
	)

func _apply_environment_effect(effect: Effect) -> bool:
	return _effects_controller.apply_environment_effect(self, effects_collector, effect)

## Funkcja zdejmująca efekty (używana przez mikstury). Ignoruje Aury Pokoju!
func clear_all_effects() -> void:
	_effects_controller.clear_all_effects(effects_collector)

## Wymuszone czyszczenie aur przy skakaniu między całymi poziomami
func clear_all_environment_effects() -> void:
	_effects_controller.clear_all_environment_effects(effects_collector)

## Funkcja do twardego usuwania po nazwie (Zdejmuje Aury, gdy gracz wychodzi z pokoju)
func remove_effect_by_name(eff_name: String) -> void:
	_effects_controller.remove_effect_by_name(effects_collector, eff_name)

## Całkowite czyszczenie absolutnie wszystkiego [Effects] (Używane przy śmierci/respawnie)
func purge_absolutely_everything() -> void:
	_effects_controller.purge_absolutely_everything(effects_collector)
#endregion

#region Silnik animacji
## Zmienia klatkę animacji w zależności od 8-kierunkowego wektora ruchu
func _update_sprite_direction(move_dir: Vector2) -> void:
	if not character_sprite or character_sprite.sprite_frames == null:
		return

	if move_dir == Vector2.ZERO:
		return

	var anim_name := character_sprite.animation
	if not character_sprite.sprite_frames.has_animation(anim_name):
		return
	if character_sprite.sprite_frames.get_frame_count(anim_name) < MIN_DIRECTIONAL_FRAMES_COUNT:
		return

	var snapped_dir = move_dir.normalized().round()

	match snapped_dir:
		Vector2(0, 1):   # Dół
			character_sprite.frame = FRAME_DOWN
		Vector2(1, 1):   # Dół-Prawo
			character_sprite.frame = FRAME_DOWN_RIGHT
		Vector2(1, 0):   # Prawo
			character_sprite.frame = FRAME_RIGHT
		Vector2(1, -1):  # Góra-Prawo
			character_sprite.frame = FRAME_UP_RIGHT
		Vector2(0, -1):  # Góra
			character_sprite.frame = FRAME_UP
		Vector2(-1, -1): # Góra-Lewo
			character_sprite.frame = FRAME_UP_LEFT
		Vector2(-1, 0):  # Lewo
			character_sprite.frame = FRAME_LEFT
		Vector2(-1, 1):  # Dół-Lewo
			character_sprite.frame = FRAME_DOWN_LEFT

func create_tracked_tween() -> Tween:
	var tween = create_tween()
	active_tweens.append(tween)

	tween.finished.connect(func(): active_tweens.erase(tween))

	if is_frozen:
		tween.pause()

	return tween
#endregion
