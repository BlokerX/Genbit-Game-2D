class_name LightSourceComponent
extends ItemComponent
## Komponent przedmiotów emitujących światło (pochodnia, latarka, świecący amulet).
## Obsługuje emisję światła zarówno podczas trzymania w dłoni, jak i po założeniu w slocie wyposażenia (np. Accessory).

## Określa, gdzie musi znajdować się przedmiot, aby emitował światło wokół postaci.
enum LightActivationScope {
	HELD_OR_EQUIPPED,  ## Świeci zarówno w aktywnej dłoni, jak i po założeniu w slocie zbroi/akcesoriów (Domyślne).
	WHEN_HELD,         ## Świeci wyłącznie wtedy, gdy postać trzyma przedmiot w aktywnej dłoni.
	WHEN_EQUIPPED,     ## Świeci wyłącznie po założeniu w slocie wyposażenia (np. Amulet / Accessory).
	WHEN_IN_INVENTORY  ## Świeci zawsze, dopóki przedmiot znajduje się w plecaku, dłoni lub slocie zbroi.
}

@export_category("Ustawienia Światła")
## Określa, w jakich miejscach ekwipunku ten przedmiot emituje światło.
@export var activation_scope: LightActivationScope = LightActivationScope.HELD_OR_EQUIPPED
## Moc świecenia przedmiotu (Energy przekazywane do PointLight2D gracza).
@export var light_energy: float = 1.0
## Rozmiar (zasięg) tekstury światła (texture_scale przekazywane do PointLight2D).
@export var light_scale: float = 1.0
## Kolor światła (np. pomarańczowy dla pochodni, biały dla latarki).
@export var light_color: Color = Color.WHITE

## Sprawdza, czy źródło światła jest aktywne w podanym kontekście slotu (Information Expert).
func is_light_active_in_context(is_equipped: bool, is_held: bool, is_in_inventory: bool) -> bool:
	match activation_scope:
		LightActivationScope.HELD_OR_EQUIPPED:
			return is_held or is_equipped
		LightActivationScope.WHEN_HELD:
			return is_held
		LightActivationScope.WHEN_EQUIPPED:
			return is_equipped
		LightActivationScope.WHEN_IN_INVENTORY:
			return is_in_inventory or is_held or is_equipped
	return false

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	return "Źródło światła (Moc: " + str(light_energy) + ")\n"

func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	var text: String = "Moc Światła: " + str(light_energy) + "\n"
	if is_advanced:
		text += "Zasięg Światła: " + str(light_scale) + "\n"
	return text
