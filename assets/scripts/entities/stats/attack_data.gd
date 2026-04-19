extends Resource
class_name AttackData

@export var damage : int = 10
@export var critical_damage : int = 0
@export var critical_rate : float = 0.0
@export var max_range : float = 1.0
@export var stun_time : float = 0.25

# Konstruktor, żeby łatwo tworzyć z kodu
func _init(_dmg: int = 10, _crit_dmg: int = 0, _crit_rate: float = 0.0, _max_range: float = 100.0, _stun: float = 0.25):
	damage = _dmg
	critical_damage = _crit_dmg
	critical_rate = _crit_rate
	max_range = _max_range
	stun_time = _stun
