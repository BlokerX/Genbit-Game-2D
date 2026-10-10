@abstract
extends CharacterBody2D

class_name CharacterEntity

const CharacterEffectsControllerType = preload(
	"res://assets/scripts/entities/characters/character_effects_controller.gd"
)

#region Signals

## Sygnał służący do spawnowania obiektów (pociski, wyrzucone przedmioty) bez wiedzy o Map
@warning_ignore("unused_signal")
signal entity_spawn_requested(spawned_node: Node2D, global_spawn_position: Vector2)

# ## Sygnał wykonywany po skończonej inicjalizacji entity
#signal setup_complete

#endregion

@export var faction_component: FactionComponent

# Zmienne respawnu:
@export var respawnVector := Vector2(512, 360)

# Komponent ruchu i statystyk:
@export var movement_universal_script : MovementComponent
@export var health_stats_script : MonitoredLifeStatsComponent 
@export var interaction_and_attack_stats_script : InteractionAndAttackStatsComponent


# KONFIGURACJA ŹRÓDEŁ DROPu:
@export_category("System Łupu (Loot)")
@export var drop_from_loot_table: bool = true
## Po śmierci wyrzuca wszystkie przedmioty z ekwipunku i założonego sprzętu.
@export var drop_inventory_on_death: bool = true
@export var loot_drop_script : LootDropComponent

@export_category("Dane Fizyczne")
## Indywidualna grubość postaci do walki ---
@export var combat_radius: float = 40.0
@export var character_sprite : AnimatedSprite2D
@export var effects_collector : Node
@export var destroy_entity_after_die : bool = true

# --- TARCZA RESPAWNU ---
var is_respawning: bool = false

# --- Zmienne do kontrolowania zamrożenia ---
var active_tweens: Array[Tween] = []
var is_frozen: bool = false
var is_dead: bool = false
var _effects_controller: CharacterEffectsControllerType

#region Główne funkcje silnikowe

func _ready():
	_effects_controller = CharacterEffectsControllerType.new()
	# Automatyczne ustawienie warstwy i sortowania[cite: 3]
	z_index = GameLayers.ENTITIES
	
	add_to_group("Character") # Wymagane, by AI mogło skanować świat w poszukiwaniu celów
	
	# AUTO-RESOLVE: Jeśli zapomniałeś podpiąć frakcję w Inspektorze, gra i tak ją znajdzie
	if faction_component == null:
		faction_component = get_node_or_null("FactionComponent")
	
	# Podłączenie sygnału z komponentu statystyk do funkcji death_sequence
	if health_stats_script:
		health_stats_script.died.connect(_on_character_died)

func _process(_delta):
	pass

func _physics_process(_delta):
	pass

func _set_character_sprite_frame(frame_index: int) -> void:
	if character_sprite == null or character_sprite.sprite_frames == null:
		push_warning("CharacterEntity: Brak grafiki animowanej dla postaci " + name)
		return

	var animation_name = character_sprite.animation
	if not character_sprite.sprite_frames.has_animation(animation_name):
		push_warning("CharacterEntity: Brak animacji '" + str(animation_name) + "' dla postaci " + name)
		return

	if frame_index < 0 or frame_index >= character_sprite.sprite_frames.get_frame_count(animation_name):
		push_warning("CharacterEntity: Klatka " + str(frame_index) + " nie istnieje w animacji '" + str(animation_name) + "' postaci " + name)
		return

	character_sprite.frame = frame_index

#endregion

#region Obsługa sygnałów

