class_name TrainingManager extends Node

static var instance: TrainingManager

@export
var training_level:int = 4

@export
var update_interval:float = 0.1

@export var load_checkpoint : bool = false
@export
var checkpoint_file :String = ""

@export_group("training")
@export
var mob_collect: int = 8
@export
var bullet_Collect:int = 10
@export
var frame_total:int = 6
@export
var move_dim : int = 6
@export
var shoot_dim : int = 4
@export
var action_dim : int = 5
@export
var player_dim : int = 10
@export
var mob_dim : int = 5
@export
var bullet_dim : int = 5
@export var train_step : int =9

@export_group("settings")
@export
var mob_shoot_enabled:bool = true

@export
var player_shoot_enabled:bool = true

@export
var mob_move_enabled:bool = true

@export
var player_move_enabled:bool = true

var next_update_time:float = 0
var next_training_sample_time_ms:int = 0
var pending_training_samples:Dictionary = {}

var Agent: AIAgent
var isAIMode : bool = false
var isPlayMode : bool = false
var ep:int = 1
var frame_collected :int = 0

func _enter_tree():
	instance = self

func _ready() -> void:
	if not is_instance_valid(GameManager.instance):
		return
	if GameManager.instance.control_mode == GameManager.ControlMode.AI:
		Agent = AIAgent.new()
		isAIMode = true
		if GameManager.instance.game_mode == GameManager.GameMode.Play:
			Agent.set_mode(AIAgent.AIAgentMode.INFERENCE)
			isPlayMode = true
		else:
			Agent.set_mode(AIAgent.AIAgentMode.TRAINING)
			isPlayMode = false
			
		initialize_agent(Agent, mob_collect, bullet_Collect, player_dim, mob_dim, bullet_dim, move_dim, shoot_dim)
		if Agent.get_mode() == AIAgent.AIAgentMode.TRAINING:
			Agent.SetBatchInfo(GameManager.instance.field_amount, action_dim, frame_total)
		
		if load_checkpoint and not checkpoint_file.is_empty():
			Agent.Load("ai", checkpoint_file)

func _physics_process(_delta: float) -> void:
	if not isAIMode:
		return
	if ! isPlayMode && Input.is_key_pressed(KEY_P):
		_request_policy_save()
	ai_loop()

func ai_loop() -> void:
	var now = Time.get_ticks_msec()
	if now <= next_training_sample_time_ms:
		return
	
	next_training_sample_time_ms = now + int(GameManager.instance.game_settings.ai_update_interval * 1000)
	
	if isPlayMode:
		if not GameManager.instance.training_fields.is_empty():
			var field = GameManager.instance.training_fields[0]
			var field_id = field.id
			if not GameData.game_end[field_id]:
				var sensor_data = field.player.get_sensor_data()
				var operations : PackedFloat32Array = process_sensor_data(Agent, sensor_data, false)
								
				var player = field.player
				if not is_instance_valid(player):
					return
				if not GameData.player_input.has(player.id):
					return

				var input_state = GameData.player_input[player.id] as GameData.PlayerInputState
				
				_decode_action(input_state, operations)
			else:
				var sensor_data = field.player_sensor_data_cache
				process_sensor_data(Agent, sensor_data, true)
	else:
		_run_training_collection_loop()		
			
func _decode_action(input_state : GameData.PlayerInputState, action_data : PackedFloat32Array):
	var horizon :float = action_data[0]
	var vertical:float = action_data[1]
	var angle_x:float = action_data[2]
	var angle_y :float = action_data[3]
	var shoot :float = action_data[4]
	
	#移动返回的是 0,1,2， 需要转成-1,0,1
	var move_dir :Vector2 = Vector2(horizon - 1.0, vertical - 1.0)
	if move_dir.length() > 0:
		input_state.start_move(move_dir)
	else:
		input_state.stop_move()

	input_state.shooting = shoot > 0
	input_state.aim_direction = Vector2(angle_x, angle_y).normalized()
	

func _run_training_collection_loop() -> void:
	for field in GameManager.instance.training_fields.values():
		_collect_training_sample_reward(field)
	_upload_batch_training_data(pending_training_samples)
	#有完整的reward之后立即训练
	#不能在函数结束之后才训练，会有没登记reward的错误数据被拿去训练
	frame_collected += 1
	if frame_collected >= frame_total:
		_train_policy_batch()
		frame_collected = 0
	#训练完成后会清空数据，这里是新的一批数据
	for field in GameManager.instance.training_fields.values():
		_collect_training_sample(field)
	#批量送入agent处理
	_request_policy_action(pending_training_samples)

