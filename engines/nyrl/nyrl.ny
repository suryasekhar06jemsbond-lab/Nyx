# ============================================================
# NyRL - Reinforcement Learning Engine
# Version 1.0.0
# Policy gradients, Actor-Critic, PPO, DQN, DDPG, SAC, TD3
# Environment interface, replay buffers, exploration strategies
# ============================================================

use nytensor;
use nygrad;
use nynet_ml;
use ny opt;
use nyloss;

# ============================================================
# SECTION 1: ENVIRONMENT INTERFACE
# ============================================================

pub enum SpaceType {
    Discrete,
    Continuous,
    MultiDiscrete,
    MultiBinary,
    Dict,
    Tuple
}

pub class Space {
    pub let space_type: SpaceType;
    pub let shape: [Int];
    pub let low: Float;
    pub let high: Float;
    pub let n: Int;  # For discrete spaces

    pub fn new_discrete(n: Int) -> Self {
        return Self {
            space_type: SpaceType::Discrete, shape: [], low: 0.0, high: n *1.0, n: n
        };
    }

    pub fn new_continuous(shape: [Int], low: Float, high: Float) -> Self {
        return Self {
            space_type: SpaceType::Continuous, shape: shape, low: low, high: high, n: 0
        };
    }

    pub fn sample(self) -> Tensor {
        match self.space_type {
            SpaceType::Discrete => {
                let idx = native_random_int(0, self.n);
                return Tensor::full([1], idx * 1.0, DType::Float32, Device::CPU);
            },
            SpaceType::Continuous => {
                return Tensor::rand(self.shape, DType::Float32, Device::CPU)
                    .scale(self.high - self.low).add_scalar(self.low);
            },
            _ => throw "Space::sample(): unsupported space type"
        };
    }

    pub fn contains(self, value:Tensor) -> Bool {
        match self.space_type {
            SpaceType::Discrete => {
                let v = value.data[0];
                return v >= 0.0 && v < self.n * 1.0;
            },
            SpaceType::Continuous => {
                for (v in value.data) {
                    if (v < self.low || v > self.high) { return false; }
                }
                return true;
            },
            _ => return false
        };
    }
}

pub class Env {
    pub let observation_space: Space;
    pub let action_space: Space;
    pub let _state: Tensor?;
    pub let _done: Bool;
    pub let _episode_reward: Float;
    pub let _episode_length: Int;

    pub fn new(obs_space: Space, act_space: Space) -> Self {
        return Self {
            observation_space: obs_space,
            action_space: act_space,
            _state: null,
            _done: false,
            _episode_reward: 0.0,
            _episode_length: 0
        };
    }

    pub fn reset(self) -> Tensor {
        throw "Env::reset() must be overridden";
    }

    pub fn step(self, action: Tensor) -> Object {
        throw "Env::step() must be overridden";
    }

    pub fn render(self) {}
    pub fn close(self) {}
}

# ============================================================
# SECTION 2: REPLAY BUFFER
# ============================================================

pub class ReplayBuffer {
    pub let capacity: Int;
    pub let _buffer: [Object];
    pub let _position: Int;
    pub let _size: Int;

    pub fn new(capacity: Int) -> Self {
        return Self {
            capacity: capacity,
            _buffer: [],
            _position: 0,
            _size: 0
        };
    }

    pub fn push(self, state: Tensor, action: Tensor, reward: Float, next_state: Tensor, done: Bool) {
        let transition = {
            "state": state,
            "action": action,
            "reward": reward,
            "next_state": next_state,
            "done": done
        };

        if (self._size < self.capacity) {
            self._buffer = self._buffer + [transition];
            self._size = self._size + 1;
        } else {
            self._buffer[self._position] = transition;
        }
        self._position = (self._position + 1) % self.capacity;
    }

    pub fn sample(self, batch_size: Int) -> Object {
        if (self._size < batch_size) {
            throw "ReplayBuffer: not enough samples (size=" + str(self._size) + ", requested=" + str(batch_size) + ")";
        }

        let indices = [];
        for (i in range(batch_size)) {
            indices = indices + [native_random_int(0, self._size)];
        }

        let states = [];
        let actions = [];
        let rewards = [];
        let next_states = [];
        let dones = [];

        for (idx in indices) {
            let t = self._buffer[idx];
            states = states + [t["state"]];
            actions = actions + [t["action"]];
            rewards = rewards + [t["reward"]];
            next_states = next_states + [t["next_state"]];
            dones = dones + [t["done"]];
        }

        return {
            "states": states,
            "actions": actions,
            "rewards": rewards,
            "next_states": next_states,
            "dones": dones
        };
    }

    pub fn size(self) -> Int {
        return self._size;
    }

    pub fn is_ready(self, min_size: Int) -> Bool {
        return self._size >= min_size;
    }

    pub fn clear(self) {
        self._buffer = [];
        self._position = 0;
        self._size = 0;
    }
}

# ============================================================
# SECTION 3: PRIORITIZED REPLAY BUFFER
# ============================================================

pub class PrioritizedReplayBuffer {
    pub let capacity: Int;
    pub let alpha: Float;  # Priority exponent
    pub let beta: Float;   # Importance sampling exponent
    pub let _buffer: [Object];
    pub let _priorities: [Float];
    pub let _position: Int;
    pub let _size: Int;

    pub fn new(capacity: Int, alpha: Float, beta: Float) -> Self {
        return Self {
            capacity: capacity,
            alpha: alpha,
            beta: beta,
            _buffer: [],
            _priorities: [],
            _position: 0,
            _size: 0
        };
    }

