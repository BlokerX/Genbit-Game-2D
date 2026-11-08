class_name AmmunitionComponent
extends ItemComponent
## Komponent amunicji określający kaliber, dodatkowe obrażenia pocisku oraz efekty specjalne nabojów.

@export_category("Ustawienia Amunicji")
@export var ammunition_type: RangedWeaponComponent.AmmoType = RangedWeaponComponent.AmmoType.NONE
@export var override_projectile_texture: Texture2D
@export var damage: int = 10
@export var speed_multiplier: float = 1.0
@export var effects: Array[Effect] = []

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	var text: String = "Typ Naboju: " + str(RangedWeaponComponent.AmmoType.keys()[ammunition_type]) + "\n"
	text += "Obrażenia Pocisku: " + str(damage) + "\n"
	if not effects.is_empty():
		for effect in effects:
			if effect != null:
				text += "- " + effect.effect_name + "\n"
	return text

func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	var text: String = "Typ Naboju: " + str(RangedWeaponComponent.AmmoType.keys()[ammunition_type]) + "\n"
	text += "Moc Pocisku: +" + str(damage) + "\n"
	if is_advanced:
		text += "Mnożnik Szybkości: x" + str(speed_multiplier) + "\n"
		if effects.size() > 0:
			text += "Efekty Naboju: " + str(effects.size()) + "\n"
	return text
