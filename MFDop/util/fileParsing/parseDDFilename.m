function info = parseDDFilename(fname)
%
% info = parseDDFilename(fname)
%
% Parse filenames like this example...
%       DD_20250929_d142f4S17X35_MF4_11_x139_Aux2_L1.mat
%
% Returns struct 'info' with fields:
%  time (datenum), d, f, S, X, MF, trialid, x
%

pattern = ['^DD_(?<date>\d{8})_', ...
           'd(?<d>\d+)f(?<f>\d+)S(?<S>\d+)X(?<X>\d+)_', ...
           'MF(?<MF>\d+)_', ...
           '(?<trialid>\d+[A-Za-z]?)_', ...
           'x(?<x>\d+)', ...
           '(?:_.*)?\.mat$'];

t = regexp(fname, pattern, 'names', 'once');
if isempty(t)
    error('Filename does not match expected pattern:\n%s', fname);
end

% Numeric conversions
info.d  = str2double(t.d);
info.f  = str2double(t.f);
info.S  = str2double(t.S);
info.X  = str2double(t.X);
info.MF = str2double(t.MF);
info.x  = str2double(t.x);

% trialid as string (e.g., '01b')
info.trialid = t.trialid;

% If you ever need the numeric portion only:
% info.trialnum = sscanf(t.trialid, '%d');   % -> 1 for '01b'

% Date -> datenum
dt = datetime(t.date,'InputFormat','yyyyMMdd');
info.time = datenum(dt);
end