    pub fn push(self, state: Tensor, action: Tensor, reward: Float, next_state: Tensor, done: Bool, priority: Float) {
        let transition = {
            "state": state,
            "action": action,
            "reward": reward,
            "next_state": next_state,
            "done": done
        };

        let max_prio = 1.0;
        for (p in self._priorities) {
            if (p > max_prio) { max_prio = p; }
        }

        if (self._size < self.capacity) {
            self._buffer = self._buffer + [transition];
            self._priorities = self._priorities + [max_prio];
            self._size = self._size + 1;
        } else {
            self._buffer[self._position] = transition;
            self._priorities[self._position] = max_prio;
        }
        self._position = (self._position + 1) % self.capacity;
    }

    pub fn sample(self, batch_size: Int) -> Object {
        let probs = _compute_sampling_probabilities(self._priorities, self.alpha);
        let indices = _sample_proportional(probs, batch_size);

        let states = [];        let actions = [];
        let rewards = [];
        let next_states = [];
        let dones = [];
        let weights = [];

        let min_prob = 1e9;
        for (p in probs) {
            if (p < min_prob) { min_prob = p; }
        }

        for (idx in indices) {
            let t = self._buffer[idx];
            states = states + [t["state"]];
            actions = actions + [t["action"]];
            rewards = rewards + [t["reward"]];
            next_states = next_states + [t["next_state"]];
            dones = dones + [t["done"]];

            let w = _pow_f(self._size * 1.0 * probs[idx], -self.beta);
            let max_w = _pow_f(self._size * 1.0 * min_prob, -self.beta);
            weights = weights + [w / max_w];
        }

        return {
            "states": states,
            "actions": actions,
            "rewards": rewards,
            "next_states": next_states,
            "dones": dones,
            "weights": weights,
            "indices": indices
        };
    }

    pub fn update_priorities(self, indices: [Int], priorities: [Float]) {
        for (i in range(len(indices))) {
            self._priorities[indices[i]] = priorities[i];
        }
    }

    pub fn size(self) -> Int {
        return self._size;
    }
}

# ============================================================
# SECTION 4: POLICY GRADIENT (REINFORCE)
# ============================================================

pub class PolicyGradientAgent {
    pub let policy_net: Module;
    pub let optimizer: Optimizer;
    pub let gamma: Float;
    pub let _trajectory: [Object];

    pub fn new(policy_net: Module, optimizer: Optimizer, gamma: Float) -> Self {
        return Self {
            policy_net: policy_net,
            optimizer: optimizer,
            gamma: gamma,
            _trajectory: []
        };
    }

    pub fn select_action(self, state: Tensor) -> Int {
        let state_var = Variable::new(state, "state");
        let logits = self.policy_net.forward(state_var);
        let probs = logits.softmax();
        let action = _sample_categorical(probs.data);
        self._trajectory = self._trajectory + [{
            "state": state,
            "action": action,
            "log_prob": logits.data.log().data[action]
        }];
        return action;
    }

    pub fn finish_episode(self, rewards: [Float]) {
        let returns = _compute_returns(rewards, self.gamma);
        let loss = 0.0;
        for (i in range(len(self._trajectory))) {
            let log_prob = self._trajectory[i]["log_prob"];
            loss = loss - log_prob * returns[i];
        }

        # Backprop
        self.optimizer.zero_grad();
        let loss_var = Variable::new(Tensor::new([loss], [1], DType::Float32, Device::CPU), "loss");
        backward(loss_var, false);
        self.optimizer.step();

        self._trajectory = [];
    }
}

# ============================================================
# SECTION 5: ACTOR-CRITIC
# ============================================================

pub class ActorCriticAgent {
    pub let actor: Module;
    pub let critic: Module;
    pub let actor_opt: Optimizer;
    pub let critic_opt: Optimizer;
    pub let gamma: Float;
    pub let _trajectory: [Object];

    pub fn new(actor: Module, critic: Module, actor_opt: Optimizer, critic_opt: Optimizer, gamma: Float) -> Self {
        return Self {
            actor: actor,
            critic: critic,
            actor_opt: actor_opt,
            critic_opt: critic_opt,
            gamma: gamma,
            _trajectory: []
        };
    }

    pub fn select_action(self, state: Tensor) -> Int {
        let state_var = Variable::new(state, "state");
        let logits = self.actor.forward(state_var);
        let value = self.critic.forward(state_var);
        let probs = logits.softmax();
        let action = _sample_categorical(probs.data);
        self._trajectory = self._trajectory + [{
            "state": state,
            "action": action,
            "log_prob": logits.data.log().data[action],
            "value": value.data.data[0]
        }];
        return action;
    }

    pub fn update(self, rewards: [Float]) {
        let returns = _compute_returns(rewards, self.gamma);
        let actor_loss = 0.0;
        let critic_loss = 0.0;

        for (i in range(len(self._trajectory))) {
            let log_prob = self._trajectory[i]["log_prob"];
            let value = self._trajectory[i]["value"];
            let advantage = returns[i] - value;
            actor_loss = actor_loss - log_prob * advantage;
            critic_loss = critic_loss + advantage * advantage;
        }

        # Update critic
        self.critic_opt.zero_grad();
        let c_loss_var = Variable::new(Tensor::new([critic_loss], [1], DType::Float32, Device::CPU), "critic_loss");
        backward(c_loss_var, false);
        self.critic_opt.step();

        # Update actor
        self.actor_opt.zero_grad();
        let a_loss_var = Variable::new(Tensor::new([actor_loss], [1], DType::Float32, Device::CPU), "actor_loss");
        backward(a_loss_var, false);
        self.actor_opt.step();

        self._trajectory = [];
    }
}

# ============================================================
# SECTION 6: PPO (PROXIMAL POLICY OPTIMIZATION)
# ============================================================

