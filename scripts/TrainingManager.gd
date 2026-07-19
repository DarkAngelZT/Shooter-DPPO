class_name TrainingManager extends Node

static var instance: TrainingManager

@export
var training_level:int = 4

@export
var update_interval:float = 0.1

@export_group("training")
@export
var mob_collect: int = 8
@export
var bullet_Collect:int = 10
@export
var frame_total:int = 6

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
var pending_training_samples:Array = []

var Agent: AIAgent
var isAIMode : bool = false
var ep:int = 1

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
		else:
			Agent.set_mode(AIAgent.AIAgentMode.TRAINING)

func _physics_process(_delta: float) -> void:
	if not isAIMode:
		return
	if Input.is_key_pressed(KEY_P):
		_request_policy_save()
	ai_loop()

func ai_loop() -> void:
	_run_training_collection_loop()

func _run_training_collection_loop() -> void:
	var now = Time.get_ticks_msec()
	if now <= next_training_sample_time_ms:
		return

	next_training_sample_time_ms = now + int(GameManager.instance.game_settings.ai_update_interval * 1000)
	for field in GameManager.instance.training_fields.values():
		_collect_training_sample(field)

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
	var reward = GameManager.instance._calculate_step_reward(player.field_id, sensor_data)
	sample = GameData.TrainingSample.new(player.field_id, player.id, sensor_data, reward, false)

	_submit_training_sample(sample)
	_request_policy_action(sample)

func _collect_terminal_sample(field:TrainingField):
	var sensor_data = field.player_sensor_data_cache
	var reward = -1.0
	return GameData.TrainingSample.new(field.id, field.id, sensor_data, reward, true)

func _submit_training_sample(sample) -> void:
	pending_training_samples.append(sample)
	if pending_training_samples.size() >= GameManager.instance.samples_per_training_batch:
		_train_policy_batch()

func _request_policy_action(_sample) -> void:
	pass

func _train_policy_batch() -> void:
	pending_training_samples.clear()
	increase_ep()

func _request_policy_save() -> void:
	pass

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
