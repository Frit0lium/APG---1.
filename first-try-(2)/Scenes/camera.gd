extends Camera2D

# How far the camera can move toward the mouse
@export var lead = 0.2              # 0 = stays on the player, 1 = moves all the way to the mouse
@export var max_distance = 80.0     # the camera area: the most it can move away from the player (pixels)
@export var speed = 3.0             # lower = slower, floatier camera
@export var peek_multiplier = 2.0   # bigger area while holding the optional "peek" key

func _physics_process(delta):
	# Mouse position relative to the center of the screen
	# (measured on screen so the camera moving doesn't change the result)
	var from_center = (get_viewport().get_mouse_position() - get_viewport_rect().size / 2.0) / zoom

	var l = lead
	var reach = max_distance
	if InputMap.has_action("peek") and Input.is_action_pressed("peek"):
		l = min(lead * peek_multiplier, 1.0)
		reach *= peek_multiplier

	var target = (from_center * l).limit_length(reach)
	offset = offset.lerp(target, 1.0 - exp(-speed * delta))