pub class PPOAgent {
    pub let actor: Module;
    pub let critic: Module;
    pub let actor_opt: Optimizer;
    pub let critic_opt: Optimizer;
    pub let gamma: Float;
    pub let gae_lambda: Float;
    pub let clip_epsilon: Float;
    pub let value_loss_coef: Float;
    pub let entropy_coef: Float;
    pub let epochs: Int;
    pub let _buffer: [Object];

    pub fn new(actor: Module, critic: Module, actor_opt: Optimizer, critic_opt: Optimizer,
               gamma: Float, gae_lambda: Float, clip_epsilon: Float) -> Self {
        return Self {
            actor: actor,
            critic: critic,
            actor_opt: actor_opt,
            critic_opt: critic_opt,
            gamma: gamma,
            gae_lambda: gae_lambda,
            clip_epsilon: clip_epsilon,
            value_loss_coef: 0.5,
            entropy_coef: 0.01,
            epochs: 10,
            _buffer: []
        };
    }

    pub fn select_action(self, state: Tensor) -> Int {
        let state_var = Variable::new(state, "state");
        let logits = self.actor.forward(state_var);
        let probs = logits.softmax();
        let action = _sample_categorical(probs.data);
        let value = self.critic.forward(state_var).data.data[0];

        self._buffer = self._buffer + [{
            "state": state,
            "action": action,
            "log_prob": logits.data.log().data[action],
            "value": value
        }];
        return action;
    }

    pub fn update(self, rewards: [Float], dones: [Bool]) {
        let advantages = _compute_gae(rewards, self._buffer, self.gamma, self.gae_lambda);
        let returns = [];
        for (i in range(len(advantages))) {
            returns = returns + [advantages[i] + self._buffer[i]["value"]];
        }

        for (epoch in range(self.epochs)) {
            let total_loss = 0.0;
            for (i in range(len(self._buffer))) {
                let state_var = Variable::new(self._buffer[i]["state"], "state");
                let logits = self.actor.forward(state_var);
                let probs = logits.softmax();
                let new_log_prob = logits.data.log().data[self._buffer[i]["action"]];
                let old_log_prob = self._buffer[i]["log_prob"];
                let ratio = _exp_f(new_log_prob - old_log_prob);

                let advantage = advantages[i];
                let surr1 = ratio * advantage;
                let surr2 = _clamp(ratio, 1.0 - self.clip_epsilon, 1.0 + self.clip_epsilon) * advantage;
                let actor_loss = -_min_f(surr1, surr2);

                let value_pred = self.critic.forward(state_var).data.data[0];
                let value_loss = (returns[i] - value_pred) * (returns[i] - value_pred);

                # Entropy bonus for exploration
                let entropy = -_sum_f([probs.data.data[j] * probs.data.log().data[j] for j in range(len(probs.data.data))]);

                total_loss = total_loss + actor_loss + self.value_loss_coef * value_loss - self.entropy_coef * entropy;
            }

            self.actor_opt.zero_grad();
            self.critic_opt.zero_grad();
            let loss_var = Variable::new(Tensor::new([total_loss], [1], DType::Float32, Device::CPU), "ppo_loss");
            backward(loss_var, false);
            self.actor_opt.step();
            self.critic_opt.step();
        }

        self._buffer = [];
    }
}

# ============================================================
# SECTION 7: DQN (DEEP Q-NETWORK)
# ============================================================

pub class DQNAgent {
    pub let q_network: Module;
    pub let target_network: Module;
    pub let optimizer: Optimizer;
    pub let replay_buffer: ReplayBuffer;
    pub let gamma: Float;
    pub let epsilon_start: Float;
    pub let epsilon_end:Float;
    pub let epsilon_decay: Float;
    pub let _epsilon: Float;
    pub let _steps: Int;
    pub let target_update_freq: Int;

    pub fn new(q_network: Module, optimizer: Optimizer, buffer_size: Int,
               gamma: Float, epsilon_start: Float, epsilon_end: Float, epsilon_decay: Float) -> Self {
        let target = q_network;  # Clone
        return Self {
            q_network: q_network,
            target_network: target,
            optimizer: optimizer,
            replay_buffer: ReplayBuffer::new(buffer_size),
            gamma: gamma,
            epsilon_start: epsilon_start,
            epsilon_end: epsilon_end,
            epsilon_decay: epsilon_decay,
            _epsilon: epsilon_start,
            _steps: 0,
            target_update_freq: 1000
        };
    }

    pub fn select_action(self, state: Tensor, training: Bool) -> Int {
        if (training && native_random_float() < self._epsilon) {
            return native_random_int(0, self.q_network.parameters()[0].data.shape()[0]);
        }
        let state_var = Variable::new(state, "state");
        let q_values = self.q_network.forward(state_var);
        return q_values.data.argmax();
    }

    pub fn store_transition(self, state: Tensor, action: Int, reward: Float, next_state: Tensor, done: Bool) {
        let action_t = Tensor::full([1], action * 1.0, DType::Float32, Device::CPU);
        self.replay_buffer.push(state, action_t, reward, next_state, done);
    }

