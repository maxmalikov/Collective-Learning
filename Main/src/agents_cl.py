import numpy as np
import random
from mesa import Agent
from prettytable import PrettyTable

class CollectiveAgent(Agent):

    def __init__(self, model, node, rng):
        super().__init__(model)

        self.node = node

        # persuasion
        self.strength = rng.random()

        # expertise for each choice
        self.expertise_list = rng.random(model.n_choices)
        self.choice = np.argmax(self.expertise_list)
        self.stubbornness = self.expertise_list[self.choice]
        self.rewards_count = np.zeros(model.n_choices)
        self.rewards_avg = np.zeros(model.n_choices)

        # puzzle state
        self.targets = []
        self.guesses = []
        self.memories = []
        self.done_flags = []

        self.done_count = 0
        self.needs_new = True
        self.done_puzzles = 0
        self.reward_plot = 0

    def __str__(self):
        table = PrettyTable()
        table.field_names = ["Property", "Value"]

        table.add_row(["Agent ID", self.unique_id])
        table.add_row(["Choice", self.choice])
        table.add_row(["Strength", f"{self.strength:.3f}"])
        table.add_row(["Stubbornness", f"{self.stubbornness:.3f}"])
        table.add_row(["Solved puzzles", self.done_puzzles])
        table.add_row(["Targets", self.targets])
        table.add_row(["Guesses", self.guesses])
        table.add_row(["Expertise List", self.expertise_list])

        return table.get_string()

    def step(self):
        """
        Equivalent to NetLogo turtle step.
        """
        pass

    def align_opinion(self):
        """
        Implement the Nowak-Szamrej-Latane persuasion dynamics here.
        Use experience-based stubbornness to determine the best choice.
        """
        neighbors = self.model.grid.get_neighbors(self.node, include_center=False)

        influence = np.zeros(self.model.n_choices)

        for n in neighbors:
            influence[n.choice] += n.strength

        modifier = 1 - self.stubbornness
        influence *= modifier
        #influence += self.expertise_list
        influence[self.choice] += self.stubbornness
        #influence = self.robust_softmax(influence)
        self.choice = np.argmax(influence)
        self.stubbornness = self.expertise_list[self.choice]

    def robust_softmax(self, x):
        """
        Robust softmax function.
        """
        x = x - np.max(x)
        exp_x = np.exp(x)
        return exp_x / np.sum(exp_x)

    def solve_puzzle(self):
        """
        Guessing / reward learning part.
        """
        if self.needs_new:
            self.start_new_puzzle()

        # placeholder guess logic
        guess = random.randint(0,9)

        self.guesses.append(guess)

        if guess in self.targets:
            self.done_count += 1

        if self.done_count == len(self.targets):
            self.done_puzzles += 1
            self.needs_new = True


    def start_new_puzzle(self):
        self.targets = self.model.generate_targets()
        self.guesses = []
        self.done_count = 0
        self.needs_new = False