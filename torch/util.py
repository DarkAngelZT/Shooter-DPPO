import torch
import torch.multiprocessing as mp
import numpy as np

memory_capacity = 10000

class GameRecord(object):
	"""docstring for GameRecord"""
	def __init__(self):
		super(GameRecord, self).__init__()
		self.lock = mp.Lock()
		self.s=mp.Array('f',[])
		self.a=mp.Array('f',[])
		self.r=mp.Array('f',[])
		self.s_prime=mp.Array('f',[])
		self.done = mp.Array('f',[])
		self.memory_amount = mp.Value('i',0)
		self.memory_index = mp.Value('i',0)

	def add_records(self, states, actions, rewards, next_states, done):
		with self.lock:
			self.s.value.extend(state)
			self.a.value.extend(action)
			self.r.value.extend(reward)
			self.s_prime.value.extend(next_state)
			self.done.value.extend(done)

			self.memory_index += len(states)
			self.memory_amount+= len(states)

	def reset(self):
		with self.lock:
			self.s.value=[]
			self.a.value=[]
			self.r.value=[]
			self.s_prime.value=[]
			self.done.value = []

			self.memory_amount = 0
			self.memory_index = 0

	def get_records(self):
		with self.lock:
			return self.s,self.a,self.r,self.s_prime,self.done

class TrafficLight:
	def __init__(self):
		self.lock = mp.Lock()
		self.val = mp.Value("b",True)

	def get(self):
		with self.lock:
			return self.val.value

	def switch(self):
		with self.lock:
			self.val.value = not self.val.value

	def turn_off(self):
		with self.lock:
			self.val.value = False

class Counter(object):
	def __init__(self):
		self.val = mp.Value("i",0)
		self.lock = mo.Lock()

	def get(self):
		with self.lock:
			return self.val.value

	def reset(self):
		with self.lock:
			self.val.value = 0

	def increase(self):
		with self.lock:
			self.val.value += 1