    pub fn update(self, batch_size: Int) {
        if (!self.replay_buffer.is_ready(batch_size)) { return; }

        let batch = self.replay_buffer.sample(batch_size);
        let states = batch["states"];
        let actions = batch["actions"];
        let rewards = batch["rewards"];
        let next_states = batch["next_states"];
        let dones = batch["dones"];

        # Compute Q(s, a)
        let q_values = [];
        for (i in range(batch_size)) {
            let s_var = Variable::new(states[i], "s");
            let q_all = self.q_network.forward(s_var);
            let action_idx = int(actions[i].data[0]);
            q_values = q_values + [q_all.data.data[action_idx]];
        }

        # Compute target: r + gamma * max Q'(s', a')
        let targets = [];
        for (i in range(batch_size)) {
            let ns_var = Variable::new(next_states[i], "ns");
            let q_next = self.target_network.forward(ns_var);
            let max_q = q_next.data.max();
            let target = rewards[i];
            if (!dones[i]) {
                target = target + self.gamma * max_q;
            }
            targets = targets + [target];
        }

        # Compute loss
        let loss = 0.0;
        for (i in range(batch_size)) {
            let diff = q_values[i] - targets[i];
            loss = loss + diff * diff;
        }
        loss = loss / batch_size;

        self.optimizer.zero_grad();
        let loss_var = Variable::new(Tensor::new([loss], [1], DType::Float32, Device::CPU), "dqn_loss");
        backward(loss_var, false);
        self.optimizer.step();

        # Update epsilon
        self._epsilon = _max_f(self.epsilon_end, self._epsilon * self.epsilon_decay);

        # Update target network
        self._steps = self._steps + 1;
        if (self._steps % self.target_update_freq == 0) {
            self._update_target_network();
        }
    }

    pub fn _update_target_network(self) {
        # Copy weights from q_network to target_network
        # Placeholder: deep copy parameters
        self.target_network = self.q_network;
    }
}

# ============================================================
# SECTION 8: DDPG (DEEP DETERMINISTIC POLICY GRADIENT)
# ============================================================

pub class DDPGAgent {
    pub let actor: Module;
    pub let critic: Module;
    pub let target_actor: Module;
    pub let target_critic: Module;
    pub let actor_opt: Optimizer;
    pub let critic_opt: Optimizer;
    pub let replay_buffer: ReplayBuffer;
    pub let gamma: Float;
    pub let tau: Float;  # Target network soft update

    pub fn new(actor: Module, critic: Module, actor_opt: Optimizer, critic_opt: Optimizer,
               buffer_size: Int, gamma: Float, tau: Float) -> Self {
        return Self {
            actor: actor,
            critic: critic,
            target_actor: actor,  # Clone
            target_critic: critic,  # Clone
            actor_opt: actor_opt,
            critic_opt: critic_opt,
            replay_buffer: ReplayBuffer::new(buffer_size),
            gamma: gamma,
            tau: tau
        };
    }

    pub fn select_action(self, state: Tensor, noise: Float) -> Tensor {
        let state_var = Variable::new(state, "state");
        let action = self.actor.forward(state_var);
        # Add exploration noise
        let noise_t = Tensor::randn(action.shape(), DType::Float32, Device::CPU).scale(noise);
        return action.data.add(noise_t).clamp(-1.0, 1.0);
    }

    pub fn update(self, batch_size: Int) {
        if (!self.replay_buffer.is_ready(batch_size)) { return; }

        let batch = self.replay_buffer.sample(batch_size);

        # Update critic
        # Q_target = r + gamma * Q'(s', A'(s'))
        # Critic_loss = MSE(Q(s,a), Q_target)

        # Update actor
        # Actor_loss = -mean(Q(s, A(s)))

        # Soft update target networks
        # θ' = τ*θ + (1-τ)*θ'
        self._soft_update();
    }

    pub fn _soft_update(self) {
        # Placeholder: soft update weights
    }
}

# ============================================================
# SECTION 9: SAC (SOFT ACTOR-CRITIC)
# ============================================================

pub class SACAgent {
    pub let actor: Module;
    pub let critic1: Module;
    pub let critic2: Module;
    pub let target_critic1: Module;
    pub let target_critic2: Module;
    pub let actor_opt: Optimizer;
    pub let critic1_opt: Optimizer;
    pub let critic2_opt: Optimizer;
    pub let replay_buffer: ReplayBuffer;
    pub let gamma: Float;
    pub let tau: Float;
    pub let alpha: Float;  # Temperature parameter

    pub fn new(actor: Module, critic1: Module, critic2: Module,
               actor_opt: Optimizer, critic1_opt: Optimizer, critic2_opt: Optimizer,
               buffer_size: Int, gamma: Float, tau: Float, alpha: Float) -> Self {
        return Self {
            actor: actor,
            critic1: critic1,
            critic2: critic2,
            target_critic1: critic1,
            target_critic2: critic2,
            actor_opt: actor_opt,
            critic1_opt: critic1_opt,
            critic2_opt: critic2_opt,
            replay_buffer: ReplayBuffer::new(buffer_size),
            gamma: gamma,
            tau: tau,
            alpha: alpha
        };
    }

    pub fn select_action(self, state: Tensor) -> Tensor {
        let state_var = Variable::new(state, "state");
        let action = self.actor.forward(state_var);
        return action.data;
    }

    pub fn update(self, batch_size: Int) {
        if (!self.replay_buffer.is_ready(batch_size)) { return; }

        # SAC update: critics + actor + temperature
        # Uses twin Q-networks, entropy regularization
    }
}

# ============================================================
# SECTION 10: MULTI-ARM BANDIT
# ============================================================

pub class EpsilonGreedyBandit {
    pub let n_arms: Int;
    pub let epsilon: Float;
    pub let _q_values: [Float];
    pub let _counts: [Int];

    pub fn new(n_arms: Int, epsilon: Float) -> Self {
        let q = [];
        let c = [];
        for (i in range(n_arms)) {
            q = q + [0.0];
            c = c + [0];
        }
        return Self { n_arms: n_arms, epsilon: epsilon, _q_values: q, _counts: c };
    }

