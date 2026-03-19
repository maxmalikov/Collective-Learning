import random
from mesa import Agent
from prettytable import PrettyTable

class CollectiveAgent(Agent):

    def __init__(self, model):
        super().__init__(model)

        # persuasion
        self.strength = random.random()

        # expertise for each choice
        self.expertise_list = [random.random() for _ in range(model.n_choices)]

        self.rewards_count = [0]*model.n_choices
        self.rewards_avg = [0]*model.n_choices

        self.stubbornness = 0
        self.choice = random.randrange(model.n_choices)

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

        return table.get_string()

    def step(self):
        """
        Equivalent to NetLogo turtle step.
        """
        self.align_opinion()
        self.solve_puzzle()


    def align_opinion(self):
        """
        Implement the Nowak-Szamrej-Latane persuasion dynamics here.
        """
        neighbors = self.model.grid.get_neighbors(self.pos, include_center=False)

        influence = [0]*self.model.n_choices

        for n in neighbors:
            influence[n.choice] += n.strength

        best_choice = influence.index(max(influence))

        if random.random() > self.stubbornness:
            self.choice = best_choice


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