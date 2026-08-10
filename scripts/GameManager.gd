class_name GameManager
extends Node

static var instance:GameManager

enum GameMode {
	Train = 1,
	Play = 2
}

enum ControlMode {
	Manual = 1,
	AI = 2
}

signal on_field_reset

@export var field_amount:int = 1
@export var training_field_size:float = 32

@export var TraningRoot:Node3D
@export var ArenaRoot:Node3D
@export var root:Node3D

@export var player_prefab:PackedScene
@export var enemy_prefab:PackedScene
@export var training_field_prefab:PackedScene
@export var arena_prefab:PackedScene
@export var blast_prefab:PackedScene

@export var game_settings:GameSettings
@export var train_camera:Node3D
@export var game_camera:Node3D

@export var game_mode:GameMode = GameMode.Train
@export var control_mode:ControlMode = ControlMode.Manual

var training_fields = {} # {field_id:TrainingField}
var players = {} # {player_id:Player}
var monsters = {} # 预留给全局怪物查询。

var reward_func:Callable
var manual_reset_key_was_pressed:bool = false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	# 静态 GameData 会跨脚本重载和场景切换保留，所以每次主场景启动时
	# 都先清空运行时状态表。
	GameData.reset_runtime()
	if game_mode == GameMode.Play:
		_setup_play_mode()
	elif game_mode == GameMode.Train:
		_setup_train_mode()


func _physics_process(_delta:float) -> void:
	if control_mode == ControlMode.Manual:
		_update_manual_debug_shortcuts()
		_update_manual_player_input()


# ---------------------------------------------------------------------------
# 模式初始化

func _setup_play_mode() -> void:
	create_game_data(1)
	var field = load_arena()
	training_fields[0] = field

	train_camera.set_active(false)
	game_camera.set_active(true)

	UIManager.instance.show_health(true)
	UIManager.instance.show_ep(false)
	UIManager.instance.set_health(game_settings.player_health)


func _setup_train_mode() -> void:
	create_game_data(field_amount)
	initialize_training_fields()
	_configure_training_level()

	train_camera.set_active(true)
	game_camera.set_active(false)

	UIManager.instance.show_health(false)
	UIManager.instance.show_ep(true)
	var initial_ep = 1
	if TrainingManager.instance != null:
		initial_ep = TrainingManager.instance.ep
	UIManager.instance.set_ep(initial_ep)


func _configure_training_level() -> void:
	reward_func = Callable(self, "_calculate_reward_new")
	return
	"""# 训练等级是简单的课程预设。这里集中开关玩法能力，让 reward 函数
	# 和可用动作保持在同一个清晰位置。
	var training_level = TrainingManager.instance.training_level
	if training_level == 1:
		TrainingManager.instance.mob_move_enabled = false
		TrainingManager.instance.mob_shoot_enabled = false
		TrainingManager.instance.player_move_enabled = false
		reward_func = Callable(self, "_calculate_reward_level_1")
	elif training_level == 2:
		TrainingManager.instance.mob_shoot_enabled = false
		TrainingManager.instance.player_move_enabled = false
		reward_func = Callable(self, "_calculate_reward_level_1")
	elif training_level == 3:
		TrainingManager.instance.player_shoot_enabled = false
		reward_func = Callable(self, "_calculate_reward_level_2")
	elif training_level == 4:
		reward_func = Callable(self, "_calculate_reward_default")"""


func create_game_data(amount:int) -> void:
	# 一个场地对应一个 player/agent id。GameData 使用扁平表，方便
	# Player、Mob、Sensor 和 GameManager 共享状态，减少节点查找。
	for field_id in range(amount):
		var paused = false
		GameData.register_field(field_id, paused)


# ---------------------------------------------------------------------------
# 玩家输入

func _update_manual_debug_shortcuts() -> void:
	var reset_key_pressed = Input.is_key_pressed(KEY_R)
	if game_mode == GameMode.Play and reset_key_pressed and not manual_reset_key_was_pressed:
		reset_field(0)
	manual_reset_key_was_pressed = reset_key_pressed


