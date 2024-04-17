extends Node3D

var target:Node3D
@export
var offset:Vector3
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_instance_valid(target):
		position = offset + target.global_position

func set_active(v):
	$Camera3D.current = v
	if v:
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		process_mode = Node.PROCESS_MODE_DISABLED
