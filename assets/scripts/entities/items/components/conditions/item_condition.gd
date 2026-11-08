class_name ItemCondition
extends Resource
## Abstrakcyjna klasa bazowa dla warunków użycia przedmiotu (SOLID - OCP).
## Jeśli check_condition() zwróci false, przypisany ItemComponent nie zostanie wykonany.

const DEFAULT_CONDITION_DESCRIPTION: String = "Zablokowane warunkiem"

@export_group("Opis Warunku (UI)")
## Opcjonalny własny opis wyświetlany w panelu informacji o przedmiocie.
## Jeśli zostawisz puste, użyty zostanie domyślny tekst konkretnej klasy warunku.
@export var custom_condition_description: String = ""

## Sprawdza, czy podmiot (actor) spełnia warunek użycia przedmiotu (_item).
func check_condition(_actor: Node2D, _item: ItemInstance) -> bool:
	return true

## Zwraca czytelny dla gracza opis wymogu wyświetlany w UI (zgodnie z zasadą OCP).
func get_condition_description() -> String:
	if custom_condition_description != "":
		return custom_condition_description
	return DEFAULT_CONDITION_DESCRIPTION
