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

%------------------------------------------
% USER-INPUT: Files and configurations used for this data collection
%------------------------------------------

% Define input parameters
basedir = '/media/wilsongr/LaCie/STONE/dataraw/20251003/MFDop';
outdir = '/media/wilsongr/LaCie/STONE/dataprocessed/20251003/MFDop_L1';
dateStr = '20251003';
xlsxFile = '/media/wilsongr/LaCie/STONE/dataraw/20251003/STONE2025_10032025.xlsx';

unix(['mkdir -p ' outdir]);

% Use utility function to read experiment log from Excel file
% This replaces the manual entry of rawfn, heads, and fout arrays
fprintf('Reading experiment log from %s...\n', xlsxFile);
[rawfn, heads, fout, startTimeApprox_cdt] = readExperimentLog(xlsxFile, basedir, outdir, dateStr);

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
clearvars -except rawfn heads xloc fout startTimeApprox_cdt dooverwrite soundspeed

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
    ddop = loadMFDopSTONE(rawfn{icase},heads{icase},soundspeed);
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
      thisfout=[fout{icase} '_' heads{icase}{ihead} '_L1.fig'];
      savefig(thisfout)
      xlim([0 30])  % for png, zoom in to time period of interest
      thisfout=[fout{icase} '_' heads{icase}{ihead} '_L1.png'];
      print('-dpng','-r300',thisfout)
    else
      disp(['SKIPPING plot (exists): ' thisfout])
    end
  end

end
