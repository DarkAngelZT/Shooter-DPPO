class_name UIManager extends Node

static var instance:UIManager

@export
var ep_num: Label

@export
var health: Label

@export
var hp_label:Label

@export
var ep_label:Label

func _enter_tree():
	instance = self
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_ep(ep:int):
	ep_num.text = String.num(ep,0)
	
func set_health(hp:int):
	health.text = String.num(hp,0)
	
func show_health(visible:bool):
	health.visible = visible
	hp_label.visible = visible
	
func show_ep(visible:bool):
	ep_label.visible = visible
	ep_num.visible = visible
