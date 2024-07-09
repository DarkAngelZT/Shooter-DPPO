import torch
import torch.multiprocessing as mp
import numpy as np

memory_capacity = 10000

class GameRecord(object):
	"""docstring for GameRecord"""
	def __init__(self):
		super(GameRecord, self).__init__()
		self.lock = mp.Lock()
		self.s=mp.Value('s',[])
		self.a=mp.Value('a',[])
		self.r=mp.Value('r',[])
		self.s_prime=mp.Value('s_',[])
		self.done = mp.Value('done',[])
		self.memory_amount = mp.Value('amount',0)
		self.memory_index = mp.Value('idx',0)

	def add_records(self, states, actions, rewards, next_states, done):
		with self.lock:
			self.s.extend(state)
			self.a.extend(action)
			self.r.extend(reward)
			self.s_prime.extend(next_state)
			self.done.extend(done)

			self.memory_index += len(states)
			self.memory_amount+= len(states)

	def reset(self):
		with self.lock:
			self.s=[]
			self.a=[]
			self.r=[]
			self.s_prime=[]
			self.done = []

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
		self.val = mp.Value("c",0)
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