class_name NetworkManager extends Node

var client := StreamPeerTCP.new()

@export
var reconnect_interval:float = 1
var connected = false

var next_retry_time = 0
var test_recved = false
const test_pb = preload("res://protobuf/test_pb.gd")
# Called when the node enters the scene tree for the first time.
func _ready():
	if GameManager.instance.control_mode != GameManager.ControlMode.Manual:
		client.connect_to_host("127.0.0.1",6666)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if GameManager.instance.control_mode == GameManager.ControlMode.Manual:
		return
	client.poll()
	if !connected:
		if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			connected = true
			print("Connected to torch server")
			
		elif client.get_status() == StreamPeerTCP.STATUS_ERROR:
			if Time.get_ticks_msec() > next_retry_time:
				client.connect_to_host("127.0.0.1",6666)
				print("Connect failed retry...")
	else:		
		# send cmd
		if !test_recved:
			var byte_count = client.get_available_bytes()
			if byte_count == 0:
				return
			var packet = client.get_data(byte_count)
			var msg_recv = test_pb.TestMsg.new()
			var result_code = msg_recv.from_bytes(packet[1])
			if result_code == test_pb.PB_ERR.NO_ERRORS:
				print('receive data')
				print(msg_recv.to_string())
			var msg_send = test_pb.TestMsg.new()
			msg_send.set_field_id(1)
			msg_send.set_id(2)
			msg_send.set_can_shoot(false)
			msg_send.set_health(3)
			var dir = msg_send.new_direction()
			dir.set_x(0.12)
			dir.set_y(0.33)
			
			var packed  = msg_send.to_bytes()
			client.put_data(packed)
			test_recved = true
