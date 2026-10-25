extends Node2D

# HP arc (blue): follows your aim, its ends sit at the character's front corners
@export var hp_radius = 50.0           # just outside the sprite's corners
@export var hp_span_deg = 250.0        # long way around, open at the front between the two corners
@export var hp_width = 6.0
@export var aim_follow_speed = 12.0    # lower = the arc lags more behind your aim

# Stamina arc (yellow): fixed under the player, doesn't rotate
@export var stamina_radius = 62.0
@export var stamina_span_deg = 80.0
@export var stamina_width = 6.0

# Colors
@export var back_color = Color(0, 0, 0, 0.45)
@export var hp_color = Color(0.3, 0.9, 1.0)
@export var stamina_color = Color(0.9, 0.85, 0.2)
@export var exhausted_color = Color.RED

var aim = 0.0            # real aim angle
var shown_aim = 0.0      # smoothed angle that gets drawn
var hp_ratio = 1.0       # 0..1	
var stamina_ratio = 1.0  # 0..1
var recover_ratio = 0.1  # where the threshold tick sits (0..1)
var exhausted = false

# Called once by the player
func setup(recover: float):
	recover_ratio = recover

# Called every frame by the player
func update_ring(hp: float, stamina: float, is_exhausted: bool, aim_angle: float):
	hp_ratio = hp
	stamina_ratio = stamina
	exhausted = is_exhausted
	aim = aim_angle

func _process(delta):
	shown_aim = lerp_angle(shown_aim, aim, 1.0 - exp(-aim_follow_speed * delta))
	queue_redraw()

func _draw():
	# --- HP arc: centered on the BACK of the player, ends at the front corners ---
	var back = shown_aim + PI
	var half = deg_to_rad(hp_span_deg) / 2.0
	draw_arc(Vector2.ZERO, hp_radius, back - half, back + half, 64, back_color, hp_width, true)
	var h = half * hp_ratio
	if h > 0.001:
		draw_arc(Vector2.ZERO, hp_radius, back - h, back + h, 64, hp_color, hp_width, true)

	# --- Stamina arc: follows the HP arc (centered on the back of the player) ---
	var s_half = deg_to_rad(stamina_span_deg) / 2.0
	var start = back + s_half            # fill begins at this end
	var s_span = s_half * 2.0
	draw_arc(Vector2.ZERO, stamina_radius, back - s_half, back + s_half, 32, back_color, stamina_width, true)
	if stamina_ratio > 0.001:
		var col = exhausted_color if exhausted else stamina_color
		draw_arc(Vector2.ZERO, stamina_radius, start - s_span * stamina_ratio, start, 32, col, stamina_width, true)

	# Threshold tick on the stamina arc
	var a = start - s_span * recover_ratio
	var d = Vector2.from_angle(a)
	draw_line(d * (stamina_radius - stamina_width), d * (stamina_radius + stamina_width), Color.WHITE, 2.0)
