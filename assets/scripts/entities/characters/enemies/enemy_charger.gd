extends EnemyEntity

# ---------------------------------------------------------------------------
#  CHARGER ENEMY
#  Stany:
#    IDLE      – fajrancik
#    SPOTTED   – namierza gracza i czeka
#    CHARGING  – biegnie po prostej do chargeTargetPos
#    RECOVERY  – chwila przerwy przed powrotem do IDLE
# ---------------------------------------------------------------------------

#region Export parameters
## How long the charger waits before lunging
@export var chargeWindup    : float = 0.9
## Speed of the lunge itself (overrides movement_universal_script.moveSpeed)
@export var chargeSpeed     : float = 950.0
## How long the charger is stunned after hitting something / reaching its target
@export var recoveryTime    : float = 0.6
## Distance at which the charge is considered "arrived" (pixels)
@export var arrivalThreshold: float = 24.0
#endregion

#region State machine
enum State { IDLE, SPOTTED, CHARGING, RECOVERY }
var state: State = State.IDLE

var windupTimer   : float   = 0.0
var recoveryTimer : float   = 0.0

## The world-space position the charger is lunging toward (frozen when lunge starts)
var chargeTargetPos : Vector2 = Vector2.ZERO
## Unit vector for the lunge direction (frozen when lunge starts)
var chargeDirection : Vector2 = Vector2.ZERO
#endregion

#region Line-of-sight
@onready var los_ray : RayCast2D = $LineOfSight
#endregion

# ---------------------------------------------------------------------------
func _ready():
	health_stats_script.max_health = 120
	health_stats_script.health     = 120

	interaction_and_attack_stats_script.hand_attack_data.damage  = 20
	interaction_and_attack_stats_script.hand_attack_cooldown      = 1.5

	respawnVector = Vector2(1080, 720)

	# Charger uses the nav agent only for IDLE roaming (not for the lunge itself)
	navigation_agent.navigation_finished.connect(_on_navigation_finished)

	super()

# ---------------------------------------------------------------------------
func has_line_of_sight() -> bool:
	if not target:
		return false
	los_ray.target_position = to_local(target.global_position)
	los_ray.force_raycast_update()
	if los_ray.is_colliding():
		return los_ray.get_collider() == target
	return false

func _on_navigation_finished():
	# Only relevant during IDLE roaming – nothing special needed for the charger
	pass

# ---------------------------------------------------------------------------
func _process(delta):
	super(delta)

func _physics_process(delta):
	process_melee_attack(delta)

	var in_range = target and global_position.distance_to(target.global_position) <= detectionDistance
	var can_see  = in_range and has_line_of_sight()

	match state:

		# ── IDLE ─────────────────────────────────────────────────────────────
		State.IDLE:
			if can_see:
				_enter_spotted()

		# ── SPOTTED (windup) ──────────────────────────────────────────────────
		State.SPOTTED:
			# Keep facing the player during the windup
			if target:
				var target_angle = global_position.angle_to_point(target.global_position)
				rotation = lerp_angle(rotation, target_angle, rotationSpeed * delta)

			windupTimer -= delta
			if windupTimer <= 0.0:
				_enter_charging()

		# ── CHARGING (lunge) ─────────────────────────────────────────────────
		State.CHARGING:
			var dist = global_position.distance_to(chargeTargetPos)

			if dist <= arrivalThreshold:
				# Reached the target position without hitting anything
				_enter_recovery()
			else:
				# Drive straight toward the frozen target position
				velocity = chargeDirection * chargeSpeed
				move_and_slide()

				# Check if we collided with anything solid this frame
				if get_slide_collision_count() > 0:
					_enter_recovery()

		# ── RECOVERY (post-lunge stun) ────────────────────────────────────────
		State.RECOVERY:
			# Bleed off momentum
			velocity = velocity.lerp(Vector2.ZERO, 0.25)
			move_and_slide()

			recoveryTimer -= delta
			if recoveryTimer <= 0.0:
				state = State.IDLE

# ---------------------------------------------------------------------------
#  State transition helpers
# ---------------------------------------------------------------------------

func _enter_spotted():
	state       = State.SPOTTED
	windupTimer = chargeWindup
	# Velocity should be zero while winding up
	velocity    = Vector2.ZERO

func _enter_charging():
	if not target:
		state = State.IDLE
		return

	# Freeze the target position so the lunge is a committed straight line
	chargeTargetPos = target.global_position
	chargeDirection = global_position.direction_to(chargeTargetPos)

	# Snap rotation to the lunge direction immediately
	rotation = chargeDirection.angle()

	state    = State.CHARGING

func _enter_recovery():
	state         = State.RECOVERY
	recoveryTimer = recoveryTime
