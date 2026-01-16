function compile_sfunction(libtorch_path)
%COMPILE_SFUNCTION Compile the LibTorch S-Function for Simulink
%
%   COMPILE_SFUNCTION() compiles using default libtorch path (./libtorch)
%   COMPILE_SFUNCTION(LIBTORCH_PATH) compiles using specified libtorch path
%
%   Requirements:
%     - Visual Studio 2019 or later (for Windows)
%     - LibTorch library files
%     - MATLAB with Simulink installed
%
%   Example:
%     compile_sfunction()
%     compile_sfunction('C:\libs\libtorch')

    % Get the directory where this script is located
    script_dir = fileparts(mfilename('fullpath'));

    % Default libtorch path
    if nargin < 1 || isempty(libtorch_path)
        libtorch_path = fullfile(script_dir, 'libtorch');
    end

    % Validate libtorch path
    if ~isfolder(libtorch_path)
        error('LibTorch path not found: %s', libtorch_path);
    end

    % Check for required directories
    include_path = fullfile(libtorch_path, 'include');
    api_include_path = fullfile(libtorch_path, 'include', 'torch', 'csrc', 'api', 'include');
    lib_path = fullfile(libtorch_path, 'lib');

    if ~isfolder(include_path)
        error('LibTorch include directory not found: %s', include_path);
    end
    if ~isfolder(lib_path)
        error('LibTorch lib directory not found: %s', lib_path);
    end

    % Source file
    src_file = fullfile(script_dir, 'src', 'libtorch_sfun.cpp');
    if ~isfile(src_file)
        error('Source file not found: %s', src_file);
    end

    % Output directory (same as script directory)
    output_dir = script_dir;

    fprintf('Compiling LibTorch S-Function...\n');
    fprintf('  Source: %s\n', src_file);
    fprintf('  LibTorch: %s\n', libtorch_path);
    fprintf('  Output: %s\n', output_dir);

    % Build MEX command
    if ispc
        % Windows compilation
        mex_cmd = { ...
            '-v', ...
            'COMPFLAGS=$COMPFLAGS /std:c++17 /EHsc', ...
            ['-I' include_path], ...
            ['-I' api_include_path], ...
            ['-L' lib_path], ...
            '-ltorch', '-ltorch_cpu', '-lc10', ...
            '-outdir', output_dir, ...
            src_file ...
        };
    else
        % Linux/Mac compilation
        mex_cmd = { ...
            '-v', ...
            'CXXFLAGS=$CXXFLAGS -std=c++17', ...
            ['-I' include_path], ...
            ['-I' api_include_path], ...
            ['-L' lib_path], ...
            '-ltorch', '-ltorch_cpu', '-lc10', ...
            ['LDFLAGS=$LDFLAGS -Wl,-rpath,' lib_path], ...
            '-outdir', output_dir, ...
            src_file ...
        };
    end

    % Execute MEX compilation
    try
        fprintf('\nRunning MEX compiler...\n\n');
        mex(mex_cmd{:});
        fprintf('\n=== Compilation successful! ===\n');

        % Display runtime requirements
        if ispc
            fprintf('\nRuntime Requirements:\n');
            fprintf('  Ensure the following DLLs are accessible (in PATH or same directory):\n');
            fprintf('    - torch.dll\n');
            fprintf('    - torch_cpu.dll\n');
            fprintf('    - c10.dll\n');
            fprintf('\n  You can add LibTorch to PATH with:\n');
            fprintf('    setenv(''PATH'', [''%s'' pathsep getenv(''PATH'')])\n', lib_path);
        end

    catch ME
        fprintf('\n=== Compilation failed! ===\n');
        fprintf('Error: %s\n', ME.message);

        % Provide troubleshooting hints
        fprintf('\nTroubleshooting:\n');
        if ispc
            fprintf('  1. Ensure Visual Studio 2019+ is installed\n');
            fprintf('  2. Run from Developer Command Prompt or configure MEX:\n');
            fprintf('     mex -setup C++\n');
            fprintf('  3. Check that LibTorch CPU version is being used\n');
        else
            fprintf('  1. Ensure GCC 7+ or Clang 5+ is installed\n');
            fprintf('  2. Configure MEX compiler: mex -setup C++\n');
        end

        rethrow(ME);
    end
end
