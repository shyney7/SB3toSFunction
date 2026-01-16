/**
 * LibTorch S-Function for Simulink
 *
 * This S-Function loads a TorchScript model and runs inference during simulation.
 * Used to deploy Stable Baselines3 trained RL agents in Simulink.
 *
 * Parameters:
 *   1. Model Path (string) - Path to the .pt TorchScript file
 *   2. Observation Dimension (int) - Number of observation inputs
 *   3. Action Dimension (int) - Number of action outputs
 *
 * Compilation (Windows):
 *   mex -v COMPFLAGS="$COMPFLAGS /std:c++17" ...
 *       -I"libtorch/include" ...
 *       -I"libtorch/include/torch/csrc/api/include" ...
 *       -L"libtorch/lib" ...
 *       -ltorch -ltorch_cpu -lc10 ...
 *       src/libtorch_sfun.cpp
 */

#define S_FUNCTION_NAME libtorch_sfun
#define S_FUNCTION_LEVEL 2

// Simulink headers
#include "simstruc.h"

// Disable min/max macros from Windows headers that conflict with STL
#ifdef _WIN32
#define NOMINMAX
#endif

// LibTorch headers
#include <torch/script.h>
#include <torch/torch.h>

// Standard headers
#include <string>
#include <vector>
#include <memory>
#include <stdexcept>

// Parameter indices
#define PARAM_MODEL_PATH    0
#define PARAM_OBS_DIM       1
#define PARAM_ACT_DIM       2
#define NUM_PARAMS          3

// PWork indices
#define PWORK_MODEL         0
#define NUM_PWORK           1

// Helper: Get string parameter from S-Function block
static std::string getStringParam(SimStruct *S, int paramIndex) {
    const mxArray *param = ssGetSFcnParam(S, paramIndex);
    if (!mxIsChar(param)) {
        return "";
    }
    char *buf = mxArrayToString(param);
    std::string result(buf);
    mxFree(buf);
    return result;
}

// Helper: Get integer parameter from S-Function block
static int getIntParam(SimStruct *S, int paramIndex) {
    const mxArray *param = ssGetSFcnParam(S, paramIndex);
    if (!mxIsNumeric(param)) {
        return 0;
    }
    return static_cast<int>(mxGetScalar(param));
}

/*====================*
 * S-Function methods *
 *====================*/

/**
 * mdlInitializeSizes - Configure ports and work vectors
 */
static void mdlInitializeSizes(SimStruct *S) {
    // Set number of parameters
    ssSetNumSFcnParams(S, NUM_PARAMS);
    if (ssGetNumSFcnParams(S) != ssGetSFcnParamsCount(S)) {
        return; // Parameter count mismatch - Simulink will report error
    }

    // Parameters are not tunable during simulation
    ssSetSFcnParamTunable(S, PARAM_MODEL_PATH, SS_PRM_NOT_TUNABLE);
    ssSetSFcnParamTunable(S, PARAM_OBS_DIM, SS_PRM_NOT_TUNABLE);
    ssSetSFcnParamTunable(S, PARAM_ACT_DIM, SS_PRM_NOT_TUNABLE);

    // Get dimensions from parameters
    int obs_dim = getIntParam(S, PARAM_OBS_DIM);
    int act_dim = getIntParam(S, PARAM_ACT_DIM);

    // Validate dimensions
    if (obs_dim <= 0) {
        ssSetErrorStatus(S, "Observation dimension must be positive");
        return;
    }
    if (act_dim <= 0) {
        ssSetErrorStatus(S, "Action dimension must be positive");
        return;
    }

    // Configure input port (observations)
    if (!ssSetNumInputPorts(S, 1)) return;
    ssSetInputPortWidth(S, 0, obs_dim);
    ssSetInputPortDataType(S, 0, SS_DOUBLE);
    ssSetInputPortDirectFeedThrough(S, 0, 1); // Output depends on input
    ssSetInputPortRequiredContiguous(S, 0, 1);

    // Configure output port (actions)
    if (!ssSetNumOutputPorts(S, 1)) return;
    ssSetOutputPortWidth(S, 0, act_dim);
    ssSetOutputPortDataType(S, 0, SS_DOUBLE);

    // Configure sample times
    ssSetNumSampleTimes(S, 1);

    // Configure work vectors
    ssSetNumPWork(S, NUM_PWORK); // Pointer work vector for model storage
    ssSetNumRWork(S, 0);
    ssSetNumIWork(S, 0);
    ssSetNumModes(S, 0);
    ssSetNumNonsampledZCs(S, 0);

    // Options
    ssSetOptions(S, SS_OPTION_EXCEPTION_FREE_CODE);
}

