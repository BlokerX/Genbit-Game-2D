class_name UIController
extends CanvasLayer

const INPUT_TOGGLE_INVENTORY = "ToggleInventory"
const INPUT_TOGGLE_CRAFTING = "ToggleCrafting"
const INPUT_TOGGLE_MAP = "ToggleMap"
const INPUT_GAME_PAUSE = "Game_Pause"

const SLOT_SCENE = preload("res://assets/scenes/inventory_slot.tscn")

@export var chest_panel: GridPanel
@export var player_panel: GridPanel
@export var backpack_panel: GridPanel

@export var hotbar_panel: Control
@export var cursor_item_rect: TextureRect
@export var cursor_amount_label: Label

@export var crafting_ui: Control
@export var minimap_ui: Minimap
var backpack_slot_ui: InventorySlot

@export_category("Gamepad UI")
## Szybkość poruszania kursorem myszy za pomocą lewej gałki
@export var gamepad_cursor_speed: float = 700.0

# Zmienna na ekwipunek gracza - znajdziemy ją automatycznie!
var player_inventory: Inventory = null

var item_in_hand: ItemInstance = null

var current_open_chest: Node = null
var is_player_inventory_open: bool = false
var is_crafting_open: bool = false
var is_map_open: bool = false

# --- NOWOŚĆ: Liczniki do auto-wyrzucania przedmiotów ---
var _drop_hold_time: float = 0.0
var _drop_tick_time: float = 0.0

func _ready() -> void:
	# Automatycznie szukamy gracza w scenie po grupie "player"
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Zakładam, że wewnątrz gracza Twój skrypt inventory.gd ma węzeł o nazwie "Inventory"
		# (Jeśli Twój węzeł nazywa się inaczej, zmień "$Inventory" na odpowiednią ścieżkę)
		player_inventory = player.get_node_or_null("Inventory")
	
	if not player_inventory:
		push_error("UIController nie mógł znaleźć ekwipunku gracza! Upewnij się, że gracz jest w grupie 'player' i posiada węzeł Inventory.")
		return

	EventBus.open_storage_ui.connect(_on_storage_opened)
	EventBus.close_storage_ui.connect(_on_storage_closed)
	EventBus.slot_clicked.connect(_on_slot_clicked)
	
	# --- NOWOŚĆ: Automatyczne GENEROWANIE slotu plecaka ---
	if backpack_panel:
		# 1. Czyścimy panel ze starych śmieci (jeśli jakieś zostały w Edytorze)
		for child in backpack_panel.get_children():
			backpack_panel.remove_child(child)
			child.queue_free()
			
		# 2. Generujemy IDEALNIE JEDEN nowy slot i wrzucamy do panelu
		backpack_slot_ui = SLOT_SCENE.instantiate()
		backpack_panel.add_child(backpack_slot_ui)
		
		# 3. Konfigurujemy go do działania z plecakiem
		backpack_slot_ui.setup_as_backpack_slot(player_inventory)
		backpack_slot_ui.update_slot(player_inventory.backpack_slot)
		player_inventory.inventory_updated.connect(func(): backpack_slot_ui.update_slot(player_inventory.backpack_slot))
	else:
		push_warning("Brak przypisanego 'backpack_panel' w Inspektorze UIController'a!")
		
	# Nasłuchujemy zmiany fokusu (gdy gracz nawiguje D-Padem)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	
	_update_cursor_visuals()
	
	# Upewniamy się, że crafting jest domyślnie ukryty
	if crafting_ui:
		crafting_ui.hide()
	
	# Upewniamy się, że plecak jest schowany na starcie gry
	_set_backpack_ui_visible(false)

