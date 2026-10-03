class_name PassiveItemComponent
extends ItemComponent

enum PassiveRequirement { INVENTORY, HELD }

@export_category("Pasywne Działanie")
## Gdzie przedmiot musi się znajdować, by pasywka działała?
@export var requirement: PassiveRequirement = PassiveRequirement.INVENTORY

@export var passive_buffs: Array[Effect] = []

## Jeśli true, efekty stackują się z każdą kolejną sztuką. 
## Jeśli false, liczy się tylko fakt posiadania minimum 1 sztuki.
@export var stack_effects_with_amount: bool = false
