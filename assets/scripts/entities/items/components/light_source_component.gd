class_name LightSourceComponent
extends ItemComponent

@export_category("Ustawienia Światła")
## Moc świecenia przedmiotu w dłoni
@export var light_energy: float = 1.0

## Rozmiar (zasięg) światła
@export var light_scale: float = 1.0

## Kolor światła (np. pomarańczowy dla pochodni, biały dla latarki)
@export var light_color: Color = Color.WHITE
