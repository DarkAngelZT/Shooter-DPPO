extends Node2D

# 替代模型已删除动画播放器、眨眼计时器、闭眼计时器和眼睛节点，停用对应声明。
# var _blinking = null : set = _set_blinking
# @onready var _animation_player : AnimationPlayer = $AnimationPlayer
# @onready var _blinking_timer : Timer = $BlinkTimer
# @onready var _closed_eyes_timer : Timer = $ClosedTimer
# @onready var _left_eye : Sprite2D = $LeftEye
# @onready var _right_eye : Sprite2D = $RightEye

# 眼睛节点已删除，不再加载或切换眼睛贴图。
# var eyes_textures = {
# 	"open" : preload("./texture/parts/eye_open.png"),
# 	"closed" : preload("./texture/parts/eye_close.png")
# }

# 面部动画组件已删除，保留空接口以兼容模型脚本的调用。
var current_face = null

func _ready():
	# 面部组件已停用，无需初始化。
	pass

func _set_blinking(_value : bool):
	# 眨眼计时器已删除，停用眨眼控制。
	pass

func _on_blink_timer_timeout():
	# 眨眼、闭眼计时器和动画播放器已删除，停用超时回调。
	pass

func _set_eyes(_eyes_name : String):
	# 眼睛节点已删除，停用贴图切换。
	pass

func _set_face(_face_name):
	# 面部动画播放器已删除，保留空接口避免调用方报错。
	pass
