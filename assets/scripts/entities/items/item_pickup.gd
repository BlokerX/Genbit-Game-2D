extends RigidBody2D 
class_name ItemPickup

## Nasza nowa, potężna klasa przechowująca cały stan przedmiotu!
@export var item: ItemInstance

# Przydatne, jeśli kładziesz przedmiot ręcznie w edytorze do testów:
@export var test_item_data: ItemData
@export var test_amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel
@onready var pickup_area: Area2D = $PickupArea 

var can_pick_up: bool = false
var _is_locked: bool = false # Zabezpieczenie przed Race Condition i duplikacją

var _despawn_timer: float = 0.0
var _despawn_limit: float = 0.0 # Cache limitu czasu z GlobalSettings
var _original_prompt_suffix: String = "" # Zapisuje oryginalny dopisek z Labela

func _ready() -> void:
	z_index = GameLayers.LOOT
	
	# Optymalizacja: Pobieramy ustawienie tylko raz na starcie
	if "loot_despawn_time" in GlobalSettings:
		_despawn_limit = GlobalSettings.get("loot_despawn_time")
		
	if prompt_label != null:
		_original_prompt_suffix = prompt_label.text
	
	# FALLBACK: Jeśli postawiliśmy obiekt ręcznie w edytorze bez gotowej instancji
	if (item == null or item.data == null) and test_item_data != null:
		# TWORZYMY GŁĘBOKĄ KOPIĘ SZABLONU:
		var unique_data = test_item_data.duplicate(true)
		item = ItemInstance.new(unique_data, test_amount)
		
	# Odwołujemy się do grafiki poprzez item.data
	if item != null and item.data != null and item.data.item_icon != null:
		sprite.texture = item.data.item_icon
	
	pickup_area.area_entered.connect(_on_area_entered)
	
	# Szukamy naszego czujnika podświetlania (InteractableComponent) i podłączamy sygnały!
	for child in get_children():
		if child is InteractableComponent:
			# Reakcja na kliknięcie/użycie:
			child.collected.connect(_on_interacted)
			
			# Reakcja na namierzenie i odznaczenie celownikiem:
			child.targeted.connect(_on_targeted)
			child.untargeted.connect(_on_untargeted)
			break
	
	can_pick_up = true
	
	# Pobieramy nazwę poprzez item.data i aktualizujemy wyświetlanie
	_update_prompt()
	prompt_label.hide() # Na starcie ukrywamy napis

func _physics_process(delta: float) -> void:
	# Bezpiecznie sprawdzamy czy opcja w ogóle istnieje w GlobalSettings (teraz z użyciem cache!)
	if _despawn_limit > 0.0:
		_despawn_timer += delta
		if _despawn_timer >= _despawn_limit:
			queue_free()
			print("Przedmiot został usunięty z powodu przekroczenia limitu czasu leżąc.")

## Aktualizuje etykietę, uwzględniając obecną ilość w stosie
func _update_prompt() -> void:
	if item != null and item.data != null and prompt_label != null:
		var current_amount = item.state.get("amount", 1)
		var text = item.data.item_name
		
		# Dodajemy licznik tylko jeśli przedmiotów jest więcej niż 1
		if current_amount > 1:
			text += " (x" + str(current_amount) + ")"
		
		if _original_prompt_suffix != "":
			text += "\n" + _original_prompt_suffix
			
		prompt_label.text = text

# --- FUNKCJE OD ETYKIETY ---

func _on_targeted() -> void:
	# Pokazujemy etykietę tylko wtedy, gdy przedmiot można już podnieść i nie znika
	if can_pick_up and not is_queued_for_deletion():
		if prompt_label != null:
			prompt_label.show()

func _on_untargeted() -> void:
	# Chowamy etykietę, gdy zjedziemy z niej celownikiem
	if prompt_label != null:
		prompt_label.hide()


