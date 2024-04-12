extends Node3D

@export
var zoom_speed:float

@export
var move_speed:float

var game_mgr
# Called when the node enters the scene tree for the first time.
func _ready():
	game_mgr = GameManager.instance

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not game_mgr.control_mode == GameManager.ControlMode.Manual:
		var move_input = Input.get_vector("move_left","move_right","move_forward","move_back")
		var delta_pos = Vector3(move_input.x,0,move_input.y)
		var zoom = 0
		if Input.is_action_just_released("zoom_in") or Input.is_key_pressed(KEY_Z):
			zoom = 1
		elif Input.is_action_just_released("zoom_out") or Input.is_key_pressed(KEY_X):
			zoom = -1
		delta_pos*=move_speed*delta
		delta_pos.y = zoom_speed*delta*zoom
		
		position += delta_pos
		
func set_active(v):
	$Camera3D.current = v
	if v:
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		process_mode = Node.PROCESS_MODE_DISABLED
