function [rawfn, heads, fout, startTimeApprox_cdt] = readExperimentLog(xlsxFile, basedir, outdir, dateStr)
% READEXPERIMENTLOG Read experiment log from Excel file and generate processing parameters
%
% USAGE:
%   [rawfn, heads, fout] = readExperimentLog(xlsxFile, basedir, outdir, dateStr)
%
% INPUTS:
%   xlsxFile - Path to Excel log file (e.g., 'STONE2025_09182025.xlsx')
%   basedir  - Base directory containing DragonData files
%   outdir   - Output directory for processed files
%   dateStr  - Date string for output filenames (e.g., '20250918')
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
%       'data/20250918/MFDop_L1', '20250918');
%
% NOTES:
%   - Robust parsing handles various beam name formats (Aux1, Aux 1, aux_1, etc.)
%   - X-coordinates are automatically extracted and appended to filenames
%   - For Main head: uses MFDop Head X-Coord column (single value)
%   - For Aux heads: extracts x from coordinate triplets like "(137, 123.5, 26)"
%   - Output format: DD_YYYYMMDD_caseXpXTrialXX_xNNN_HeadName_L1

    % Read the Excel file
    data = readtable(xlsxFile);

    % Initialize output arrays
    rawfn = {};
    heads = {};
    fout = {};
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
        if isempty(caseTrialStr) || isempty(beamsStr) || isnan(fileNum)
            continue;
        end

        % Parse case/trial string (e.g., '1.3_03' -> 'case1p3Trial03')
        caseTrialClean = strrep(caseTrialStr, '.', 'p');
        caseTrialClean = strrep(caseTrialClean, '_', 'Trial');
        if ~startsWith(caseTrialClean, 'case')
            caseTrialClean = ['case' caseTrialClean];
        end

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
        % Handle string time format like "10:38:00"
        if iscell(startTimeValue)
            timeStr = startTimeValue{1};
        else
            timeStr = startTimeValue;
        end

        if ~isempty(timeStr)
            try
                % Parse the date string to get the base date
                baseDate = datenum(dateStr, 'yyyymmdd');
                % Parse the time string (assume HH:MM:SS format)
                timeParts = sscanf(timeStr, '%d:%d:%d');
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
                warning('Could not parse string start time: %s', timeStr);
            end
        end
    end
end
