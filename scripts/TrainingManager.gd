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

var Agent: AIAgent

func _enter_tree():
	instance = self
	
func _ready() -> void:
	if GameManager.instance.control_mode == GameManager.ControlMode.AI:
		Agent = AIAgent.new()
		if GameManager.instance.game_mode == GameManager.GameMode.Play:
			Agent.set_mode(AIAgent.AIAgentMode.INFERENCE)
		else:
			Agent.set_mode(AIAgent.AIAgentMode.TRAINING)

func _physics_process(delta: float) -> void:
	if Time.get_ticks_msec() > next_update_time:
		next_update_time = Time.get_ticks_msec() + update_interval * 1000
		#gether data
		#send state
		#process input

static func enable_player_shoot():
	return instance.player_shoot_enabled

static func enable_mob_shoot():
	return instance.mob_shoot_enabled
	
static func enable_player_move():
	return instance.player_move_enabled
	
static func enable_mob_move():
	return instance.mob_move_enabled
