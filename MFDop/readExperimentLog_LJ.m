function [rawfn, heads, fout, startTimeApprox_cdt, jackfn] = readExperimentLog(xlsxFile, basedir, outdir, dateStr, printdebug)
% READEXPERIMENTLOG Read experiment log from Excel file and generate processing parameters
%
% USAGE:
%   [rawfn, heads, fout] = readExperimentLog(xlsxFile, basedir, outdir, dateStr, printdebug)
%
% INPUTS:
%   xlsxFile - Path to Excel log file (e.g., 'STONE2025_09182025.xlsx')
%   basedir  - Base directory containing DragonData files
%   outdir   - Output directory for processed files
%   dateStr  - Date string for output filenames (e.g., '20250918')
%   printdebug - Optional flag to enable debug output (default: false)
%
% OUTPUTS:
%   rawfn - Cell array of file lists for each trial
%   heads - Cell array of active heads for each trial
%   fout  - Cell array of output filenames for each trial (includes x-coordinate)
%   startTimeApprox_cdt - Array of start times in MATLAB datenum format (CDT)
%
% EXAMPLE:
%   [rawfn, heads, fout, startTimeApprox_cdt] = readExperimentLog('STONE2025_09182025.xlsx', ...
%       '/media/wilsongr/LaCie/STONE_20250918/MFDop', ...
%       'data/20250918/MFDop_L1', '20250918', false);
%
% EXCEL FILE FORMAT REQUIREMENTS:
%   The Excel file must have the following structure:
%   - Row 1: Headers including 'Case&Trial', 'Time Start (CDT)', 'MFDop Transmitting Beams', 'MFDop File'
%   - Row 2+: Data rows with valid values (no "?" in Time Start column)
%   - Column A: Case&Trial names (e.g., '1.3_01', 'd142f4S10X40_01')
%   - Column C: Time Start in HH:MM:SS format (e.g., '10:38:00')
%   - Column G: MFDop Transmitting Beams (e.g., 'Aux 1, Aux 2', 'Main Head')
%   - Column L: MFDop File numbers (numeric, e.g., 0, 1, 2, ...)
%
% NOTES:
%   - Robust parsing handles various beam name formats (Aux1, Aux 1, aux_1, etc.)
%   - X-coordinates are automatically extracted and appended to filenames
%   - For Main head: uses MFDop Head X-Coord column (single value)
%   - For Aux heads: extracts x from coordinate triplets like "(137, 123.5, 26)"
%   - Output format: DD_YYYYMMDD_casename_xNNN_HeadName_L1

    % Set default debug flag if not provided
    if nargin < 5
        printdebug = false;
    end

    % Read the Excel file using readcell for explicit control over row reading
    % This ensures we get ALL rows including the header row
    cellData = readcell(xlsxFile);

    % Convert to table format for compatibility with rest of code
    % Remove completely empty rows first
    validRows = false(size(cellData, 1), 1);
    for i = 1:size(cellData, 1)
        % A row is valid if any of the first 12 columns has non-empty content
        hasContent = false;
        for j = 1:min(12, size(cellData, 2))
            val = cellData{i, j};
            if ~isempty(val) && ~(isnumeric(val) && isnan(val))
                hasContent = true;
                break;
            end
        end
        validRows(i) = hasContent;
    end
    cellData = cellData(validRows, :);

    % Validate basic structure
    if size(cellData, 2) < 12
        error('Excel file format error: Expected at least 12 columns, found %d. Please check file format.', size(cellData, 2));
    end

    if size(cellData, 1) < 2
        error('Excel file format error: Expected header row plus data rows, found only %d rows total.', size(cellData, 1));
    end

    % Validate that the first row contains expected headers
    if printdebug
        fprintf('Debug: First row contents (should be headers):\n');
        for i = 1:min(12, size(cellData, 2))
            val = cellData{1, i};
            if ischar(val)
                fprintf('  Column %d: "%s"\n', i, val);
            else
                fprintf('  Column %d: %s\n', i, string(val));
            end
        end
    end

    % Check for critical header patterns
    col1_valid = false; col7_valid = false; col12_valid = false;

    % Check Column 1 (Case&Trial)
    val = cellData{1, 1};
    if ischar(val) || isstring(val)
        valStr = lower(string(val));
        col1_valid = contains(valStr, 'case') || contains(valStr, 'trial');
    end

    % Check Column 7 (Beams)
    val = cellData{1, 7};
    if ischar(val) || isstring(val)
        valStr = lower(string(val));
        col7_valid = contains(valStr, 'beam') || contains(valStr, 'transmit');
    end

    % Check Column 10 (LJFile)
    val = cellData{1, 10};
    if ischar(val) || isstring(val)
        valStr = lower(string(val));
        col10_valid = contains(valStr, 'file') || contains(valStr, 'mfdop');
    end

    % Check Column 12 (DopFile)
    val = cellData{1, 12};
    if ischar(val) || isstring(val)
        valStr = lower(string(val));
        col12_valid = contains(valStr, 'file') || contains(valStr, 'mfdop');
    end
    
    if printdebug
        fprintf('Header validation: Col1=%d, Col7=%d, Col12=%d\n', col1_valid, col7_valid, col12_valid);
    end

    % If headers don't validate, check if first row might actually be data
    if sum([col1_valid, col7_valid, col12_valid]) < 2
        if printdebug
            fprintf('Headers not found in row 1. Checking if row 1 contains data instead...\n');
        end
        % Check if first row looks like data (has case name pattern and beam names)
        val1 = cellData{1, 1}; val7 = cellData{1, 7};
        if ischar(val1) && ischar(val7) && (contains(val7, 'Aux') || contains(val7, 'Main'))
            warning(['Excel file appears to be missing header row. Proceeding with all rows as data.\n' ...
                    'Expected format: Row 1 should contain headers like "Case&Trial", "MFDop Transmitting Beams", etc.']);
            dataRows = cellData;
        else
            error(['Excel file format error: Cannot determine data structure.\n' ...
                   'Please ensure your Excel file has proper headers in row 1.']);
        end
    else
        % Headers found, remove header row
        dataRows = cellData(2:end, :);
    end

    % Convert to table with generic variable names for compatibility
    data = cell2table(dataRows, 'VariableNames', ...
        arrayfun(@(x) sprintf('Var%d', x), 1:size(dataRows, 2), 'UniformOutput', false));

    % Final validation
    if height(data) == 0
        error(['Excel file format error: No valid data rows found.\n' ...
               'Please ensure the Excel file contains data rows with valid entries.']);
    end

    % Initialize output arrays
    rawfn = {};
    heads = {};
    fout = {};
    jackfn = {};
    startTimeApprox_cdt = [];

    % Process each row of data
    for i = 1:height(data)
        % Extract trial information
        % Var1 = Case&Trial, Var3 = Time Start (CDT), Var7 = MFDop Transmitting Beams, Var12 = MFDop File
        % Var4 = MFDop Head X-Coord, Var5 = Aux 1 Coords, Var6 = Aux 2 Coords
        caseTrialCell = data{i, 'Var1'};
        startTimeValue = data{i, 'Var3'};
        beamsCell = data{i, 'Var7'};
        fileNum = data{i, 'Var12'};
        jackFileNum = data{i, 'Var10'};   
        mainXCoord = data{i, 'Var4'};
        aux1CoordsCell = data{i, 'Var5'};
        aux2CoordsCell = data{i, 'Var6'};

        % Handle cell array extraction for string columns
        if iscell(caseTrialCell)
            caseTrialStr = caseTrialCell{1};
        else
            caseTrialStr = caseTrialCell;
        end

        if iscell(beamsCell)
            beamsStr = beamsCell{1};
        else
            beamsStr = beamsCell;
        end

        if iscell(aux1CoordsCell)
            aux1CoordsStr = aux1CoordsCell{1};
        else
            aux1CoordsStr = aux1CoordsCell;
        end

        if iscell(aux2CoordsCell)
            aux2CoordsStr = aux2CoordsCell{1};
        else
            aux2CoordsStr = aux2CoordsCell;
        end

        % Skip rows with missing critical data
        if isempty(caseTrialStr) || isempty(beamsStr) || (isnumeric(fileNum) && isnan(fileNum))
            continue;
        end

        % Skip rows where MFDop File entry is not a valid number (e.g., "No MFDop File")
        % Handle cell arrays (common with readcell)
        if iscell(fileNum)
            if ~isempty(fileNum)
                fileNum = fileNum{1};  % Extract from cell
            else
                if printdebug
                    fprintf('Skipping trial %s: Empty cell for MFDop File entry\n', caseTrialStr);
                end
                continue;
            end
        end

        if isnumeric(fileNum)
            % Already numeric - check if it's valid
            if ~isfinite(fileNum) || fileNum < 0
                if printdebug
                    fprintf('Skipping trial %s: Invalid numeric MFDop File entry (%g)\n', caseTrialStr, fileNum);
                end
                continue;
            end
        else
            % Try to convert string to number
            if ischar(fileNum) || isstring(fileNum)
                numericFileNum = str2double(fileNum);
                if isnan(numericFileNum) || numericFileNum < 0
                    % Not a valid number or negative
                    if printdebug
                        fprintf('Skipping trial %s: Invalid MFDop File entry ("%s")\n', caseTrialStr, string(fileNum));
                    end
                    continue;
                else
                    % Valid numeric string - convert it
                    fileNum = numericFileNum;
                end
            else
                % Neither numeric nor string/char
                if printdebug
                    fprintf('Skipping trial %s: Invalid MFDop File entry type\n', caseTrialStr);
                end
                continue;
            end
        end
        
        % Handle Jack File entry (column 10)
        jackFileNum = data{i, 'Var10'};
        
        if iscell(jackFileNum)
            if ~isempty(jackFileNum)
                jackFileNum = jackFileNum{1};
            else
                if printdebug
                    fprintf('Skipping trial %s: Empty cell for Jack File entry\n', caseTrialStr);
                end
                continue;
            end
        end
        
        if isnumeric(jackFileNum)
            if ~isfinite(jackFileNum) || jackFileNum < 0
                if printdebug
                    fprintf('Skipping trial %s: Invalid numeric Jack File entry (%g)\n', caseTrialStr, jackFileNum);
                end
                continue;
            end
        else
            if ischar(jackFileNum) || isstring(jackFileNum)
                numericJackFileNum = str2double(jackFileNum);
                if isnan(numericJackFileNum) || numericJackFileNum < 0
                    if printdebug
                        fprintf('Skipping trial %s: Invalid Jack File entry ("%s")\n', caseTrialStr, string(jackFileNum));
                    end
                    continue;
                else
                    jackFileNum = numericJackFileNum;
                end
            else
                if printdebug
                    fprintf('Skipping trial %s: Invalid Jack File entry type\n', caseTrialStr);
                end
                continue;
            end
        end

        % % Parse case/trial string (e.g., '1.3_03' -> 'case1p3Trial03')
        % caseTrialClean = strrep(caseTrialStr, '.', 'p');
        % caseTrialClean = strrep(caseTrialClean, '_', 'Trial');
        % if ~startsWith(caseTrialClean, 'case')
        %     caseTrialClean = ['case' caseTrialClean];
        % end
        caseTrialClean=caseTrialStr;  % GW: After changing to more descriptive case ID's

        % Parse beam configuration using tokenization approach
        [headConfig, xCoord] = parseBeamConfiguration(beamsStr, mainXCoord, aux1CoordsStr, aux2CoordsStr);

        if isempty(headConfig)
            warning('Unknown beam configuration: %s for trial %s', beamsStr, caseTrialStr);
            continue;
        end

        % Parse start time to datenum format
        startTimeDatenum = parseStartTime(startTimeValue, dateStr);

        % Generate output filenames with x-coordinate
        baseFilename = [outdir '/DD_' dateStr '_' caseTrialClean '_x' num2str(round(xCoord))];
        fout{end+1} = baseFilename;
        heads{end+1} = headConfig;
        startTimeApprox_cdt(end+1) = startTimeDatenum;

        % Generate file pattern based on MFDop file number
        % File numbers should be formatted as 5-digit strings with leading zeros
        filePattern = sprintf('%05d', round(fileNum));

        % Generate file list using fileList_ls function with warning mode
        rawfn{end+1} = fileList_ls([basedir '/DragonData.*.' filePattern '*.mat'], 0);
        
        jackFilePattern = sprintf('%05d', round(jackFileNum));
        jackfn{end+1} = fileList_ls([basedir '/JackData.*.' jackFilePattern '*.mat'], 0);

        % Display progress
        fprintf('Added trial: %s, Beams: %s, X-coord: %.1f, Files: %s\n', ...
            caseTrialClean, beamsStr, xCoord, filePattern);
    end

    % Display summary
    fprintf('\nSummary:\n');
    fprintf('Total trials processed: %d\n', length(rawfn));
    fprintf('Trials with Main head: %d\n', sum(cellfun(@(x) any(strcmp(x, 'Main')), heads)));
    fprintf('Trials with Aux heads: %d\n', sum(cellfun(@(x) any(strcmp(x, 'Aux1')) || any(strcmp(x, 'Aux2')), heads)));

