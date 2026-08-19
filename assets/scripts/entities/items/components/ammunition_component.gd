class_name AmmunitionComponent
extends ItemComponent

@export_category("Ustawienia Amunicji")
# Pobieramy Enum prosto z broni dystansowej!
@export var ammunition_type: RangedWeaponComponent.AmmoType = RangedWeaponComponent.AmmoType.NONE
@export var override_projectile_texture: Texture2D
@export var damage: int = 10
@export var speed_multiplier: float = 1.0
@export var effects: Array[Effect] = []
