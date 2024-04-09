extends CharacterBody3D

@export
var player_id:int

@export
var character_mesh:Node3D

@export
var shoot_pos:Node3D

@export
var move_speed:float = 5

var can_shoot:bool = false
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func shoot():
	pass

func _physics_process(delta):
	if GameData.actor_info[player_id].hp<=0:
		return
	var input = GameData.player_input[player_id]
	if is_instance_valid(input):
		var direction = Vector3.ZERO
		direction.z = input.direction.y
		direction.x = input.direction.x
		character_mesh.basis = Basis.looking_at(direction)
		
		if input.move_state == GameData.Op_Move:
			var speed = direction * move_speed
			velocity = speed
			character_mesh.walk()
			move_and_slide()
		elif input.move_state == GameData.Op_Stop:
			velocity = Vector3.ZERO
			character_mesh.idle()