func _update_manual_player_input() -> void:
	# 手动模式会把同一份实时输入写入所有有效玩家。Play 模式通常只有
	# 一个玩家，这样也能让调试训练场景不用额外分支就能移动。
	var move_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var shooting = Input.is_action_pressed("shoot")

	for player in players.values():
		if not is_instance_valid(player):
			continue
		if not GameData.player_input.has(player.id):
			continue

		var input_state = GameData.player_input[player.id] as GameData.PlayerInputState
		if move_dir.length() > 0:
			input_state.start_move(move_dir)
		else:
			input_state.stop_move()

		input_state.shooting = shooting
		input_state.aim_direction = _get_manual_aim_direction(player)


func _get_manual_aim_direction(player:Player) -> Vector2:
	var camera = get_viewport().get_camera_3d()
	var cursor_pos = get_viewport().get_mouse_position()
	var cursor_world_pos = camera.project_position(cursor_pos, 50)
	var cursor_direction = cursor_world_pos - player.global_position
	return Vector2(cursor_direction.x, cursor_direction.z).normalized()


# ---------------------------------------------------------------------------
# 场地生命周期

func load_trainning_field(center:Vector3) -> TrainingField:
	# 保留这个拼错的公开函数名，兼容旧场景和旧脚本。
	return load_training_field(center)


func load_training_field(center:Vector3) -> TrainingField:
	var field = training_field_prefab.instantiate() as TrainingField
	field.position = center
	return field


func load_arena():
	var field = arena_prefab.instantiate()
	field.id = 0
	# 先加入场景树，再初始化会读取 global transform 的子节点。
	ArenaRoot.add_child(field)
	field.position = Vector3.ZERO
	field.on_player_spawn.connect(on_player_spawn)
	field.on_player_dead.connect(on_player_dead)
	field.init(0)
	game_camera.target = field.player
	return field


func initialize_training_fields() -> void:
	# 将训练场按网格排布，方便多个 agent 并行模拟，并避免共享碰撞或导航状态。
	var col:int = ceili(sqrt(field_amount))
	var row:int = ceili(float(field_amount) / col)
	var start_x = -col / 2 * training_field_size
	var start_z = -row / 2 * training_field_size
	var id_counter = 0

	for r in range(row):
		for c in range(col):
			var center = Vector3(
				start_x + (training_field_size + 2) * c,
				0,
				start_z + (training_field_size + 2) * r)
			var field = load_training_field(center)
			field.on_player_spawn.connect(on_player_spawn)
			field.on_player_dead.connect(on_player_dead)
			# 和 load_arena() 一样：TrainingField.init() 会读取子节点全局位置，
			# 所以 field 必须先进入场景树。
			TraningRoot.add_child(field)
			field.init(id_counter)
			training_fields[id_counter] = field

			var player = field.player
			players[player.id] = player
			id_counter += 1
			if id_counter == field_amount:
				return


func reset_field(field_id:int) -> void:
	if not training_fields.has(field_id):
		return

	var field = training_fields[field_id]
	# Field.reset() 会清理旧怪物/玩家，并立刻为下一局生成新玩家。
	field.reset()
	GameData.game_end[field_id] = false
	GameData.game_pause[field_id] = false
	if game_mode == GameMode.Play:
		game_camera.target = field.player

	on_field_reset.emit(field_id)


func pause_game(field_id:int) -> void:
	GameData.game_pause[field_id] = true


func resume_game(field_id:int) -> void:
	GameData.game_pause[field_id] = false


# ---------------------------------------------------------------------------
# 实体创建和事件

func spawn_player(scene_root, position:Vector3, rotation=Quaternion.IDENTITY) -> Player:
	var player = player_prefab.instantiate() as Player
	scene_root.add_child(player)
	player.global_position = position
	player.basis = Basis(rotation)
	return player


func spawn_monster(scene_root, position:Vector3, rotation=Quaternion.IDENTITY) -> Mob:
	var mob = enemy_prefab.instantiate() as Mob
	scene_root.add_child(mob)
	mob.position = position
	mob.basis = Basis(rotation)
	return mob


func spawn_blast(pos:Vector3) -> void:
	var blast = blast_prefab.instantiate()
	pos.y += 1
	blast.position = pos
	root.add_child(blast)


func on_player_spawn(player:Player) -> void:
	players[player.id] = player
	# Reward 按策略采样间隔计算，而不是按物理帧计算。
	GameData.register_player_reward_baseline(player.id, player.health, player.position)


func on_player_dead(player:Player) -> void:
	players.erase(player.id)
	# 下一次训练 tick 会采集终止样本，并重置场地。
	GameData.game_end[player.field_id] = true


