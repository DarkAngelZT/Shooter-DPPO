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

var reward_func:Callable
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
		
		#set traiing level
		var trainning_level = TrainingManager.instance.training_level
		if trainning_level == 1:
			TrainingManager.instance.mob_move_enabled = false
			TrainingManager.instance.mob_shoot_enabled = false
			TrainingManager.instance.player_move_enabled = false
			reward_func = Callable(self,"calculate_reward_lv1")
		elif trainning_level == 2:
			TrainingManager.instance.mob_shoot_enabled = false
			TrainingManager.instance.player_move_enabled = false
			reward_func = Callable(self,"calculate_reward_lv1")
		elif  trainning_level == 3:
			TrainingManager.instance.player_shoot_enabled = false
			reward_func = Callable(self,"calculate_reward_lv2")
		elif trainning_level == 4:
			reward_func = Callable(self,"calculate_reward")
		
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
	GameData.player_pos_cache[player.id] = player.position
	
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
					var reward
					if reward_func.is_valid():
						reward = reward_func.call(p.field_id, data)
					else:
						reward = 0
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

func calculate_reward(field_id, sensor_data)->float:
	var training_field = training_fields[field_id]
	if GameData.game_end[field_id]:
		return -1
	else:
		var player = training_field.player

		var move_bonus = 0.1 * (1 if GameData.player_input[player.id].move_state==GameData.Op_Move else 0)
		var delta_d = player.position.distance_to(GameData.player_pos_cache[player.id])
		var life_loss_penalty = -0.3 * (GameData.player_hp_cache[player.id] - player.health)
		#var kill_reward = 0.06 * GameData.mob_kill_cache[player.id]
		#var closest_d = sensor_data.player_data.terrain_info.min()
		#var edge_panelty = min(-0.1*(3-closest_d),0)
		#var shoot_bonus = 0.03 if GameData.player_shooted[player.id] else 0
		
		#var center_bonus = 0.008 * (10 - Vector2(player.position.x,player.position.z).length())
		
		var not_hit_bonus = 0.1 if life_loss_penalty == 0 else 0
		
		#第一轮评估用这个
		var reward = life_loss_penalty + move_bonus*delta_d + not_hit_bonus
		#第二轮评估用这个
		#var reward = life_loss_penalty + stay_penalty + center_bonus
		#clean up
		GameData.mob_kill_cache[player.id] = 0
		GameData.player_shooted[player.id] = false
		GameData.player_hp_cache[player.id] = player.health
		GameData.player_pos_cache[player.id] = player.position
		return reward

func calculate_reward_lv1(field_id, sensor_data)->float:
	var reward = 0
	var training_field = training_fields[field_id]
	var player = training_field.player
	var shoot_dir_penalty = training_field.lv1_shoot_penalty_cache if training_field.lv1_shoot_penalty_cache <0 else 0
	var do_nothing_penalty = -0.02
	
	reward = 0.5 * GameData.mob_kill_cache[player.id] + shoot_dir_penalty+do_nothing_penalty
	
	GameData.mob_kill_cache[player.id] = 0
	training_field.lv1_shoot_penalty_cache = 1
	return reward

func calculate_reward_lv2(field_id, sensor_data)->float:
	var reward = 0
	var training_field = training_fields[field_id]
	if GameData.game_end[field_id]:
		return -1
		
	var player = training_field.player
	
	var life_loss_penalty = -0.1 * (GameData.player_hp_cache[player.id] - player.health)
	reward = life_loss_penalty
		
	GameData.player_hp_cache[player.id] = player.health
	return reward

func on_player_bullet_hit(other):
	if other is Mob:
		other.take_damage(GameManager.instance.game_settings.bullet_damage)
	
func on_mob_bullet_hit(other):
	if other is Player:
		other.take_damage(GameManager.instance.game_settings.bullet_damage)

func test_func():
	var sensor_data = players[0].get_sensor_data()
	var p_data = sensor_data.player_data
	print("===player data===")
	prints("hp",p_data.hp,"move_dir",p_data.move_dir,
	"aim",p_data.aim_dir,"moving",p_data.is_moving,
	"shoot_cd",p_data.shoot_cd_left)
	prints("terrain info", p_data.terrain_info)
	print("===region data===")
	var region_info = sensor_data.compose_final_cell()
	for r in range(18):
		print(region_info.slice(r*18,(r+1)*18))
				
	prints("Param total", sensor_data.get_nn_param_total())
