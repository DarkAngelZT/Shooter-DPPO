class_name PlayerSensor extends Node

@export var radius_far:float
@export var radius_near:float
@export var detect_shape:Shape3D
@export_flags_3d_physics var collision_mask

var owner_id:int
var owner_field_id:int
var query_param: PhysicsShapeQueryParameters3D
var space:PhysicsDirectSpaceState3D

# Called when the node enters the scene tree for the first time.
func _ready():
	owner_id = owner.id
	owner_field_id = owner.field_id
	query_param = PhysicsShapeQueryParameters3D.new()
	query_param.collision_mask = collision_mask
	query_param.shape = detect_shape
	query_param.collide_with_bodies = true
	
	space = owner.get_world_3d().direct_space_state

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func gether_sensor_data():
	query_param.transform.origin = owner.global_position
	var result = space.intersect_shape(query_param)
	#分类整理
