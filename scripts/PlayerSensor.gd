class_name PlayerSensor extends Node

@export var radius_far:float
@export var radius_near:float
@export var detect_shape:Shape3D
@export_flags_3d_physics var collision_mask

var owner_id:int
var owner_field_id:int
var query_param: PhysicsShapeQueryParameters3D
var space:PhysicsDirectSpaceState3D

const NEAR = 1
const MED = 2
const FAR = 3

const Center = 1
const Right = 2
const Left = 3
const Behind = 4

class SensorData:
	class PlayerData:
		var hp:int
		var move_dir:float
		var aim_dir:float
		var is_moving:bool
		var shoot_cd_left:float
		var terrain_info:Array[float]
		
	class MobData:
		var amount:int
		var hp_total:int
		var move_dir:Array[int]
	
	class BulletData:
		var amount:int
		var dir_info:Array[int]
	
	var player_data:PlayerData=PlayerData.new()
	
	var mob_data_near:Array[MobData]=[]
	var mob_data_med:Array[MobData]=[]
	var mob_data_far:Array[MobData]=[]
	
	var mob_bullet_data={}
	
	var player_bullet_data={}

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

func get_angle(target, target_dir,origin):
	var dir = target.global_position - origin
	var dir_vec2 = Vector2(dir.x,dir.z)
	var aim_dir_vec2 = Vector2(target_dir.x,target_dir.z)
	return rad_to_deg(dir_vec2.angle_to(aim_dir_vec2))
	
func get_region(target, target_dir,origin):
	var angle = get_angle(target,target_dir,origin)
	if absf(angle) < 5:
		return Center
	elif angle<90:
		return Left
	else:
		return Behind

func analyse_bullets(source, dist):
	var origin :Vector3 = owner.global_position
	dist[NEAR] = [0,0,0,0]
	dist[MED] = [0,0,0,0]
	dist[FAR] = [0,0,0,0]
	for bullet in source:
		var d = origin.distance_to(bullet.global_position)
		if d<radius_near:
			#dist[NEAR][self.get_region(bullet,)]
			pass

func gether_sensor_data():
	query_param.transform.origin = owner.global_position
	var result = space.intersect_shape(query_param)
	var monsters = []
	var bullet_monster = []
	var bullet_player = []
	
	var sensor_data = SensorData.new()
	#分类整理
	for hit_result in result:
		var obj = hit_result.collider
		if obj is Mob:
			monsters.append(obj)
		else:
			var obj_owner = obj.owner
			if obj_owner is Bullet:
				if obj_owner.instigator is Player:
					bullet_player.append(obj_owner)
				elif obj_owner is Mob:
					bullet_monster.append(obj_owner)
	#计算分区信息
	
	return sensor_data