func on_player_bullet_hit(other) -> void:
	if other is Mob:
		other.take_damage(game_settings.bullet_damage)


func on_mob_bullet_hit(other) -> void:
	if other is Player:
		other.take_damage(game_settings.bullet_damage)


# ---------------------------------------------------------------------------
# Reward 计算

func _calculate_step_reward(field_id:int, sensor_data) -> float:
	if reward_func.is_valid():
		return reward_func.call(field_id, sensor_data)
	return 0.0


func _calculate_reward_default(field_id:int, sensor_data) -> float:
	var training_field = training_fields[field_id]
	if GameData.game_end[field_id]:
		return -5.0

	var player = training_field.player
	# 生存训练：避免受伤、保持移动；如果这一段没有掉血，给一点小奖励。
	var move_bonus = 0.1 if GameData.player_input[player.id].move_state == GameData.Op_Move else 0.0
	var delta_distance = player.position.distance_to(GameData.player_pos_cache[player.id])
	var life_loss_penalty = -0.3 * (GameData.player_hp_cache[player.id] - player.health)
	var not_hit_bonus = 0.1 if life_loss_penalty == 0 else 0.0
	var reward = life_loss_penalty + move_bonus * delta_distance + not_hit_bonus

	# 从当前血量/位置开始下一段 reward 统计区间。
	GameData.update_player_reward_baseline(player.id, player.health, player.position)
	return reward

func _calculate_reward_new(field_id : int, sensor_data) ->float:
	var training_field = training_fields[field_id]
	var player = training_field.player	
	var invalid_op_penalty = 0.05
	var kill_score = 0.001 if GameData.mob_kill_cache[field_id] > 0 else 0.0
	var threat = GameData.has_threat[field_id]
	#if not GameData.has_threat[field_id]:
		#life_score = 0.0
		#kill_score = 0.0
	var behit_penalty = 1.0 if (GameData.player_hp_cache[player.id] - player.health) > 0.0 else 0.0
	var life_score = 0.001 * (float(player.health) / float(GameManager.instance.game_settings.player_health)) if not GameData.game_end[field_id] else 0.0	
	GameData.reset_step_reward_stats(player.id)
	GameData.update_player_reward_baseline(player.id, player.health, player.position)
	var reward = life_score - behit_penalty - invalid_op_penalty * GameData.invalid_op[field_id]
	return reward

func _calculate_reward_level_1(field_id:int, _sensor_data) -> float:
	var training_field = training_fields[field_id]
	var player = training_field.player
	# Level 1 只训练射击：移动被禁用，击杀给奖励，偏离目标的瞄准由
	# TrainingField 给惩罚。
	var shoot_dir_penalty = training_field.lv1_shoot_penalty_cache if training_field.lv1_shoot_penalty_cache < 0 else 0.0
	var do_nothing_penalty = -0.02
	var reward = 0.5 * GameData.mob_kill_cache[player.id] + shoot_dir_penalty + do_nothing_penalty

	# 击杀/射击计数是区间统计，每次采样后消费一次。
	GameData.reset_step_reward_stats(player.id)
	training_field.lv1_shoot_penalty_cache = 1
	return reward


func _calculate_reward_level_2(field_id:int, _sensor_data) -> float:
	var training_field = training_fields[field_id]
	if GameData.game_end[field_id]:
		return -1.0

	var player = training_field.player
	# Level 2 关注躲避/生存，所以这里只计算掉血惩罚。
	var life_loss_penalty = -0.1 * (GameData.player_hp_cache[player.id] - player.health)
	GameData.update_player_reward_baseline(player.id, player.health, player.position)
	return life_loss_penalty


# ---------------------------------------------------------------------------
# 调试辅助

func increase_ep() -> void:
	if TrainingManager.instance != null:
		TrainingManager.instance.increase_ep()


func test_func() -> void:
	var sensor_data = players[0].get_sensor_data()
	var player_data = sensor_data.player_data
	print("===player data===")
	prints(
		"hp", player_data.hp,
		"move_dir", player_data.move_dir,
		"moving", player_data.is_moving,
		"shoot_cd", player_data.shoot_cd_left)
	prints("terrain info", player_data.terrain_info)
	print("===region data===")
	var region_info = sensor_data.compose_final_cell()
	for r in range(18):
		print(region_info.slice(r * 18, (r + 1) * 18))

	prints("Param total", sensor_data.get_nn_param_total())
