class_name GameManager
extends Node

static var instance:GameManager
enum GameMode {
	Train = 1,
	Play = 2
}

enum ControlMode{
	Manual = 1,
	AI = 2
}

signal on_field_reset

@export
var field_amount:int = 1

@export
var training_field_size:float = 32

@export
var TraningRoot:Node3D

@export
var ArenaRoot:Node3D

@export
var root:Node3D

@export
var player_prefab: PackedScene

@export
var enemy_prefab:PackedScene

@export
var training_field_prefab:PackedScene

@export
var arena_prefab:PackedScene

@export
var blast_prefab:PackedScene

@export
var game_settings:GameSettings

@export
var train_camera:Node3D

@export
var game_camera:Node3D

@export
var game_mode:GameMode = GameMode.Train

@export
var control_mode:ControlMode = ControlMode.Manual

var next_ai_update_time = 0

var training_fields = {} #{field_id:field}
var players = {} #{field_id:player}
var monsters = {} #{field_id:{monster_id:monster}}
var ep = 1
# Called when the node enters the scene tree for the first time.
func _enter_tree():
	instance = self
	
func _ready():
	
	if game_mode == GameMode.Play:
		create_game_data(1)
		var field = load_arena()
		training_fields[0] = field
		train_camera.set_active(false)
		game_camera.set_active(true)
		UIManager.instance.show_health(true)
		UIManager.instance.show_ep(false)
		UIManager.instance.set_health(GameManager.instance.game_settings.player_health)
		
	elif game_mode == GameMode.Train:
		create_game_data(field_amount)
		initialize_training_fields()
		
		train_camera.set_active(true)
		game_camera.set_active(false)
		
		UIManager.instance.show_health(false)
		UIManager.instance.show_ep(true)
		UIManager.instance.set_ep(1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func create_game_data(amount):
	for i in range(amount):
		GameData.player_input[i]=GameData.PlayerInputState.new(i)
		GameData.game_end[i]=false
		GameData.game_pause[i]= true if control_mode == ControlMode.AI else false
		GameData.actor_info[i]={}
		if control_mode == ControlMode.AI:
			GameData.ai_need_update[i] = 1
			GameData.mob_kill_cache[i] = 0

func _physics_process(delta):
	if control_mode == ControlMode.Manual and players.has(0):
		var dir = Input.get_vector("move_left","move_right","move_forward","move_back")
		
		var moving = dir.length() > 0
		if moving:
			GameData.player_input[0].direction = dir.normalized()
			GameData.player_input[0].move_state = GameData.Op_Move
		else:
			GameData.player_input[0].move_state = GameData.Op_Stop
			
		var shooting = Input.is_action_pressed("shoot")
		GameData.player_input[0].shooting = shooting
		#鼠标位置
		var camera = get_viewport().get_camera_3d()
		var cursor_pos = get_viewport().get_mouse_position()
		var cursor_dist = camera.project_position(cursor_pos,50)
		
		var result_dir = cursor_dist - players[0].global_position
		var aim_dir = Vector2(result_dir.x,result_dir.z)
		aim_dir = aim_dir.normalized()
		GameData.player_input[0].aim_direction = aim_dir
	elif control_mode == ControlMode.AI:
		if Input.is_key_pressed(KEY_P):
			#manual save
			NetworkManager.instance.request_save()
		ai_loop()

func load_trainning_field(center):
	var field = training_field_prefab.instantiate()
	field.position = center
	return field
	
func load_arena():
	var field = arena_prefab.instantiate()
	field.global_position = ArenaRoot.position
	field.id = 0
	ArenaRoot.add_child(field)
	field.on_player_spawn.connect(on_player_spawn)
	field.on_player_dead.connect(on_player_dead)
	field.init(0)
	game_camera.target = field.player	
	return field
	
func initialize_training_fields():
	var col:int =1
	var row:int =1
	col = ceili(sqrt(field_amount))
	row = ceili(float(field_amount)/col)
	var start_x = -col/2*training_field_size
	var start_y = -row/2*training_field_size
	var id_counter = 0
	var amount = 0
	for r in range(row):
		for c in range(col):
			var center = Vector3(start_x+(training_field_size+2)*c,0,start_y+(training_field_size+2)*r)
			var field = load_trainning_field(center)
			field.on_player_spawn.connect(on_player_spawn)
			field.on_player_dead.connect(on_player_dead)
			field.init(id_counter)
			training_fields[id_counter] = field
			TraningRoot.add_child(field)
			id_counter += 1
			amount += 1
			var p = field.player
			players[p.id] = p			
			if amount == field_amount:
				break

func reset_field(field_id):
	if training_fields.has(field_id):
		var field = training_fields[field_id]
		field.reset()
		GameData.game_end[field_id] = false
		GameData.game_pause[field_id] = false
		if game_mode == GameMode.Play:
			game_camera.target = field.player
		
		on_field_reset.emit(field_id)

func spawn_player(scene_root, position, rotation=Quaternion.IDENTITY):
	var player = player_prefab.instantiate()
	scene_root.add_child(player)
	player.global_position = position
	player.basis = Basis(rotation)
	return player
	
func spawn_monster(scene_root, position, rotation=Quaternion.IDENTITY):
	var mob = enemy_prefab.instantiate()
	scene_root.add_child(mob)
	mob.position = position
	mob.basis = Basis(rotation)
	return mob
	
func on_player_spawn(player):
	players[player.id] = player
	GameData.player_hp_cache[player.id] = player.health
	GameData.player_shooted[player.id] = false
	
func on_player_dead(player):
	players.erase(player.id)
	GameData.game_end[player.field_id] = true

func pause_game(field_id):
	GameData.game_pause[field_id] = true
	
func resume_game(field_id):
	GameData.game_pause[field_id] = false

func spawn_blast(pos):
	var blast = blast_prefab.instantiate()
	pos.y+=1
	blast.position = pos
	root.add_child(blast)
	
func ai_loop():
	if Time.get_ticks_msec() > next_ai_update_time:
		next_ai_update_time = Time.get_ticks_msec()+game_settings.ai_update_interval*1000
	else:
		return
		
	for f in training_fields.values():
		var field_id = f.id
		if not GameData.game_pause[field_id]:
			if GameData.ai_need_update[field_id] == 1:
				if GameData.game_end[field_id]:
					var data = f.player_sensor_data_cache
					NetworkManager.instance.send_server_state(field_id,field_id,data,0,true)
				else:
					var p = f.player
					var data = p.get_sensor_data()
					var game_end = GameData.game_end[p.field_id]
					var reward = calculate_reward(p.field_id)
					if not NetworkManager.instance.send_server_state(p.field_id,p.id,data,reward,game_end):
						return
					GameData.player_shooted[p.id] = false
					GameData.mob_kill_cache[p.id] = 0
				GameData.ai_need_update[field_id] = 0
			if GameData.ai_need_update[field_id] > 0:
				GameData.ai_need_update[field_id] -= 1

func increase_ep():
	ep += 1
	UIManager.instance.set_ep(ep)

func calculate_reward(field_id)->float:
	var training_field = training_fields[field_id]
	if GameData.game_end[field_id]:
		return 0
	else:
		var player = training_field.player

		var stay_penalty = -0.02 * (1 if GameData.player_input[player.id].move_state==GameData.Op_Stop else 0)
		var life_loss_penalty = -0.05 * (GameData.player_hp_cache[player.id] - player.health)
		var shoot_bonus = 0.01 if GameData.player_shooted[player.id] else 0
		var kill_reward = 0.03 * GameData.mob_kill_cache[player.id]
		
		var reward = stay_penalty + life_loss_penalty + shoot_bonus + kill_reward
		
		#clean up
		GameData.mob_kill_cache[player.id] = 0
		GameData.player_shooted[player.id] =false
		GameData.player_hp_cache[player.id] = player.health
		return reward

func test_func():
	var sensor_data = players[0].get_sensor_data()
	var p_data = sensor_data.player_data
	print("===player data===")
	prints("hp",p_data.hp,"move_dir",p_data.move_dir,
	"aim",p_data.aim_dir,"moving",p_data.is_moving,
	"shoot_cd",p_data.shoot_cd_left)
	prints("terrain info", p_data.terrain_info)
	print("===mob data===")
	var m = sensor_data.mob_data
	for r in m:
		for s in range(m[r].size()):
			if m[r][s].amount>0:
				prints("region",r,"section",s,"amount",m[r][s].amount,"dir",m[r][s].region_dir_info)
	print("===mob bullet info===")
	var bm = sensor_data.mob_bullet_data
	for r in bm:
		for s in range(bm[r].size()):
			if bm[r][s].amount>0:
				prints("region",r,"section",s,"amount",bm[r][s].amount,"dir",bm[r][s].dir_info)
	print("===player bullet info===")
	var bp = sensor_data.player_bullet_data
	for r in bp:
		for s in range(bp[r].size()):
			if bp[r][s].amount>0:
				prints("region",r,"section",s,"amount",bp[r][s].amount,"dir",bp[r][s].dir_info)
				
	prints("Param total", sensor_data.get_nn_param_total())
