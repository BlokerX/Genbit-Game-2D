@abstract
extends Resource
class_name AbilityComponent
## Abstrakcyjna klasa bazowa dla modularnych komponentów zdolności specjalnych AI (SOLID - SRP / OCP / DIP).
## Pozwala dowolnie komponować dodatkowe zachowania (wsparcie sojuszników, winieta ekranowa, amnezja NPC,
## wstrząs kamery, kradzież przedmiotu) w plikach .tres dla każdego archetypu zdolności bez duplikowania kodu.

## Wywoływane w momencie rozpoczęcia rzucania zdolności (przed fazą ładowania / lotu).
func on_cast_started(_ability: Resource, _attacker: CharacterEntity, _target: Variant) -> void:
	pass

## Wywoływane w momencie detonacji obszaru lub głównego impulsu/tiku zdolności.
func on_area_detonated(_ability: Resource, _attacker: CharacterEntity, _origin_pos: Vector2, _radius: float) -> void:
	pass

## Wywoływane dla każdego trafionego celu (po weryfikacji przynależności frakcyjnej).
func on_target_hit(_ability: Resource, _attacker: CharacterEntity, _target: Node2D, _origin_pos: Vector2) -> void:
	pass

## Wywoływane w chwili zakończenia lub przerwania zdolności (parametr attacker ma typ Variant dla bezpieczeństwa po await).
func on_cast_finished(_ability: Resource, _attacker: Variant) -> void:
	pass