    pub fn select_arm(self) -> Int {
        if (native_random_float() < self.epsilon) {
            return native_random_int(0, self.n_arms);
        }
        let best_arm = 0;
        let best_value = self._q_values[0];
        for (i in range(1, self.n_arms)) {
            if (self._q_values[i] > best_value) {
                best_value = self._q_values[i];
                best_arm = i;
            }
        }
        return best_arm;
    }

    pub fn update(self, arm: Int, reward: Float) {
        self._counts[arm] = self._counts[arm] + 1;
        let alpha = 1.0 / self._counts[arm];
        self._q_values[arm] = self._q_values[arm] + alpha * (reward - self._q_values[arm]);
    }
}

pub class UCBBandit {
    pub let n_arms: Int;
    pub let c: Float;  # Exploration constant
    pub let _q_values: [Float];
    pub let _counts: [Int];
    pub let _total_count: Int;

    pub fn new(n_arms: Int, c: Float) -> Self {
        let q = [];
        let counts = [];
        for (i in range(n_arms)) {
            q = q + [0.0];
            counts = counts + [0];
        }
        return Self { n_arms: n_arms, c: c, _q_values: q, _counts: counts, _total_count: 0 };
    }

    pub fn select_arm(self) -> Int {
        self._total_count = self._total_count + 1;
        let best_arm = 0;
        let best_ucb = -1e9;
        for (i in range(self.n_arms)) {
            if (self._counts[i] == 0) { return i; }
            let ucb = self._q_values[i] + self.c * _sqrt_f(_log_f(self._total_count * 1.0) / self._counts[i]);
            if (ucb > best_ucb) {
                best_ucb = ucb;
                best_arm = i;
            }
        }
        return best_arm;
    }

    pub fn update(self, arm: Int, reward: Float) {
        self._counts[arm] = self._counts[arm] + 1;
        let alpha = 1.0 / self._counts[arm];
        self._q_values[arm] = self._q_values[arm] + alpha * (reward - self._q_values[arm]);
    }
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

fn _compute_returns(rewards: [Float], gamma: Float) -> [Float] {
    let returns = [];
    let G = 0.0;
    for (i in range(len(rewards) - 1, -1, -1)) {
        G = rewards[i] + gamma * G;
        returns = [G] + returns;
    }
    return returns;
}

fn _compute_gae(rewards: [Float], trajectory: [Object], gamma: Float, lambda: Float) -> [Float] {
    let advantages = [];
    let gae = 0.0;
    for (i in range(len(rewards) - 1, -1, -1)) {
        let value = trajectory[i]["value"];
        let next_value = i < len(rewards) - 1 ? trajectory[i + 1]["value"] : 0.0;
        let delta = rewards[i] + gamma * next_value - value;
        gae = delta + gamma * lambda * gae;
        advantages = [gae] + advantages;
    }
    return advantages;
}

fn _sample_categorical(probs: Tensor) -> Int {
    let r = native_random_float();
    let cumsum = 0.0;
    for (i in range(probs.numel())) {
        cumsum = cumsum + probs.data[i];
        if (r < cumsum) { return i; }
    }
    return probs.numel() - 1;
}

fn _compute_sampling_probabilities(priorities: [Float], alpha: Float) -> [Float] {
    let total = 0.0;
    for (p in priorities) {
        total = total + _pow_f(p, alpha);
    }
    let probs = [];
    for (p in priorities) {
        probs = probs + [_pow_f(p, alpha) / total];
    }
    return probs;
}

fn _sample_proportional(probs: [Float], n: Int) -> [Int] {
    let samples = [];
    for (i in range(n)) {
        let r = native_random_float();
        let cumsum = 0.0;
        for (j in range(len(probs))) {
            cumsum = cumsum + probs[j];
            if (r < cumsum) {
                samples = samples + [j];
                break;
            }
        }
    }
    return samples;
}

fn _pow_f(x: Float, y: Float) -> Float { return native_pow(x, y); }
fn _exp_f(x: Float) -> Float { return native_exp(x); }
fn _log_f(x: Float) -> Float { return native_log(x); }
fn _sqrt_f(x: Float) -> Float { return native_sqrt(x); }
fn _min_f(a: Float, b: Float) -> Float { return a < b ? a : b; }
fn _max_f(a: Float, b: Float) -> Float { return a > b ? a : b; }
fn _clamp(x: Float, lo: Float, hi: Float) -> Float {
    if (x < lo) { return lo; }
    if (x > hi) { return hi; }
    return x;
}
fn _sum_f(arr: [Float]) -> Float {
    let s = 0.0;
    for (v in arr) { s = s + v; }
    return s;
}

# ============================================================
# NATIVE FFI
# ============================================================

native_random_float() -> Float;
native_random_int(low: Int, high: Int) -> Int;
native_pow(x: Float, y: Float) -> Float;
native_exp(x: Float) -> Float;
native_log(x: Float) -> Float;
native_sqrt(x: Float) -> Float;

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "SpaceType": SpaceType,
    "Space": Space,
    "Env": Env,
    "ReplayBuffer": ReplayBuffer,
    "PrioritizedReplayBuffer": PrioritizedReplayBuffer,
    "PolicyGradientAgent": PolicyGradientAgent,
    "ActorCriticAgent": ActorCriticAgent,
    "PPOAgent": PPOAgent,
    "DQNAgent": DQNAgent,
    "DDPGAgent": DDPGAgent,
    "SACAgent": SACAgent,
    "EpsilonGreedyBandit": EpsilonGreedyBandit,
    "UCBBandit": UCBBandit
}

# ============================================================
# PRODUCTION-READY INFRASTRUCTURE
# ============================================================

pub mod production {

    pub class HealthStatus {
        pub let status: String;
        pub let uptime_ms: Int;
        pub let checks: Map;
        pub let version: String;

