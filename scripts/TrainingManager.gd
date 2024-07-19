class_name TrainingManager extends Node

static var instance: TrainingManager

@export
var training_level:int = 4

@export
var mob_shoot_enabled:bool = true

@export
var player_shoot_enabled:bool = true

@export
var mob_move_enabled:bool = true

@export
var player_move_enabled:bool = true

func _enter_tree():
	instance = self

static func enable_player_shoot():
	return instance.player_shoot_enabled

static func enable_mob_shoot():
	return instance.mob_shoot_enabled
	
static func enable_player_move():
	return instance.player_move_enabled
	
static func enable_mob_move():
	return instance.mob_move_enabled
