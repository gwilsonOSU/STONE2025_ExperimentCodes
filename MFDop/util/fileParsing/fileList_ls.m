function fn = fileList_ls(pattern, errtype)
%
% fn = fileList_ls(pattern, errtype)
%
% Gets list of files matching glob <pattern> using modern MATLAB dir() function
%
% INPUTS:
%   pattern  - File pattern with wildcards (e.g., '/path/to/files/*.mat')
%   errtype  - Error handling mode (optional, default=1)
%              1: throw error if no files match
%              0: return empty cell array if no files match, with warning
%
% OUTPUTS:
%   fn - Cell array of full file paths, or single string if only one file
%        Returns empty cell array {} if no matches and errtype=0
%
% EXAMPLES:
%   fn = fileList_ls('/data/*.mat')           % Error if no .mat files
%   fn = fileList_ls('/data/*.mat', 0)        % Warning if no .mat files
%   fn = fileList_ls('DragonData.*.00001*.mat') % Pattern matching
%
% NOTES:
%   - Uses modern MATLAB dir() function for better performance
%   - Handles large numbers of files efficiently
%   - Supports standard file globbing patterns
%   - Returns full paths for all matched files
%

if ~exist('errtype', 'var')
    errtype = 1;
end

% Input validation
if ~ischar(pattern) || isempty(pattern)
    error('Pattern must be a non-empty string');
end

try
    % Use dir() to find matching files
    % dir() handles wildcards and is much faster than unix commands
    dirInfo = dir(pattern);

    % Filter out directories if any are returned
    fileInfo = dirInfo(~[dirInfo.isdir]);

    if isempty(fileInfo)
        % No files match the pattern
        if errtype == 1
            error('No files matched the pattern: %s', pattern);
        else
            warning('fileList_ls:noMatch', 'No files matched the pattern: %s', pattern);
            fn = {};
            return;
        end
    end

    % Build full file paths
    fn = cell(length(fileInfo), 1);
    for i = 1:length(fileInfo)
        fn{i} = fullfile(fileInfo(i).folder, fileInfo(i).name);
    end

    % Sort files for consistent ordering
    fn = sort(fn);

    % Convert to single string if only one file (maintains backward compatibility)
    if length(fn) == 1
        fn = fn{1};
    end

catch ME
    % Handle potential errors from dir() function
    if errtype == 1
        error('Error searching for files with pattern "%s": %s', pattern, ME.message);
    else
        warning('fileList_ls:searchError', ...
            'Error searching for files with pattern "%s": %s', pattern, ME.message);
        fn = {};
        return;
    end
end

end