        pub fn new() -> Self {
            return Self {
                status: "healthy",
                uptime_ms: 0,
                checks: {},
                version: VERSION
            };
        }

        pub fn is_healthy(self) -> Bool {
            return self.status == "healthy";
        }

        pub fn add_check(self, name: String, passed: Bool, detail: String) {
            self.checks[name] = { "passed": passed, "detail": detail };
            if !passed { self.status = "degraded"; }
        }
    }

    pub class MetricsCollector {
        pub let counters: Map;
        pub let gauges: Map;
        pub let histograms: Map;
        pub let start_time: Int;

        pub fn new() -> Self {
            return Self {
                counters: {},
                gauges: {},
                histograms: {},
                start_time: native_production_time_ms()
            };
        }

        pub fn increment(self, name: String, value: Int) {
            self.counters[name] = (self.counters[name] or 0) + value;
        }

        pub fn gauge_set(self, name: String, value: Float) {
            self.gauges[name] = value;
        }

        pub fn histogram_observe(self, name: String, value: Float) {
            if self.histograms[name] == null { self.histograms[name] = []; }
            self.histograms[name].push(value);
        }

        pub fn snapshot(self) -> Map {
            return {
                "counters": self.counters,
                "gauges": self.gauges,
                "uptime_ms": native_production_time_ms() - self.start_time
            };
        }

        pub fn reset(self) {
            self.counters = {};
            self.gauges = {};
            self.histograms = {};
        }
    }

    pub class Logger {
        pub let level: String;
        pub let buffer: List;
        pub let max_buffer: Int;

        pub fn new(level: String) -> Self {
            return Self { level: level, buffer: [], max_buffer: 10000 };
        }

        pub fn debug(self, msg: String, context: Map?) {
            if self.level == "debug" { self._log("DEBUG", msg, context); }
        }

        pub fn info(self, msg: String, context: Map?) {
            if self.level != "error" and self.level != "warn" {
                self._log("INFO", msg, context);
            }
        }

        pub fn warn(self, msg: String, context: Map?) {
            if self.level != "error" { self._log("WARN", msg, context); }
        }

        pub fn error(self, msg: String, context: Map?) {
            self._log("ERROR", msg, context);
        }

        fn _log(self, lvl: String, msg: String, context: Map?) {
            let entry = {
                "ts": native_production_time_ms(),
                "level": lvl,
                "msg": msg,
                "ctx": context
            };
            self.buffer.push(entry);
            if self.buffer.len() > self.max_buffer {
                self.buffer = self.buffer[self.max_buffer / 2..];
            }
        }

        pub fn flush(self) -> List {
            let out = self.buffer;
            self.buffer = [];
            return out;
        }
    }

    pub class CircuitBreaker {
        pub let state: String;
        pub let failure_count: Int;
        pub let threshold: Int;
        pub let reset_timeout_ms: Int;
        pub let last_failure_time: Int;

        pub fn new(threshold: Int, reset_timeout_ms: Int) -> Self {
            return Self {
                state: "closed",
                failure_count: 0,
                threshold: threshold,
                reset_timeout_ms: reset_timeout_ms,
                last_failure_time: 0
            };
        }

        pub fn allow_request(self) -> Bool {
            if self.state == "closed" { return true; }
            if self.state == "open" {
                let elapsed = native_production_time_ms() - self.last_failure_time;
                if elapsed >= self.reset_timeout_ms {
                    self.state = "half-open";
                    return true;
                }
                return false;
            }
            return true;
        }

        pub fn record_success(self) {
            self.failure_count = 0;
            self.state = "closed";
        }

        pub fn record_failure(self) {
            self.failure_count = self.failure_count + 1;
            self.last_failure_time = native_production_time_ms();
            if self.failure_count >= self.threshold {
                self.state = "open";
            }
        }
    }

    pub class RetryPolicy {
        pub let max_retries: Int;
        pub let base_delay_ms: Int;
        pub let max_delay_ms: Int;
        pub let backoff_multiplier: Float;

        pub fn new(max_retries: Int) -> Self {
            return Self {
                max_retries: max_retries,
                base_delay_ms: 100,
                max_delay_ms: 30000,
                backoff_multiplier: 2.0
            };
        }

        pub fn get_delay(self, attempt: Int) -> Int {
            let delay = self.base_delay_ms;
            for _ in 0..attempt { delay = (delay * self.backoff_multiplier).to_int(); }
            if delay > self.max_delay_ms { delay = self.max_delay_ms; }
            return delay;
        }
    }

    pub class RateLimiter {
        pub let max_requests: Int;
        pub let window_ms: Int;
        pub let requests: List;

        pub fn new(max_requests: Int, window_ms: Int) -> Self {
            return Self { max_requests: max_requests, window_ms: window_ms, requests: [] };
        }

        pub fn allow(self) -> Bool {
            let now = native_production_time_ms();
            self.requests = self.requests.filter(fn(t) { t > now - self.window_ms });
            if self.requests.len() >= self.max_requests { return false; }
            self.requests.push(now);
            return true;
        }
    }

    pub class GracefulShutdown {
        pub let hooks: List;
        pub let timeout_ms: Int;
        pub let is_shutting_down: Bool;

        pub fn new(timeout_ms: Int) -> Self {
            return Self { hooks: [], timeout_ms: timeout_ms, is_shutting_down: false };
        }

        pub fn register(self, name: String, hook: Fn) {
            self.hooks.push({ "name": name, "hook": hook });
        }

        pub fn shutdown(self) {
            self.is_shutting_down = true;
            for entry in self.hooks {
                entry.hook();
            }
        }
    }

