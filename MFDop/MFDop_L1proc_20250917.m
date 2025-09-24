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

basedir='dataraw/20250917/MFDop';
outdir='dataraw/20250917/MFDop_L1';

% below copied directly from log spreadsheet

% ** TODO: Main-head cases are commented out for now, pending finalization of beam2uvw

% % fout{end+1} = [outdir '/DD_20250917_case1p3Trial01'];
% fout{end+1} = [outdir '/DD_20250917_case1p3Trial02'];
% fout{end+1} = [outdir '/DD_20250917_case1p3Trial03'];
fout{end+1} = [outdir '/DD_20250917_case1p3Trial04'];
fout{end+1} = [outdir '/DD_20250917_case1p3Trial05'];
fout{end+1} = [outdir '/DD_20250917_case1p3Trial06'];
fout{end+1} = [outdir '/DD_20250917_case1p3Trial07'];
% fout{end+1} = [outdir '/DD_20250917_case1p3Trial08'];
% fout{end+1} = [outdir '/DD_20250917_case1p3Trial09'];
% % fout{end+1} = [outdir '/DD_20250917_case1p3Trial10'];

% % rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00000*.mat']);
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00001*.mat']);
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00002*.mat']);
rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00003*.mat']);
rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00004*.mat']);
rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00005*.mat']);
rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00006*.mat']);
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00007*.mat']);
% rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00008*.mat']);
% % rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00009*.mat']);

% % heads{end+1}={'Main'};
% heads{end+1}={'Aux1'};
% heads{end+1}={'Aux2'};
heads{end+1}={'Aux1', 'Aux2'};
heads{end+1}={'Aux1', 'Aux2'};
heads{end+1}={'Aux1', 'Aux2'};
heads{end+1}={'Aux1', 'Aux2'};
% heads{end+1}={'Aux2'};
% heads{end+1}={'Aux1'};
% % heads{end+1}={'Main'};

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
clearvars -except rawfn heads xloc fout dooverwrite

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
