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
        self.sampling = False
        self.choice = self.impact_choice(self.expertise_list)
        self.experience = self.expertise_list[self.choice]
        self.impact = np.zeros(self.n_choices)
        self.choices_count = np.zeros(self.n_choices)
        self.rewards_avg = np.zeros(self.n_choices)

        # For learning from social input and experience
        self.delta = 0.5 # balance between social impact and reward in target calculation
        self.alpha = 0.1 # learning rate for updating expertise based on reward

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

    def __str__(self):
        table = PrettyTable()
        table.field_names = ["Property", "Value"]

        table.add_row(["Agent ID", self.unique_id])
        table.add_row(["Strength", f"{self.strength:.3f}"])
        table.add_row(["Expertise List", self.expertise_list])
        table.add_row(["Experience", f"{self.experience:.3f}"])
        table.add_row(["Choice", self.choice])
        table.add_row(["Solved puzzles", self.done_puzzles])
        table.add_row(["Targets", self.targets])
        table.add_row(["Guesses", self.guesses])

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
        added_strength = np.zeros(self.model.n_choices)

        # Get neighbors and calculate impact based on their choices and strengths
        neighbors = self.model.grid.get_neighbors(self.node, include_center=False)
        for n in neighbors:
            impact[n.choice] += n.strength * n.experience
            added_strength[n.choice] += n.strength

        # impact = np.divide(impact, added_strength, out=np.zeros_like(impact), where=added_strength!=0)
        if self.debug_mode:
            print("-"*60)
            print(f"Agent {self.node} Impacts before stubbornness: {impact}")

        # Compare impact with own choice and strength
        # modifier = 1 - self.experience
        # impact *= modifier
        impact[self.choice] += self.experience
        if self.debug_mode:
            print("-"*60)
            print(f"Agent {self.node} (experience: {self.experience:.3f}) --- (strength: {self.strength:.3f}) --- (neighbors: {len(neighbors)}):")
            print(f"\tImpacts before softmax: {impact}")

        # Create probability distribution over choices using robust softmax
        distribution = self.robust_softmax(impact)
        if self.debug_mode:
            print(f"\tImpacts after softmax: {distribution}")

        # Update choice and experience based on social impact
        self.choice = self.impact_choice(distribution)
        self.experience = self.expertise_list[self.choice]
        self.impact = impact

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
        self.expertise_list = self.get_experience_vector()
        self.choice = self.impact_choice(self.expertise_list)
        
        # expertise for each choice
        self.experience = self.expertise_list[self.choice]

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
    
    def get_experience_vector(self):

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
        x = x * 1 / self.model.temperature
        exp_x = np.exp(x)
        return exp_x / np.sum(exp_x)
    
    def update_reward(self):
        beta = self.calculate_beta()
        target = self.calculate_target(beta)
        self.expertise_list[self.choice] += self.alpha * (target - self.expertise_list[self.choice])

    def calculate_beta(self):
        time_social = self.model.alignment_time
        time_work = self.model.work_duration
        return (self.delta * time_social) / (self.delta * time_social + (1 - self.delta) * time_work)

    def calculate_target(self, beta):
        reward = self.get_reward()
        social_impact = self.impact[self.choice]
        target = beta * social_impact + (1 - beta) * reward
        return target
    
    def get_reward(self):
        return self.done_puzzles

    def start_new_puzzle(self):
        self.targets = self.model.generate_targets()
        self.guesses = []
        self.done_count = 0
        self.needs_new = False
        
    def update_choice(self):
        distribution = self.robust_softmax(self.expertise_list)
        self.choice = self.impact_choice(distribution)
        self.experience = self.expertise_list[self.choice]

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