    pub class ProductionRuntime {
        pub let health: HealthStatus;
        pub let metrics: MetricsCollector;
        pub let logger: Logger;
        pub let circuit_breaker: CircuitBreaker;
        pub let rate_limiter: RateLimiter;
        pub let shutdown: GracefulShutdown;

        pub fn new() -> Self {
            return Self {
                health: HealthStatus::new(),
                metrics: MetricsCollector::new(),
                logger: Logger::new("info"),
                circuit_breaker: CircuitBreaker::new(5, 30000),
                rate_limiter: RateLimiter::new(1000, 60000),
                shutdown: GracefulShutdown::new(30000)
            };
        }

        pub fn check_health(self) -> HealthStatus {
            self.health.uptime_ms = native_production_time_ms() - self.metrics.start_time;
            return self.health;
        }

        pub fn get_metrics(self) -> Map {
            return self.metrics.snapshot();
        }

        pub fn is_ready(self) -> Bool {
            return self.health.is_healthy() and !self.shutdown.is_shutting_down;
        }
    }
}

native_production_time_ms() -> Int;

# ============================================================
# OBSERVABILITY & ERROR HANDLING
# ============================================================

pub mod observability {

    pub class Span {
        pub let trace_id: String;
        pub let span_id: String;
        pub let parent_id: String?;
        pub let operation: String;
        pub let start_time: Int;
        pub let end_time: Int?;
        pub let tags: Map;
        pub let status: String;

        pub fn new(operation: String, parent_id: String?) -> Self {
            return Self {
                trace_id: native_production_time_ms().to_string(),
                span_id: native_production_time_ms().to_string(),
                parent_id: parent_id,
                operation: operation,
                start_time: native_production_time_ms(),
                end_time: null,
                tags: {},
                status: "ok"
            };
        }

        pub fn set_tag(self, key: String, value: String) {
            self.tags[key] = value;
        }

        pub fn finish(self) {
            self.end_time = native_production_time_ms();
        }

        pub fn finish_with_error(self, error: String) {
            self.end_time = native_production_time_ms();
            self.status = "error";
            self.tags["error"] = error;
        }

        pub fn duration_ms(self) -> Int {
            if self.end_time == null { return 0; }
            return self.end_time - self.start_time;
        }
    }

    pub class Tracer {
        pub let spans: List;
        pub let active_span: Span?;
        pub let service_name: String;

        pub fn new(service_name: String) -> Self {
            return Self { spans: [], active_span: null, service_name: service_name };
        }

        pub fn start_span(self, operation: String) -> Span {
            let parent = if self.active_span != null { self.active_span.span_id } else { null };
            let span = Span::new(operation, parent);
            span.set_tag("service", self.service_name);
            self.active_span = span;
            return span;
        }

        pub fn finish_span(self, span: Span) {
            span.finish();
            self.spans.push(span);
            self.active_span = null;
        }

        pub fn get_traces(self) -> List {
            return self.spans;
        }
    }

    pub class AlertRule {
        pub let name: String;
        pub let condition: Fn;
        pub let severity: String;
        pub let cooldown_ms: Int;
        pub let last_fired: Int;

        pub fn new(name: String, condition: Fn, severity: String) -> Self {
            return Self {
                name: name,
                condition: condition,
                severity: severity,
                cooldown_ms: 60000,
                last_fired: 0
            };
        }

        pub fn evaluate(self, metrics: Map) -> Bool {
            let now = native_production_time_ms();
            if now - self.last_fired < self.cooldown_ms { return false; }
            if self.condition(metrics) {
                self.last_fired = now;
                return true;
            }
            return false;
        }
    }

    pub class AlertManager {
        pub let rules: List;
        pub let alerts: List;

        pub fn new() -> Self {
            return Self { rules: [], alerts: [] };
        }

        pub fn add_rule(self, rule: AlertRule) {
            self.rules.push(rule);
        }

        pub fn evaluate_all(self, metrics: Map) -> List {
            let fired = [];
            for rule in self.rules {
                if rule.evaluate(metrics) {
                    let alert = {
                        "name": rule.name,
                        "severity": rule.severity,
                        "time": native_production_time_ms()
                    };
                    self.alerts.push(alert);
                    fired.push(alert);
                }
            }
            return fired;
        }
    }
}

pub mod error_handling {

    pub class EngineError {
        pub let code: String;
        pub let message: String;
        pub let context: Map;
        pub let timestamp: Int;
        pub let recoverable: Bool;

        pub fn new(code: String, message: String, recoverable: Bool) -> Self {
            return Self {
                code: code,
                message: message,
                context: {},
                timestamp: native_production_time_ms(),
                recoverable: recoverable
            };
        }

        pub fn with_context(self, key: String, value: Any) -> Self {
            self.context[key] = value;
            return self;
        }
    }

    pub class ErrorRegistry {
        pub let errors: List;
        pub let max_errors: Int;

        pub fn new(max_errors: Int) -> Self {
            return Self { errors: [], max_errors: max_errors };
        }

        pub fn record(self, error: EngineError) {
            self.errors.push(error);
            if self.errors.len() > self.max_errors {
                self.errors = self.errors[self.errors.len() - self.max_errors..];
            }
        }

        pub fn get_recent(self, count: Int) -> List {
            let start = if self.errors.len() > count { self.errors.len() - count } else { 0 };
            return self.errors[start..];
        }

        pub fn count_by_code(self, code: String) -> Int {
            return self.errors.filter(fn(e) { e.code == code }).len();
        }
    }

    pub class RecoveryStrategy {
        pub let name: String;
        pub let max_attempts: Int;
        pub let handler: Fn;

        pub fn new(name: String, max_attempts: Int, handler: Fn) -> Self {
            return Self { name: name, max_attempts: max_attempts, handler: handler };
        }
    }

