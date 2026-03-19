import random
import numpy as np
import networkx as nx

from mesa import Model
from mesa.space import NetworkGrid
from mesa.datacollection import DataCollector

from agents_cl import CollectiveAgent

class CollectiveLearningModel(Model):

    def __init__(self, n_agents=50, n_choices=6):

        super().__init__()

        self.num_agents = n_agents
        self.n_choices = n_choices

        # globals
        self.alignment_time = 0
        self.current_round = 0
        self.total_puzzles = 0
        self.total_time = 0
        self.salary = 1

        # network
        self.G = nx.watts_strogatz_graph(n_agents, 4, 0.1)
        self.grid = NetworkGrid(self.G)

        # create agents
        self.agents_list = []

        for i in range(n_agents):
            a = CollectiveAgent(self)
            self.agents_list.append(a)

            node = list(self.G.nodes())[i]
            self.grid.place_agent(a, node)

        self.datacollector = DataCollector(

            model_reporters={
                "Round": lambda m: m.current_round,
                "Total_Puzzles": lambda m: m.total_puzzles,
                "Total_Time": lambda m: m.total_time,

                # mean puzzles solved
                "Mean_Puzzles_Solved": lambda m: np.mean(
                    [a.done_puzzles for a in m.agents]
                ),

                # consensus level
                "Consensus": lambda m: np.max(
                    np.bincount([a.choice for a in m.agents])
                ) / m.num_agents
            },

            agent_reporters={
                "Choice": "choice",
                "Strength": "strength",
                "Stubbornness": "stubbornness",
                "Solved": "done_puzzles",
                "Reward": "reward_plot"
            }
        )


    def generate_targets(self):
        return [random.randint(0,9) for _ in range(3)]


    def step(self):
        """
        Equivalent to NetLogo 'go'
        """

        self.random.shuffle(self.agents_list)

        for agent in self.agents_list:
            agent.step()

        self.current_round += 1

        self.datacollector.collect(self)