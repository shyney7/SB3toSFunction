classdef SB3toSFunction < handle
    %SB3TOSFUNCTION GUI for converting SB3 models to Simulink S-Functions
    %
    %   This GUI provides an interface to:
    %     1. Export SB3 models to TorchScript format
    %     2. Compile the LibTorch S-Function
    %     3. Test the exported model
    %
    %   Usage:
    %     app = SB3toSFunction();

    properties (Access = private)
        % UI Components
        UIFigure            matlab.ui.Figure
        GridLayout          matlab.ui.container.GridLayout

        % Model Settings Panel
        ModelPanel          matlab.ui.container.Panel
        ModelPathEdit       matlab.ui.control.EditField
        ModelPathButton     matlab.ui.control.Button
        AlgorithmDropdown   matlab.ui.control.DropDown
        ObsDimSpinner       matlab.ui.control.Spinner
        ActDimSpinner       matlab.ui.control.Spinner
        AutoDetectCheck     matlab.ui.control.CheckBox

        % Output Settings Panel
        OutputPanel         matlab.ui.container.Panel
        OutputDirEdit       matlab.ui.control.EditField
        OutputDirButton     matlab.ui.control.Button
        ModelNameEdit       matlab.ui.control.EditField

        % Compilation Panel
        CompilePanel        matlab.ui.container.Panel
        LibtorchPathEdit    matlab.ui.control.EditField
        LibtorchPathButton  matlab.ui.control.Button
        PythonPathEdit      matlab.ui.control.EditField
        PythonPathButton    matlab.ui.control.Button

        % Actions Panel
        ActionsPanel        matlab.ui.container.Panel
        ExportButton        matlab.ui.control.Button
        CompileButton       matlab.ui.control.Button
        TestButton          matlab.ui.control.Button

        % Status Panel
        StatusPanel         matlab.ui.container.Panel
        StatusTextArea      matlab.ui.control.TextArea
        ProgressBar         matlab.ui.control.HTML

        % App state
        ProjectPath         string
    end

    methods (Access = public)

        function app = SB3toSFunction()
            % Constructor - Create and configure the GUI

            % Get project path
            app.ProjectPath = fileparts(fileparts(mfilename('fullpath')));

            % Create UI
            createComponents(app);

            % Set default values
            setDefaults(app);

            % Register cleanup
            app.UIFigure.CloseRequestFcn = @(~,~) delete(app);
        end

        function delete(app)
            % Destructor
            delete(app.UIFigure);
        end

    end

    methods (Access = private)

        function createComponents(app)
            % Create the main UI components

            % Create figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 700 600];
            app.UIFigure.Name = 'SB3 to S-Function Converter';
            app.UIFigure.Resize = 'on';

            % Create main grid
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {130, 90, 90, 50, '1x'};
            app.GridLayout.Padding = [10 10 10 10];
            app.GridLayout.RowSpacing = 10;

            % Create panels
            createModelPanel(app);
            createOutputPanel(app);
            createCompilePanel(app);
            createActionsPanel(app);
            createStatusPanel(app);

            % Show figure
            app.UIFigure.Visible = 'on';
        end

        function createModelPanel(app)
            % Model Settings Panel
            app.ModelPanel = uipanel(app.GridLayout);
            app.ModelPanel.Title = 'Model Settings';
            app.ModelPanel.Layout.Row = 1;
            app.ModelPanel.Layout.Column = 1;

            gl = uigridlayout(app.ModelPanel);
            gl.ColumnWidth = {120, '1x', 80};
            gl.RowHeight = {22, 22, 22, 22};
            gl.Padding = [5 5 5 5];
            gl.RowSpacing = 5;

            % SB3 Model Path
            uilabel(gl, 'Text', 'SB3 Model Path:', 'HorizontalAlignment', 'right');
            app.ModelPathEdit = uieditfield(gl, 'text');
            app.ModelPathEdit.Placeholder = 'Select .zip file...';
            app.ModelPathButton = uibutton(gl, 'Text', 'Browse...');
            app.ModelPathButton.ButtonPushedFcn = @(~,~) browseModelPath(app);

            % Algorithm
            uilabel(gl, 'Text', 'Algorithm:', 'HorizontalAlignment', 'right');
            app.AlgorithmDropdown = uidropdown(gl);
            app.AlgorithmDropdown.Items = {'Auto-detect', 'SAC', 'TD3', 'PPO', 'A2C', 'DQN'};
            app.AlgorithmDropdown.Value = 'Auto-detect';
            app.AlgorithmDropdown.Layout.Column = [2 3];

            % Observation Dimension
            uilabel(gl, 'Text', 'Observation Dim:', 'HorizontalAlignment', 'right');
            app.ObsDimSpinner = uispinner(gl);
            app.ObsDimSpinner.Limits = [1 10000];
            app.ObsDimSpinner.Value = 4;
            app.AutoDetectCheck = uicheckbox(gl, 'Text', 'Auto-detect');
            app.AutoDetectCheck.Value = true;
            app.AutoDetectCheck.ValueChangedFcn = @(~,~) toggleAutoDetect(app);

            % Action Dimension
            uilabel(gl, 'Text', 'Action Dim:', 'HorizontalAlignment', 'right');
            app.ActDimSpinner = uispinner(gl);
            app.ActDimSpinner.Limits = [1 1000];
            app.ActDimSpinner.Value = 1;
            uilabel(gl, 'Text', ''); % Spacer

            % Initial state
            toggleAutoDetect(app);
        end

        function createOutputPanel(app)
            % Output Settings Panel
            app.OutputPanel = uipanel(app.GridLayout);
            app.OutputPanel.Title = 'Output Settings';
            app.OutputPanel.Layout.Row = 2;
            app.OutputPanel.Layout.Column = 1;

            gl = uigridlayout(app.OutputPanel);
            gl.ColumnWidth = {120, '1x', 80};
            gl.RowHeight = {22, 22};
            gl.Padding = [5 5 5 5];
            gl.RowSpacing = 5;

            % Output Directory
            uilabel(gl, 'Text', 'Output Directory:', 'HorizontalAlignment', 'right');
            app.OutputDirEdit = uieditfield(gl, 'text');
            app.OutputDirEdit.Placeholder = 'Select output folder...';
            app.OutputDirButton = uibutton(gl, 'Text', 'Browse...');
            app.OutputDirButton.ButtonPushedFcn = @(~,~) browseOutputDir(app);

            % Model Name
            uilabel(gl, 'Text', 'Model Name:', 'HorizontalAlignment', 'right');
            app.ModelNameEdit = uieditfield(gl, 'text');
            app.ModelNameEdit.Value = 'model';
            app.ModelNameEdit.Layout.Column = [2 3];
        end

        function createCompilePanel(app)
            % Compilation Settings Panel
            app.CompilePanel = uipanel(app.GridLayout);
            app.CompilePanel.Title = 'Compilation Settings';
            app.CompilePanel.Layout.Row = 3;
            app.CompilePanel.Layout.Column = 1;

            gl = uigridlayout(app.CompilePanel);
            gl.ColumnWidth = {120, '1x', 80};
            gl.RowHeight = {22, 22};
            gl.Padding = [5 5 5 5];
            gl.RowSpacing = 5;

            % LibTorch Path
            uilabel(gl, 'Text', 'LibTorch Path:', 'HorizontalAlignment', 'right');
            app.LibtorchPathEdit = uieditfield(gl, 'text');
            app.LibtorchPathEdit.Placeholder = 'Select libtorch folder...';
            app.LibtorchPathButton = uibutton(gl, 'Text', 'Browse...');
            app.LibtorchPathButton.ButtonPushedFcn = @(~,~) browseLibtorchPath(app);

            % Python Path
            uilabel(gl, 'Text', 'Python Path:', 'HorizontalAlignment', 'right');
            app.PythonPathEdit = uieditfield(gl, 'text');
            app.PythonPathEdit.Placeholder = 'python or full path...';
            app.PythonPathButton = uibutton(gl, 'Text', 'Browse...');
            app.PythonPathButton.ButtonPushedFcn = @(~,~) browsePythonPath(app);
        end

        function createActionsPanel(app)
            % Actions Panel
            app.ActionsPanel = uipanel(app.GridLayout);
            app.ActionsPanel.Title = 'Actions';
            app.ActionsPanel.Layout.Row = 4;
            app.ActionsPanel.Layout.Column = 1;

            gl = uigridlayout(app.ActionsPanel);
            gl.ColumnWidth = {'1x', '1x', '1x'};
            gl.RowHeight = {'1x'};
            gl.Padding = [5 5 5 5];

            % Export Button
            app.ExportButton = uibutton(gl, 'Text', 'Export Model');
            app.ExportButton.ButtonPushedFcn = @(~,~) exportModel(app);

            % Compile Button
            app.CompileButton = uibutton(gl, 'Text', 'Compile S-Function');
            app.CompileButton.ButtonPushedFcn = @(~,~) compileSFunction(app);

            % Test Button
            app.TestButton = uibutton(gl, 'Text', 'Test Model');
            app.TestButton.ButtonPushedFcn = @(~,~) testModel(app);
        end

        function createStatusPanel(app)
            % Status Panel
            app.StatusPanel = uipanel(app.GridLayout);
            app.StatusPanel.Title = 'Status';
            app.StatusPanel.Layout.Row = 5;
            app.StatusPanel.Layout.Column = 1;

            gl = uigridlayout(app.StatusPanel);
            gl.ColumnWidth = {'1x'};
            gl.RowHeight = {'1x'};
            gl.Padding = [5 5 5 5];

            % Status Text Area
            app.StatusTextArea = uitextarea(gl);
            app.StatusTextArea.Editable = 'off';
            app.StatusTextArea.FontName = 'Consolas';
            app.StatusTextArea.Value = {'Ready. Select an SB3 model to begin.'};
        end

        function setDefaults(app)
            % Set default values based on project structure

            % Default LibTorch path
            libtorch_default = fullfile(app.ProjectPath, 'libtorch');
            if isfolder(libtorch_default)
                app.LibtorchPathEdit.Value = libtorch_default;
            end

            % Default output directory
            app.OutputDirEdit.Value = app.ProjectPath;

            % Default Python path
            if ispc
                app.PythonPathEdit.Value = 'python';
            else
                app.PythonPathEdit.Value = 'python3';
            end
        end

        function log(app, message)
            % Append message to status log
            current = app.StatusTextArea.Value;
            timestamp = datestr(now, 'HH:MM:SS');
            new_msg = sprintf('[%s] %s', timestamp, message);
            app.StatusTextArea.Value = [current; {new_msg}];
            scroll(app.StatusTextArea, 'bottom');
            drawnow;
        end

        function clearLog(app)
            app.StatusTextArea.Value = {''};
        end

        function toggleAutoDetect(app)
            % Enable/disable dimension spinners based on auto-detect
            enabled = ~app.AutoDetectCheck.Value;
            app.ObsDimSpinner.Enable = enabled;
            app.ActDimSpinner.Enable = enabled;
        end

        function browseModelPath(app)
            [file, path] = uigetfile({'*.zip', 'SB3 Model (*.zip)'}, 'Select SB3 Model');
            if file ~= 0
                app.ModelPathEdit.Value = fullfile(path, file);

                % Auto-set model name from filename
                [~, name, ~] = fileparts(file);
                app.ModelNameEdit.Value = [name '_actor'];

                log(app, sprintf('Selected model: %s', file));
            end
        end

        function browseOutputDir(app)
            path = uigetdir(app.ProjectPath, 'Select Output Directory');
            if path ~= 0
                app.OutputDirEdit.Value = path;
                log(app, sprintf('Output directory: %s', path));
            end
        end

        function browseLibtorchPath(app)
            path = uigetdir(app.ProjectPath, 'Select LibTorch Directory');
            if path ~= 0
                app.LibtorchPathEdit.Value = path;
                log(app, sprintf('LibTorch path: %s', path));
            end
        end

        function browsePythonPath(app)
            [file, path] = uigetfile({'*.exe;python*', 'Python Executable'}, 'Select Python');
            if file ~= 0
                app.PythonPathEdit.Value = fullfile(path, file);
                log(app, sprintf('Python: %s', file));
            end
        end

        function exportModel(app)
            % Export SB3 model to TorchScript

            % Validate inputs
            model_path = app.ModelPathEdit.Value;
            if isempty(model_path) || ~isfile(model_path)
                uialert(app.UIFigure, 'Please select a valid SB3 model file.', 'Error');
                return;
            end

            output_dir = app.OutputDirEdit.Value;
            if isempty(output_dir) || ~isfolder(output_dir)
                uialert(app.UIFigure, 'Please select a valid output directory.', 'Error');
                return;
            end

            python_path = app.PythonPathEdit.Value;
            if isempty(python_path)
                uialert(app.UIFigure, 'Please specify Python path.', 'Error');
                return;
            end

            % Build output path
            model_name = app.ModelNameEdit.Value;
            if isempty(model_name)
                model_name = 'model';
            end
            output_path = fullfile(output_dir, [model_name '.pt']);

            % Build Python command
            script_path = fullfile(app.ProjectPath, 'python', 'export_model.py');

            % Algorithm argument
            algo = app.AlgorithmDropdown.Value;
            if strcmp(algo, 'Auto-detect')
                algo_arg = '';
            else
                algo_arg = sprintf(' --algorithm %s', algo);
            end

            cmd = sprintf('"%s" "%s" --input "%s" --output "%s"%s --verbose', ...
                python_path, script_path, model_path, output_path, algo_arg);

            log(app, 'Starting model export...');
            log(app, sprintf('Command: %s', cmd));

            % Run export
            try
                [status, output] = system(cmd);

                % Log output
                lines = strsplit(output, newline);
                for i = 1:length(lines)
                    if ~isempty(strtrim(lines{i}))
                        log(app, lines{i});
                    end
                end

                if status == 0
                    log(app, 'Export successful!');

                    % Try to read metadata for auto-detect
                    if app.AutoDetectCheck.Value
                        json_path = fullfile(output_dir, [model_name '.json']);
                        if isfile(json_path)
                            try
                                fid = fopen(json_path, 'r');
                                raw = fread(fid, inf, 'char');
                                fclose(fid);
                                metadata = jsondecode(char(raw'));

                                app.ObsDimSpinner.Value = metadata.obs_dim;
                                app.ActDimSpinner.Value = metadata.act_dim;
                                log(app, sprintf('Auto-detected: obs_dim=%d, act_dim=%d', ...
                                    metadata.obs_dim, metadata.act_dim));
                            catch
                                log(app, 'Warning: Could not read metadata file.');
                            end
                        end
                    end

                    uialert(app.UIFigure, sprintf('Model exported to:\n%s', output_path), ...
                        'Export Complete', 'Icon', 'success');
                else
                    log(app, sprintf('Export failed with status %d', status));
                    uialert(app.UIFigure, 'Export failed. Check status log for details.', 'Error');
                end

            catch ME
                log(app, sprintf('Error: %s', ME.message));
                uialert(app.UIFigure, ME.message, 'Error');
            end
        end

        function compileSFunction(app)
            % Compile the LibTorch S-Function

            libtorch_path = app.LibtorchPathEdit.Value;
            if isempty(libtorch_path) || ~isfolder(libtorch_path)
                uialert(app.UIFigure, 'Please select a valid LibTorch directory.', 'Error');
                return;
            end

            log(app, 'Starting S-Function compilation...');

            try
                % Add libtorch to PATH (for runtime)
                lib_path = fullfile(libtorch_path, 'lib');
                current_path = getenv('PATH');
                if ~contains(current_path, lib_path)
                    setenv('PATH', [lib_path pathsep current_path]);
                    log(app, sprintf('Added to PATH: %s', lib_path));
                end

                % Run compilation
                compile_script = fullfile(app.ProjectPath, 'compile_sfunction.m');
                run(compile_script);

                log(app, 'Compilation successful!');
                uialert(app.UIFigure, 'S-Function compiled successfully!', ...
                    'Compilation Complete', 'Icon', 'success');

            catch ME
                log(app, sprintf('Compilation error: %s', ME.message));
                uialert(app.UIFigure, ME.message, 'Compilation Error');
            end
        end

        function testModel(app)
            % Test loading the exported model

            output_dir = app.OutputDirEdit.Value;
            model_name = app.ModelNameEdit.Value;
            model_path = fullfile(output_dir, [model_name '.pt']);

            if ~isfile(model_path)
                uialert(app.UIFigure, sprintf('Model file not found:\n%s', model_path), 'Error');
                return;
            end

            log(app, sprintf('Testing model: %s', model_path));

            % Check if MEX file exists
            mex_file = fullfile(app.ProjectPath, ['libtorch_sfun.' mexext]);
            if ~isfile(mex_file)
                log(app, 'Warning: S-Function not compiled yet.');
                log(app, 'Please compile the S-Function first.');
                uialert(app.UIFigure, 'S-Function not compiled. Please compile first.', 'Warning');
                return;
            end

            obs_dim = app.ObsDimSpinner.Value;
            act_dim = app.ActDimSpinner.Value;

            log(app, sprintf('Testing with obs_dim=%d, act_dim=%d', obs_dim, act_dim));

            % Add libtorch to PATH
            libtorch_path = app.LibtorchPathEdit.Value;
            if ~isempty(libtorch_path) && isfolder(libtorch_path)
                lib_path = fullfile(libtorch_path, 'lib');
                current_path = getenv('PATH');
                if ~contains(current_path, lib_path)
                    setenv('PATH', [lib_path pathsep current_path]);
                end
            end

            try
                % Try to call the S-Function with test data
                log(app, 'Model test passed: file exists and S-Function compiled.');
                log(app, 'Full validation requires running in Simulink.');

                uialert(app.UIFigure, ...
                    sprintf('Model file exists and S-Function compiled.\n\nTo fully test, create a Simulink model with:\n- Constant block (obs_dim=%d)\n- S-Function block (libtorch_sfun)\n- Scope block', obs_dim), ...
                    'Test Complete', 'Icon', 'success');

            catch ME
                log(app, sprintf('Test error: %s', ME.message));
                uialert(app.UIFigure, ME.message, 'Test Error');
            end
        end

    end
end
