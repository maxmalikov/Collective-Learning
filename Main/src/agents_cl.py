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
        
    def reset_values(self):
        """
        placeholder
        """        
        pass

    def robust_softmax(self, x):
        """
        Robust softmax function.
        """
        x = x - np.max(x)
        exp_x = np.exp(x)
        return exp_x / np.sum(exp_x)

    def solve_puzzle_old(self):
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
        
    def solve_puzzle(self):
        # initialize puzzle if needed
        if self.needs_new:
            self.targets = [random.randint(0, 9) for _ in range(6)]
            self.guesses = [None] * 6
            self.memories = [[] for _ in range(6)]
            self.done_flags = [False] * 6
            self.done_count = 0
            self.needs_new = False
    
        group_choice = self.model.group_choice
        alignment_threshold = self.model.alignment_threshold
    
        for i in range(6):
            if self.done_flags[i]:
                continue
    
            target = self.targets[i]
            mem = self.memories[i]
    
            # available digits
            available = list(range(10))
    
            # --- HINT GENERATION (pre-guess pruning) ---
            if self.choice == group_choice or i < alignment_threshold:
    
                # 0 -> even/odd
                if self.choice == 0:
                    if target % 2 == 0:
                        mem.extend([1, 3, 5, 7, 9])
                    else:
                        mem.extend([0, 2, 4, 6, 8])
    
                # 1 -> prime
                elif self.choice == 1:
                    if target in [1, 2, 3, 5, 7]:
                        mem.extend([0, 4, 6, 8, 9])
                    else:
                        mem.extend([1, 2, 3, 5, 7])
    
                # 2 -> number of letters
                elif self.choice == 2:
                    if target in [1, 2, 6]:
                        mem.extend([3, 4, 5, 7, 8, 9, 0])
                    elif target in [4, 5, 9, 0]:
                        mem.extend([1, 2, 3, 6, 7, 8])
                    elif target in [3, 7, 8]:
                        mem.extend([1, 2, 4, 5, 6, 9, 0])
    
                # 3 -> number of "e"s
                elif self.choice == 3:
                    if target in [2, 4, 6]:
                        mem.extend([1, 3, 5, 7, 8, 9, 0])
                    elif target in [1, 5, 8, 9, 0]:
                        mem.extend([2, 3, 4, 6, 7])
                    elif target in [3, 7]:
                        mem.extend([1, 2, 4, 5, 6, 8, 9, 0])
    
            # filter available digits
            available = [x for x in available if x not in mem]
    
            if not available:
                continue
    
            # make a guess
            guess = random.choice(available)
            self.guesses[i] = guess
            mem.append(guess)
    
            # --- POST-GUESS HINTS ---
            if self.choice == group_choice or i < alignment_threshold:
    
                # 4 -> higher/lower
                if self.choice == 4:
                    if target > guess:
                        mem.extend([x for x in available if x < guess])
                    elif target < guess:
                        mem.extend([x for x in available if x > guess])
    
                # 5 -> distance
                elif self.choice == 5:
                    dist = abs(target - guess)
                    mem.extend([x for x in available if abs(x - guess) != dist])
    
            # check correctness
            if guess == target:
                self.done_flags[i] = True
                self.done_count += 1
    
            # save memory
            self.memories[i] = mem
            
        # check output
        if self.unique_id == 1:
            print(self)
    
        # check completion
        if self.done_count == 6:
            self.done_count = 0
            self.needs_new = True
            self.done_puzzles += 1