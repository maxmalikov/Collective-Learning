import numpy as np
import networkx as nx

from mesa import Model
from mesa.space import NetworkGrid
from mesa.datacollection import DataCollector

from agents_cl import CollectiveAgent


class CollectiveLearningModel(Model):

    def __init__(
        self, 
        n_agents=50, 
        n_choices=6,
        network_type="complete",
        alignment_max_time=1,
        consensus_threshold=0.9,
        seed=42
    ) -> None:

        super().__init__()

        self.num_agents = n_agents
        self.n_choices = n_choices

        self.rng = np.random.default_rng(seed=seed)
        self.seed = seed

        # globals for alignment phase
        self.alignment_max_time = 1      
        self.consensus_threshold = 0.9
        self.alignment_time = 0

        # globals for work phase
        self.current_round = 0
        self.total_puzzles = 0
        self.total_time = 0
        self.salary = 1

        # network
        self.G = self.create_network(network_type="complete")
        self.grid = NetworkGrid(self.G)

        # create agents
        self.agents_list = []

        for node in self.G.nodes():
            a = CollectiveAgent(
                model=self,
                node=node,
                rng=self.rng
            )
            self.agents_list.append(a)
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
                "Consensus": lambda m: m.calculate_consensus()
            },

            agent_reporters={
                "Choice": "choice",
                "Strength": "strength",
                "Stubbornness": "stubbornness",
                "Solved": "done_puzzles",
                "Reward": "reward_plot"
            }
        )

    def create_network(self, network_type="watts_strogatz"):
        """
        Create a network of the agents.
        """
        if network_type == "watts_strogatz":
            return nx.watts_strogatz_graph(self.num_agents, 4, 0.1)
        elif network_type == "complete":
            return nx.complete_graph(self.num_agents)
        elif network_type == "star":
            return nx.star_graph(self.num_agents)
        elif network_type == "wheel":
            return nx.wheel_graph(self.num_agents)
        elif network_type == "tree":
            return nx.tree_graph(self.num_agents)
        elif network_type == "erdos_renyi":
            return nx.erdos_renyi_graph(self.num_agents, 0.1)
        elif network_type == "barabasi_albert":
            return nx.barabasi_albert_graph(self.num_agents, 1)
        else:
            raise ValueError(f"Invalid network type: {network_type}")

    def generate_targets(self):
        return [self.rng.randint(0,9) for _ in range(3)]

    def step(self):
        """
        Equivalent to NetLogo 'go'
        """

        self.current_round += 1
        self.alignment_phase()
        self.work_phase()

        self.datacollector.collect(self)

    def alignment_phase(self):
        """
        Align the opinions of the agents.
        """

        self.alignment_time = 0
        run_alignment = True

        while run_alignment:

            self.alignment_time += 1

            self.rng.shuffle(self.agents_list)
            for agent in self.agents_list:
                agent.align_opinion()

            if self.alignment_time >= self.alignment_max_time:
                run_alignment = False
                break

            consensus = self.calculate_consensus()
            if consensus >= self.consensus_threshold:
                run_alignment = False
                break

        return self.alignment_time

    def work_phase(self):
        """
        Work phase.
        """
        pass

    def calculate_consensus(self):
        """
        Calculate the consensus of the agents.
        """
        return np.max(np.bincount([a.choice for a in self.agents_list])) / self.num_agents

    def draw_network(self, ax=None, figsize=(8, 8), seed=42):
        """
        Plot ``self.G``. Nodes are colored by each agent's current ``choice``.
        Dense graphs use a circular layout; sparser graphs use a spring layout.
        """
        import matplotlib.pyplot as plt

        G = self.G
        if ax is None:
            _, ax = plt.subplots(figsize=figsize)

        n, m = G.number_of_nodes(), G.number_of_edges()
        pos = (
            nx.circular_layout(G)
            if m > 4 * max(n, 1)
            else nx.spring_layout(G, seed=seed, k=2 / np.sqrt(max(n, 1)))
        )

        node_list = list(G.nodes())
        choice_by_node = {a.node: float(a.choice) for a in self.agents}
        colors = [choice_by_node[node] for node in node_list]

        lw = float(np.clip(400 / max(m, 1), 0.02, 1.0))
        alpha_e = float(np.clip(800 / max(m, 1), 0.05, 0.6))
        node_size = int(np.clip(800 // max(n, 1), 40, 200))

        nx.draw_networkx_nodes(
            G,
            pos,
            ax=ax,
            nodelist=node_list,
            node_size=node_size,
            node_color=colors,
            cmap=plt.cm.tab10,
            vmin=0,
            vmax=max(self.n_choices - 1, 1),
            edgecolors="white",
            linewidths=0.3,
        )
        nx.draw_networkx_edges(
            G, pos, ax=ax, width=lw, alpha=alpha_e, edge_color="#888888"
        )
        ax.set_axis_off()
        ax.set_title(f"{n} agents, {m} ties")
        return ax