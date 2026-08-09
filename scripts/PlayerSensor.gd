class_name PlayerSensor extends Node

@export var radius_far:float
@export var radius_near:float
@export var detect_shape:Shape3D
@export_flags_3d_physics var collision_mask
@export var radius_player:float
@export var terrain_detect_range:float = 100
@export_range(0, 64, 1) var mob_max_count:int = 8
@export_range(0, 64, 1) var mob_bullet_max_count:int = 10

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

const cell_size = 324
const PLAYER_DATA_SIZE = 10
const MOB_DATA_SIZE = 5
const BULLET_DATA_SIZE = 5

const Collision_Mask_Floor = 32 # blocker

const RegionNums = [8,12,12]

"""class SensorData:
	class PlayerData:
		var hp:int
		var move_dir:float
		var is_moving:bool
		var shoot_cd_left:float
		var terrain_info:Array[float]
		
		var param_num:
			get:
				return 13		
	
	var player_data:PlayerData=PlayerData.new()
	#cell amount = (9*2)^2 = 324
	var mob_data = {}#[cell_id]->[dir]
	
	var mob_bullet_data={} #[cell_id]->[dir]
	
	var player_bullet_data={} #[cell_id]->[dir]
	
	func get_nn_param_total()->int:
		var total = player_data.param_num
		total += cell_size
		return total
		
	static func coordinate_to_cell_id(row:int,column:int)->int:
		return row*18+column
		
	func compose_final_cell()->Array[int]:
		var result :Array[int] = []
		result.resize(cell_size)
		result.fill(-1)
		for i in range(cell_size):
			var empty = true
			var mob_dir:int = 0
			var mob_bullet:int = 0
			var player_bullet:int = 0
			if mob_data.has(i):
				empty = false
				mob_dir = mob_data[i]
			if mob_bullet_data.has(i):
				empty = false
				mob_bullet = mob_bullet_data[i] << 4
			if player_bullet_data.has(i):
				empty = false
				player_bullet = player_bullet_data[i]<<8
			if not empty:
				result[i] = mob_dir | mob_bullet | player_bullet
		return result"""

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
	for i in range(4):
		terrain_rays.append(forward)
		forward = forward.rotated(Vector3.UP,PI*0.5)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

"""func get_angles(target, target_dir,origin):
	var dir = origin - target.global_position
	var dir_vec2 = Vector2(dir.x,dir.z)
	var aim_dir_vec2
	if target_dir is Vector3:
		aim_dir_vec2 = Vector2(target_dir.x,target_dir.z)
	else:
		aim_dir_vec2 = target_dir
	var aim_angle = rad_to_deg(dir_vec2.angle_to(aim_dir_vec2))
	return aim_angle
	
func get_dir(target, target_dir,origin):
	var aim_angle = get_angles(target,target_dir,origin)
	var dir
	if target_dir.is_zero_approx():
		dir = 0
	elif absf(aim_angle) < 5:
		dir = Center
	elif aim_angle<0 and aim_angle > -90:
		dir = Left
	elif aim_angle>0 and aim_angle < 90:
		dir = Right
	else:
		dir = Behind
	
	return dir"""
	
func get_bullet_ttc(relative_pos: Vector2, relative_vel: Vector2, player_radius: float) -> float:
	const INF := 999.0
	const EPS := 0.000001

	var pos := relative_pos
	var v := relative_vel
	var radius := player_radius

	# 已经命中/重叠
	var distance := pos.dot(pos) - radius * radius
	if distance <= 0.0:
		return 0.0

	var a := v.dot(v)

	# 相对速度几乎为 0
	if a < EPS:
		return INF

	var b := 2.0 * pos.dot(v)

	# 在命中半径外，并且正在远离玩家
	if b >= 0.0:
		return INF

	var discriminant := b * b - 4.0 * a * distance

	# 轨迹不穿过玩家圆
	if discriminant < 0.0:
		return INF

	var ttc := (-b - sqrt(discriminant)) / (2.0 * a)

	if ttc >= 0.0:
		return ttc

	return INF

func get_closest_objects(source:Array, max_count:int) -> Array:
	var objects := source.duplicate()
	objects.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(owner.global_position) < b.global_position.distance_squared_to(owner.global_position)
	)
	objects.resize(mini(objects.size(), max_count))
	return objects

func pad_entity_data(data:Array, target_count:int, feature_dim:int) -> PackedFloat32Array:
	var padded_data := PackedFloat32Array()
	for i in range(target_count):
		if i < data.size():
			padded_data.append_array(PackedFloat32Array(data[i]))
		else:
			for _j in range(feature_dim):
				padded_data.append(0.0)
	return padded_data

func compose_sensor_data(player_data, mob_data:Array, bullet_data:Array,
		mob_count:int = mob_max_count, bullet_count:int = mob_bullet_max_count) -> Array:
	var player_array := PackedFloat32Array(player_data)
	var mob_array := pad_entity_data(mob_data, mob_count, MOB_DATA_SIZE)
	var bullet_array := pad_entity_data(bullet_data, bullet_count, BULLET_DATA_SIZE)
	return [player_array, mob_array, bullet_array]

