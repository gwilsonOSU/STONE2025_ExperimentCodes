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

% basedir: Directory where raw DD files can be found
basedir='../exampledata/MFDop';

% outdir: Directory where L1 processed files will be saved
outdir='../exampledata/MFDop/MFDop_L1'

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

rawfn{end+1} = fileList_ls([basedir '/DragonData.*.0000[01234]*.mat']);
heads{end+1} = {'Aux2'};
fout{end+1} = [outdir '/DD_20250912_case1p3trial01'];

% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.0000[56]*.mat']);
% heads{end+1} = {'Aux2'};
% fout{end+1} = [outdir '/DD_20250912_case1p3trial02'];

rawfn{end+1} = fileList_ls([basedir '/DragonData.*.0000[789]*.mat']);
heads{end+1} = {'Aux1'};
fout{end+1} = [outdir '/DD_20250912_case1p3trial03'];

rawfn{end+1} = fileList_ls([basedir '/DragonData.*.0001[012]*.mat']);
heads{end+1} = {'Main'};
fout{end+1} = [outdir '/DD_20250912_case1p3trial04'];

% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00016*.mat']);
% heads{end+1} = {'Aux1'};
% fout{end+1} = [outdir '/DD_20250912_case6p1trial01'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00017*.mat']);
% heads{end+1} = {'Aux2'};
% fout{end+1} = [outdir '/DD_20250912_case3p3trial01'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00018*.mat']);
% heads{end+1} = {'Main'};
% fout{end+1} = [outdir '/DD_20250912_case5p1trial01'];

% NOTE: 3-head mode not working yet.  For now, skip over the 3-head
% collections.
%
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00015*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250912_case2p5trial01'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00013*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250912_case2p3trial01'];
% 
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00014*.mat']);
% heads{end+1} = {'Aux1','Aux2','Main'};
% fout{end+1} = [outdir '/DD_20250912_case3p2trial01'];


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

end