func _process(delta: float) -> void:
	# --- 1. WIRTUALNY KURSOR DLA PADA ---
	if is_any_ui_open():
		# Odczytujemy lewą gałkę (używamy akcji ruchu Gracza)
		var move_dir = Input.get_vector("Left", "Right", "Up", "Down")
		
		if move_dir != Vector2.ZERO:
			# [NOWOŚĆ] Resetujemy klasyczny focus Godota, gdy ruszamy gałką!
			# Zapobiega to "podwójnemu klikaniu" i uciekaniu podświetlenia.
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner:
				focus_owner.release_focus()
			
			# Pobieramy aktualną pozycję prawdziwej myszki
			var current_pos = get_viewport().get_mouse_position()
			var new_pos = current_pos + (move_dir * gamepad_cursor_speed * delta)
			
			# Zabezpieczenie, żeby kursor nie wyleciał poza krawędzie ekranu
			var screen_size = get_viewport().get_visible_rect().size
			new_pos.x = clamp(new_pos.x, 0, screen_size.x)
			new_pos.y = clamp(new_pos.y, 0, screen_size.y)
			
			# Przesuwamy systemową myszkę
			get_viewport().warp_mouse(new_pos)
			
			# --- KLUCZOWA NAPRAWKA: Wstrzykujemy zdarzenie ruchu myszy ---
			# To sprawia, że Godot natychmiast "widzi", nad jakim slotem jesteśmy
			var motion_event = InputEventMouseMotion.new()
			motion_event.global_position = new_pos
			motion_event.position = new_pos
			Input.parse_input_event(motion_event)
		
		# --- NOWOŚĆ: AUTO-FIRE WYRZUCANIA (Przytrzymanie klawisza) ---
		# Jeśli trzymamy "Q", ale NIE trzymamy Ctrl/Shift (bo to by wyrzucało całe stacki)
		if Input.is_action_pressed("DropItem") and not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
			_drop_hold_time += delta
			# Jeśli trzymamy klawisz dłużej niż 0.4 sekundy (tzw. opóźnienie startowe / initial delay)
			if _drop_hold_time > 0.4:
				_drop_tick_time += delta
				# Wyrzucaj jedną sztukę co 0.1 sekundy (szybkość karabinu)
				if _drop_tick_time > 0.1:
					_try_drop_hovered_slot(false)
					_drop_tick_time = 0.0 # resetujemy tylko czas "strzału", żeby strzelił znowu za 0.1s
		else:
			# Natychmiast resetujemy wszystko po puszczeniu klawisza
			_drop_hold_time = 0.0
			_drop_tick_time = 0.0
	
	# --- 2. Rysowanie trzymanego przedmiotu pod kursorem (Twój stary kod) ---
	if item_in_hand != null:
		cursor_item_rect.global_position = get_viewport().get_mouse_position() + Vector2(5, 5)

func toggle_player_inventory() -> void:
	if is_player_inventory_open:
		_close_all_ui()
	else:
		_close_all_ui() # Zamknij wszystko inne (np. crafting), zanim otworzysz ekwipunek
		
		is_player_inventory_open = true
		
		# Wysyłamy sygnał, że okno się otworzyło
		EventBus.ui_state_changed.emit(true)
		
		player_panel.open_panel(player_inventory)
		
		# Pokazujemy slot plecaka ---
		_set_backpack_ui_visible(true)
		
		if hotbar_panel:
			hotbar_panel.hide()

## Funkcja do otwierania/zamykania Craftingu
# (Wywołaj ją z miejsca, w którym włączasz crafting, np. po naciśnięciu "C" lub użyciu stołu)
func toggle_crafting_ui() -> void:
	if is_crafting_open:
		_close_all_ui()
	else:
		_close_all_ui() # Zamknij ekwipunki i skrzynie, żeby zrobić czyste miejsce
		
		is_crafting_open = true
		
		# Wysyłamy sygnał, że okno się otworzyło
		EventBus.ui_state_changed.emit(true)
		
		if crafting_ui:
			crafting_ui.show()
		
		# Zostawiamy hotbar widoczny podczas craftingu!
		if hotbar_panel:
			hotbar_panel.show()

func toggle_map_ui() -> void:
	if is_map_open:
		_close_all_ui()
	else:
		_close_all_ui() # Zamyka ekwipunek/crafting
		is_map_open = true
		
		# Wysyłamy sygnał zamrożenia gracza
		EventBus.ui_state_changed.emit(true)
		
		if minimap_ui:
			minimap_ui.toggle_large_map(true)
			
		if hotbar_panel:
			hotbar_panel.hide()