end

function [headConfig, xCoord] = parseBeamConfiguration(beamsStr, mainXCoord, aux1CoordsStr, aux2CoordsStr)
    % Parse beam configuration using tokenization and standardization
    % Handles all combinations: Main only, Aux only, or mixed combinations

    headConfig = {};
    xCoord = NaN;

    if isempty(beamsStr) || ~ischar(beamsStr)
        return;
    end

    % Tokenize the beam string on commas and normalize each token
    tokens = strsplit(beamsStr, ',');
    standardizedHeads = {};

    for i = 1:length(tokens)
        token = strtrim(tokens{i}); % Remove leading/trailing whitespace
        standardizedHead = standardizeBeamName(token);

        if ~isempty(standardizedHead)
            % Avoid duplicates
            if ~any(strcmp(standardizedHeads, standardizedHead))
                standardizedHeads{end+1} = standardizedHead;
            end
        end
    end

    % Sort heads in standard order: Main, Aux1, Aux2
    headOrder = {'Main', 'Aux1', 'Aux2'};
    headConfig = {};
    for i = 1:length(headOrder)
        if any(strcmp(standardizedHeads, headOrder{i}))
            headConfig{end+1} = headOrder{i};
        end
    end

    % Determine x-coordinate based on priority: Main > Aux1 > Aux2
    hasMain = any(strcmp(headConfig, 'Main'));
    hasAux1 = any(strcmp(headConfig, 'Aux1'));
    hasAux2 = any(strcmp(headConfig, 'Aux2'));

    if hasMain && ~isnan(mainXCoord)
        xCoord = mainXCoord;
    elseif hasAux1 && ~isempty(aux1CoordsStr)
        xCoord = extractXFromCoords(aux1CoordsStr);
    elseif hasAux2 && ~isempty(aux2CoordsStr)
        xCoord = extractXFromCoords(aux2CoordsStr);
    end

    % Fallback coordinate extraction if primary method failed
    if isnan(xCoord)
        if ~isempty(aux1CoordsStr)
            xCoord = extractXFromCoords(aux1CoordsStr);
        elseif ~isempty(aux2CoordsStr)
            xCoord = extractXFromCoords(aux2CoordsStr);
        elseif hasMain && ~isnan(mainXCoord)
            xCoord = mainXCoord;
        end
    end

    % Final fallback with appropriate warning
    if isnan(xCoord)
        if hasMain
            warning('Main head specified but no main x-coordinate found');
        end
        warning('Could not determine x-coordinate, using default value 0');
        xCoord = 0;
    end
