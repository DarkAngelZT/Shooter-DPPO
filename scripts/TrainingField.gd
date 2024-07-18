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
