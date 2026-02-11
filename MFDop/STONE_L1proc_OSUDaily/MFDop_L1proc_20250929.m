% L1 Processing Script:
%
% INPUT: DD.mat files created by DD software ntk->mat file conversion tool
%
%    - Edit the parameters at the top of this script to point to the desired
%    files for each collection, and specify the case ID and head
%    configuration for each file.  Use the log book to gather this info and
%    enter it into this script.
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
clear
addpath(genpath('util'))

dooverwrite=0;
soundspeed=1500;

% nnode: This determines how many nodes we collected data with.  Use 4
% nodes prior to 9/29, then we switched to single-node collections so
% after 9/29 we should set nnode=1 for data when we just collected
% Aux1+Aux2.  Later when we collect the main head we may require two
% nodes, so nnode=2.
nnode=1;  % when collecting ONLY Aux1+Aux2 (post-9/29)

%------------------------------------------
% USER-INPUT: Files and configurations used for this data collection
%------------------------------------------

% Define input parameters
basedir = '/media/wilsongr/LaCie/STONE/STONE_20250929/MFDop';
outdir = '~/STONE/dataprocessed_MFDop_20250929';
dateStr = '20250929';
xlsxFile = '/media/wilsongr/LaCie/STONE/STONE_20250929/STONE2025 09292025.xlsx';

unix(['mkdir -p ' outdir]);

% Use utility function to read experiment log from Excel file
% This replaces the manual entry of rawfn, heads, and fout arrays
fprintf('Reading experiment log from %s...\n', xlsxFile);
[rawfn, heads, fout, startTimeApprox_cdt] = readExperimentLog(xlsxFile, basedir, outdir, dateStr);

% % Filter out Main head trials for now (pending finalization of beam2uvw)
% % ** TODO: Remove this filter when Main head processing is ready
% mainHeadIndices = cellfun(@(x) any(strcmp(x, 'Main')), heads);
% if any(mainHeadIndices)
%     fprintf('Filtering out %d Main head trials (pending beam2uvw finalization)\n', sum(mainHeadIndices));
%     rawfn(mainHeadIndices) = [];
%     heads(mainHeadIndices) = [];
%     fout(mainHeadIndices) = [];
% end

%------------------------------------------
%------------------------------------------
%------------------------------------------
% - - - - - - END OF USER INPUT - - - - - -
%
% From here on, the code will work through the collections and write the L1
% output files, with output filenames based on 'fout'.
%------------------------------------------
%------------------------------------------
%------------------------------------------
clearvars -except rawfn heads xloc fout startTimeApprox_cdt dooverwrite soundspeed nnode

for icase = 1:length(rawfn)
  disp(['PROCESSING CASE ' num2str(icase) ' of ' num2str(length(rawfn)) ': ' strsh(fout{icase},'t')])

  % create mat-files, if needed
  dorun=1;
  for ihead=1:length(heads{icase})
    thisfout=[fout{icase} '_' heads{icase}{ihead} '_L1.mat'];
    if(~isempty(dir(thisfout)) & ~dooverwrite)
      dorun=0;
    end
  end
  if(dorun==0)
    disp(['Loading existing files for ' fout{icase}])
    for ihead=1:length(heads{icase})
      ddop(ihead)=load([fout{icase} '_' heads{icase}{ihead} '_L1.mat']);
    end
  else  % create new files
    ddop = loadMFDopSTONE(rawfn{icase},heads{icase},soundspeed,nnode);
    for ihead=1:length(heads{icase})
      thisfout=[fout{icase} '_' heads{icase}{ihead} '_L1.mat'];
      thisddop=ddop(ihead);
      disp(['Saving: ' num2str(thisfout) '...'])
      save(thisfout,'-struct','thisddop')
    end
  end

  % create quicklook plots
  ppos=[0 0 11 8.5];
  for ihead=1:length(heads{icase})
    thisfout=[fout{icase} '_' heads{icase}{ihead} '_L1.png'];
    if(isempty(dir(thisfout)) | dooverwrite)
      if(strcmp(heads{icase}{ihead},'Main'))
        quicklook_MFDopSTONE_MainHead(ddop(ihead))  % make plot
      elseif(strcmp(heads{icase}{ihead},'Aux1'))
        quicklook_MFDopSTONE_Aux1(ddop(ihead))  % make plot
      elseif(strcmp(heads{icase}{ihead},'Aux2'))
        quicklook_MFDopSTONE_Aux2(ddop(ihead))  % make plot
      end
      set(gcf,'paperposition',ppos)
      print('-dpng','-r300',thisfout)
      thisfout=[fout{icase} '_' heads{icase}{ihead} '_L1.fig'];
      savefig(thisfout)
    else
      disp(['SKIPPING plot (exists): ' thisfout])
    end
  end

end