end

function standardizedName = standardizeBeamName(token)
    % Standardize individual beam name tokens using switch statement
    % Handles various user input formats and converts to standard names

    if isempty(token)
        standardizedName = '';
        return;
    end

    % Normalize the token: lowercase, remove extra spaces, replace underscores
    normalizedToken = lower(strtrim(token));
    normalizedToken = regexprep(normalizedToken, '\s+', ' '); % Multiple spaces -> single space
    normalizedToken = strrep(normalizedToken, '_', ' '); % Underscores -> spaces
    normalizedToken = regexprep(normalizedToken, '(\w+)\s+(\d+)', '$1$2'); % "aux 1" -> "aux1"

    % Use switch statement to convert to standardized names
    switch normalizedToken
        case {'main', 'main head', 'mainhead'}
            standardizedName = 'Main';
        case {'aux1', 'aux 1', 'auxiliary1', 'auxiliary 1'}
            standardizedName = 'Aux1';
        case {'aux2', 'aux 2', 'auxiliary2', 'auxiliary 2'}
            standardizedName = 'Aux2';
        otherwise
            % Check for partial matches or common variations
            if contains(normalizedToken, 'main')
                standardizedName = 'Main';
            elseif contains(normalizedToken, 'aux') && (contains(normalizedToken, '1') || contains(normalizedToken, 'one'))
                standardizedName = 'Aux1';
            elseif contains(normalizedToken, 'aux') && (contains(normalizedToken, '2') || contains(normalizedToken, 'two'))
                standardizedName = 'Aux2';
            else
                % Unknown token - issue warning but don't fail
                warning('Unknown beam configuration token: "%s" (original: "%s")', normalizedToken, token);
                standardizedName = '';
            end
    end
