import torch
import torch.multiprocessing as mp
import numpy as np

memory_capacity = 10000

class GameRecord(object):
	"""docstring for GameRecord"""
	def __init__(self,manager):
		super(GameRecord, self).__init__()
		self.lock = mp.Lock()
		self.s=manager.list()
		self.a=manager.list()
		self.r=manager.list()
		self.s_prime=manager.list()
		self.done = manager.list()
		self.memory_amount = mp.Value('i',0)
		self.memory_index = mp.Value('i',0)

	def add_records(self, states, actions, rewards, next_states, done):
		with self.lock:
			self.s.extend(states)
			self.a.extend(actions)
			self.r.extend(rewards)
			self.s_prime.extend(next_states)
			self.done.extend(done)

			self.memory_index.value += len(states)
			self.memory_amount.value += len(states)

	def reset(self):
		with self.lock:
			del self.s[:]
			del self.a[:]
			del self.r[:]
			del self.s_prime[:]
			del self.done[:]

			self.memory_amount.value = 0
			self.memory_index.value = 0

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
		self.lock = mp.Lock()

	def get(self):
		with self.lock:
			return self.val.value

	def reset(self):
		with self.lock:
			self.val.value = 0

	def increase(self):
		with self.lock:
			self.val.value += 1