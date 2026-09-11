extends AIAbility
class_name JumpSmashAbility

@export var damage: int = 30
@export var stun_duration: float = 1.5

func _init():
	ability_name = "Miażdżący Skok"
	cooldown = 8.0
	min_range = 50.0
	max_range = 250.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	print(attacker.name + " używa umiejętności: " + ability_name)
	
	# Tworzymy potężny atak bezpośrednio wymierzony w gracza
	var dmg_effect = DamageEffect.new(damage)
	dmg_effect.source_entity = attacker
	dmg_effect.source_position = attacker.global_position
	
	var stun_eff = StunEffect.new(stun_duration)
	
	if target.has_method("receive_effect"):
		target.receive_effect(dmg_effect)
		target.receive_effect(stun_eff)
