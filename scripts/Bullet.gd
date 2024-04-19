extends Node3D

signal hit

@export
var speed:float = 0

@export_flags_3d_physics var collision_mask

var direction:Vector3
var space_state
# Called when the node enters the scene tree for the first time.
func _ready():
	space_state = get_world_3d().direct_space_state

func _physics_process(delta):
	var old_position = position
	var new_position = position + direction*(speed*delta)
	var query = PhysicsRayQueryParameters3D.create(old_position,new_position,collision_mask)
	var result = space_state.intersect_ray(query)
	if result:
		var target_pos = Vector3(position)
		target_pos.x = result.position.x
		target_pos.z = result.position.z
		on_hit(result.collider)
	else:
		position = new_position
	
func on_hit(other):
	hit.emit(other)
	queue_free()