func analyse_bullets(source):
	var player_state := GameData.actor_info[owner_field_id][owner_id] as GameData.ActorState
	var origin :Vector3 = owner.global_position
	var player_v = player_state.move_dir * owner.move_speed
	var result =[]
	for bullet : Bullet in source:
		if bullet.instigator_field_id != owner_field_id:
			continue
		var d : Vector3= bullet.global_position - origin
		var v = bullet.direction * bullet.speed
		var bullet_v = Vector2(v.x, v.z)
		var relative_v = bullet_v - player_v
		var ttc = get_bullet_ttc(Vector2(d.x, d.z), relative_v, 0.5)
		var single_bullet = [d.x, d.z, relative_v.x, relative_v.y, 1.0/(ttc+1)]
		result.append(single_bullet)
	
	return result

func analyse_mob(source:Array):
	var origin :Vector3 = owner.global_position
	var result = []
	for mob:CharacterBody3D in source:
		if mob.field_id != owner_field_id:
			continue
		var single_mob: Array[float]
		var d:Vector3 = mob.global_position - origin
		var v:Vector3 = mob.velocity
		single_mob = [d.x, d.z, v.x, v.z, 1]
		
		result.append(single_mob)
	
	return result

func gether_player_info():
	var player_state := GameData.actor_info[owner_field_id][owner_id] as GameData.ActorState
	#var forward = Vector2.UP
	var terrain_info : Array[float] = []
	
	var hp = player_state.hp
	var percent = hp/float(GameManager.instance.game_settings.player_health)
	var move_x = player_state.move_dir.x * owner.move_speed
	var move_y = player_state.move_dir.y * owner.move_speed
	#player_data.shoot_cd_left = owner.get_shoot_cd_left()
	#var is_moving = not player_state.move_dir.is_zero_approx()
	# collect terrain info	
	var invalid_op := 0
	for i in range(terrain_rays.size()):
		var query = PhysicsRayQueryParameters3D.create(
			owner.global_position,owner.global_position+terrain_rays[i]*terrain_detect_range,
			Collision_Mask_Floor)
		var result = space.intersect_ray(query)
		if result:
			terrain_info.append((result.position.distance_to(owner.global_position) - radius_player )/terrain_detect_range)
			if terrain_info[i] <=0.001:
				if i == 0 and move_x < 0:
					invalid_op +=1
				if i == 0 and move_y < 0:
					invalid_op +=1
				if i == 2 and move_y > 0:
					invalid_op +=1
				if i == 3 and move_x > 0:
					invalid_op +=1
		else:
			terrain_info.append(1.0)	
			
	GameData.invalid_op[owner_field_id] = invalid_op
			
	return [0,0,move_x,move_y,percent,player_state.can_shoot] + terrain_info

func gether_sensor_data():
	query_param.transform.origin = owner.global_position
	var result = space.intersect_shape(query_param)
	var monsters = []
	var bullet_monster = []
	var bullet_player = []
	
	#分类整理
	for hit_result in result:
		var obj = hit_result.collider
		if obj is Mob :
			if obj.field_id == owner_field_id:
				monsters.append(obj)
		else:
			var obj_owner = obj.owner
			if obj_owner is Bullet:
				if obj_owner.instigator_field_id == owner_field_id:
					if  obj_owner.instigator != null:
						if obj_owner.instigator is Player:
							bullet_player.append(obj_owner)
						elif obj_owner.instigator is Mob:
							bullet_monster.append(obj_owner)
					else:
						if GameManager.instance.players.has(obj_owner.instigator_id):
							bullet_player.append(obj_owner)
						else:
							bullet_monster.append(obj_owner)
	#计算分区信息
	var bullets = get_closest_objects(bullet_monster, mob_bullet_max_count)
	var bullet_data = analyse_bullets(bullets)
	#analyse_bullets(bullet_player, sensor_data.player_bullet_data)
	
	var monster_targets = get_closest_objects(monsters, mob_max_count)
	var mob_data = analyse_mob(monster_targets)
	
	var bullet_threat:float = 0
	var monster_threat:float = 0
	for b in bullets:
		bullet_threat += 1.0 - b.global_position.distance_to(owner.global_position) / 12.0
	bullet_threat = bullet_threat / bullets.size() if bullets.size() > 0 else 0.0
	for m in monster_targets:
		monster_threat += 1.0 - m.global_position.distance_to(owner.global_position) / 12.0
	monster_threat = monster_threat / bullets.size() if bullets.size() > 0 else 0.0
	
	var ttc_total = 0
	for b in bullet_data:
		if b[-1] > 0.001:
			ttc_total += b[-1]
	
	#GameData.has_threat[owner_field_id] = 0.005 * (0.8 * bullet_threat + 0.4 * monster_threat)
	GameData.has_threat[owner_field_id] = ttc_total * 0.01
	
	var player_data = gether_player_info()
	var sensor_data := compose_sensor_data(player_data, mob_data, bullet_data)
	GameData.set_player_targets(owner_field_id, monster_targets)
	return sensor_data
