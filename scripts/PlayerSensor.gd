class_name PlayerSensor extends Node

@export var radius_far:float
@export var radius_near:float
@export var detect_shape:Shape3D
@export_flags_3d_physics var collision_mask
@export var terrain_detect_range:float = 9

var owner_id:int
var owner_field_id:int
var query_param: PhysicsShapeQueryParameters3D
var space:PhysicsDirectSpaceState3D

var terrain_rays = []

#region
const NEAR = 1
const MED = 2
const FAR = 3
#dir
const Center = 0x1
const Right = 0x2
const Left = 0x4
const Behind = 0x8

const Collision_Mask_Floor = 1

const RegionNums = [8,12,12]

class SensorData:
	class PlayerData:
		var hp:int
		var move_dir:float
		var aim_dir:float
		var is_moving:bool
		var shoot_cd_left:float
		var terrain_info:Array[float]
		
		var param_num:
			get:
				return 13
		
	class MobData:
		var amount:int = 0
		var region_dir_info:int = 0
		
		var param_num:
			get:
				return 2
		
	class BulletData:
		var amount:int = 0
		var dir_info:int = 0
		
		var param_num:
			get:
				return 2
	
	var player_data:PlayerData=PlayerData.new()
	
	var mob_data = {}#[region_id]->[MobData * section_num]
	
	var mob_bullet_data={} #[region_id]->[BulletData * section_num]
	
	var player_bullet_data={} #[region_id]->[BulletData * section_num]
	
	func get_nn_param_total()->int:
		var total = player_data.param_num
		for r in mob_data:
			total += mob_data[r][0].param_num * mob_data[r].size()
				
		for r in mob_bullet_data:
			total += mob_bullet_data[r][0].param_num * mob_bullet_data[r].size()
		
		for r in player_bullet_data:
			total += player_bullet_data[r][0].param_num * player_bullet_data[r].size()	
		return total

# Called when the node enters the scene tree for the first time.
func _ready():
	owner_id = owner.id
	owner_field_id = owner.field_id
	query_param = PhysicsShapeQueryParameters3D.new()
	query_param.collision_mask = collision_mask
	query_param.shape = detect_shape
	query_param.collide_with_bodies = true
	
	space = owner.get_world_3d().direct_space_state
	
	var forward = Vector3.FORWARD
	for i in range(8):
		terrain_rays.append(forward)
		forward = forward.rotated(Vector3.UP,45)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func get_angles(target, target_dir,origin):
	var dir = origin - target.global_position
	var dir_vec2 = Vector2(dir.x,dir.z)
	var aim_dir_vec2
	if target_dir is Vector3:
		aim_dir_vec2 = Vector2(target_dir.x,target_dir.z)
	else:
		aim_dir_vec2 = target_dir
	var aim_angle = rad_to_deg(dir_vec2.angle_to(aim_dir_vec2))
	var region_angle = rad_to_deg(dir_vec2.angle_to(Vector2.UP))
	return [region_angle,aim_angle]
	
func get_region_and_dir(target, target_dir,origin,region_num):
	var result = get_angles(target,target_dir,origin)
	var aim_angle = result[1]
	var region_angle = result[0]
	var region
	var dir
	var region_gap = 360.0/region_num
	if absf(aim_angle) < 5:
		dir = Center
	elif aim_angle<0 and aim_angle > -90:
		dir = Left
	elif aim_angle>0 and aim_angle < 90:
		dir = Right
	else:
		dir = Behind
	
	if region_angle>=0:
		region = floori(region_angle/region_gap)
	else:
		region = floori((360 + region_angle)/region_gap)
	
	return [region, dir]

func analyse_bullets(source, dist:Dictionary):
	dist.clear()
	var origin :Vector3 = owner.global_position
	dist[NEAR] = []
	dist[MED] = []
	dist[FAR] = []
	for i in range(NEAR,FAR+1):
		for r in range(RegionNums[i-1]):
			dist[i].append(SensorData.BulletData.new())
			
	for bullet in source:
		var d = origin.distance_to(bullet.global_position)
		var result
		#var region = result[0]
		#var dir = result[1]
		if d < radius_near:
			result = get_region_and_dir(bullet,bullet.direction,origin,RegionNums[0])
			dist[NEAR][result[0]].amount += 1
			dist[NEAR][result[0]].dir_info |= result[1]
		elif d < radius_far:
			result = get_region_and_dir(bullet,bullet.direction,origin,RegionNums[1])
			dist[MED][result[0]].amount  += 1
			dist[MED][result[0]].dir_info |= result[1]
		else:
			result = get_region_and_dir(bullet,bullet.direction,origin,RegionNums[2])
			dist[FAR][result[0]].amount  += 1
			dist[FAR][result[0]].dir_info |= result[1]

func analyse_mob(source:Array,dist:Dictionary):
	dist.clear()
	var origin :Vector3 = owner.global_position
	for i in range(NEAR,FAR+1):
		dist[i] = []
		for r in range(RegionNums[i-1]):
			dist[i].append(SensorData.MobData.new())
	
	for mob in source:
		var d = origin.distance_to(mob.global_position)
		var area
		if d < radius_near:
			area = NEAR
		elif d< radius_far:
			area = MED
		else:
			area = FAR
		var dir = GameData.actor_info[mob.field_id][mob.id].move_dir
		var result = get_region_and_dir(mob,dir,origin,RegionNums[area-1])
		var region = result[0]
		var dir_part = result[1]
		dist[area][region].amount  += 1
		dist[area][region].region_dir_info |= dir_part	

func gether_player_info(player_data:SensorData.PlayerData):
	var player_state := GameData.actor_info[owner_field_id][owner_id] as GameData.ActorState
	var forward = Vector2.UP
	player_data.terrain_info = []
	
	player_data.hp = player_state.hp
	player_data.move_dir = forward.angle_to(player_state.move_dir)
	player_data.aim_dir = forward.angle_to(player_state.direction)
	player_data.shoot_cd_left = owner.get_shoot_cd_left()
	player_data.is_moving = not player_state.move_dir.is_zero_approx()
	# collect terrain info	
	for i in range(terrain_rays.size()):
		var query = PhysicsRayQueryParameters3D.create(
			owner.global_position,owner.global_position+terrain_rays[i]*terrain_detect_range,
			Collision_Mask_Floor)
		var result = space.intersect_ray(query)
		if result:
			player_data.terrain_info.append(result.position.distance_to(owner.global_position))
		else:
			player_data.terrain_info.append(terrain_detect_range)

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
		if obj is Mob :
			if obj.field_id == owner_field_id:
				monsters.append(obj)
		else:
			var obj_owner = obj.owner
			if obj_owner is Bullet:
				if obj_owner.instigator.field_id == owner_field_id:
					if obj_owner.instigator is Player:
						bullet_player.append(obj_owner)
					elif obj_owner.instigator is Mob:
						bullet_monster.append(obj_owner)
	#计算分区信息
	analyse_bullets(bullet_monster,sensor_data.mob_bullet_data)
	analyse_bullets(bullet_player, sensor_data.player_bullet_data)
	
	analyse_mob(monsters,sensor_data.mob_data)
	
	gether_player_info(sensor_data.player_data)
	return sensor_data
