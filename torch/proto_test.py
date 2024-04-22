import socket
import test_pb2

buffer_size = 1024
sent_data_size = 128

server = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
server.bind(('localhost',6666))
server.listen(1)


print('waiting for game...')
connect, addr = server.accept()
print('game client conneted from:', addr)

test_msg = test_pb2.TestMsg()
test_msg.field_id = 0
test_msg.id = 1
test_msg.direction.x = 0.24
test_msg.direction.y = 0.51
test_msg.health = 9
test_msg.can_shoot = True

msg = test_msg.SerializeToString()

connect.send(msg)

data = connect.recv(buffer_size)
test_data = test_pb2.TestMsg()
test_data.ParseFromString(data)

print("data received")
print(test_data)

connect.close()
server.close()
