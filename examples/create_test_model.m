function create_test_model(model_name, obs_dim, act_dim, pt_file_path)
%CREATE_TEST_MODEL Create a test Simulink model for LibTorch S-Function
%
%   CREATE_TEST_MODEL() creates a model with default settings (obs_dim=4, act_dim=1)
%   CREATE_TEST_MODEL(MODEL_NAME) creates model with specified name
%   CREATE_TEST_MODEL(MODEL_NAME, OBS_DIM, ACT_DIM) creates model with specified dimensions
%   CREATE_TEST_MODEL(MODEL_NAME, OBS_DIM, ACT_DIM, PT_FILE) also sets the model path
%
%   The created model contains:
%     - Constant block (provides observation input)
%     - S-Function block (libtorch_sfun)
%     - Scope block (displays action output)
%
%   Example:
%     create_test_model('test_sac', 4, 1, 'sac_expander_actor.pt')

    % Default values
    if nargin < 1 || isempty(model_name)
        model_name = 'test_libtorch_sfun';
    end
    if nargin < 2 || isempty(obs_dim)
        obs_dim = 4;
    end
    if nargin < 3 || isempty(act_dim)
        act_dim = 1;
    end
    if nargin < 4
        pt_file_path = 'model.pt';  % Placeholder
    end

    % Close model if already open
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
    end

    % Create new model
    fprintf('Creating Simulink model: %s\n', model_name);
    new_system(model_name);
    open_system(model_name);

    % Set solver to fixed-step for S-Function compatibility
    set_param(model_name, 'Solver', 'FixedStepDiscrete');
    set_param(model_name, 'FixedStep', '0.01');
    set_param(model_name, 'StopTime', '10');

    % Add Constant block (observation input)
    const_block = [model_name '/Observations'];
    add_block('simulink/Sources/Constant', const_block);
    set_param(const_block, 'Position', [100, 100, 180, 130]);

    % Set constant value (vector of obs_dim elements)
    obs_value = mat2str(zeros(1, obs_dim));
    set_param(const_block, 'Value', obs_value);
    set_param(const_block, 'OutDataTypeStr', 'double');
    set_param(const_block, 'SampleTime', '0.01');

    % Add S-Function block using Level-2 M-File S-Function or standard S-Function block
    sfun_block = [model_name '/LibTorch_Policy'];
    add_block('simulink/User-Defined Functions/S-Function', sfun_block);
    set_param(sfun_block, 'Position', [280, 90, 400, 140]);

    % Configure S-Function name first (before setting parameters)
    set_param(sfun_block, 'FunctionName', 'libtorch_sfun');

    % Use SFunctionModules parameter for S-Function parameters
    % Format: 'param1','param2','param3' separated by commas
    params = sprintf('''%s'',%d,%d', strrep(pt_file_path, '\', '/'), obs_dim, act_dim);
    set_param(sfun_block, 'SFunctionModules', '');

    % For C MEX S-Functions, parameters go in the 'Parameters' field
    % The block must be configured for the correct number of parameters
    try
        set_param(sfun_block, 'Parameters', params);
    catch
        % If direct parameter setting fails, we need to update the model
        % to use the correct block dialog configuration
        warning('Could not set S-Function parameters directly. Please configure manually.');
        disp(['Parameters to set: ' params]);
    end

    % Add Scope block (action output)
    scope_block = [model_name '/Actions'];
    add_block('simulink/Sinks/Scope', scope_block);
    set_param(scope_block, 'Position', [500, 95, 530, 135]);

    % Add Display block for real-time viewing
    display_block = [model_name '/Action_Display'];
    add_block('simulink/Sinks/Display', display_block);
    set_param(display_block, 'Position', [500, 160, 590, 190]);

    % Connect blocks
    add_line(model_name, 'Observations/1', 'LibTorch_Policy/1');
    add_line(model_name, 'LibTorch_Policy/1', 'Actions/1');
    add_line(model_name, 'LibTorch_Policy/1', 'Action_Display/1');

    % Add annotations
    annotation_text = sprintf(['LibTorch S-Function Test Model\n' ...
        'Observation Dim: %d\n' ...
        'Action Dim: %d\n' ...
        'Model: %s'], obs_dim, act_dim, pt_file_path);

    add_block('simulink/Commonly Used Blocks/Annotation', [model_name '/Info']);
    % Note: Annotations are typically set differently, using handle

    % Save model
    examples_dir = fileparts(mfilename('fullpath'));
    model_path = fullfile(examples_dir, [model_name '.slx']);
    save_system(model_name, model_path);

    fprintf('Model created: %s\n', model_path);
    fprintf('\nBefore running:\n');
    fprintf('  1. Ensure libtorch_sfun.%s is compiled\n', mexext);
    fprintf('  2. Update the model path parameter in the S-Function block\n');
    fprintf('  3. Set observation values in the Constant block\n');
    fprintf('  4. Add libtorch/lib to system PATH\n');
end
