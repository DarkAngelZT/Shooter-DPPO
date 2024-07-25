class_name TrainingField
extends Node3D

signal on_reset
signal on_player_spawn
signal on_player_dead

@export
var id:int
@export
var player_spawn:Node3D
@export
var mob_spawner:Array[Node3D]

var monsters = {}

var player:Node3D

var mob_id_counter:int = 100

var EQS:SimpleEQS
var eqs_update_time:float = 0

var player_sensor_data_cache = null

var lv1_spawn_time:int = 0
var lv1_monster:Mob = null
var lv1_shoot_penalty_cache = 1

func reset():
	for m in monsters.values():
		m.queue_free()
	monsters.clear()
	for spawner in mob_spawner:
		spawner.reset()
	if player:
		player.queue_free()
	GameData.actor_info[id].clear()
	GameData.mob_kill_cache[id]=0
	GameData.player_hp_cache[id] = GameManager.instance.game_settings.player_health	
	init(id)
	GameData.player_pos_cache[id] = player.position
	on_reset.emit(self)
# Called when the node enters the scene tree for the first time.
func _ready():
	for spawner in mob_spawner:
		spawner.owner_field = self
		spawner.on_monster_dead.connect(on_mob_dead)
		spawner.on_monster_spawn.connect(on_monster_spawned)

func init(field_id):
	id = field_id
	player = GameManager.instance.spawn_player(self, player_spawn.global_position)
	
	player.field_id = field_id
	player.id = field_id
	player.name = "Player_"+str(player.id)
	var state = GameData.ActorState.new(field_id,player.id)
	state.hp = GameManager.instance.game_settings.player_health
	GameData.actor_info[field_id][player.id]=state
	player.on_player_dead.connect(on_player_die)
	on_player_spawn.emit(player)
	
	EQS = SimpleEQS.new()
	
	if GameManager.instance.game_mode == GameManager.GameMode.Train:
		if TrainingManager.instance.training_level == 1:
			for spawner in mob_spawner:
				spawner.enabled = false
	
	call_deferred("eqs_setup")

func eqs_setup():
	# Wait for the first physics frame so the NavigationServer can sync.
	await get_tree().physics_frame
	
	EQS.init(
		GameManager.instance.game_settings.eqs_inner_radius,
		GameManager.instance.game_settings.eqs_outer_radius,
		get_world_3d().navigation_map)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	if GameData.game_end[id]:
		return
	var pos = player.global_position
	pos.y+=1
	#DebugDraw3D.draw_box(player.global_position,Quaternion.IDENTITY,
	#Vector3(18,2,18),Color.RED,true)
	if GameManager.instance.game_mode == GameManager.GameMode.Train:
		if TrainingManager.instance.training_level == 1:
			if lv1_monster == null and Time.get_ticks_msec() > lv1_spawn_time:
				lv1_spawn_time =Time.get_ticks_msec() + 200
				spawn_lv1_training_mob()
			if lv1_monster != null and lv1_shoot_penalty_cache>0:
				lv1_shoot_penalty_cache = get_training_lv1_shoot_penalty()
		
	if GameData.game_pause[id]:
		eqs_update_time+=_delta*1000
		return
	if EQS.initilized and player and Time.get_ticks_msec() > eqs_update_time:
		EQS.set_center(player.global_position)
		eqs_update_time = Time.get_ticks_msec()+GameManager.instance.game_settings.eqs_update_interval*1000

func on_monster_spawned(mob):
	if is_instance_valid(mob):
		mob.field_id = id
		mob.id = mob_id_counter
		mob_id_counter += 1
		mob.name = "Monster_"+str(mob.id)
		var state = GameData.ActorState.new(id,mob.id)
		GameData.actor_info[id][mob.id]=state
		monsters[mob.id] = mob
		mob.set_target(player)

func on_mob_dead(mob):
	if is_instance_valid(mob):
		if GameManager.instance.control_mode == GameManager.ControlMode.AI:
			GameData.mob_kill_cache[id]+=1
		if GameManager.instance.game_mode == GameManager.GameMode.Train:
			if TrainingManager.instance.training_level == 1:
				lv1_monster = null
		GameData.actor_info[id].erase(mob.id)
		monsters.erase(mob.id)
		mob.queue_free()

func on_player_die(target_player):
	player_sensor_data_cache = player.get_sensor_data()
	on_player_dead.emit(target_player)	
	player = null	
 
func get_attack_position():
	if  EQS.initilized:
		return EQS.get_point()
	else:
		return player.global_position

func get_lv1_training_mob_spawn_pos()->Vector3:
	var pos:Vector3
	var distance = randf_range(2,GameManager.instance.game_settings.eqs_outer_radius)
	var angle = deg_to_rad(randf_range(0,360))
	pos = Vector3(distance*sin(angle),0,distance*cos(angle))
	return pos+player.position
	
func spawn_lv1_training_mob():
	var pos = get_lv1_training_mob_spawn_pos()
	var mob = GameManager.instance.spawn_monster(self,pos)
	mob.spawner = self
	lv1_monster = mob
	on_monster_spawned(mob)
	mob_id_counter -= 1

func get_training_lv1_shoot_penalty()->float:
	var target_dir = lv1_monster.position - player.position
	target_dir = Vector2(target_dir.x,target_dir.z)
	var aim_dir:Vector2 = GameData.actor_info[id][player.id].direction
	var angle = abs(aim_dir.angle_to(target_dir))
	var penalty = -0.1*(max(angle-deg_to_rad(5),0))
	return penalty