## Funkcja obsługująca wchłanianie innych przedmiotów z ziemi
func _on_area_entered(area: Area2D) -> void:
	var other_pickup = area.get_parent()
	if other_pickup is ItemPickup and other_pickup != self:
		# Deterministyczne decydowanie, kto przetwarza fuzję (zapobiega pętli)
		if get_instance_id() < other_pickup.get_instance_id(): return
		
		# Zabezpieczenie przed usuwanymi oraz zablokowanymi elementami (Race Condition)
		if self.is_queued_for_deletion() or other_pickup.is_queued_for_deletion(): return
		if self._is_locked or other_pickup.get("_is_locked") == true: return
		
		if item == null or item.data == null or other_pickup.item == null or other_pickup.item.data == null: return
		
		if item.can_stack_with(other_pickup.item):
			var max_stack = 1
			if item.data.components != null:
				for comp in item.data.components:
					if comp is StackComponent:
						max_stack = comp.max_stack
						break
			
			var my_amount = item.state.get("amount", 1)
			var other_amount = other_pickup.item.state.get("amount", 1)
			var available_space = max_stack - my_amount
			
			# WYKONUJEMY BLOKADĘ TYLKO GDY JEST WOLNE MIEJSCE
			if available_space > 0:
				# Zamrażamy oba przedmioty dla gracza na czas trwania obliczeń
				self._is_locked = true
				other_pickup.set("_is_locked", true)
				
				var amount_to_take = min(available_space, other_amount)
				
				# Aktualizujemy główny pickup
				item.state["amount"] = my_amount + amount_to_take
				if item.has_signal("state_changed"):
					item.state_changed.emit()
				_update_prompt()
				
				# Aktualizujemy wysysany pickup
				other_pickup.item.state["amount"] = other_amount - amount_to_take
				if other_pickup.item.has_signal("state_changed"):
					other_pickup.item.state_changed.emit()
					
				if other_pickup.item.state["amount"] <= 0:
					other_pickup.queue_free()
				else:
					# Jeśli coś zostało z tamtego przedmiotu, odblokuj go i zaktualizuj napis
					other_pickup.call("_update_prompt")
					other_pickup.set("_is_locked", false)
					
				# Zdejmujemy naszą blokadę
				self._is_locked = false

## Funkcja wywoływana, gdy Gracz celuje w przedmiot i wciska "Interact" (lub klika myszką)
func _on_interacted(interactor: Node) -> void:
	if not can_pick_up or is_queued_for_deletion() or _is_locked: 
		return
	if item == null or item.data == null: 
		return
		
	# Zamykamy dostęp dla innych interakcji z tym ciałem fizycznym (Race Condition lock)
	_is_locked = true 

	# Duck Typing: Nieważne czy to gracz, czy NPC. Ważne czy ma metodę get_inventory()!
	if interactor.has_method("get_inventory"):
		var inventory = interactor.get_inventory() 
		
		if inventory != null:
			var original_amount: int = item.state.get("amount", 1)
			# --- UŻYWAMY NASZEJ NOWEJ FUNKCJI ---
			# Przekazujemy całą instancję, zamiast rozbijać ją na item_data i amount
			var leftovers = inventory.add_instance(item)
			
			if leftovers == null:
				# Całość się zmieściła - usuwamy z ziemi
				if interactor.has_method("play_item_pickup_feedback"):
					interactor.call("play_item_pickup_feedback")
				queue_free()
			else:
				# Plecak jest pełny, aktualizujemy naszą instancję na ziemi by zachowała resztki
				item = leftovers
				_update_prompt()
				_is_locked = false # Odblokowujemy obiekt by gracz mógł zwolnić na niego miejsce
				
				if (
					int(item.state.get("amount", 1)) < original_amount
					and interactor.has_method("play_item_pickup_feedback")
				):
					interactor.call("play_item_pickup_feedback")
		else:
			# Zabezpieczenie: jeśli inventory jest zepsute, pozwalamy na ponowną próbę podniesienia
			_is_locked = false 
	else:
		# Zabezpieczenie: interaktor nie umie nosić przedmiotów
		_is_locked = false

## Odbieranie efektów środowiskowych (np. fali uderzeniowej z bomby)
func receive_effect(effect: Effect) -> bool:
	# Przekazuje siebie (obiekt fizyczny) do efektu, pozwalając mu podziałać na ciało
	return effect.apply_effect(self)