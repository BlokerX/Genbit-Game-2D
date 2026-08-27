# 🔧 DOKUMENTACJA TECHNICZNA - GENBIT-GAME-2D

Szczegółowe opisy techniczne i implementacyjne głównych systemów gry.

---

## 📌 SPIS TREŚCI

1. [System Efektów (Effects System)](#system-efektów)
2. [System Przedmiotów (Item System)](#system-przedmiotów)
3. [System Walki (Combat System)](#system-walki)
4. [System Ruchu (Movement System)](#system-ruchu)
5. [System Mapy i Pokojów (Level System)](#system-mapy-i-pokojów)
6. [System Ekwipunku (Inventory System)](#system-ekwipunku)
7. [System Craftingu (Crafting System)](#system-craftingu)
8. [System UI (User Interface)](#system-ui)
9. [Event Bus i Komunikacja](#event-bus-i-komunikacja)
10. [Performance i Optymalizacja](#performance-i-optymalizacja)

---

## System Efektów

### Architektura

```
Effect (Resource)
├─ effect_name: String
├─ effect_color: Color
├─ icon: Texture2D
└─ apply_effect(target) → bool

TimedEffect (Effect)
├─ duration: float
├─ tick_interval: float
└─ Overridable: on_effect_start, on_effect_tick, on_effect_end

ActiveEffect (Node)
├─ target: Node2D
├─ effect_resource: Resource
├─ duration: float
├─ is_infinite: bool
└─ Manages lifecycle
```

### Jak działają efekty?

1. **Tworzenie efektu**: `var effect = FreezeEffect.new(3.0)`
2. **Aplikacja**: `player.receive_effect(effect)`
3. **Załadowanie**: Gracz tworzy `ActiveEffect` węzeł
4. **Start**: Wywoła się `on_effect_start(player)`
5. **Update**: Co `tick_interval` sekund wywołuje się `on_effect_tick()`
6. **Koniec**: Po `duration` sekundach wywoła się `on_effect_end()`
7. **Usunięcie**: `ActiveEffect` węzeł jest usuwany

### Kod receptury (Template)

```gdscript
extends TimedEffect
class_name CustomEffect

@export var my_param: float = 1.0

func _init(_duration: float = 3.0):
	effect_name = "Custom Effect"
	effect_color = Color.YELLOW
	duration = _duration
	tick_interval = 1.0  # 0 = bez ticków

# Wywoływane na START
func on_effect_start(target: Node2D) -> void:
	print("Efekt START: ", target.name)
	# Logika startowa

# Wywoływane co TICK
func on_effect_tick(target: Node2D) -> void:
	print("Efekt TICK: ", target.name)
	# Logika powtarzalna (np. obrażenia)

# Wywoływane na KONIEC
func on_effect_end(target: Node2D) -> void:
	print("Efekt END: ", target.name)
	# Przywrócenie stanów
```

### Warstwy efektów

| Typ | Opis | Przykład |
|-----|------|---------|
| **Timed Effects** | Z limitem czasu | Poison (5s), Freeze (2s) |
| **Infinite Effects** | Nieskończone (room aura) | Radiation, Darkness |
| **Instant Effects** | Jednokrotne | Damage, Heal |
| **Toggle Effects** | Włączalne/wyłączalne | Shield, Invisibility |

### Listy efektów w graczу

```gdscript
# Przechowywane w nodes
var active_effects_nodes: Array[Node] = []

# Zarządzanie:
player.receive_effect(effect)           # Dodaj
player.remove_effect_by_name("Poison")  # Usuń po nazwie
player.clear_all_effects()              # Wyczyść wszystkie
```

---

## System Przedmiotów

### Hierarchia klas

```
ItemData (Resource) - Dane przedmiotu
├─ item_id: StringName
├─ item_name: String
├─ item_description: String
├─ tags: Array[StringName]
├─ item_icon: Texture2D
└─ components: Array[ItemComponent]

ItemInstance (Resource) - Instancja przedmiotu w grze
├─ data: ItemData (ref)
├─ state: Dictionary (ilość, wytrzymałość, itp.)
├─ can_stack_with(other) → bool
├─ consume_durability(amount)
└─ consume_amount(count)

ItemComponent (Resource) - Komponenty zachowania
├─ MeleeWeaponComponent
├─ RangedWeaponComponent
├─ ConsumableComponent
├─ BackpackComponent
├─ EquippableComponent
├─ DurabilityComponent
├─ StackComponent
└─ ChargesComponent
```

### Cykl życia przedmiotu

1. **Definicja**: Tworzenie `ItemData` w `/assets/data/items/`
2. **Rejestracja**: Dodanie do `ItemDatabase`
3. **Instancja**: Tworzenie `ItemInstance` w ekwipunku
4. **Użycie**: Wywołanie metody `use()` lub `consume_durability()`
5. **Usunięcie**: `consume_amount()` usuwa ze stacku

### Stan przedmiotu (Dictionary)

```gdscript
var state: Dictionary = {
	"amount": 1,              # Ilość w stacku
	"durability": 100,        # Wytrzymałość broni
	"charges": 30,            # Ładunki
	"condition": 1.0,         # 0.0-1.0 (stan)
	# ... inne custom stany
}
```

### Komponenty przedmiotów

#### MeleeWeaponComponent
```gdscript
@export var damage: float = 10.0
@export var attack_speed: float = 1.0
@export var range: float = 40.0
@export var knockback_force: float = 10.0
```

#### RangedWeaponComponent
```gdscript
@export var damage: float = 15.0
@export var fire_rate: float = 1.2
@export var projectile_speed: float = 400.0
@export var ammo_type: String = "gun_ammo"
@export var magazine_size: int = 30
```

#### ConsumableComponent
```gdscript
@export var effect: Effect  # Efekt przy użyciu
@export var amount_consumed: int = 1
@export var can_use_infinite: bool = false
```

### Stackowanie przedmiotów

```gdscript
# Warunki stackowania
func can_stack_with(other: ItemInstance) -> bool:
	# 1. Porównaj ID
	if data.item_id != other.data.item_id:
		return false
	
	# 2. Porównaj STATE (ważne dla broni z różną durability)
	for key in state.keys():
		if key == "amount": continue
		if state[key] != other.state[key]:
			return false
	
	return true
```

---

## System Walki

### Komponenty walki

```
AttackComponent
├─ hand_damage: float
├─ hand_cooldown: float
├─ execute_attack_on_target(target)
└─ can_attack() → bool

AttackData
├─ damage: int
├─ range: float
├─ knockback: float
└─ effects: Array[Effect]

RangedWeaponComponent
├─ projectile_scene: PackedScene
├─ fire_projectile(direction)
└─ Consumuje amunicję

MeleeWeaponComponent
├─ damage: float
├─ attack_speed: float
└─ execute_melee_attack()
```

### Sekwencja ataku

```
1. Gracz naciśka LMB
   ↓
2. PlayerScript.input_event() sprawdza can_attack()
   ↓
3. AttackComponent.execute_attack_on_target(target)
   ↓
4. Broń sprawdza typ:
   ├─ Melee: instant damage
   └─ Ranged: create projectile
   ↓
5. Obrażenia/efekty aplikowane do celu
   ↓
6. Cooldown aktywowany
```

### Cooldown system

```gdscript
var can_attack(): bool
	return current_cooldown <= 0.0

func interaction_cooldown_process(delta):
	current_cooldown -= delta
	current_cooldown = max(0.0, current_cooldown)

func execute_attack_on_target(target):
	if can_attack():
		# ... wykonaj atak ...
		current_cooldown = hand_cooldown
```

### Damage Calculation

```gdscript
var total_damage = base_damage
# + skill modifiers
# + equipment bonuses
# + active buffs
# - enemy armor/defense
# ± randomness (±10%)

target.take_damage(total_damage)
```

---

## System Ruchu

### MovementComponent

```gdscript
@export var max_speed: float = 200.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

func movement_procedure(delta, velocity, direction) -> Vector2:
	# Aplikuj przyspieszenie
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	return velocity
```

### Efekty ruchu

| Efekt | Wpływ | Kod |
|-------|-------|------|
| **Slow Effect** | -50% prędkości | `max_speed *= 0.5` |
| **Haste Effect** | +50% prędkości | `max_speed *= 1.5` |
| **Freeze Effect** | 0% prędkości | `set_physics_process(false)` |
| **Giant Effect** | +scale, -speed | `scale *= 1.5` |
| **Liliput Effect** | -scale, +speed | `scale *= 0.5` |

### Nawigacja (PathFinding)

```gdscript
# Wrogowie używają NavigationAgent2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

func set_movement_target(target_pos: Vector2):
	navigation_agent.target_position = target_pos

func _physics_process(delta):
	if not navigation_agent.is_navigation_finished():
		var next_pos = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_pos)
		velocity = movement_procedure(delta, velocity, direction)
		move_and_slide()
```

---

## System Mapy i Pokojów

### Klasa Room

```gdscript
class_name Room
extends Node2D

@export var room_type: RoomType = RoomType.NORMAL
@export var map_position: Vector2i = Vector2i(0, 0)
@export var size_px: Vector2 = Vector2(960, 540)
@export var is_dark_room: bool = false
@export var darkness_color: Color = Color.BLACK

# Listy
var doors: Array[Door] = []
var spawn_points: Array[Node2D] = []
var enemy_spawn_pool: EnemySpawnPool
var item_loot_pool: ItemLootPool
```

### Typy pokojów

```gdscript
enum RoomType {
	NORMAL,        # Zwykły pokój
	START,         # Pokój początkowy
	BOSS,          # Pokój bossa
	TREASURE,      # Pokój ze skarbem
	SHOP,          # Sklep
	ARENA,         # Arena walki
	DEV_ROOM       # Pokój deweloperski
}
```

### Siatka pokojów (Grid)

```
Map poziom 1 (960x960px każdy):

[0,0]     [1,0]     [2,0]
Start  →  Enemy   →  Treasure

[0,1]     [1,1]     [2,1]
Enemy     Normal     Enemy

[0,2]     [1,2]     [2,2]
Treasure  Boss       Treasure
```

### System drzwi

```gdscript
class_name Door
extends Area2D

enum Direction {
	UP,
	DOWN,
	LEFT,
	RIGHT
}

@export var direction: Direction = Direction.RIGHT
@export var door_texture: Texture2D
@export var destination_door: Door  # Połączenie do drzwi w sąsiednim pokoju
```

### Przejście między pokojami

```
1. Gracz wszedł w drzwi
   ↓
2. Door.player_entered_door.emit()
   ↓
3. Map._on_door_entered(door)
   ↓
4. Map.change_room(next_room, door.destination_door)
   ↓
5. Fade/Slide animacja
   ↓
6. Gracz teleportowany do nowego pokoju
   ↓
7. Spawn punkty aktywne
   ↓
8. Wrogowie spawn'ują się
```

### Pule spawn'u

```gdscript
class_name EnemySpawnPool
extends Resource

@export var spawn_entries: Array[EnemySpawnEntry] = []

# Struktura wpisu:
# - enemy_scene: PackedScene
# - spawn_count: int
# - weight: float (prawdopodobieństwo)
```

---

## System Ekwipunku

### Struktura

```gdscript
class_name Inventory
extends Node

@export var max_slots: int = 20
var slots: Array[InventorySlot] = []

# Operacje
func add_item(item: ItemData, amount: int = 1) → bool
func remove_item(item_id: StringName, amount: int = 1) → bool
func get_item(slot_index: int) → ItemInstance
func is_full() → bool
func get_free_space() → int
```

### Slot

```gdscript
class_name InventorySlot
extends Resource

var item: ItemInstance = null  # null jeśli pusty

func is_empty() → bool
func place_item(new_item: ItemInstance) → bool
func remove_item() → ItemInstance
```

### Równoległy ekwipunek (Equipment Slots)

```gdscript
# Specjalnie sloty dla części ciała
var equipment: Dictionary = {
	"hand": null,       # Broń
	"armor": null,      # Zbroja
	"accessory": null,  # Talizman
	# ...
}
```

### UI Ekwipunku

```
InventoryUI (Control)
├─ GridPanel (custom grid)
│  └─ [InventorySlot nodes]
├─ ItemPreview
│  ├─ Icon
│  ├─ Name
│  ├─ Description
│  └─ Stats
└─ EquippedItems
   ├─ MainHand
   ├─ Armor
   └─ Accessories
```

---

## System Craftingu

### Architektura

```gdscript
class_name CraftingRecipe
extends Resource

@export var recipe_id: String
@export var result_item: ItemData
@export var ingredients: Array[RecipeIngredient]
@export var conditions: Array[ItemCondition]  # np. pełne HP
@export var result_amount: int = 1

func can_craft() → bool:
	# Sprawdź wszystkie warunki
	return true
```

### Ingredienty

```gdscript
class_name RecipeIngredient
extends Resource

@export var item_id: StringName
@export var amount_required: int = 1

# Sprawdzenie:
var inventory = player.inventory
if inventory.get_item_amount(item_id) >= amount_required:
	# Możesz craftować
```

### Warunki Craftingu

```gdscript
class_name ItemCondition
extends Resource

@export var condition_type: String  # "health_full", "level_min", etc.

func check_condition(player) → bool:
	match condition_type:
		"health_full":
			return player.health == player.max_health
		"level_min":
			return player.level >= condition_value
```

### Proces craftingu

```
1. Gracz otwiera UI craftingu (C)
   ↓
2. Wyświetlane receptury, które gracz zna
   ↓
3. Gracz klika na recepturę
   ↓
4. System sprawdza:
   ├─ Czy ma ingredients?
   └─ Czy warunki spełnione?
   ↓
5. Jeśli OK: konsumuj ingredienty, dodaj wynik
   ↓
6. UI odśwież się
```

---

## System UI

### Struktura UI w grze

```
Main (CanvasLayer)
├─ HUD (Layer - zawsze widoczny)
│  ├─ HealthBar
│  ├─ ActiveEffectsUI
│  ├─ PlayerStatsUI
│  └─ Minimap
├─ InventoryUI (Control)
│  ├─ GridPanel
│  └─ ItemPreview
├─ CraftingUI (Control)
│  ├─ RecipeList
│  ├─ IngredientCheck
│  └─ CraftButton
├─ PauseMenu (Control)
│  ├─ Resume
│  ├─ Settings
│  └─ Quit
└─ Notifications (VBoxContainer)
   └─ [ToastMessages]
```

### HealthBar

```gdscript
class_name HealthBar
extends Control

func _ready():
	player.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health: int, max_health: int):
	$ProgressBar.max_value = max_health
	$ProgressBar.value = new_health
	$Label.text = str(new_health) + "/" + str(max_health)
```

### ActiveEffectsUI

```
┌─────────────────────┐
│ ❄️ 2.5s │ 💜 4.2s │ 🔴 1.1s │
└─────────────────────┘

Każdy efekt = ikona + timer
```

### Minimap

```gdscript
# Renderuje odkryte pokoje na 2D texture
func _on_room_changed(new_room: Room):
	discovered_rooms.append(new_room)
	redraw_minimap()

func redraw_minimap():
	# Narysuj każdy pokój jako kwadrat
	# Gracz = biały punkt
	# Wrogowie = czerwone punkty
```

---

## Event Bus i Komunikacja

### Definicje sygnałów

```gdscript
# assets/scripts/autoload/event_bus.gd

# Gracz
signal player_health_changed(health: int, max_health: int)
signal player_died()
signal player_level_up(new_level: int)

# Przedmioty
signal item_picked_up(item_id: String)
signal item_used(item_id: String)
signal item_dropped(item_id: String)

# Mapa
signal room_changed(room: Room)
signal boss_defeated(boss_name: String)

# UI
signal inventory_opened()
signal inventory_closed()
signal notification_show(message: String, duration: float)
```

### Przykład: Powiadomienie

```gdscript
# W item_pickup.gd
func _on_picked_up(item: ItemData):
	EventBus.item_picked_up.emit(item.item_id)
	EventBus.notification_show.emit("Podniósł: " + item.item_name, 3.0)

# W notification_manager.gd
func _ready():
	EventBus.notification_show.connect(_on_notification)

func _on_notification(message: String, duration: float):
	var toast = Toast.new()
	toast.text = message
	add_child(toast)
	await get_tree().create_timer(duration).timeout
	toast.queue_free()
```

### Przykład: System osiągnięć

```gdscript
# W achievement_manager.gd
func _ready():
	EventBus.player_died.connect(_on_player_died)
	EventBus.item_used.connect(_on_item_used)
	EventBus.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated(boss_name: String):
	unlock_achievement("beat_" + boss_name.to_lower())
	EventBus.achievement_unlocked.emit("beat_" + boss_name.to_lower())
```

---

## Performance i Optymalizacja

### Rendering Optimization

```gdscript
# 1. Culling - Wyłączanie renderowania poza ekranem
if not is_on_screen():
	visible = false
	return

# 2. LOD (Level of Detail) - Mniejsze detale daleko
if distance_to_camera > 1000:
	detail_level = LOW
else:
	detail_level = HIGH

# 3. Batch Rendering - Łączenie draw callsów
# Używaj CanvasGroup dla grup UI
```

### Physics Optimization

```gdscript
# 1. Disable Physics poza ekranem
if not visible:
	set_physics_process(false)
else:
	set_physics_process(true)

# 2. Optimize Collision Shapes
# - Używaj najprostszych shape'ów
# - CapsuleShape2D lepszy niż ComplexPolygon2D

# 3. Physics Layers
# - Oddziel Layer dla player, enemy, items
# - Zmniejsz liczbę collision checks
```

### Memory Optimization

```gdscript
# 1. Object Pooling - Recycle obiekty zamiast tworzenia nowych
var projectile_pool: Array[Projectile] = []

func get_projectile() -> Projectile:
	if projectile_pool.size() > 0:
		return projectile_pool.pop_front()
	return Projectile.new()

func return_projectile(p: Projectile):
	p.reset()
	projectile_pool.append(p)

# 2. Unload Scenes poza widokiem
if not current_room.visible:
	current_room.process_mode = Node.PROCESS_MODE_DISABLED
```

### Script Optimization

```gdscript
# 1. Cache scene references
@onready var sprite = $Sprite2D  # Zamiast get_node() każdą klatkę

# 2. Avoid allocations w _process
func _process(delta):
	# BAD:
	var vec = Vector2.ZERO  # Nowa alokacja każdej klatki
	
	# GOOD:
	var vec = my_cached_vector
	vec = Vector2.ZERO

# 3. Use early returns
func expensive_check():
	if not is_valid():
		return
	if not is_ready():
		return
	# ... reszta logiki
```

### Profiling

```gdscript
# Godot wbudowany profiler
# Debug → Monitor

# Custom timers:
var timer = Time.get_ticks_msec()
# ... execute code ...
var elapsed = Time.get_ticks_msec() - timer
print("Czas: %d ms" % elapsed)
```

---

## Checklist Optymalizacji

- [ ] Disabled physics dla niewidocznych bytów
- [ ] Object pooling dla pocisków i efektów
- [ ] Cached NodeReferences (@onready)
- [ ] Proper layer masks dla colizji
- [ ] Unloaded old rooms
- [ ] Profiled hot paths
- [ ] Minimal allocations w _process
- [ ] Used early returns w conditionals
- [ ] Proper Asset Compression
- [ ] No memory leaks (queue_free() zamiast free())

---

**Potrzebujesz szczegółów? Sprawdź kod w `assets/scripts/` - każdy system ma komentarze!** 🎮
