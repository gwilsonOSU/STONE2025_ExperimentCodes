% L1 Processing Script:
%
% INPUT: DD.mat files created by DD software ntk->mat file conversion tool
%
%    - Edit the parameters at the top of this script to point to the desired
%    files for each collection, and specify the case ID and head
%    configuration for each file.  Use the log book to gather this info and
%    enter it into this script.
%
%  
% OUTPUT: Uses loadMFDopSTONE.m to create L1 processed files with the
% following properties
%
%    - DD.mat files 00001,00002,..., are concatenated into a single
%    collection flie
%
%    - Desired acoustic beam(s) for each collection are kept, non-active
%    beams are discarded
%
%    - For cases where main head was active, uvw velocities are calculated
%    and saved for the main head using beam2uvw
%
%    - Now uses labjack files (data_[0,1,2...]) and creates JackEdges data
%    structure in each L1 processed file with rising and falling edges.
%clear
addpath(genpath('util'))

dooverwrite = 0;
soundspeed = 1500;

%------------------------------------------
% USER INPUT
%------------------------------------------
% Define input parameters
basedir = '/mnt/synologyNAS/dataraw/20251007/MFDop';
outdir = '/mnt/synologyNAS/dataprocessed/20251007/MFDop_L1';
dateStr = '20251007';
xlsxFile = '/mnt/synologyNAS/DailyLogs/20251007/STONE2025_10072025_FIXED.xlsx';

unix(['mkdir -p ' outdir]);

% Use utility function to read experiment log from Excel file
% This replaces the manual entry of rawfn, heads, and fout arrays
fprintf('Reading experiment log from %s...\n', xlsxFile);
[rawfn, heads, fout, startTimeApprox_cdt, jackfn] = ...
    readExperimentLog(xlsxFile, basedir, outdir, dateStr);

clearvars -except rawfn heads fout startTimeApprox_cdt jackfn dooverwrite soundspeed outdir

%------------------------------------------
% PROCESS L1 FILES
%------------------------------------------
for icase = 1:length(rawfn)
  disp(['PROCESSING CASE ' num2str(icase) ' of ' num2str(length(rawfn)) ': ' strsh(fout{icase},'t')])

  dorun = 1;
  for ihead = 1:length(heads{icase})
    thisfout = [fout{icase} '_' heads{icase}{ihead} '_L1.mat'];
    if (~isempty(dir(thisfout)) && ~dooverwrite)
      dorun = 0;
    end
  end

  if (dorun == 0)
    disp(['Loading existing files for ' fout{icase}])
    for ihead = 1:length(heads{icase})
      ddop(ihead) = load([fout{icase} '_' heads{icase}{ihead} '_L1.mat']);
    end
  else
    ddop = loadMFDopSTONE(rawfn{icase}, heads{icase}, soundspeed);

    %------------------------------------------
    % JACK FILE EDGE DETECTION
    %------------------------------------------
    if length(jackfn) >= icase && ~isempty(jackfn{icase})
        jackFile = jackfn{icase}{1};  % assume first matching file
        if isfile(jackFile)
            disp(['Analyzing Jack file: ' jackFile])
            try
                data = load(jackFile);
                if isnumeric(data) && size(data,2) >= 2
                    timestamps = data(:,1);
                    values = data(:,2);
                    diffs = diff(values);

                    % Condition: rising or falling edges beyond threshold
                    mask = diffs > 2 | diffs < -2;

                    % Extract indices (second row onward due to diff)
                    edgeIdx = find(mask) + 1;

                    JackEdges.indices = edgeIdx;
                    JackEdges.timestamps = timestamps(edgeIdx);
                    JackEdges.values = values(edgeIdx);
                    JackEdges.diff = diffs(mask);

                    fprintf('  Found %d edge events.\n', numel(edgeIdx));
                else
                    warning('Jack file %s not in expected format (2+ columns).', jackFile);
                    JackEdges = struct('indices', [], 'timestamps', [], 'values', [], 'diff', []);
                end
            catch ME
                warning('Error processing Jack file %s: %s', jackFile, ME.message);
                JackEdges = struct('indices', [], 'timestamps', [], 'values', [], 'diff', []);
            end
        else
            warning('Jack file not found: %s', jackfn{icase}{1});
            JackEdges = struct('indices', [], 'timestamps', [], 'values', [], 'diff', []);
        end
    else
        disp('No jackfn entry for this trial.')
        JackEdges = struct('indices', [], 'timestamps', [], 'values', [], 'diff', []);
    end

    %------------------------------------------
    % SAVE L1 FILES INCLUDING JACK EDGES
    %------------------------------------------
    for ihead = 1:length(heads{icase})
      thisfout = [fout{icase} '_' heads{icase}{ihead} '_L1.mat'];
      thisddop = ddop(ihead);
      thisddop.JackEdges = JackEdges;  % attach edge data
      disp(['Saving: ' num2str(thisfout) '...'])
      save(thisfout, '-struct', 'thisddop')
    end
  end

  %------------------------------------------
  % QUICKLOOK PLOTS
  %------------------------------------------
  ppos = [0 0 11 8.5];
  for ihead = 1:length(heads{icase})
    thisfout = [fout{icase} '_' heads{icase}{ihead} '_L1.png'];
    if (isempty(dir(thisfout)) || dooverwrite)
      if (strcmp(heads{icase}{ihead}, 'Main'))
        quicklook_MFDopSTONE_MainHead(ddop(ihead)) % make plot
      elseif (strcmp(heads{icase}{ihead}, 'Aux1'))
        quicklook_MFDopSTONE_Aux1(ddop(ihead)) % make plot
      elseif (strcmp(heads{icase}{ihead}, 'Aux2'))
        quicklook_MFDopSTONE_Aux2(ddop(ihead)) % make plot
      end
      set(gcf, 'paperposition', ppos)
      print('-dpng', '-r300', thisfout)
      thisfout = [fout{icase} '_' heads{icase}{ihead} '_L1.fig'];
      savefig(thisfout)
    else
      disp(['SKIPPING plot (exists): ' thisfout])
    end
  end
end
