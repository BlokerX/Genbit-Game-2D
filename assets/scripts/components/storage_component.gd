class_name StorageComponent
extends Node

#region Storage stats
## Rozmiar skrzyni
@export var slots_amount: int = 16

## Używamy tej samej klasy SlotData co w inventory.gd
@export var slots: Array[SlotData] = []

#endregion

#region Signals

## Sygnał do powiadomienia UI o zmianie zawartości
signal storage_updated

## Sygnał wysyłany do UI po wejściu w interakcję ze skrzynią
signal storage_opened(storage_reference: StorageComponent)

#endregion

@onready var interactable_comp: Node = $"../InteractableComponent" # todo rozwiązać to lepiej

## Inicjalizacja pustych slotów wzorowana na inventory.gd
func _init() -> void:
	slots.resize(slots_amount)
	for i in range(slots_amount):
		slots[i] = SlotData.new()

func _ready() -> void:
	# Naprawa rozmiaru tablicy po nadpisaniu przez Inspektor
	if slots.size() < slots_amount:
		slots.resize(slots_amount)
		
	# Upewniamy się, że żaden slot nie jest "null" i ODKLEJAMY referencje
	for i in range(slots_amount):
		if slots[i] == null:
			slots[i] = SlotData.new()
		else:
			# ZABEZPIECZENIE: Odróżniamy od siebie sloty sklonowane w edytorze
			slots[i] = slots[i].duplicate(true)
			
			# Jeśli w slocie startowym jest przedmiot, upewniamy się, 
			# że jego instancja i dane również są unikalne
			if not slots[i].is_empty():
				slots[i].item = slots[i].item.duplicate(true)
				slots[i].item.data = slots[i].item.data.duplicate(true)

	# Podpinamy się pod komponent interakcji (ten kod już tu miałeś)
	if interactable_comp and interactable_comp.has_signal("interacted"):
		interactable_comp.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	# Wysyłamy w świat informację: "Otwórzcie interfejs dla tego magazynu!"
	EventBus.open_storage_ui.emit(self)


# ----------------------------------------------------
# --- ZARZĄDZANIE INSTANCJAMI (Kompatybilne z ECS) ---
# ----------------------------------------------------

## Przyjmuje instancję do skrzyni (automatyczne szukanie miejsca)
## Zwraca null jeśli wszystko weszło, lub resztę instancji, jeśli zabrakło miejsca.
func insert_instance(instance_to_add: ItemInstance) -> ItemInstance:
	# ZMIANA: Czytamy ilość ze słownika 'state'
	var add_amount = instance_to_add.state.get("amount", 1) if instance_to_add != null else 0
	if instance_to_add == null or add_amount <= 0:
		return null
		
	# ZMIANA: Szukamy komponentu StackComponent zamiast czytać zmienną z ItemData
	var is_stackable = false
	var max_stack = 1
	if instance_to_add.data.components != null:
		for comp in instance_to_add.data.components:
			if comp is StackComponent:
				is_stackable = true
				max_stack = comp.max_stack
				break

	# 1. Próbujemy uzupełnić istniejące stosy
	if is_stackable:
		for slot in slots:
			if not slot.is_empty() and slot.item.can_stack_with(instance_to_add):
				var slot_amount = slot.item.state.get("amount", 1)
				var available_space = max_stack - slot_amount
				
				if available_space > 0:
					# ZMIANA: Modyfikujemy słownik state zamiast zmiennej amount
					var adding = min(instance_to_add.state.get("amount", 1), available_space)
					slot.item.state["amount"] = slot_amount + adding
					instance_to_add.state["amount"] = instance_to_add.state.get("amount", 1) - adding
					
					if instance_to_add.state["amount"] <= 0:
						storage_updated.emit()
						return null # Całość się zmieściła w stosie
						
	# 2. Szukamy dowolnego pustego slota od lewej
	for slot in slots:
		if slot.is_empty():
			slot.item = instance_to_add
			storage_updated.emit()
			return null # Przedmiot zajął pusty slot
			
	# Brak miejsca - zwracamy instancję z powrotem do gracza/na ziemię
	return instance_to_add

## Wkłada instancję do KONKRETNEGO slotu (przydatne przy Drag & Drop w UI)
## Zwraca stary item (jeśli slot był zajęty) lub null, jeśli się udało.
func insert_instance_at(instance_to_add: ItemInstance, slot_index: int) -> ItemInstance:
	if slot_index < 0 or slot_index >= slots_amount:
		return instance_to_add
		
	var slot = slots[slot_index]
	
	# Jeśli slot jest pusty
	if slot.is_empty():
		slot.item = instance_to_add
		storage_updated.emit()
		return null
		
	# Jeśli w slocie jest ten sam przedmiot - sprawdzamy czy można go stackować
	if slot.item.can_stack_with(instance_to_add):
		# ZMIANA: Znowu musimy znaleźć StackComponent dla przedmiotu w slocie
		var max_stack = 1
		if slot.item.data.components != null:
			for comp in slot.item.data.components:
				if comp is StackComponent:
					max_stack = comp.max_stack
					break
					
		var slot_amount = slot.item.state.get("amount", 1)
		var available_space = max_stack - slot_amount
		
		if available_space > 0:
			var adding = min(instance_to_add.state.get("amount", 1), available_space)
			# ZMIANA: Modyfikujemy słownik state
			slot.item.state["amount"] = slot_amount + adding
			instance_to_add.state["amount"] = instance_to_add.state.get("amount", 1) - adding
			
			if instance_to_add.state["amount"] <= 0:
				storage_updated.emit()
				return null
		else:
			storage_updated.emit()
			return instance_to_add # Zwraca resztę, która nie weszła do stacka
			
	# Jeśli w slocie jest inny przedmiot (lub brak miejsca) - Zamieniamy je miejscami!
	var old_instance = slot.item
	slot.item = instance_to_add
	storage_updated.emit()
	return old_instance

## Wyciąga całą instancję (lub część) ze slotu. Zwraca wyciągnięty ItemInstance.
func remove_instance(slot_index: int, amount_to_remove: int = -1) -> ItemInstance:
	if slot_index < 0 or slot_index >= slots_amount:
		return null
		
	var slot = slots[slot_index]
	if slot.is_empty():
		return null
		
	var extracted_instance
	var current_slot_amount = slot.item.state.get("amount", 1)
	
	# Scenariusz 1: Zabieramy cały stack (lub wpisano wartość -1)
	if amount_to_remove == -1 or amount_to_remove >= current_slot_amount:
		extracted_instance = slot.item
		slot.clear_slot()
		storage_updated.emit()
		return extracted_instance
		
	# Scenariusz 2: Zabieramy tylko część sztuk (np. Shift+Click lub prawy przycisk myszy)
	var unique_data = slot.item.data.duplicate(true)
	extracted_instance = ItemInstance.new(unique_data, amount_to_remove)
	
	# ZMIANA: Klonujemy zużycie (jeśli istnieje) używając słownika state!
	if slot.item.state.has("durability"):
		extracted_instance.state["durability"] = slot.item.state["durability"]
		
	# Zdejmujemy zabraną ilość z oryginalnego slotu
	slot.item.state["amount"] = current_slot_amount - amount_to_remove
	
	storage_updated.emit()
	return extracted_instance
