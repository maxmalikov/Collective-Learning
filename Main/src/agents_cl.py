import numpy as np
import random

from mesa import Agent
from prettytable import PrettyTable
from typing import List


class CollectiveAgent(Agent):

    def __init__(self, model, node, num_digits, rng):
        super().__init__(model)
        
        self.node = node
        self.rng_ = rng
        self.num_digits = num_digits

        # persuasion
        self.strength = rng.random()

        # expertise for each choice
        self.n_choices = model.n_choices
        self.expertise_list = rng.random(self.n_choices)
        self.choice = np.argmax(self.expertise_list)
        self.stubbornness = self.expertise_list[self.choice]
        self.choices_count = np.zeros(self.n_choices)
        self.rewards_avg = np.zeros(self.n_choices)

        # puzzle state
        self.targets = []
        self.guesses = []
        self.memories = []
        self.done_flags = []

        self.done_count = 0
        self.needs_new = True
        self.done_puzzles = 0
        self.reward_plot = 0

        self.debug_mode = False
        self.sampling = False

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
        # Initialize impact vector
        impact = np.zeros(self.model.n_choices)

        # Get neighbors and calculate impact based on their choices and strengths
        neighbors = self.model.grid.get_neighbors(self.node, include_center=False)
        for n in neighbors:
            impact[n.choice] += n.strength

        # Compare impact with own choice and strength
        modifier = 1 - self.stubbornness
        impact *= modifier
        impact[self.choice] += self.stubbornness
        print("-"*60)
        print(f"Agent {self.node} (stubbornness: {self.stubbornness:.3f}) --- (strength: {self.strength:.3f}) --- (neighbors: {len(neighbors)}):")
        print(f"\tImpacts before softmax: {impact}")

        # Create probability distribution over choices using robust softmax
        impact = self.robust_softmax(impact)
        print(f"\tImpacts after softmax: {impact}")

        # Update choice and stubbornness based on impact
        self.choice = self.impact_choice(impact)
        self.stubbornness = self.expertise_list[self.choice]

    def impact_choice(self, impact:List[float]) -> int:
        if self.sampling is True:
            return self.rng_.choice(
                np.arange(self.n_choices),
                size=1,
                p=impact
            )[0]
        else:
            return np.argmax(impact)

    def reset_values(self):
        """
        placeholder
        """        
        
        # UPDATE SELF CHOICE
        self.expertise_list = self.get_stubbornness_vector()
        self.choice = np.random.choice(np.arange(self.model.n_choices), p = self.expertise_list)
        
        # expertise for each choice
        self.stubbornness = self.expertise_list[self.choice]

        # puzzle state
        self.targets = []
        self.guesses = []
        self.memories = []
        self.done_flags = []

        self.done_count = 0
        self.needs_new = True
        self.reward_plot = self.done_puzzles # storing done puzzles for plotting
        self.done_puzzles = 0

    def get_ucb_value(self, option):
        n = self.choices_count[option]
    
        # if never chosen
        if n == 0:
            n = 1
    
        t = np.sum(self.choices_count) + 1
    
        return self.model.explore_param * np.sqrt(np.log(t) / n)
    
    def get_stubbornness_vector(self):

        values = np.zeros(self.model.n_choices)
    
        for i in range(self.model.n_choices):
            reward_instance = self.rewards_avg[i]
    
            # fallback for zero reward
            if reward_instance == 0:
                reward_instance = self.model.work_duration / 6 # min expected reward rate TODO
                # reward_instance = 1
    
            values[i] = reward_instance + self.get_ucb_value(i)
    
        return self.robust_softmax(values)

    def robust_softmax(self, x):
        """
        Robust softmax function.
        """
        x = x - np.max(x)
        # x *= x * 1 / self.model.temperature
        exp_x = np.exp(x)
        return exp_x / np.sum(exp_x)
    
    def update_reward(self, reward):
        i = self.choice
    
        self.choices_count[i] += 1
    
        current_count = self.choices_count[i]
        current_value = self.rewards_avg[i]
    
        # incremental average
        self.rewards_avg[i] += (reward - current_value) / current_count

    def start_new_puzzle(self):
        self.targets = self.model.generate_targets()
        self.guesses = []
        self.done_count = 0
        self.needs_new = False
        
    def update_choice(self):
        pass

    def solve_puzzle(self):
        # initialize puzzle if needed
        if self.needs_new:
            self.targets = [self.rng_.integers(0, 10, 1) for _ in range(self.num_digits)]
            self.guesses = [None] * self.num_digits
            self.memories = [[] for _ in range(self.num_digits)]
            self.done_flags = [False] * self.num_digits
            self.done_count = 0
            self.needs_new = False
    
        group_choice = self.model.group_choice
        alignment_threshold = self.model.alignment_threshold
    
        for i in range(self.num_digits):
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
    
            if len(available) == 0:
                raise ValueError(f"No available digits for digit {i}")
    
            # make a guess
            guess = self.rng_.choice(available)
            #print(guess)
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
        if self.debug_mode:
            if self.unique_id == 1:
                print(self)

        # check completion
        if self.done_count == self.num_digits:
            self.done_count = 0
            self.needs_new = True
            self.done_puzzles += 1