end

function xCoord = extractXFromCoords(coordsStr)
    % Extract x-coordinate from coordinate string like "(137, 123.5, 26)"

    xCoord = NaN;

    if isempty(coordsStr) || ~ischar(coordsStr)
        return;
    end

    % Use regular expression to find numbers in parentheses
    pattern = '\(\s*([0-9.]+)';  % Match opening paren, optional space, then number
    matches = regexp(coordsStr, pattern, 'tokens');

    if ~isempty(matches) && ~isempty(matches{1})
        xCoord = str2double(matches{1}{1});
    else
        % Fallback: try to find first number in the string
        numbers = regexp(coordsStr, '[0-9.]+', 'match');
        if ~isempty(numbers)
            xCoord = str2double(numbers{1});
        end
    end
end

function startTimeDatenum = parseStartTime(startTimeValue, dateStr)
    % Parse start time value and convert to MATLAB datenum format
    % Handles both numeric (Excel time) and string time formats

    startTimeDatenum = NaN;

    if (isnumeric(startTimeValue) && isnan(startTimeValue)) || isempty(startTimeValue)
        return;
    end

    if isnumeric(startTimeValue)
        % Excel stores times as decimal fractions of a day
        % Convert to full datetime by adding to the date
        try
            % Parse the date string to get the base date
            baseDate = datenum(dateStr, 'yyyymmdd');
            % Add the time fraction
            startTimeDatenum = baseDate + startTimeValue;
        catch
            warning('Could not parse numeric start time: %f', startTimeValue);
        end
    elseif ischar(startTimeValue) || (iscell(startTimeValue) && ~isempty(startTimeValue))
        % Handle string time format like "10:38:00" or cell arrays
        if iscell(startTimeValue)
            timeValue = startTimeValue{1};
        else
            timeValue = startTimeValue;
        end

        if ~isempty(timeValue)
            % Check if the extracted value is actually numeric (Excel time fraction)
            if isnumeric(timeValue)
                try
                    % Parse the date string to get the base date
                    baseDate = datenum(dateStr, 'yyyymmdd');
                    % Add the time fraction
                    startTimeDatenum = baseDate + timeValue;
                catch
                    warning('Could not parse numeric start time from cell: %f', timeValue);
                end
            elseif ischar(timeValue) || isstring(timeValue)
                try
                    % Parse the date string to get the base date
                    baseDate = datenum(dateStr, 'yyyymmdd');
                    % Parse the time string (assume HH:MM:SS format)
                    timeParts = sscanf(char(timeValue), '%d:%d:%d');
                    if length(timeParts) >= 2
                        hours = timeParts(1);
                        minutes = timeParts(2);
                        seconds = 0;
                        if length(timeParts) >= 3
                            seconds = timeParts(3);
                        end
                        % Convert to fraction of day and add to base date
                        timeFraction = (hours + minutes/60 + seconds/3600) / 24;
                        startTimeDatenum = baseDate + timeFraction;
                    end
                catch
                    warning('Could not parse string start time: %s', char(timeValue));
                end
            end
        end
    end
end