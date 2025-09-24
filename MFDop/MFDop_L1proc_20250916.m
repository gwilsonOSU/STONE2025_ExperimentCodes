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

%------------------------------------------
% USER-INPUT: Files and configurations used for this data collection
%------------------------------------------

% NOTE: The use of 'basedir' and 'outdir' are optional, they are often
% convenient for entering your rawfn input files.  These variables are only
% used within the user-input block for organizing your files, they do not
% influence the processing itself.

% initialize list of collections (do not edit this block)
rawfn={};
heads={};
fout={};

% Collections: Edit the remainder of this section based on the log book to
% select the batches of files to be processed.  For each collection, append
% an entry for the following:
%
% rawfn: Cell-array of DD.mat filenames for this collection, including the
% directory path.  The list does not need to be time-ordered, they will be
% sorted automatically.
%
% heads: Cell-array stating the active heads for this collection.  Options
% are 'Main', 'Aux1' and 'Aux2'.  For example if only Aux1 was used, append
% with heads(end+1)={'Aux1'}.  If Main head and Aux2 was used,
% heads(end+1)={'Main','Aux2'}.  Order must match the order of heads
% indicated in the log book.
%
% fout: Output file to be created for this collection, including directory
% path.  This should be of the form
%
%     fout{end+1} = '/path/to/outdir/DD_<yyyymmdd>_case<XpX>trial<0X>'
%
%     Where text in <> is case-dependent.  Note, additional text will be
%     appended to fout when writing the final output files.  The final
%     output filenames are of the form:
%
%     '/path/to/outdir/DD_<yyyymmdd>_case<XpX>trial<0X>_<HeadName>_L1.mat'
%

% %-------------------------
% % Morning runs: Still water, testing different modes including the switcher
% %-------------------------
% 
% % basedir: Directory where raw DD files can be found
% basedir='exampledata/20250916/MFDop/switcher_test';
% 
% % outdir: Directory where L1 processed files will be saved
% outdir='exampledata/20250916/MFDop_L1/switcher_test';
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00000*.mat']);
% heads{end+1} = {'Aux1'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial01'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00001*.mat']);
% heads{end+1} = {'Aux2'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial02'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00002*.mat']);
% heads{end+1} = {'Main'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial03'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00003*.mat']);
% heads{end+1} = {'Aux1','Aux2'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial04'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00004*.mat']);
% heads{end+1} = {'Aux1','Main'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial05'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00005*.mat']);
% heads{end+1} = {'Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial06'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00006*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial07'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00007*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial08'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00008*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial09'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00009*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial10'];
% 
% % % IGNORE: switcher obviously not working
% % rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00010*.mat']);
% % heads{end+1} = {'Aux1','Aux2','Main'};
% % fout{end+1} = [outdir '/DD_20250916_stillwaterTrial11'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00011*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250916_stillwaterTrial12'];

%-------------------------
% Afternoon runs: Case 1.3, mapping the eddies
%-------------------------

% basedir: Directory where raw DD files can be found
basedir='exampledata/20250916/MFDop';

% outdir: Directory where L1 processed files will be saved
outdir='exampledata/20250916/MFDop_L1';

% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00013*.mat']);
% heads{end+1} = {'Aux1','Aux2'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial01'];

% % TODO: Main head ignored for now, beam2uvw needs beam assignments to be fixed
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00014*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial02'];

% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00015*.mat']);
% heads{end+1} = {'Aux1'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial03'];

% % TODO: Main head ignored for now, beam2uvw needs beam assignments to be fixed
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00016*.mat']);
% heads{end+1} = {'Main'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial04'];

% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00017*.mat']);
% heads{end+1} = {'Aux2'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial05'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00018*.mat']);
% heads{end+1} = {'Aux2'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial06'];

rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00000*.mat']);
heads{end+1} = {'Aux2'};
fout{end+1} = [outdir '/DD_20250916_case3p1Trial07'];

rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00001*.mat']);
heads{end+1} = {'Aux1'};
fout{end+1} = [outdir '/DD_20250916_case3p1Trial08'];

% % TODO: Main head ignored for now, beam2uvw needs beam assignments to be fixed
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00002*.mat']);
% heads{end+1} = {'Main'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial09'];

% % TODO: Main head ignored for now, beam2uvw needs beam assignments to be fixed
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00003*.mat']);
% heads{end+1} = {'Main'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial10'];

% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00004*.mat']);
% heads{end+1} = {'Aux1'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial11'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00005*.mat']);
% heads{end+1} = {'Aux2'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial12'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00006*.mat']);
% heads{end+1} = {'Aux2'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial13'];

% % TODO: Main head ignored for now, beam2uvw needs beam assignments to be fixed
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00007*.mat']);
% heads{end+1} = {'Main'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial14'];

% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00008*.mat']);
% heads{end+1} = {'Aux1'};
% fout{end+1} = [outdir '/DD_20250916_case3p1Trial15'];

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
clearvars -except rawfn heads fout dooverwrite

for icase = 1:length(rawfn)

  if(length(heads{icase})>1)
    warning('Skipping multi-head mode for first pass')
  else
  
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
    ddop = loadMFDopSTONE(rawfn{icase},heads{icase});
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

end  % temporary skipping multi-head files
end
