# SB3toSFunction User Guide

Convert Stable Baselines3 reinforcement learning models to Simulink S-Functions using LibTorch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Using the GUI](#using-the-gui)
5. [Command Line Usage](#command-line-usage)
6. [Troubleshooting](#troubleshooting)
7. [Technical Details](#technical-details)

---

## Prerequisites

### Software Requirements

| Software | Version | Notes |
|----------|---------|-------|
| MATLAB | R2020a+ | With Simulink |
| Python | 3.8+ | With pip |
| Visual Studio | 2019+ | Windows only, C++ build tools |
| LibTorch | 2.0+ | CPU version recommended |

### Python Packages

```bash
pip install stable-baselines3>=2.0.0 torch>=2.0.0 gymnasium numpy
```

Or install from requirements file:

```bash
cd python
pip install -r requirements.txt
```

### LibTorch Setup

1. Download LibTorch from [pytorch.org](https://pytorch.org/get-started/locally/)
   - Select: LibTorch → C++/Java → CPU → Release
2. Extract to the project's `libtorch/` folder or a custom location

---

## Installation

### Step 1: Clone/Download the Project

```
SB3toSFunction/
├── gui/
│   └── SB3toSFunction.m       # MATLAB GUI
├── python/
│   ├── export_model.py        # Export script
│   └── requirements.txt       # Python dependencies
├── src/
│   └── libtorch_sfun.cpp      # S-Function source
├── libtorch/                  # LibTorch library (add this)
├── examples/
│   └── create_test_model.m    # Test model generator
└── compile_sfunction.m        # Compilation helper
```

### Step 2: Install Python Dependencies

```bash
cd SB3toSFunction/python
pip install -r requirements.txt
```

### Step 3: Configure MATLAB MEX

In MATLAB:
```matlab
mex -setup C++
```

Select a compatible C++ compiler (Visual Studio 2019+ on Windows).

### Step 4: Compile the S-Function

```matlab
cd C:\path\to\SB3toSFunction
compile_sfunction()
```

### Step 5: Add LibTorch to PATH

Before running Simulink with the S-Function:

```matlab
libtorch_lib = 'C:\path\to\SB3toSFunction\libtorch\lib';
setenv('PATH', [libtorch_lib pathsep getenv('PATH')]);
```

---

## Quick Start

### 1. Export Your SB3 Model

**Using Python:**
```bash
python python/export_model.py --input my_model.zip --output my_model.pt --verbose
```

**Using MATLAB GUI:**
```matlab
addpath('gui')
SB3toSFunction()  % Opens the GUI
```

### 2. Create a Simulink Model

```matlab
addpath('examples')
create_test_model('my_test', 4, 1, 'my_model.pt')
```

### 3. Configure and Run

1. Open the generated Simulink model
2. Double-click the S-Function block
3. Verify the model path parameter points to your `.pt` file
4. Set observation values in the Constant block
5. Run the simulation

---

## Using the GUI

Launch the GUI:
```matlab
addpath('gui')
app = SB3toSFunction();
```

### Model Settings

| Field | Description |
|-------|-------------|
| SB3 Model Path | Path to your `.zip` file from SB3 |
| Algorithm | Select or auto-detect (SAC, TD3, PPO, A2C, DQN) |
| Observation Dim | Number of observation inputs |
| Action Dim | Number of action outputs |
| Auto-detect | Read dimensions from model metadata |

### Output Settings

| Field | Description |
|-------|-------------|
| Output Directory | Where to save the `.pt` file |
| Model Name | Base name for output files |

### Compilation Settings

| Field | Description |
|-------|-------------|
| LibTorch Path | Path to LibTorch installation |
| Python Path | Python executable (e.g., `python` or full path) |

### Actions

| Button | Function |
|--------|----------|
| Export Model | Convert SB3 → TorchScript |
| Compile S-Function | Build the MEX file |
| Test Model | Verify the exported model |

---

## Command Line Usage

### Export Script

```bash
python export_model.py --input MODEL.zip --output MODEL.pt [OPTIONS]

Options:
  -i, --input       Path to SB3 model (.zip)
  -o, --output      Path for TorchScript output (.pt)
  -a, --algorithm   Algorithm type: SAC, TD3, PPO, A2C, DQN
  -v, --verbose     Print detailed progress

Examples:
  python export_model.py -i sac_model.zip -o sac_model.pt -v
  python export_model.py --input ppo_model.zip --output ppo_model.pt --algorithm PPO
```

### MATLAB Compilation

```matlab
% Using default libtorch path (./libtorch)
compile_sfunction()

% Using custom libtorch path
compile_sfunction('C:\libs\libtorch-2.0')
```

---

## Troubleshooting

### Export Errors

**"Could not load model"**
- Verify the `.zip` file is a valid SB3 model
- Try specifying `--algorithm` explicitly
- Ensure Python packages are installed correctly

**"Unsupported algorithm"**
- Only SAC, TD3, PPO, A2C, DQN are supported
- Custom algorithms require modifying `export_model.py`

### Compilation Errors

**"torch/script.h not found"**
- Verify LibTorch path is correct
- Check that `libtorch/include` exists

**"Unresolved external symbol"**
- Ensure linking to all required libraries: torch, torch_cpu, c10
- Verify library path points to `libtorch/lib`

**"C++17 required"**
- Update your compiler (Visual Studio 2019+)
- Verify MEX compiler configuration: `mex -setup C++`

### Runtime Errors

**"DLL not found" or model fails to load**
- Add `libtorch/lib` to system PATH:
  ```matlab
  setenv('PATH', ['C:\path\to\libtorch\lib' pathsep getenv('PATH')]);
  ```
- On Windows, required DLLs: torch.dll, torch_cpu.dll, c10.dll

**"Dimension mismatch"**
- Verify obs_dim and act_dim match your model
- Check the `.json` metadata file generated during export

**"Model not loaded" in Simulink**
- Verify the `.pt` file path in S-Function parameters
- Use absolute paths to avoid working directory issues

### Simulink Errors

**S-Function not found**
- Ensure `libtorch_sfun.mexw64` is on MATLAB path
- Run `addpath('path/to/SB3toSFunction')`

**Input/output dimension mismatch**
- The Constant block output must match obs_dim
- Check S-Function block parameters

---

## Technical Details

### Supported Algorithms

| Algorithm | Policy Extraction | Output |
|-----------|-------------------|--------|
| SAC | `model.policy.actor` | Continuous actions [-1, 1] |
| TD3 | `model.policy.actor` | Continuous actions [-1, 1] |
| PPO | `model.policy.action_net` | Continuous (mean) |
| A2C | `model.policy.action_net` | Continuous (mean) |
| DQN | `model.policy.q_net` | Discrete action index |

### S-Function Parameters

```
Parameter 1: Model path (string) - Path to .pt file
Parameter 2: Observation dimension (integer)
Parameter 3: Action dimension (integer)
```

### Data Flow

```
Observation (double[obs_dim]) → S-Function → Action (double[act_dim])
```

### Performance Notes

- Model is loaded once at simulation start
- Inference runs each timestep with `torch::NoGradGuard`
- CPU-only inference (no CUDA overhead)
- Suitable for real-time applications with proper tuning

### File Outputs

| File | Description |
|------|-------------|
| `model.pt` | TorchScript model |
| `model.json` | Metadata (dimensions, algorithm) |
| `libtorch_sfun.mexw64` | Compiled S-Function |

---

## Examples

### Example: SAC Agent

```bash
# Train with SB3 (in Python)
from stable_baselines3 import SAC
model = SAC("MlpPolicy", "Pendulum-v1")
model.learn(10000)
model.save("sac_pendulum")
```

```bash
# Export to TorchScript
python export_model.py -i sac_pendulum.zip -o sac_pendulum.pt -v
```

```matlab
% Create Simulink test model
create_test_model('test_pendulum', 3, 1, 'sac_pendulum.pt')
```

### Example: Custom Dimensions

If your model has unusual observation/action spaces:

```matlab
% Manual configuration in GUI or:
create_test_model('custom_model', 12, 4, 'my_model.pt')
```

---

## Support

For issues and questions:
- Check the troubleshooting section above
- Verify all prerequisites are met
- If nothing of the above mentioned helps create a github issue

## Contribution
Any kind of contribution is appreciated just create a pull request!
