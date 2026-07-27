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

@onready var interactable_comp: Node = $"../InteractableComponent"

## Inicjalizacja pustych slotów wzorowana na inventory.gd
func _init() -> void:
	slots.resize(slots_amount)
	for i in range(slots_amount):
		slots[i] = SlotData.new()

func _ready() -> void:
	# --- NOWOŚĆ: Naprawa rozmiaru tablicy po nadpisaniu przez Inspektor ---
	if slots.size() < slots_amount:
		slots.resize(slots_amount)
		
	# Upewniamy się, że żaden slot nie jest "null"
	for i in range(slots_amount):
		if slots[i] == null:
			slots[i] = SlotData.new()

	# Podpinamy się pod komponent interakcji (ten kod już tu miałeś)
	if interactable_comp and interactable_comp.has_signal("interacted"):
		interactable_comp.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	# Wysyłamy w świat informację: "Otwórzcie interfejs dla tego magazynu!"
	EventBus.open_storage_ui.emit(self)


# ----------------------------------------------------
# --- ZARZĄDZANIE INSTANCJAMI (Kompatybilne z inventory.gd) ---
# ----------------------------------------------------

## Przyjmuje instancję do skrzyni (automatyczne szukanie miejsca)
## Zwraca null jeśli wszystko weszło, lub resztę instancji, jeśli zabrakło miejsca.
func insert_instance(instance_to_add: ItemInstance) -> ItemInstance:
	if instance_to_add == null or instance_to_add.amount <= 0:
		return null
		
	# 1. Próbujemy uzupełnić istniejące stosy
	if instance_to_add.data.item_is_stackable:
		for slot in slots:
			if not slot.is_empty() and slot.item.data.item_id == instance_to_add.data.item_id:
				var available_space = instance_to_add.data.item_max_stack_count - slot.item.amount
				if available_space > 0:
					var adding = min(instance_to_add.amount, available_space)
					slot.item.amount += adding
					instance_to_add.amount -= adding
					
					if instance_to_add.amount <= 0:
						storage_updated.emit()
						return null # Całość się zmieściła w stosie

	# 2. Szukamy dowolnego pustego slota od lewej
	for slot in slots:
		if slot.is_empty():
			slot.item = instance_to_add
			storage_updated.emit()
			return null
			
	# Brak miejsca - zwracamy instancję z powrotem
	return instance_to_add

## Wkłada instancję do KONKRETNEGO slotu (przydatne przy Drag & Drop w UI)
## Zwraca stary item (jeśli slot był zajęty) lub null, jeśli udało się położyć.
func insert_instance_at(instance_to_add: ItemInstance, slot_index: int) -> ItemInstance:
	if slot_index < 0 or slot_index >= slots_amount:
		return instance_to_add
		
	var slot = slots[slot_index]
	
	# Jeśli slot jest pusty
	if slot.is_empty():
		slot.item = instance_to_add
		storage_updated.emit()
		return null
		
	# Jeśli w slocie jest ten sam przedmiot i można go stackować
	if slot.item.data.item_id == instance_to_add.data.item_id and instance_to_add.data.item_is_stackable:
		var available_space = slot.item.data.item_max_stack_count - slot.item.amount
		if available_space > 0:
			var adding = min(instance_to_add.amount, available_space)
			slot.item.amount += adding
			instance_to_add.amount -= adding
			
			if instance_to_add.amount <= 0:
				storage_updated.emit()
				return null
			else:
				storage_updated.emit()
				return instance_to_add # Zwraca resztę, która nie weszła do stacka
				
	# Jeśli w slocie jest inny przedmiot (lub brak miejsca w stacku) - Zamieniamy je miejscami
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
	
	# Scenariusz 1: Zabieramy cały stack (lub wpisano wartość -1)
	if amount_to_remove == -1 or amount_to_remove >= slot.item.amount:
		extracted_instance = slot.item
		slot.clear_slot()
		storage_updated.emit()
		return extracted_instance
		
	# Scenariusz 2: Zabieramy tylko część sztuk (np. Shift+Click lub prawy przycisk myszy)
	# Tworzymy nową instancję na bazie starej
	extracted_instance = ItemInstance.new(slot.item.data, amount_to_remove)
	extracted_instance.durability = slot.item.durability # Klonujemy zużycie
	
	slot.item.amount -= amount_to_remove
	storage_updated.emit()
	
	return extracted_instance
