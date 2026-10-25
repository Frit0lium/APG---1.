extends CharacterBody2D

var aim_angle = 0.0
@onready var ring = $AimRing
@onready var sprite = $AnimatedSprite2D

# Health
var max_hp = 100.0
var hp = 100.0

var movespeed = 400 	# Speed
# Normal movement
var acceleration = 4000
var friction = 4000

# Sprinting
var glide_acceleration = 14000 	# Acceler..
var glide_friction = 2000		# Length of slide

# Speed
var sprint_multiplier = 2.0     # while holding Shift
var exhausted_multiplier = 0.5  # while exhausted

# Stamina
var max_stamina = 100.0
var stamina = 100.0
var stamina_drain = 20.0         # /s while sprinting
var stamina_regen = 10.0         # /s while not sprinting
var recover_threshold = 10.0     # needed to end exhaustion
var exhausted = false

func _ready():
	global_position = get_viewport_rect().size / 2
	ring.setup(recover_threshold / max_stamina)

func _physics_process(delta):
	var motion = Input.get_vector("left", "right", "up", "down")

	# End exhaustion once enough stamina has regenerated
	if exhausted and stamina >= recover_threshold:
		exhausted = false

	var is_sprinting = Input.is_action_pressed("Shift") and motion != Vector2.ZERO and not exhausted

	# Target speed
	var speed = movespeed
	if exhausted:		# Slowing cuz of stamina
		speed *= exhausted_multiplier
	elif is_sprinting:	# Sprint speed
		speed *= sprint_multiplier

	if is_sprinting:	# Drain stamina
		stamina -= stamina_drain * delta
		if stamina <= 0:
			stamina = 0
			exhausted = true
	else:				# Stamina regeneration
		stamina = min(stamina + stamina_regen * delta, max_stamina)

	# Inertia only while sprinting or still moving faster than normal speed
	var gliding = is_sprinting or velocity.length() > movespeed + 1 	# After Shift slowing down
	var accel = glide_acceleration if gliding else acceleration  		# If glide use slippery
	var fric = glide_friction if gliding else friction  				# If not glide use snappy

	if motion != Vector2.ZERO:
		velocity = velocity.move_toward(motion * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, fric * delta)

	move_and_slide()

	# Turn the sprite toward the mouse
	var dir = get_global_mouse_position() - global_position
	if dir.length() > 1.0:
		aim_angle = dir.angle()
		# The art faces UP, but angle 0 points right, so add 90°
		sprite.rotation = aim_angle + PI / 2

	# Walk animation while moving, idle frame while standing
	sprite.play("walk_up" if velocity.length() > 10.0 else "idle_up")

	# Send everything to the ring
	ring.update_ring(hp / max_hp, stamina / max_stamina, exhausted, aim_angle)

func take_damage(amount: float):
	hp = max(hp - amount, 0)