func _on_storage_opened(storage_ref: Node) -> void:
	_close_all_ui() # Zamknij crafting, jeśli był otwarty
	
	current_open_chest = storage_ref
	is_player_inventory_open = true
	
	# Upewnij się, że ta linijka tu jest! To ona mrozi gracza.
	# Wysyłamy sygnał, że okno się otworzyło
	EventBus.ui_state_changed.emit(true)
	
	player_panel.open_panel(player_inventory)
	chest_panel.open_panel(storage_ref)
	if hotbar_panel:
		hotbar_panel.hide() # Ukrywa hotbar

func _on_storage_closed() -> void:
	_close_all_ui()

func _close_all_ui() -> void:
	# 1. Odkładanie przedmiotu z ręki
	if item_in_hand != null and player_inventory != null:
		var remainder = player_inventory.add_instance(item_in_hand)
		if remainder != null:
			player_inventory.item_dropped.emit(remainder, true) 
		item_in_hand = null
		
	_update_cursor_visuals()
	
	# 2. Reset zmiennych i ukrywanie paneli
	current_open_chest = null
	is_player_inventory_open = false
	is_crafting_open = false
	is_map_open = false
	
	if minimap_ui:
		minimap_ui.toggle_large_map(false)
	
	player_panel.close_panel()
	_set_backpack_ui_visible(false)
	
	chest_panel.close_panel()
	
	if crafting_ui:
		crafting_ui.hide()
		
	if hotbar_panel:
		hotbar_panel.show()
	
	# Wysyłamy sygnał, że wszystkie okna są zamknięte
	EventBus.ui_state_changed.emit(false)

