import socket
import test_pb2

buffer_size = 1024
sent_data_size = 128

client = socket.socket(socket.AF_INET,socket.SOCK_STREAM)


print('waiting for game...')
client.connect(("127.0.0.1",6666))
print('game client conneted')

test_msg = test_pb2.TestMsg()
test_msg.field_id = 0
test_msg.id = 1
test_msg.direction.x = 0.24
test_msg.direction.y = 0.51
test_msg.health = 9
test_msg.can_shoot = True

msg = test_msg.SerializeToString()

client.send(msg)

data = client.recv(buffer_size)
test_data = test_pb2.TestMsg()
test_data.ParseFromString(data)

print("data received")
print(test_data)
print(test_data.can_shoot)

client.close()
