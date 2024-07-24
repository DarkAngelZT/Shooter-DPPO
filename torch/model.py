import torch
import torch.nn as nn
import torch.optim as optim
from torch.nn import functional as F

class Actor(nn.Module):
	"""Actor Net"""
	def __init__(self, n_states,n_actions, hidden_dim):
		super(Actor, self).__init__()
		self.model = nn.Sequential(
			nn.Linear(n_states, hidden_dim),
			nn.ReLU(inplace=True),
			nn.Linear(hidden_dim,hidden_dim),
			nn.ReLU(inplace=True),
			nn.Linear(hidden_dim,hidden_dim),
			nn.ReLU(inplace=True),
			nn.Linear(hidden_dim,n_actions),
		)
		self.actor_logstd = nn.Parameter(torch.zeros(1, n_actions))
	
	def forward(self, inputs):
		x = self.model(inputs)
		mean = torch.tanh(x)
		# action_logstd = self.actor_logstd.expand_as(mean)
		action_std = torch.exp(self.actor_logstd)
		dist = torch.distributions.Normal(mean, action_std)
		a = dist.sample()
		return a, dist.log_prob(a).sum(1)

	def get_action(self,inputs):
		x = self.model(inputs)
		mean = torch.tanh(x)
		# action_logstd = self.actor_logstd.expand_as(mean)
		action_std = torch.exp(self.actor_logstd)
		dist = torch.distributions.Normal(mean, action_std)
		a = dist.sample()
		return a

class Critic(nn.Module):
	"""Critic Net"""
	def __init__(self, n_states, hidden_dim):
		super(Critic, self).__init__()
		self.model = nn.Sequential(
			nn.Linear(n_states, hidden_dim*3),
			nn.ReLU(inplace=True),
			nn.Linear(hidden_dim*3,1),
		)
	
	def forward(self, inputs):
		return self.model(inputs)