# DODAJEMY NOWĄ FUNKCJĘ _input, KTÓRA JEST PIERWSZA W KOLEJCE:
func _input(event: InputEvent) -> void:
	# Obsługa Pauzy (Zamykanie aktywnych okien)
	if event.is_action_pressed(INPUT_GAME_PAUSE):
		if is_any_ui_open(): # <--- Skrócone i obejmujące mapę!
			_close_all_ui()
			get_viewport().set_input_as_handled()
	
	# Wyrzucanie przedmiotu poza okno dla myszki
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if item_in_hand != null and is_player_inventory_open:
			if not _is_mouse_over_inventory_panels():
				_drop_item_from_cursor()

	# --- SYMULACJA KLIKNIĘĆ PADEM I INNE AKCJE (w _input) ---
	if is_any_ui_open():
		# Akcja "Interact" symuluje LEWY Przycisk Myszy (Podnoszenie przedmiotu)
		if event.is_action_pressed("Interact"):
			_simulate_mouse_click(MOUSE_BUTTON_LEFT, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_released("Interact"):
			_simulate_mouse_click(MOUSE_BUTTON_LEFT, false)
			get_viewport().set_input_as_handled()
			
		# Akcja "RotateBuilding" symuluje PRAWY Przycisk Myszy (Dzielenie przedmiotów na pół)
		if event.is_action_pressed("RotateBuilding"):
			_simulate_mouse_click(MOUSE_BUTTON_RIGHT, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_released("RotateBuilding"):
			_simulate_mouse_click(MOUSE_BUTTON_RIGHT, false)
			get_viewport().set_input_as_handled()
		
		# --- WYRZUCANIE ITEMÓW (Pierwsze kliknięcie lub cała sterta) ---
		if event.is_action_pressed("DropItem"):
			# Używamy Ctrl LUB Shift, żeby wyrzucić od razu całą stertę
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT):
				_try_drop_hovered_slot(true)
			else:
				# Natychmiastowe wyrzucenie 1 sztuki po pierwszym kliknięciu
				_try_drop_hovered_slot(false)
			get_viewport().set_input_as_handled()

# Pomocnicza funkcja sprawdzająca, czy kursor jest nad okienkiem ekwipunku
func _is_mouse_over_inventory_panels() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Sprawdzamy panel gracza
	if player_panel and player_panel.visible:
		if player_panel.get_global_rect().has_point(mouse_pos):
			return true
			
	# --- Sprawdzamy obszar slotu plecaka! ---
	if backpack_panel and backpack_panel.visible:
		if backpack_panel.get_global_rect().has_point(mouse_pos):
			return true
			
	# Sprawdzamy panel skrzyni (jeśli jest otwarta)
	if chest_panel and chest_panel.visible:
		if chest_panel.get_global_rect().has_point(mouse_pos):
			return true
			
	return false

# Funkcja wyrzucająca trzymany przedmiot z kursora
func _drop_item_from_cursor() -> void:
	var dropped_instance = item_in_hand
	item_in_hand = null
	_update_cursor_visuals()
	_execute_drop_in_world(dropped_instance)

# Uniwersalna funkcja fizycznie wyrzucająca przedmioty na świat gry
func _execute_drop_in_world(dropped_instance: ItemInstance) -> void:
	if dropped_instance == null: return
	
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("ItemThrowerComponent"):
		var thrower = player.get_node("ItemThrowerComponent")
		var aim_target = Vector2.ZERO
		if player.has_node("AimController") and player.get_node("AimController").aim_scanner:
			aim_target = player.get_node("AimController").aim_scanner.target_position
			
		thrower.handle_item_drop(player, dropped_instance, true, true, aim_target)
	else:
		# Fallback awaryjny
		if player_inventory:
			player_inventory.item_dropped.emit(dropped_instance, true)
			
	print("UIController: Pomyślnie wyrzucono przedmiot (" + dropped_instance.data.item_name + ")!")

func _try_drop_hovered_slot(drop_all: bool) -> void:
	# 1. Priorytet 1: Jeśli mamy coś w ręku (kursorze), to najpierw wyrzucamy z kursora
	if item_in_hand != null:
		# ZMIANA: Pobieranie ilości ze słownika 'state'
		var hand_amount = item_in_hand.state.get("amount", 1)
		var amount_to_drop = hand_amount if drop_all else 1
		
		var unique_data = item_in_hand.data.duplicate(true)
		var dropped_instance = ItemInstance.new(unique_data, amount_to_drop)
		
		# --- OSTATECZNA ZMIANA ECS: Klonowanie całego stanu ---
		dropped_instance.state = item_in_hand.state.duplicate(true)
		dropped_instance.state["amount"] = amount_to_drop
		
		# Odejmowanie ze słownika
		item_in_hand.state["amount"] = hand_amount - amount_to_drop
		if item_in_hand.state["amount"] <= 0:
			item_in_hand = null
			
		_update_cursor_visuals()
		_execute_drop_in_world(dropped_instance)
		return

	# 2. Priorytet 2: Sprawdzamy, na jaki element interfejsu najechał kursor
	var hovered = get_viewport().gui_get_hovered_control()
	var target_slot_ui: InventorySlot = null
	
	# Szukamy po strukturze węzłów w górę, czy trafiliśmy w InventorySlot
	while hovered != null:
		if hovered is InventorySlot:
			target_slot_ui = hovered
			break
		hovered = hovered.get_parent()
		
	# Jeśli kursor jest nad slotem
	if target_slot_ui != null:
		var parent_node = target_slot_ui.parent_reference
		var slot_idx = target_slot_ui.slot_index
		
		# -- ZABEZPIECZENIE: WYRZUCANIE ZAŁOŻONEGO PLECAKA --
		if slot_idx == -2 and parent_node is Inventory:
			if not parent_node.backpack_slot.is_empty():
				var backpack_to_drop = parent_node.unequip_backpack()
				_execute_drop_in_world(backpack_to_drop)
			return
		
		var target_slot: SlotData
		if parent_node is StorageComponent:
			target_slot = parent_node.slots[slot_idx]
		elif parent_node is Inventory:
			target_slot = parent_node.slots[slot_idx]
			
		# Odrywanie przedmiotu ze slota i rzut
		if target_slot and not target_slot.is_empty():
			var slot_amount = target_slot.item.state.get("amount", 1)
			var amount_to_drop = slot_amount if drop_all else 1
			
			var unique_data = target_slot.item.data.duplicate(true)
			var dropped_instance = ItemInstance.new(unique_data, amount_to_drop)
			
			# --- OSTATECZNA ZMIANA ECS: Klonowanie całego stanu ---
			dropped_instance.state = target_slot.item.state.duplicate(true)
			dropped_instance.state["amount"] = amount_to_drop
			
			target_slot.item.state["amount"] = slot_amount - amount_to_drop
			if target_slot.item.state["amount"] <= 0:
				target_slot.clear_slot()
				
			if parent_node is StorageComponent:
				parent_node.storage_updated.emit()
			elif parent_node is Inventory:
				parent_node.inventory_updated.emit()
				
			_execute_drop_in_world(dropped_instance)

# ZMIENIAMY _unhandled_input TAK, ŻEBY OTWIERAŁO TYLKO EKWIPUNEK:
func _unhandled_input(event: InputEvent) -> void:
	# Otwieranie/Zamykanie ekwipunku
	if event.is_action_pressed(INPUT_TOGGLE_INVENTORY):
		if current_open_chest == null:
			toggle_player_inventory()
		else:
			_close_all_ui()
		get_viewport().set_input_as_handled()
		
	# --- TUTAJ OBSŁUGUJEMY KLAWISZ CRAFTINGU ---
	# Wpisz tu dokładną nazwę swojej akcji z Input Map (np. "ToggleCrafting" lub "Crafting")
	elif event.is_action_pressed(INPUT_TOGGLE_CRAFTING): 
		toggle_crafting_ui()
		get_viewport().set_input_as_handled()
	
	# --- Otwieranie Mapy ---
	elif event.is_action_pressed(INPUT_TOGGLE_MAP):
		toggle_map_ui()
		get_viewport().set_input_as_handled()

# --- LOGIKA MINECRAFTOWA (KLIKNIĘCIA) ---

func _on_slot_clicked(parent_node: Node, slot_index: int, button_index: int) -> void:
	var target_slot: SlotData
	
	if parent_node is StorageComponent:
		target_slot = parent_node.slots[slot_index]
	elif parent_node is Inventory:
		# Przechwytywanie kliknięcia w plecak
		if slot_index == -2:
			target_slot = parent_node.backpack_slot
		else:
			target_slot = parent_node.slots[slot_index]
	else:
		return

	if button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(target_slot)
	elif button_index == MOUSE_BUTTON_RIGHT:
		# Prawy klik na plecak go ignoruje (nie dzielimy plecaka na pół)
		if slot_index == -2:
			_handle_left_click(target_slot) 
		else:
			_handle_right_click(target_slot)
	elif button_index == -1: 
		# --- ZAKTUALIZOWANA Logika dla Shift + Klik ---
		if slot_index == -2:
			# Zdejmujemy plecak
			_handle_quick_unequip_backpack()
		else:
			# Jeśli skrzynia JEST otwarta, priorytetem jest zawsze przerzucenie przedmiotu do niej
			if current_open_chest != null:
				_handle_quick_transfer(parent_node, slot_index)
			else:
				# Jeśli jesteśmy tylko w swoim ekwipunku, próbujemy założyć plecak
				if not _try_quick_equip_backpack(parent_node, slot_index):
					_handle_quick_transfer(parent_node, slot_index)

	_update_cursor_visuals()
	
	if parent_node is StorageComponent:
		parent_node.storage_updated.emit()
	elif parent_node is Inventory:
		parent_node.inventory_updated.emit()

func _handle_left_click(slot: SlotData) -> void:
	# --- SPECJALNA LOGIKA: SLOT PLECACA ---
	if player_inventory != null and slot == player_inventory.backpack_slot:
		if item_in_hand == null:
			if not slot.is_empty():
				item_in_hand = player_inventory.unequip_backpack()
		else:
			# ZMIANA ECS: Zamiast "is BackpackItem", szukamy BackpackComponent
			var is_backpack = false
			if item_in_hand.data.components != null:
				for comp in item_in_hand.data.components:
					if comp is BackpackComponent:
						is_backpack = true
						break
			
			if is_backpack:
				# Odczyt ze słownika
				var hand_amount = item_in_hand.state.get("amount", 1)
				if hand_amount > 1:
					var unique_data = item_in_hand.data.duplicate(true)
					var single_bp = ItemInstance.new(unique_data, 1)
					
					if item_in_hand.state.has("durability"):
						single_bp.state["durability"] = item_in_hand.state["durability"]
						
					item_in_hand.state["amount"] = hand_amount - 1
					var old_bp = player_inventory.equip_backpack(single_bp)
					if old_bp != null:
						var remainder = player_inventory.add_instance(old_bp)
						if remainder != null:
							player_inventory.item_dropped.emit(remainder, false)
				else:
					var leftover = player_inventory.equip_backpack(item_in_hand)
					item_in_hand = leftover
			else:
				print("W to miejsce można założyć tylko plecak!")
		return

	# --- ZWYKŁA LOGIKA DLA INNYCH SLOTÓW ---
	if item_in_hand == null:
		if not slot.is_empty():
			item_in_hand = slot.item
			slot.clear_slot()
	else:
		if slot.is_empty():
			slot.item = item_in_hand
			item_in_hand = null
		else:
			if slot.item.can_stack_with(item_in_hand):
				# ZMIANA ECS: Szukamy max_stack w komponencie StackComponent
				var max_stack = 1
				if slot.item.data.components != null:
					for comp in slot.item.data.components:
						if comp is StackComponent:
							max_stack = comp.max_stack
							break
							
				var slot_amount = slot.item.state.get("amount", 1)
				var hand_amount = item_in_hand.state.get("amount", 1)
				var available_space = max_stack - slot_amount
				
				if available_space > 0:
					var amount_to_add = min(available_space, hand_amount)
					slot.item.state["amount"] = slot_amount + amount_to_add
					item_in_hand.state["amount"] = hand_amount - amount_to_add
					
					if item_in_hand.state["amount"] <= 0:
						item_in_hand = null
			else:
				var temp_item = slot.item
				slot.item = item_in_hand
				item_in_hand = temp_item

func _handle_right_click(slot: SlotData) -> void:
	if item_in_hand == null:
		if not slot.is_empty():
			var slot_amount = slot.item.state.get("amount", 1)
			if slot_amount > 1:
				@warning_ignore("integer_division")
				var half_amount = int(slot_amount / 2) 
				
				var unique_data = slot.item.data.duplicate(true)
				item_in_hand = ItemInstance.new(unique_data, half_amount)
				
				# --- OSTATECZNA ZMIANA ECS: Klonujemy CAŁY słownik state ---
				item_in_hand.state = slot.item.state.duplicate(true)
				item_in_hand.state["amount"] = half_amount
					
				slot.item.state["amount"] = slot_amount - half_amount
			else:
				item_in_hand = slot.item
				slot.clear_slot()
	else:
		if slot.is_empty():
			var unique_data = item_in_hand.data.duplicate(true)
			slot.item = ItemInstance.new(unique_data, 1)
			
			# --- OSTATECZNA ZMIANA ECS: Klonujemy CAŁY słownik state ---
			slot.item.state = item_in_hand.state.duplicate(true)
			slot.item.state["amount"] = 1
				
			var hand_amount = item_in_hand.state.get("amount", 1)
			item_in_hand.state["amount"] = hand_amount - 1
			if item_in_hand.state["amount"] <= 0:
				item_in_hand = null
				
		elif slot.item.can_stack_with(item_in_hand):
			var max_stack = 1
			if slot.item.data.components != null:
				for comp in slot.item.data.components:
					if comp is StackComponent:
						max_stack = comp.max_stack
						break
						
			var slot_amount = slot.item.state.get("amount", 1)
			var hand_amount = item_in_hand.state.get("amount", 1)
			
			if slot_amount < max_stack:
				slot.item.state["amount"] = slot_amount + 1
				item_in_hand.state["amount"] = hand_amount - 1
				if item_in_hand.state["amount"] <= 0:
					item_in_hand = null

func _handle_quick_transfer(from_node: Node, slot_index: int) -> void:
	if not current_open_chest or not player_inventory: return 
	
	if from_node is StorageComponent:
		var instance_to_move = from_node.remove_instance(slot_index)
		if instance_to_move != null:
			var remainder = player_inventory.add_instance(instance_to_move)
			if remainder != null:
				from_node.insert_instance(remainder)

	elif from_node is Inventory: 
		var slot_data = from_node.slots[slot_index]
		if not slot_data.is_empty():
			var instance_to_move = slot_data.item 
			slot_data.clear_slot()
			
			var remainder = current_open_chest.insert_instance(instance_to_move)
			if remainder != null:
				player_inventory.add_instance(remainder)

func _handle_quick_unequip_backpack() -> void:
	if not player_inventory or player_inventory.backpack_slot.is_empty():
		return
		
	# Zdejmujemy plecak do zmiennej.
	# UWAGA: Ta funkcja w inventory.gd z miejsca uetnie ekwipunek i WYRZUCI nadmiar przedmiotów na ziemię
	var backpack_to_unequip = player_inventory.unequip_backpack()
	
	# Teraz próbujemy dodać ściągnięty plecak w wolne miejsce pomniejszonego już ekwipunku
	var remainder = player_inventory.add_instance(backpack_to_unequip)
	
	# Jeśli z jakiegoś powodu w ekwipunku bazowym (np. w Twoich domyślnych 4 slotach) 
	# nie ma miejsca, ściągnięty plecak musi upaść na ziemię.
	if remainder != null:
		player_inventory.item_dropped.emit(remainder, false)
		print("Brak miejsca w ekwipunku! Ściągnięty plecak upada na ziemię.")

func _try_quick_equip_backpack(from_node: Node, slot_index: int) -> bool:
	if not player_inventory: 
		return false
		
	if from_node is Inventory:
		var slot_data = from_node.slots[slot_index]
		
		# ZMIANA ECS: Szukamy klocka BackpackComponent
		var is_backpack = false
		if not slot_data.is_empty() and slot_data.item.data.components != null:
			for comp in slot_data.item.data.components:
				if comp is BackpackComponent:
					is_backpack = true
					break
		
		if is_backpack:
			if player_inventory.backpack_slot.is_empty():
				var unique_data = slot_data.item.data.duplicate(true)
				var single_bp = ItemInstance.new(unique_data, 1)
				
				if slot_data.item.state.has("durability"):
					single_bp.state["durability"] = slot_data.item.state["durability"]
				
				var slot_amount = slot_data.item.state.get("amount", 1)
				slot_data.item.state["amount"] = slot_amount - 1
				if slot_data.item.state["amount"] <= 0:
					slot_data.clear_slot()
					
				player_inventory.equip_backpack(single_bp)
				return true
				
	return false

func _update_cursor_visuals() -> void:
	if item_in_hand != null:
		cursor_item_rect.texture = item_in_hand.data.item_icon
		cursor_item_rect.show()
		
		# ZMIANA ECS
		var hand_amount = item_in_hand.state.get("amount", 1)
		if hand_amount > 1:
			cursor_amount_label.text = str(hand_amount)
			cursor_amount_label.show()
		else:
			cursor_amount_label.hide()
	else:
		cursor_item_rect.texture = null
		cursor_item_rect.hide()
		cursor_amount_label.hide()

# Zwraca true, jeśli otwarty jest JAKIKOLWIEK panel interfejsu
func is_any_ui_open() -> bool:
	return is_player_inventory_open or current_open_chest != null or is_crafting_open or is_map_open

# Bezpieczna symulacja kliknięcia uwzględniająca zarówno przyciski, jak i sloty
func _simulate_mouse_click(button_idx: int, is_pressed: bool) -> void:
	var hovered = get_viewport().gui_get_hovered_control()
	if hovered == null:
		return

	var target = hovered
	while target != null:
		# 1. Jeśli to natywny przycisk (np. w menu craftingu / interfejsie)
		if target is BaseButton:
			if is_pressed and button_idx == MOUSE_BUTTON_LEFT:
				target.emit_signal("pressed")
			return
		
		# 2. Jeśli to nasz customowy element ze skryptem (np. InventorySlot)
		if target.has_method("_gui_input"):
			var ev = InputEventMouseButton.new()
			ev.button_index = button_idx
			ev.pressed = is_pressed
			ev.position = target.get_local_mouse_position()
			target._gui_input(ev)
			return
			
		target = target.get_parent()

# [NOWOŚĆ] Magnetyczne przyciąganie wirtualnej myszki do przycisków
func _on_gui_focus_changed(control: Control) -> void:
	if is_any_ui_open() and control != null:
		# Obliczamy środek zaznaczonego elementu
		var center_pos = control.get_global_rect().get_center()
		# Teleportujemy systemową myszkę idealnie na środek przycisku
		get_viewport().warp_mouse(center_pos)

# Pomocnicza funkcja do pokazywania/ukrywania slotu na plecak
func _set_backpack_ui_visible(show_slot: bool) -> void:
	if backpack_panel:
		backpack_panel.visible = show_slot
