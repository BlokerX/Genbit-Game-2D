class_name LightSourceComponent
extends ItemComponent
## Komponent przedmiotów emitujących światło po wzięciu do ręki (pochodnia, latarka).

@export_category("Ustawienia Światła")
## Moc świecenia przedmiotu w dłoni.
@export var light_energy: float = 1.0
## Rozmiar (zasięg) światła.
@export var light_scale: float = 1.0
## Kolor światła (np. pomarańczowy dla pochodni, biały dla latarki).
@export var light_color: Color = Color.WHITE

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	return "Źródło światła (Moc: " + str(light_energy) + ")\n"

func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	var text: String = "Moc Światła: " + str(light_energy) + "\n"
	if is_advanced:
		text += "Zasięg Światła: " + str(light_scale) + "\n"
	return text
