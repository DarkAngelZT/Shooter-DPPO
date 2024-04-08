extends Marker3D

@export
var spwan_time:float

@export
var size_cube:Node3D

var size:Vector2
# Called when the node enters the scene tree for the first time.
func _ready():
	size_cube.visible = false
	var scale = size_cube.scale
	size.x = scale.x
	size.y = scale.z


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