func _collect_training_sample_reward(field:TrainingField) -> void:
	var field_id = field.id
	if GameData.game_end[field_id]:
		#更新上一帧的reward
		pending_training_samples[field_id].reward = -1
		return

	var player = field.player
	if not is_instance_valid(player):
		return

	var sensor_data = player.get_sensor_data()
	var reward = GameManager.instance._calculate_step_reward(player.field_id, sensor_data)
	
	#更新上一帧的reward
	if not pending_training_samples.is_empty() and not pending_training_samples[field_id].game_end:
		pending_training_samples[field_id].reward = reward
	
func _collect_training_sample(field:TrainingField) -> void:
	var field_id = field.id
	if GameData.game_pause[field_id]:
		return

	var sample
	if GameData.game_end[field_id]:
		sample = _collect_terminal_sample(field)
		_submit_training_sample(sample)
		GameManager.instance.reset_field(field_id)
		return

	var player = field.player
	if not is_instance_valid(player):
		return

	var sensor_data = player.get_sensor_data()
	sample = GameData.TrainingSample.new(field_id, sensor_data, 0, false)

	_submit_training_sample(sample)	

func _collect_terminal_sample(field:TrainingField):
	var sensor_data = field.player_sensor_data_cache
	var reward = -1.0
	return GameData.TrainingSample.new(field.id, sensor_data, reward, true)

func _submit_training_sample(sample : GameData.TrainingSample) -> void:
	pending_training_samples[sample.field_id] = sample

func _upload_batch_training_data(_batch_sample) -> void:
	var ids = []
	var rewards = []
	var dones = []
	for field_id in _batch_sample:
		ids.append(field_id)
		rewards.append(_batch_sample[field_id].reward)
		dones.append(1.0 if _batch_sample[field_id].game_end else 0.0)
	Agent.PushTrainingData(PackedFloat32Array(rewards), PackedInt32Array(ids), PackedFloat32Array(dones))

func _request_policy_action(_batch_sample) -> void:
	var batch_result = batch_process_sensor_data(Agent, _batch_sample)
	var ids: PackedInt32Array = batch_result[0]
	var ops: Array = batch_result[1]
	for index in ops.size():
		var id = ids[index]
		var action_data = ops[index]
		var input_state = GameData.player_input[id] as GameData.PlayerInputState
		_decode_action(input_state, action_data)

static func process_sensor_data(agent, sensor_data:Array, is_game_end:bool = false):
	return agent.ProcessSensorData(sensor_data[0], sensor_data[1], sensor_data[2], is_game_end)

static func batch_process_sensor_data(agent, batch_samples:Dictionary) -> Array:
	var ids := PackedInt32Array()
	var players: Array[PackedFloat32Array] = []
	var mobs: Array[PackedFloat32Array] = []
	var bullets: Array[PackedFloat32Array] = []
	for field_id in batch_samples:
		var sensor_data:Array = batch_samples[field_id].sensor_data
		ids.append(field_id)
		players.append(sensor_data[0])
		mobs.append(sensor_data[1])
		bullets.append(sensor_data[2])
	var operations:Array = agent.BatchProcessSensorData(players, mobs, bullets, ids)
	return [ids, operations]

static func initialize_agent(agent, monster_count:int, bullet_count:int,
		in_player_dim:int, in_mob_dim:int, in_bullet_dim:int,
		in_move_dim:int, in_shoot_dim:int) -> void:
	agent.Init(monster_count, bullet_count, in_player_dim, in_mob_dim, in_bullet_dim,
		in_move_dim, in_shoot_dim, 16, 16, 196, 256)

func _train_policy_batch() -> void:
	for field_id in GameManager.instance.training_fields:
		GameManager.instance.pause_game(field_id)
	Agent.Train(train_step);
	increase_ep()
	for field_id in GameManager.instance.training_fields:
		GameManager.instance.resume_game(field_id)

func _request_policy_save() -> void:
	Agent.Save("ai", "checkpoint_" + str(ep)+".mnn")

func increase_ep() -> void:
	ep += 1
	UIManager.instance.set_ep(ep)

static func enable_player_shoot():
	return instance.player_shoot_enabled

static func enable_mob_shoot():
	return instance.mob_shoot_enabled

static func enable_player_move():
	return instance.player_move_enabled

static func enable_mob_move():
	return instance.mob_move_enabled
