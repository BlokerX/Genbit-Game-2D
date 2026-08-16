class_name PlaceableComponent
extends ItemComponent

@export_category("Budowanie")
## Scena, która pojawi się na mapie po postawieniu tego przedmiotu
@export_file("*.tscn") var scene_path: String

func execute(actor: Node2D, _target: Node2D, _item_instance: ItemInstance) -> void:
	# Delegujemy akcję do gracza
	if actor.has_method("_start_building"):
		actor._start_building(self)
