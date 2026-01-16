#!/usr/bin/env python3
"""
Export Stable Baselines3 models to TorchScript format for use with LibTorch S-Functions.

Usage:
    python export_model.py --input model.zip --output model.pt [--algorithm SAC] [--verbose]

Supported algorithms: SAC, TD3, PPO, A2C, DQN
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional, Tuple, Dict, Any

import torch as th
import numpy as np


class OnnxableSACTD3Policy(th.nn.Module):
    """Wrapper for SAC/TD3 actor networks."""

    def __init__(self, actor: th.nn.Module):
        super().__init__()
        self.actor = actor

    def forward(self, observation: th.Tensor) -> th.Tensor:
        return self.actor(observation, deterministic=True)


class OnnxablePPOA2CPolicy(th.nn.Module):
    """Wrapper for PPO/A2C policy networks (continuous actions)."""

    def __init__(self, policy: th.nn.Module):
        super().__init__()
        self.policy = policy

    def forward(self, observation: th.Tensor) -> th.Tensor:
        features = self.policy.extract_features(observation, self.policy.features_extractor)
        if self.policy.share_features_extractor:
            latent_pi = self.policy.mlp_extractor.forward_actor(features)
        else:
            pi_features = self.policy.pi_features_extractor(observation)
            latent_pi = self.policy.mlp_extractor.forward_actor(pi_features)
        # Return mean action (deterministic)
        return self.policy.action_net(latent_pi)


class OnnxableDQNPolicy(th.nn.Module):
    """Wrapper for DQN Q-networks (discrete actions)."""

    def __init__(self, q_net: th.nn.Module):
        super().__init__()
        self.q_net = q_net

    def forward(self, observation: th.Tensor) -> th.Tensor:
        q_values = self.q_net(observation)
        # Return action index as float for compatibility
        return th.argmax(q_values, dim=1).float().unsqueeze(1)


def detect_algorithm(model) -> str:
    """Detect algorithm type from model class name."""
    class_name = model.__class__.__name__.upper()

    supported = ['SAC', 'TD3', 'PPO', 'A2C', 'DQN']
    for algo in supported:
        if algo in class_name:
            return algo

    raise ValueError(f"Could not detect algorithm from class: {model.__class__.__name__}. "
                     f"Supported: {supported}")


def get_dimensions(model) -> Tuple[Tuple[int, ...], Tuple[int, ...]]:
    """Extract observation and action dimensions from model."""
    obs_shape = model.observation_space.shape

    # Handle different action space types
    if hasattr(model.action_space, 'shape'):
        act_shape = model.action_space.shape
    elif hasattr(model.action_space, 'n'):
        # Discrete action space
        act_shape = (1,)
    else:
        raise ValueError(f"Unsupported action space type: {type(model.action_space)}")

    return obs_shape, act_shape


def load_sb3_model(model_path: str, algorithm: Optional[str] = None, verbose: bool = False):
    """Load an SB3 model from a .zip file."""
    # Import all supported algorithms
    from stable_baselines3 import SAC, TD3, PPO, A2C, DQN

    algo_classes = {
        'SAC': SAC,
        'TD3': TD3,
        'PPO': PPO,
        'A2C': A2C,
        'DQN': DQN,
    }

    if algorithm:
        algorithm = algorithm.upper()
        if algorithm not in algo_classes:
            raise ValueError(f"Unknown algorithm: {algorithm}. Supported: {list(algo_classes.keys())}")

        if verbose:
            print(f"Loading model with specified algorithm: {algorithm}")
        return algo_classes[algorithm].load(model_path, device='cpu')

    # Try each algorithm until one works
    if verbose:
        print("Auto-detecting algorithm...")

    for algo_name, algo_class in algo_classes.items():
        try:
            model = algo_class.load(model_path, device='cpu')
            if verbose:
                print(f"Successfully loaded as {algo_name}")
            return model
        except Exception:
            continue

    raise ValueError(f"Could not load model from {model_path}. "
                     "Try specifying --algorithm explicitly.")


def create_exportable_policy(model, algorithm: str, verbose: bool = False):
    """Create an exportable policy wrapper based on algorithm type."""
    if algorithm in ['SAC', 'TD3']:
        if verbose:
            print(f"Extracting actor network for {algorithm}")
        return OnnxableSACTD3Policy(model.policy.actor)

    elif algorithm in ['PPO', 'A2C']:
        if verbose:
            print(f"Extracting policy network for {algorithm}")
        return OnnxablePPOA2CPolicy(model.policy)

    elif algorithm == 'DQN':
        if verbose:
            print(f"Extracting Q-network for {algorithm}")
        return OnnxableDQNPolicy(model.policy.q_net)

    else:
        raise ValueError(f"Unsupported algorithm: {algorithm}")


def export_to_torchscript(
    model_path: str,
    output_path: str,
    algorithm: Optional[str] = None,
    verbose: bool = False
) -> Dict[str, Any]:
    """
    Export an SB3 model to TorchScript format.

    Args:
        model_path: Path to the SB3 .zip file
        output_path: Path for the output .pt file
        algorithm: Algorithm type (auto-detected if None)
        verbose: Print progress messages

    Returns:
        Metadata dictionary with obs_dim, act_dim, algorithm
    """
    # Load model
    if verbose:
        print(f"Loading model from: {model_path}")
    model = load_sb3_model(model_path, algorithm, verbose)

    # Detect algorithm if not specified
    detected_algo = detect_algorithm(model)
    if algorithm and algorithm.upper() != detected_algo:
        if verbose:
            print(f"Warning: Specified algorithm {algorithm} differs from detected {detected_algo}")
    algorithm = detected_algo

    # Get dimensions
    obs_shape, act_shape = get_dimensions(model)
    obs_dim = int(np.prod(obs_shape))
    act_dim = int(np.prod(act_shape))

    if verbose:
        print(f"Algorithm: {algorithm}")
        print(f"Observation shape: {obs_shape} (flattened: {obs_dim})")
        print(f"Action shape: {act_shape} (flattened: {act_dim})")

    # Create exportable policy
    exportable_policy = create_exportable_policy(model, algorithm, verbose)
    exportable_policy.eval()

    # Create dummy input for tracing
    dummy_input = th.randn(1, obs_dim)

    if verbose:
        print("Tracing model...")

    # Trace the model
    with th.no_grad():
        traced_module = th.jit.trace(exportable_policy, dummy_input)

    # Freeze and optimize
    if verbose:
        print("Freezing and optimizing...")
    frozen_module = th.jit.freeze(traced_module)
    frozen_module = th.jit.optimize_for_inference(frozen_module)

    # Verify output shape
    if verbose:
        print("Verifying model output...")
    with th.no_grad():
        test_output = frozen_module(dummy_input)
        if verbose:
            print(f"Test input shape: {dummy_input.shape}")
            print(f"Test output shape: {test_output.shape}")
            print(f"Test output: {test_output.numpy()}")

    # Save model
    if verbose:
        print(f"Saving TorchScript model to: {output_path}")
    th.jit.save(frozen_module, output_path)

    # Create metadata
    metadata = {
        'algorithm': algorithm,
        'obs_dim': obs_dim,
        'act_dim': act_dim,
        'obs_shape': list(obs_shape),
        'act_shape': list(act_shape),
        'input_model': str(Path(model_path).name),
        'output_model': str(Path(output_path).name),
    }

    # Save metadata as JSON alongside the model
    metadata_path = Path(output_path).with_suffix('.json')
    if verbose:
        print(f"Saving metadata to: {metadata_path}")
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)

    if verbose:
        print("Export complete!")
        print(f"\nMetadata: {json.dumps(metadata, indent=2)}")

    return metadata


def main():
    parser = argparse.ArgumentParser(
        description='Export Stable Baselines3 models to TorchScript format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python export_model.py --input model.zip --output model.pt
    python export_model.py --input model.zip --output model.pt --algorithm SAC --verbose

Supported algorithms: SAC, TD3, PPO, A2C, DQN
        """
    )
    parser.add_argument(
        '--input', '-i',
        required=True,
        help='Path to the SB3 model (.zip file)'
    )
    parser.add_argument(
        '--output', '-o',
        required=True,
        help='Path for the output TorchScript model (.pt file)'
    )
    parser.add_argument(
        '--algorithm', '-a',
        choices=['SAC', 'TD3', 'PPO', 'A2C', 'DQN', 'sac', 'td3', 'ppo', 'a2c', 'dqn'],
        help='Algorithm type (auto-detected if not specified)'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Print detailed progress messages'
    )

    args = parser.parse_args()

    # Validate input path
    if not Path(args.input).exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    # Create output directory if needed
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        metadata = export_to_torchscript(
            model_path=args.input,
            output_path=args.output,
            algorithm=args.algorithm,
            verbose=args.verbose
        )

        # Print minimal output for non-verbose mode
        if not args.verbose:
            print(json.dumps(metadata))

        sys.exit(0)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