/**
 * mdlInitializeSampleTimes - Set sample time
 */
static void mdlInitializeSampleTimes(SimStruct *S) {
    // Inherit sample time from the model
    ssSetSampleTime(S, 0, INHERITED_SAMPLE_TIME);
    ssSetOffsetTime(S, 0, 0.0);
}

/**
 * mdlStart - Load the TorchScript model
 */
#define MDL_START
static void mdlStart(SimStruct *S) {
    // Get model path
    std::string model_path = getStringParam(S, PARAM_MODEL_PATH);
    if (model_path.empty()) {
        ssSetErrorStatus(S, "Model path is empty");
        return;
    }

    try {
        // Load the TorchScript model
        auto model = new torch::jit::script::Module(torch::jit::load(model_path));

        // Configure for inference
        model->to(torch::kCPU);
        model->eval();

        // Store model pointer in PWork
        ssSetPWorkValue(S, PWORK_MODEL, static_cast<void*>(model));

    } catch (const c10::Error& e) {
        static char err_msg[512];
        snprintf(err_msg, sizeof(err_msg), "Failed to load TorchScript model: %s", e.what());
        ssSetErrorStatus(S, err_msg);
        ssSetPWorkValue(S, PWORK_MODEL, nullptr);
    } catch (const std::exception& e) {
        static char err_msg[512];
        snprintf(err_msg, sizeof(err_msg), "Error loading model: %s", e.what());
        ssSetErrorStatus(S, err_msg);
        ssSetPWorkValue(S, PWORK_MODEL, nullptr);
    }
}

/**
 * mdlOutputs - Run inference each timestep
 */
static void mdlOutputs(SimStruct *S, int_T tid) {
    UNUSED_ARG(tid);

    // Get model pointer
    auto* model = static_cast<torch::jit::script::Module*>(ssGetPWorkValue(S, PWORK_MODEL));
    if (model == nullptr) {
        ssSetErrorStatus(S, "Model not loaded");
        return;
    }

    // Get dimensions
    int obs_dim = getIntParam(S, PARAM_OBS_DIM);
    int act_dim = getIntParam(S, PARAM_ACT_DIM);

    // Get input (observations)
    const real_T *obs_input = ssGetInputPortRealSignal(S, 0);

    // Get output pointer
    real_T *act_output = ssGetOutputPortRealSignal(S, 0);

    try {
        // Disable gradient computation for inference
        torch::NoGradGuard no_grad;

        // Create input tensor from observation data
        // Shape: [1, obs_dim] (batch size of 1)
        auto options = torch::TensorOptions().dtype(torch::kFloat32);
        torch::Tensor input_tensor = torch::zeros({1, obs_dim}, options);

        // Copy observation data to tensor
        auto accessor = input_tensor.accessor<float, 2>();
        for (int i = 0; i < obs_dim; i++) {
            accessor[0][i] = static_cast<float>(obs_input[i]);
        }

        // Run inference
        std::vector<torch::jit::IValue> inputs = {input_tensor};
        torch::Tensor output_tensor = model->forward(inputs).toTensor();

        // Copy output to Simulink port
        auto out_accessor = output_tensor.accessor<float, 2>();
        for (int i = 0; i < act_dim; i++) {
            act_output[i] = static_cast<real_T>(out_accessor[0][i]);
        }

    } catch (const c10::Error& e) {
        static char err_msg[512];
        snprintf(err_msg, sizeof(err_msg), "Inference error: %s", e.what());
        ssSetErrorStatus(S, err_msg);
    } catch (const std::exception& e) {
        static char err_msg[512];
        snprintf(err_msg, sizeof(err_msg), "Runtime error: %s", e.what());
        ssSetErrorStatus(S, err_msg);
    }
}

/**
 * mdlTerminate - Clean up resources
 */
static void mdlTerminate(SimStruct *S) {
    // Delete the model
    auto* model = static_cast<torch::jit::script::Module*>(ssGetPWorkValue(S, PWORK_MODEL));
    if (model != nullptr) {
        delete model;
        ssSetPWorkValue(S, PWORK_MODEL, nullptr);
    }
}

/*=============================*
 * Required S-function trailer *
 *=============================*/

#ifdef MATLAB_MEX_FILE
#include "simulink.c"
#else
#include "cg_sfun.h"
#endif
