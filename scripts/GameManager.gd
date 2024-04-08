class_name GameManager
extends Node

enum GameMode {
	Train = 1,
	Game = 2
}	

@export
var field_amount:int = 1

@export
var TraningRoot:Node3D

@export
var ArenaRoot:Node3D

@export
var player_prefab: PackedScene

@export
var enemy_prefab:PackedScene

@export
var training_field_prefab:PackedScene

@export
var train_camera:Node3D

@export
var game_camera:Node3D

@export
var game_mode:GameMode = GameMode.Train

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