# Funkcja wywoływana TYLKO gdy postać zginie
func _on_character_died():
	# --- TARCZA NIEŚMIERTELNOŚCI (Immortality) ---
	if has_meta("is_immortal") and get_meta("is_immortal") == true:
		print("Zadziałała NIEŚMIERTELNOŚĆ! Postać odmawia śmierci i leczy się o 1 HP.")
		is_dead = false
		if health_stats_script:
			health_stats_script.heal(1) # Zostawiamy postać na 1 HP, ratując ją przed zgonem
		return
	# ---------------------------------------------
	
	# Zabezpieczenie przed podwójnym wywołaniem śmierci w tej samej klatce
	if is_dead:
		return
	is_dead = true
	
	# Zmiana wizualna: "Kładziemy" postać na ziemi
	_set_character_sprite_frame(8)
	
	print(self.name + " zginął! Przetwarzanie łupu...")
	
	# 1. Źródło: Tabela Łupu (LootDropComponent)
	if drop_from_loot_table and loot_drop_script:
		loot_drop_script.perform_drop(self)
		
	# 2. Źródło: Aktualny Ekwipunek (Upuść wszystko, co trzymał/miał w plecaku)
	if drop_inventory_on_death and has_method("get_inventory"):
		# ZMIANA: call("nazwa_metody") omija sprawdzanie statyczne!
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
	

# Sekwencja respawnu, Uruchomi się, gdy wszystkie efekty (w tym zamrożenie) skończą się nakładać
func respawn_sequence():
	health_stats_script.heal_completely()
	
	position = respawnVector
	velocity.x = 0
	velocity.y = 0
	
	# przywrócenie domyślnej orientacji
	_set_character_sprite_frame(0)
	
	purge_absolutely_everything()

# --- FUNKCJA WYWOŁYWANA PRZEZ MAPĘ (Gdy ekran jest w 100% czarny) ---
func reset_state_for_respawn() -> void:
	# Mapa w ogóle nie wie, co tu się dzieje. Wie tylko, że ma to wywołać, gdy jest ciemno.
	health_stats_script.heal_completely()
	
	# Przywracamy postać do pionu i resetujemy animację z "leżącej" na "stojącą"
	if character_sprite:
		character_sprite.rotation_degrees = 0
	_set_character_sprite_frame(0)
	
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
		self,
		effects_collector,
		effect,
		is_dead,
		is_respawning
	)

## Wejściowe efekty mapy muszą zostać zastosowane także podczas animowanego respawnu.
func receive_map_entry_effect(effect: Effect, is_environment_aura: bool) -> bool:
	return _effects_controller.receive_map_entry_effect(
		self,
		effects_collector,
		effect,
		is_dead,
		is_environment_aura
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
	# Zabezpieczenie przed brakiem przypisanego sprite'a
	if not character_sprite:
		return

	# Jeśli entity stoi, zostawiamy go w ostatniej pozycji (nie zmieniamy klatki)
	if move_dir == Vector2.ZERO:
		return

	# Normalizujemy wektor i zaokrąglamy go (round). 
	# Dzięki temu z ułamków zrobimy idealne wektory kierunkowe (np. Vector2(1, 1), Vector2(0, -1))
	var snapped_dir = move_dir.normalized().round()

	# Dopasowujemy zaokrąglony wektor do 8 klatek (ruch przeciwny do wskazówek zegara)
	match snapped_dir:
		Vector2(0, 1):   # Dół
			character_sprite.frame = 0
		Vector2(1, 1):   # Dół-Prawo
			character_sprite.frame = 1
		Vector2(1, 0):   # Prawo
			character_sprite.frame = 2
		Vector2(1, -1):  # Góra-Prawo
			character_sprite.frame = 3
		Vector2(0, -1):  # Góra
			character_sprite.frame = 4
		Vector2(-1, -1): # Góra-Lewo
			character_sprite.frame = 5
		Vector2(-1, 0):  # Lewo
			character_sprite.frame = 6
		Vector2(-1, 1):  # Dół-Lewo
			character_sprite.frame = 7

# Zamiast nadpisywać, tworzymy WŁASNĄ funkcję śledzącą Tweeny!
func create_tracked_tween() -> Tween:
	var tween = create_tween() # Wywołujemy natywną funkcję Godota w tle
	active_tweens.append(tween)
	
	# Gdy Tween (atak) się skończy, usuwamy go z listy
	tween.finished.connect(func(): active_tweens.erase(tween))
	
	# Jeśli potwór JEST zamrożony w momencie odpalenia skoku/ataku, atak od razu się pauzuje!
	if is_frozen:
		tween.pause()
		
	return tween

#endregion