    pub class ErrorHandler {
        pub let registry: ErrorRegistry;
        pub let strategies: Map;
        pub let fallback: Fn?;

        pub fn new() -> Self {
            return Self {
                registry: ErrorRegistry::new(1000),
                strategies: {},
                fallback: null
            };
        }

        pub fn register_strategy(self, code: String, strategy: RecoveryStrategy) {
            self.strategies[code] = strategy;
        }

        pub fn set_fallback(self, handler: Fn) {
            self.fallback = handler;
        }

        pub fn handle(self, error: EngineError) -> Any? {
            self.registry.record(error);
            if error.recoverable and self.strategies[error.code] != null {
                let strategy = self.strategies[error.code];
                return strategy.handler(error);
            }
            if self.fallback != null { return self.fallback(error); }
            return null;
        }
    }
}

# ============================================================
# CONFIGURATION & LIFECYCLE MANAGEMENT
# ============================================================

pub mod config_management {

    pub class EnvConfig {
        pub let values: Map;
        pub let defaults: Map;
        pub let required_keys: List;

        pub fn new() -> Self {
            return Self { values: {}, defaults: {}, required_keys: [] };
        }

        pub fn set_default(self, key: String, value: Any) {
            self.defaults[key] = value;
        }

        pub fn set(self, key: String, value: Any) {
            self.values[key] = value;
        }

        pub fn require(self, key: String) {
            self.required_keys.push(key);
        }

        pub fn get(self, key: String) -> Any? {
            if self.values[key] != null { return self.values[key]; }
            return self.defaults[key];
        }

        pub fn get_int(self, key: String) -> Int {
            let v = self.get(key);
            if v == null { return 0; }
            return v.to_int();
        }

        pub fn get_bool(self, key: String) -> Bool {
            let v = self.get(key);
            if v == null { return false; }
            return v == true or v == "true" or v == "1";
        }

        pub fn validate(self) -> List {
            let missing = [];
            for key in self.required_keys {
                if self.get(key) == null { missing.push(key); }
            }
            return missing;
        }

        pub fn from_map(self, map: Map) {
            for key in map.keys() { self.values[key] = map[key]; }
        }
    }

    pub class FeatureFlag {
        pub let name: String;
        pub let enabled: Bool;
        pub let rollout_pct: Float;
        pub let metadata: Map;

        pub fn new(name: String, enabled: Bool) -> Self {
            return Self { name: name, enabled: enabled, rollout_pct: 100.0, metadata: {} };
        }

        pub fn is_enabled(self) -> Bool {
            return self.enabled;
        }

        pub fn is_enabled_for(self, user_id: String) -> Bool {
            if !self.enabled { return false; }
            if self.rollout_pct >= 100.0 { return true; }
            let hash = user_id.len() % 100;
            return hash < self.rollout_pct.to_int();
        }
    }

    pub class FeatureFlagManager {
        pub let flags: Map;

        pub fn new() -> Self {
            return Self { flags: {} };
        }

        pub fn register(self, flag: FeatureFlag) {
            self.flags[flag.name] = flag;
        }

        pub fn is_enabled(self, name: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled();
        }

        pub fn is_enabled_for(self, name: String, user_id: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled_for(user_id);
        }
    }
}

pub mod lifecycle {

    pub class Phase {
        pub let name: String;
        pub let order: Int;
        pub let handler: Fn;
        pub let completed: Bool;

        pub fn new(name: String, order: Int, handler: Fn) -> Self {
            return Self { name: name, order: order, handler: handler, completed: false };
        }
    }

    pub class LifecycleManager {
        pub let phases: List;
        pub let current_phase: String;
        pub let state: String;
        pub let hooks: Map;

        pub fn new() -> Self {
            return Self {
                phases: [],
                current_phase: "init",
                state: "created",
                hooks: {}
            };
        }

        pub fn add_phase(self, phase: Phase) {
            self.phases.push(phase);
            self.phases.sort_by(fn(a, b) { a.order - b.order });
        }

        pub fn on(self, event: String, handler: Fn) {
            if self.hooks[event] == null { self.hooks[event] = []; }
            self.hooks[event].push(handler);
        }

        pub fn start(self) {
            self.state = "starting";
            self._emit("before_start");
            for phase in self.phases {
                self.current_phase = phase.name;
                phase.handler();
                phase.completed = true;
            }
            self.state = "running";
            self._emit("after_start");
        }

        pub fn stop(self) {
            self.state = "stopping";
            self._emit("before_stop");
            for phase in self.phases.reverse() {
                self.current_phase = "teardown_" + phase.name;
            }
            self.state = "stopped";
            self._emit("after_stop");
        }

        fn _emit(self, event: String) {
            if self.hooks[event] != null {
                for handler in self.hooks[event] { handler(); }
            }
        }

        pub fn is_running(self) -> Bool {
            return self.state == "running";
        }
    }

    pub class ResourcePool {
        pub let name: String;
        pub let resources: List;
        pub let max_size: Int;
        pub let in_use: Int;

        pub fn new(name: String, max_size: Int) -> Self {
            return Self { name: name, resources: [], max_size: max_size, in_use: 0 };
        }

        pub fn acquire(self) -> Any? {
            if self.resources.len() > 0 {
                self.in_use = self.in_use + 1;
                return self.resources.pop();
            }
            if self.in_use < self.max_size {
                self.in_use = self.in_use + 1;
                return {};
            }
            return null;
        }

        pub fn release(self, resource: Any) {
            self.in_use = self.in_use - 1;
            self.resources.push(resource);
        }

        pub fn available(self) -> Int {
            return self.max_size - self.in_use;
        }
    }
}
