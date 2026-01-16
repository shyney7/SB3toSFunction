# SB3toSFunction

Convert Stable Baselines3 reinforcement learning agents to Simulink S-Functions using LibTorch.

## Overview

SB3toSFunction enables you to deploy trained RL agents from [Stable Baselines3](https://stable-baselines3.readthedocs.io/) directly in Simulink for hardware-in-the-loop simulation, rapid prototyping, or integration with existing control systems.

**Workflow:**
```
SB3 Model (.zip) → Python Export → TorchScript (.pt) → C++ S-Function → Simulink
```

## Features

- **Multi-algorithm support**: SAC, TD3, PPO, A2C, DQN
- **Auto-detection**: Automatically detects algorithm type and dimensions
- **MATLAB GUI**: User-friendly interface for the complete workflow
- **Command-line tools**: Python script and MATLAB functions for automation
- **Real-time ready**: Optimized inference with `torch::NoGradGuard`

## Prerequisites

| Software | Version | Notes |
|----------|---------|-------|
| MATLAB | R2020a+ | With Simulink |
| Python | 3.8+ | With pip |
| Visual Studio | 2019+ | Windows, C++ build tools |
| LibTorch | 2.0+ | CPU version (download separately) |

### Python Dependencies

```bash
pip install stable-baselines3>=2.0.0 torch>=2.0.0 gymnasium numpy
```

## Installation

### 1. Clone or Download

```bash
git clone https://github.com/shyney7/SB3toSFunction.git
cd SB3toSFunction
```

### 2. Install Python Dependencies

```bash
pip install -r python/requirements.txt
```

### 3. Setup LibTorch

Download LibTorch from [pytorch.org](https://pytorch.org/get-started/locally/):
- Select: LibTorch → C++/Java → CPU → Release
- Extract to the `libtorch/` folder

### 4. Configure MATLAB MEX Compiler

```matlab
mex -setup C++
```

### 5. Compile the S-Function

```matlab
cd path/to/SB3toSFunction
compile_sfunction()
```

### 6. Add LibTorch to PATH

Before running Simulink simulations:

```matlab
setenv('PATH', [fullfile(pwd, 'libtorch', 'lib') pathsep getenv('PATH')]);
```

## Quick Start

### Using the GUI

```matlab
addpath('gui')
SB3toSFunction()
```

1. Select your SB3 model (.zip file)
2. Click **Export Model** to create TorchScript
3. Click **Compile S-Function** to build MEX file
4. Click **Test Model** to verify

### Using Command Line

**Export model (Python):**
```bash
python python/export_model.py --input my_agent.zip --output my_agent.pt --verbose
```

**Compile S-Function (MATLAB):**
```matlab
compile_sfunction()
```

**Create Simulink test model:**
```matlab
addpath('examples')
create_test_model('test_model', 4, 1, 'my_agent.pt')  % obs_dim=4, act_dim=1
```

## Project Structure

```
SB3toSFunction/
├── python/
│   ├── export_model.py      # SB3 to TorchScript export
│   └── requirements.txt     # Python dependencies
├── src/
│   └── libtorch_sfun.cpp    # C++ S-Function source
├── gui/
│   └── SB3toSFunction.m     # MATLAB GUI
├── examples/
│   ├── create_test_model.m  # Simulink model generator
│   └── test_libtorch_sfun.slx
├── docs/
│   └── user_guide.md        # Detailed documentation
├── libtorch/                # LibTorch library
├── compile_sfunction.m      # MEX compilation helper
└── README.md
```

## Supported Algorithms

| Algorithm | Policy Extraction | Action Type |
|-----------|-------------------|-------------|
| SAC | `model.policy.actor` | Continuous [-1, 1] |
| TD3 | `model.policy.actor` | Continuous [-1, 1] |
| PPO | `model.policy.action_net` | Continuous (mean) |
| A2C | `model.policy.action_net` | Continuous (mean) |
| DQN | `model.policy.q_net` | Discrete (argmax) |

## S-Function Parameters

The S-Function block accepts three parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| Model Path | string | Path to the `.pt` TorchScript file |
| Observation Dim | integer | Number of observation inputs |
| Action Dim | integer | Number of action outputs |

**Example:**
```
'C:/models/my_agent.pt', 4, 1
```

## Simulink Integration

```
┌──────────────┐    ┌─────────────────┐    ┌─────────┐
│   Constant   │───▶│  libtorch_sfun  │───▶│  Scope  │
│ (obs_dim=4)  │    │   S-Function    │    │         │
└──────────────┘    └─────────────────┘    └─────────┘
     Input              Inference            Output
  observations           (RL agent)          actions
```

## Troubleshooting

### "DLL not found" at runtime
Add LibTorch to PATH:
```matlab
setenv('PATH', ['C:\path\to\libtorch\lib' pathsep getenv('PATH')]);
```

### "Model not loaded" in Simulink
- Verify the `.pt` file path in S-Function parameters
- Use forward slashes or escaped backslashes in paths

### Compilation errors
- Ensure Visual Studio 2019+ is installed
- Run `mex -setup C++` to configure compiler
- Verify LibTorch paths are correct

### Dimension mismatch
- Check `obs_dim` and `act_dim` match your model
- Inspect the `.json` metadata file created during export

## Example: End-to-End Workflow

```python
# 1. Train in Python
from stable_baselines3 import SAC
model = SAC("MlpPolicy", "Pendulum-v1")
model.learn(10000)
model.save("pendulum_agent")
```

```bash
# 2. Export to TorchScript
python python/export_model.py -i pendulum_agent.zip -o pendulum.pt -v
```

```matlab
% 3. Use in MATLAB/Simulink
compile_sfunction()
addpath('examples')
create_test_model('pendulum_sim', 3, 1, 'pendulum.pt')
sim('pendulum_sim')
```

## Performance Notes

- Model loads once at simulation start (`mdlStart`)
- Inference uses `torch::NoGradGuard` for speed
- CPU-only execution avoids CUDA overhead
- Suitable for real-time applications with proper tuning

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

GPLv2 License - see LICENSE file for details.

## Acknowledgments

- [Stable Baselines3](https://stable-baselines3.readthedocs.io/) - RL training framework
- [PyTorch/LibTorch](https://pytorch.org/) - Deep learning framework
- [MathWorks](https://www.mathworks.com/) - MATLAB/Simulink platform
