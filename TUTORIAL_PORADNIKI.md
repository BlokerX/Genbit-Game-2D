# 📚 PORADNIKI DEWELOPERSKIE - GENBIT-GAME-2D

Kompletne instrukcje krok po kroku do tworzenia wszystkich elementów gry.

---

## 📌 SPIS TREŚCI

1. [🎮 Jak utworzyć NOWY ITEM (Przedmiot)](#jak-utworzyć-nowy-item)
2. [👾 Jak utworzyć NOWEGO WROGA](#jak-utworzyć-nowego-wroga)
3. [✨ Jak utworzyć NOWY EFEKT](#jak-utworzyć-nowy-efekt)
4. [🗺️ Jak tworzyć MAPY I POKOJE](#jak-tworzyć-mapy-i-pokoje)
5. [🎨 Jak dodać TEKSTURY I GRAFIKI](#jak-dodać-tekstury-i-grafiki)
6. [🔧 Jak MODYFIKOWAĆ KOMPONENTY](#jak-modyfikować-komponenty)
7. [🎵 Jak dodać DŹWIĘKI I MUZYKĘ](#jak-dodać-dźwięki-i-muzykę)
8. [🔗 Jak używać EVENT BUS'a](#jak-używać-event-busa)

---

## 🎮 JAK UTWORZYĆ NOWY ITEM

### Krok 1: Tworzenie zasobu ItemData (.tres)

1. **Otwórz folder** `assets/data/items/`
2. **Kliknij prawym przyciskiem** → **Nowy Zasób (New Resource)**
3. **Szukaj** `ItemData` i wybierz
4. **Zapisz jako**: `my_new_item.tres`

### Krok 2: Konfiguruj właściwości w Inspektorze

W zakładce Inspector dla `my_new_item.tres` ustaw:

```
Informacje Ogólne:
├─ Item ID:        "my_sword"           # Unikalne ID przedmiotu
├─ Item Name:      "Mój Miecz"          # Nazwa wyświetlana
├─ Item Description: "Miecz o dużej mocy" # Opis
└─ Item Icon:      [Załaduj teksturę]   # Ikonka w ekwipunku

System Tagów:
└─ Tags: 
   ├─ "weapon_sword"   # Tag typu broni
   ├─ "melee"          # Tag kategorii
   └─ "enchanted"      # Dodatkowe tagi
```

### Krok 3: Dodaj Komponenty do przedmiotu

Komponenty definiują zachowanie przedmiotu. Kliknij w `Komponenty Zachowań` → **Dodaj element (+)**

#### Opcja A: Broń Melee (Miecz, Topór, itp.)

```gdscript
Dodaj: MeleeWeaponComponent
├─ Damage:           20.0        # Obrażenia
├─ Attack Speed:     1.5         # Szybkość ataku
├─ Range:            40.0        # Zasięg
└─ Knockback Force:  10.0        # Siła wyrzucenia
```

Plik: `assets/scripts/entities/items/components/melee_weapon_component.gd`

#### Opcja B: Broń Ranged (Pistolet, Strzelba)

```gdscript
Dodaj: RangedWeaponComponent
├─ Damage:           15.0        # Obrażenia
├─ Fire Rate:        1.2         # Szybkostrzelność
├─ Projectile Speed: 400.0       # Prędkość pocisku
├─ Ammo Type:        "gun_ammo"  # Typ amunicji
└─ Magazine Size:    30          # Pojemność magazynka
```

#### Opcja C: Pocisk konsumowany (Potion, Cookie)

```gdscript
Dodaj: ConsumableComponent
├─ Effect:           [Załaduj efekt] # Efekt przy użyciu
├─ Amount Consumed:  1               # Ile się zużywa
└─ Can Use Infinite: false           # Czy można używać bez limitu
```

#### Opcja D: Kontener (Backpack)

```gdscript
Dodaj: BackpackComponent
├─ Storage Capacity: 10          # Pojemność slotów
└─ Weight Modifier:  1.2         # Modyfikator wagi
```

#### Opcja E: Uzbrojenie (Ekwipunek)

```gdscript
Dodaj: EquippableComponent
├─ Slot Type:        "hand"      # Slot: hand, head, chest, etc.
├─ Stats Boost:      
│  ├─ Damage:        +5.0
│  ├─ Defense:       +2.0
│  └─ Speed:         -1.0        # Ujemna wartość = spowolnienie
└─ Visual Effect:    [Effect]    # Efekt wizualny
```

### Krok 4: Dodaj przedmiot do bazy danych (ItemDatabase)

1. Otwórz `assets/scripts/autoload/item_database.gd`
2. Znajdź funkcję `_init()` lub `_ready()`
3. Dodaj linię:
```gdscript
items["my_sword"] = preload("res://assets/data/items/my_new_item.tres")
```

### Krok 5: Testuj!

1. Utwórz skrzynię w scenie
2. Dodaj do niej item ID "my_sword"
3. Uruchom grę (F5)
4. Otwórz ekwipunek i sprawdź przedmiot

---

## 👾 JAK UTWORZYĆ NOWEGO WROGA

### Krok 1: Utwórz scenę (.tscn)

1. **Nowa scena** → **Podstawowy węzeł 2D (CharacterBody2D)**
2. **Zapisz jako**: `assets/scenes/enemies/my_enemy.tscn`
3. **Zmień nazwę roota** na `MyEnemy`

### Krok 2: Strukturuj scenę

Dodaj jako dzieci roota:

```
MyEnemy (CharacterBody2D)
├─ Sprite2D                    # Grafika wroga
├─ CollisionShape2D            # Kolizja
├─ AnimationPlayer             # Animacje (opcjonalnie)
├─ NavigationAgent2D           # Nawigacja (pathing)
├─ LineOfSight (RayCast2D)     # Widzenie (linia wzroku)
├─ HealthBar (Control)         # UI zdrowia
└─ AttackCooldownTimer         # Timer cooldownu
```

### Krok 3: Skonfiguruj węzły

**Sprite2D:**
- Texture: Załaduj grafikę wroga
- Offset: Wyśrodkuj grafikę

**CollisionShape2D:**
- Shape: CapsuleShape2D
- Radius: 15-25 (w zależności od rozmiaru)
- Height: 30-40

**NavigationAgent2D:**
- Target Position: (0, 0)
- Max Speed: 150

### Krok 4: Utwórz skrypt wroga

Utwórz plik: `assets/scripts/entities/characters/enemies/my_enemy.gd`

```gdscript
extends CharacterEntity
class_name MyEnemy

# Region parametrów
@export var rotationSpeed: float = 5.0
@export var detectionDistance: float = 600.0
@export var attack_reach: float = 110.0
@export var push_force: float = 5.0

# Węzły
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var los_ray: RayCast2D = $LineOfSight

# Stan
var target: Node2D
var lastKnownPos: Vector2 = Vector2.ZERO
var hasLastKnownPos: bool = false

enum State { IDLE, CHASING, SEARCHING }
var state: State = State.IDLE

func _ready():
	# Ustaw statystyki wroga
	health_stats_script.health = 30
	health_stats_script.max_health = 30
	
	interaction_and_attack_stats_script.hand_damage = 8
	interaction_and_attack_stats_script.hand_cooldown = 1.5
	
	respawnVector = Vector2(1080, 720)
	
	# Wywołaj inicjalizację z klasy bazowej
	super()
	
	# Znów gracza
	target = get_tree().get_first_node_in_group("Player")

func set_movement_target(movement_target: Vector2):
	if navigation_agent:
		navigation_agent.target_position = movement_target

func has_line_of_sight() -> bool:
	if not target:
		return false
	los_ray.target_position = to_local(target.global_position)
	los_ray.force_raycast_update()
	if los_ray.is_colliding():
		return los_ray.get_collider() == target
	return false

func actor_setup():
	await get_tree().physics_frame
	set_movement_target(target.position)

func _process(_delta):
	super(_delta)

func _physics_process(delta):
	super(delta)
	
	interaction_and_attack_stats_script.interaction_cooldown_process(delta)
	
	# Logika państw
	var in_range = target and global_position.distance_to(target.global_position) <= detectionDistance
	var can_see = in_range and has_line_of_sight()
	
	match state:
		State.IDLE:
			if can_see:
				state = State.CHASING
		
		State.CHASING:
			if can_see:
				lastKnownPos = target.global_position
				hasLastKnownPos = true
				set_movement_target(lastKnownPos)
			else:
				if hasLastKnownPos:
					set_movement_target(lastKnownPos)
					state = State.SEARCHING
				else:
					state = State.IDLE
		
		State.SEARCHING:
			if can_see:
				state = State.CHASING
			elif navigation_agent.is_navigation_finished():
				hasLastKnownPos = false
				state = State.IDLE
	
	# Ruch i obrót
	var should_move = (state == State.CHASING or state == State.SEARCHING) and not navigation_agent.is_navigation_finished()
	
	if state == State.CHASING and can_see:
		var target_angle = global_position.angle_to_point(target.global_position)
		rotation = lerp_angle(rotation, target_angle, rotationSpeed * delta)
	
	if should_move:
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		velocity = movement_universal_script.movement_procedure(delta, velocity, direction)
		move_and_slide()
	
	# Atak
	if get_edge_distance_to_target() <= attack_reach:
		if interaction_and_attack_stats_script.can_attack():
			print(name + " atakuje gracza!")
			interaction_and_attack_stats_script.hand_attack(target)

func get_edge_distance_to_target() -> float:
	if target and is_instance_valid(target):
		var center_dist = global_position.distance_to(target.global_position)
		var target_radius = 20.0
		
		if "combat_radius" in target:
			target_radius = target.combat_radius
		
		return max(0.0, center_dist - (combat_radius + target_radius))
	return INF
```

### Krok 5: Przypisz skrypt do sceny

1. Zaznacz root węzła (`MyEnemy`)
2. W Inspektorze przejdź do **Script**
3. Załaduj `my_enemy.gd`

### Krok 6: Dodaj wroga do spawnu

1. Otwórz scena mapy
2. Dodaj do pokoju węzeł `SpawnPoint2D` (punkt spawn'u)
3. Utwórz zasób spawn'u:
   - Nowy Resource → `EnemySpawnEntry`
   - Ustaw `Enemy Scene: res://assets/scenes/enemies/my_enemy.tscn`
4. Dodaj do puli spawn'u pokoju

---

## ✨ JAK UTWORZYĆ NOWY EFEKT

### Krok 1: Zrozum hierarchię efektów

```
Effect (bazowa klasa)
├─ TimedEffect (efekt z czasem trwania)
│  └─ [Twoje konkretne efekty: FreezeEffect, PoisonEffect, etc.]
└─ [Efekty jednokrotne: DamageEffect, HealEffect]
```

### Krok 2: Utwórz plik efektu

Utwórz: `assets/scripts/entities/effects/my_new_effect.gd`

```gdscript
extends TimedEffect
class_name MyNewEffect

# Eksportuj zmienne do edytora
@export var my_parameter: float = 1.0

func _init(_duration: float = 3.0):
	effect_name = "My New Effect"
	effect_color = Color.YELLOW
	duration = _duration
	tick_interval = 0.5  # Co 0.5 sekundy wykonaj tick
	icon = preload("res://assets/textures/my_effect_icon.png")

# Wywoływane na START efektu
func on_effect_start(target: Node2D) -> void:
	print("Efekt zaczął się na: ", target.name)
	
	# Tutaj dodaj logikę startową
	# np. zmiana kolorów, wyłączenie ruchu, itp.
	target.modulate = Color.YELLOW

# Wywoływane CO TICK (co tick_interval sekund)
func on_effect_tick(target: Node2D) -> void:
	print("Tick efektu na: ", target.name)
	
	# Tutaj dodaj logikę powtarzalną
	# np. zadawanie obrażeń (poison), regeneracja (regen), itp.
	
	if "health" in target:
		target.health -= 5  # Przykład: 5 obrażeń co tick

# Wywoływane na KONIEC efektu
func on_effect_end(target: Node2D) -> void:
	print("Efekt skończył się na: ", target.name)
	
	# Tutaj przywróć normalne stany
	# np. przywróć oryginalny kolor
	target.modulate = Color.WHITE
```

### Krok 3: Przykłady konkretnych efektów

#### Efekt Mrożący (Freeze)
```gdscript
extends TimedEffect
class_name FreezeEffectCustom

@export var freeze_modulate: Color = Color(0.337, 0.341, 1.0, 0.502)

func _init(_duration: float = 2.0):
	effect_name = "Freeze"
	effect_color = Color.CYAN
	duration = _duration
	tick_interval = 0.0

func on_effect_start(target: Node2D) -> void:
	# Wyłącz fizykę
	target.set_physics_process(false)
	target.set_process(false)
	
	# Zmień kolor
	if target.has_node("Sprite2D"):
		target.get_node("Sprite2D").modulate = freeze_modulate

func on_effect_end(target: Node2D) -> void:
	# Włącz fizykę
	target.set_physics_process(true)
	target.set_process(true)
	
	# Przywróć kolor
	if target.has_node("Sprite2D"):
		target.get_node("Sprite2D").modulate = Color.WHITE
```

#### Efekt Trucizny (Poison)
```gdscript
extends TimedEffect
class_name PoisonEffectCustom

@export var damage_per_tick: int = 3

func _init(_duration: float = 5.0):
	effect_name = "Poison"
	effect_color = Color.GREEN
	duration = _duration
	tick_interval = 1.0  # Obrażenia co sekundę

func on_effect_start(target: Node2D) -> void:
	print("Otruta: ", target.name)
	# Opcjonalne: zmień wygląd
	target.modulate = Color.GREEN

func on_effect_tick(target: Node2D) -> void:
	# Zadaj obrażenia
	if target.has_method("take_damage"):
		target.take_damage(damage_per_tick)
	print("Trucizna: -", damage_per_tick, " HP")

func on_effect_end(target: Node2D) -> void:
	target.modulate = Color.WHITE
```

### Krok 4: Dodaj efekt do bazy danych

Edytuj: `assets/scripts/autoload/item_database.gd`

```gdscript
var my_effect = MyNewEffect.new()
```

### Krok 5: Zaaplikuj efekt

```gdscript
# Gdziekolwiek w kodzie:
var target = get_tree().get_first_node_in_group("Player")
var effect = MyNewEffect.new(5.0)  # 5 sekund
target.receive_effect(effect)
```

---

## 🗺️ JAK TWORZYĆ MAPY I POKOJE

### Krok 1: Utwórz nową scenę pokoju

1. **Nowa Scena** → **Podstawowy 2D Node (Node2D)**
2. **Zapisz jako**: `assets/scenes/rooms/my_room.tscn`
3. **Zmień nazwę** na `MyRoom`

### Krok 2: Strukturuj pokój

```
MyRoom (Node2D) - Dodaj skrypt: Room.gd
├─ TileMap                         # Podstawa pokoju (ściany, podłoga)
├─ Entities (Node2D - do Y-sortu)
│  ├─ [Wrogowie będą spawniać się tutaj]
│  └─ [Gracze pojawią się tutaj]
├─ Doors (Node2D)
│  ├─ DoorRight (Door.tscn)
│  ├─ DoorLeft (Door.tscn)
│  ├─ DoorUp (Door.tscn)
│  └─ DoorDown (Door.tscn)
├─ SpawnPoints
│  ├─ PlayerSpawn (Node2D)
│  ├─ EnemySpawn1 (Node2D)
│  └─ ItemSpawn1 (Node2D)
├─ Lighting
│  └─ CenterRoomLight (PointLight2D)
└─ DecorationLayer (Node2D)
```

### Krok 3: Skonfiguruj Room.gd

Dla węzła `MyRoom` dodaj skrypt `assets/scripts/map_system/room.gd`:

W Inspektorze ustaw:

```
Room Settings:
├─ Room Size (PX):      (960, 540)      # Rozmiar pokoju w pikselach
├─ Room Type:           "NORMAL"         # Typ: NORMAL, BOSS, TREASURE, etc.
├─ Map Position:        (0, 0)           # Pozycja na siatce mapy
├─ Is Dark Room:        false            # Ciemny pokój?
└─ Darkness Color:      (Color.BLACK)    # Kolor ciemności

Połączenia Drzwi:
├─ Allow Door Left:     true
├─ Allow Door Right:    true
├─ Allow Door Up:       true
└─ Allow Door Down:     true

Loot Pool:
├─ Item Loot Pool:      [Załaduj item_loot_pool.tres]
├─ Enemy Spawn Pool:    [Załaduj enemy_spawn_pool.tres]
└─ Object Spawn Pool:   [Załaduj object_spawn_pool.tres]
```

### Krok 4: Utwórz i skonfiguruj drzwi

1. Instancjonuj scenę `assets/scenes/door.tscn` 4 razy (lewo, prawo, góra, dół)
2. Dla każdych drzwi ustaw w Inspektorze:

```
Door Settings:
├─ Direction:           (Direction.RIGHT, LEFT, UP, DOWN)
├─ Door Texture:        [Załaduj teksturę drzwi]
└─ Destination Door:    [Przypisz do drzwi w sąsiednim pokoju]
```

### Krok 5: Dodaj spawn pointy

1. Utwórz węzły **Node2D** jako dzieci `SpawnPoints`
2. Ustaw ich pozycje w pokoju
3. Dodaj skrypt `LevelEntrance.gd` do gracza spawn point'u:
```gdscript
@export var my_entrance_id: String = "room1_entrance"
```

### Krok 6: Dodaj pule spawn'u

1. Utwórz nowy Resource: `EnemySpawnPool`
2. Dodaj wpisy:
```
Spawn Entries:
├─ [0] Enemy Scene: res://assets/scenes/enemies/spider.tscn
│      Spawn Count: 2
│      Weight: 1.0
└─ [1] Enemy Scene: res://assets/scenes/enemies/my_enemy.tscn
       Spawn Count: 1
       Weight: 0.5
```

3. Przypisz do `Enemy Spawn Pool` w pokoju

### Krok 7: Dodaj TileMap (Układanka terenu)

1. Dodaj węzeł `TileMap` do pokoju
2. W Inspektorze załaduj TileSet
3. Rysuj podłogę i ściany

### Krok 8: Testuj nowy pokój

1. Utwórz nową scenę gry
2. Zamiast mapy, załaduj sam pokój
3. Uruchom (F5) i testuj spawny, drzwi, wrogów

### Krok 9: Dodaj pokój do mapy

Edytuj scenę mapy (`assets/scenes/maps/level_1_test_map.tscn`):

1. **Instancjonuj** `my_room.tscn` wiele razy
2. Pozycjonuj je na siatce (Vector2i grid)
3. Ustaw pozycje w Inspektorze dla każdego Room:
```
Map Position: (1, 0)    # Kolumna 1, Rząd 0
```

---

## 🎨 JAK DODAĆ TEKSTURY I GRAFIKI

### Krok 1: Przygotuj plik grafiki

1. **Format**: PNG, JPG (przezroczystość: PNG)
2. **Rozmiar**: Potęga 2 (64x64, 128x128, 256x256, itp.)
3. **Przezroczystość**: Prawidłowo ustawiona dla PNG

### Krok 2: Zaimportuj grafikę

1. **Kopiuj plik** do `assets/textures/` lub odpowiedniego podfolderu
2. **Godot automatycznie importuje** jako `.import`
3. **Kliknij na plik** w Project → Inspector

### Krok 3: Konfiguruj import

W Inspektorze (Texture Import Settings):

```
Texture Type:          2D Texture
Compression:           Lossy (VRAM)   # Dla sprite'ów
Filter:                Linear         # Dla pixel artu
Mipmaps:               OFF            # Dla 2D gier
```

### Krok 4: Użyj w kodzie

```gdscript
# W skrypcie:
@export var my_texture: Texture2D = preload("res://assets/textures/my_sprite.png")

# Przypisz do Sprite2D:
$Sprite2D.texture = my_texture
```

### Krok 5: Animated Sprites

Dla animowanych sprite'ów:

1. Utwórz `AnimatedSprite2D` węzeł
2. Utwórz nowy `SpriteFrames` Resource
3. Dodaj animacje z sekwencją tekstur
4. W kodzie:
```gdscript
$AnimatedSprite2D.play("run")
```

---

## 🔧 JAK MODYFIKOWAĆ KOMPONENTY

### Krok 1: Zrozum Component Pattern

Komponenty to małe, wielokrotnego użytku moduły:

```
Gracz (CharacterEntity)
  ├─ MovementComponent     # Odpowiada za ruch
  ├─ AttackComponent       # Odpowiada za atak
  ├─ LifeStatsComponent    # Odpowiada za HP
  └─ InventoryComponent    # Odpowiada za ekwipunek
```

### Krok 2: Modyfikuj istniejący komponent

Przykład: Zmiana szybkości poruszania się gracza

1. Otwórz: `assets/scripts/components/movement_component.gd`
2. Znaleź zmienną `speed`:
```gdscript
@export var speed: float = 200.0  # Zmień wartość
```

3. Lub zmień w Inspektorze dla instancji gracza

### Krok 3: Utwórz nowy komponent

Utwórz: `assets/scripts/components/my_custom_component.gd`

```gdscript
extends Node
class_name MyCustomComponent

# Zmienne eksportowane (widoczne w Inspektorze)
@export var my_value: float = 1.0
@export var my_enabled: bool = true

# Węzły
@onready var owner_entity = get_parent()

func _ready():
	print("Komponent załadowany dla: ", owner_entity.name)

func _process(delta):
	if my_enabled:
		# Logika komponentu
		pass

# Publiczne metody, które mogą być wywoływane z innych miejsc
func activate() -> void:
	my_enabled = true

func deactivate() -> void:
	my_enabled = false

func get_value() -> float:
	return my_value
```

### Krok 4: Dodaj komponent do bytu

1. W scenie (np. gracz):
2. Dodaj nowy węzeł → **Other Node (Other)**
3. Szukaj `MyCustomComponent` i dodaj
4. Konfiguruj w Inspektorze

### Krok 5: Komunikuj się między komponentami

```gdscript
# Z jednego komponentu do drugiego:
func use_item():
	var inventory = owner_entity.inventory_script
	if inventory:
		inventory.remove_item(item_id)
```

---

## 🎵 JAK DODAĆ DŹWIĘKI I MUZYKĘ

### Krok 1: Przygotuj plik audio

1. **Format**: WAV, OGG (OGG lepszy dla grania)
2. **Bitrate**: 128-192 kbps
3. **Sample Rate**: 44100 Hz

### Krok 2: Zaimportuj do gry

1. **Kopiuj do**: `assets/audio/`
2. **Godot auto-importuje** jako `.import`

### Krok 3: Utwórz AudioStreamPlayer

W scenie:

1. Dodaj węzeł `AudioStreamPlayer` (do muzyki)
   lub `AudioStreamPlayer2D` (do dźwięków 3D)

2. W Inspektorze:
```
Stream:                [Załaduj plik WAV/OGG]
Bus:                   "Master"  (lub stwórz własny bus)
Volume DB:             0.0
Pitch Scale:           1.0
```

### Krok 4: Odtwarzaj w kodzie

```gdscript
# Odtwarzanie muzyki:
$MusicPlayer.play()

# Zatrzymanie:
$MusicPlayer.stop()

# Zmiana głośności:
$MusicPlayer.volume_db = -10.0

# Efekt fade-out:
var tween = create_tween()
tween.tween_property($MusicPlayer, "volume_db", -80.0, 2.0)
```

### Krok 5: Zarządzaj dźwiękami efektów

```gdscript
# Prosty dźwięk efektu:
func play_sound_effect(sfx_path: String):
	var player = AudioStreamPlayer.new()
	player.stream = load(sfx_path)
	player.bus = "SFX"
	add_child(player)
	player.play()
	await player.finished
	player.queue_free()
```

---

## 🔗 JAK UŻYWAĆ EVENT BUS'a

### Krok 1: Zrozum EventBus

EventBus to **globalny system komunikacji** między obiektami bez bezpośrednich powiązań.

```
Gracz             Wróg               UI
  ↓                 ↓                 ↓
  └─→ EventBus ←──┴──┬───────────────→
      (Singleton)    │
                     └─ Odbiera sygnały
```

### Krok 2: Emituj sygnały (Wysłanie wiadomości)

```gdscript
# W graczу (player_script.gd):
func take_damage(amount: int):
	health -= amount
	
	# Wyemituj sygnał
	EventBus.player_health_changed.emit(health, max_health)
	
	# Wyemituj sygnał śmierci
	if health <= 0:
		EventBus.player_died.emit()
```

### Krok 3: Słuchaj sygnałów (Odbiór wiadomości)

```gdscript
# W UI (health_bar.gd):
func _ready():
	# Podłącz się do sygnału
	EventBus.player_health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(new_health: int, max_health: int):
	# Odśwież UI
	$ProgressBar.value = float(new_health) / max_health * 100
	$Label.text = str(new_health) + "/" + str(max_health)
```

### Krok 4: Zdefiniuj własne sygnały

Edytuj: `assets/scripts/autoload/event_bus.gd`

```gdscript
# Sygnały gry
signal player_health_changed(health: int, max_health: int)
signal player_died()
signal player_level_up(new_level: int)

# Sygnały przedmiotów
signal item_picked_up(item_id: String)
signal item_used(item_id: String)

# Sygnały map
signal room_changed(new_room: String)
signal boss_defeated(boss_name: String)

# Sygnały UI
signal inventory_opened()
signal inventory_closed()
```

### Krok 5: Praktyczne przykłady

#### Powiadomienie o podbieraniu przedmiotu

```gdscript
# W item_pickup.gd:
func _on_picked_up():
	EventBus.item_picked_up.emit(item_id)
	queue_free()

# W inventory_ui.gd:
func _ready():
	EventBus.item_picked_up.connect(_on_item_picked_up)

func _on_item_picked_up(item_id: String):
	print("Gracz podniósł: " + item_id)
	# Odśwież UI ekwipunku
```

#### System osiągnięć

```gdscript
# W achievement_manager.gd (singleton):
func _ready():
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.player_level_up.connect(_on_level_up)

func _on_boss_defeated(boss_name: String):
	unlock_achievement("boss_" + boss_name.to_lower())

func unlock_achievement(achievement_id: String):
	print("Osiągnięcie: " + achievement_id)
	EventBus.achievement_unlocked.emit(achievement_id)
```

---

## 🔧 SZYBKIE REFERENCJE

### Ładowanie zasobów
```gdscript
# Dynamiczne
var item = load("res://path/to/item.tres")

# W preload (szybciej)
var item = preload("res://path/to/item.tres")
```

### Tworzenie instancji scen
```gdscript
var enemy_scene = preload("res://assets/scenes/enemies/spider.tscn")
var enemy = enemy_scene.instantiate()
add_child(enemy)
enemy.global_position = Vector2(100, 100)
```

### Znajdowanie węzłów
```gdscript
# Po nazwie
var node = get_node("NodeName")

# Po grupie (zwraca tablicę)
var all_players = get_tree().get_nodes_in_group("Player")

# Unikalny (zwraca pojedynczy węzeł)
var player = get_tree().get_first_node_in_group("Player")
```

### Sygnały
```gdscript
# Definiowanie
signal my_signal(param1: String, param2: int)

# Emitowanie
my_signal.emit("Hello", 42)

# Słuchanie
my_signal.connect(_on_signal_received)

func _on_signal_received(param1: String, param2: int):
	print(param1, " ", param2)
```

---

## 📚 PRZYDATNE SKRÓTY KLAWISZOWE GODOT

| Skrót | Opis |
|-------|------|
| F5 | Uruchom scenę |
| F6 | Uruchom projekt |
| Ctrl+Shift+F10 | Restart |
| Ctrl+S | Zapisz scenę |
| Ctrl+Z | Cofnij |
| Ctrl+D | Duplikuj węzeł |
| Ctrl+L | Zainstaluj skrypt |

---

## 🐛 DEBUGOWANIE I TESTY

### Drukuj do konsoli
```gdscript
print("Wartość: ", my_var)
print_debug("Debug: ", my_var)
printerr("BŁĄD: ", error_msg)
```

### Breakpoints
1. Kliknij na numer linii w edytorze
2. Uruchom debug (F5)
3. Gra zatrzyma się na breakpoint'cie

### Szybkie testy
```gdscript
# Spawn test gracza w scenie
func _ready():
	if get_tree().current_scene.name == "TestScene":
		spawn_test_player()
```

---

## 📝 CHECKLIST PRZED PUSHEM

- [ ] Nowy kod skomentowany
- [ ] Brak debug print'ów w release'owym kodzie
- [ ] Wytestowane na kilku mapach
- [ ] Event bus użyty zamiast bezpośrednich powiązań
- [ ] Komponenty umieszczone w odpowiednich folderach
- [ ] Zasoby dodane do bazy danych
- [ ] Bez błędów w konsolach Godot

---

**Pytania? Sprawdź kod w `assets/scripts/` - każdy system ma przykłady!**

🎮 **Powodzenia w tworzeniu gry!** 🎮
