function ddop = loadMFDopSTONE(rawfn,heads,soundspeed,nnode)
%
% ddop = loadMFDopSTONE(rawfn,heads,[soundspeed,nnode])
%
% MFDop file-loading program for STONE 2025.  Loads "raw" mat-files, the
% ones named DragonData.255.25.DragonDop.NNNNN_N.mat that are obtained by
% converting the native .ntk files with the DD software.
%
% INPUTS:
%
% heads : Cell-array of strings.  Determines how the data will be
%         interpreted depending on how the head was configured.  In STONE we
%         collect data in both single-head and multi-head mode, depending on
%         the collection.  When in single-head mode we choose one of the
%         beams (Main, Aux1, or Aux2), while in multi-head mode we
%         distribute pings across multiple heads.
%
%         NOTE: If you select single head mode (for example heads='Main' or
%         heads='Aux1'), then you will only get the data from the head you
%         selected.  If for some reason you really want data from the other
%         non-active heads, you can call the function for each head one at a
%         time.  (If the above doesn't make sense to you, then ignore this
%         note -- you want the default behavior.)
%
%         ** TODO: Write up some examples of how to use the 'heads' variable.
%
% OPTIONAL-INPUT:
%
% soundspeed : Speed of sound in water, if available.  Default 1500 m/s.
%
% OUTPUT:
%
% ** ** TODO: Below output descriptions are not correct, need updating.
%
% ddop is a struct containing standard human-readable MFDop variables.  In
% the case of multi-head mode, an array of ddop structs is returned, one for
% each head.  Here are some relevant variables that are provided:
%
%   ddop.etime : Epoch timestamp for each data point.  These are from the
%   internal DragonDop instrument clock.
%
%   ddop.r : Range from xdr (meters)
%
%   ddop.beamname = software name for each beam, ordered as in the 'f' and
%     Phase|Cor|Amp variables
%
%
% WARNING: For STONE 2025, multi-head mode still has the property that the
% head that pings first is non-deterministic.  We use STONE-specific
% heuristics to determine which head sampled first.  These may fail if the
% code is reused in other/future experiments.  See comments in code about
% "first-ping detection".
%

% check user inputs
if(~exist('soundspeed'))
  soundspeed=1500;
end
if(~iscell(rawfn))
  rawfn={rawfn};
end
validHeadNames={'Main','Aux1','Aux2'};
if(~iscell(heads))
  heads={heads};
end
for j=1:length(heads)
  if(isempty(findCellStr(validHeadNames,heads{j})))
    error(['Input ''heads'' contains an invalid head name.  ' ...
           'Valid names are ''Main'', ''Aux1'', or ''Aux2''.'])
  end
end

% Set up unwrapping options (you may wish to modify these).  Note these
% options will be stored in the output struct as documentation.
opts_unwrap = struct;  % init
opts_unwrap.use_huber = true;
opts_unwrap.hybrid_mode = true;
opts_unwrap.median3x3 = false;
opts_unwrap.min_correl = 40;

% nnode is the number of DD pitaya nodes (for STONE we had 4, for
% Blasstex/ArchCape it was 3)
if(~exist('nnode'))
  nnode=4;  % default
end

% do some detective work to re-order the input files, accounting for lack of
% zero-padding in the names.  For STONE, an example filename is:
% DragonData.255.25.DragonDop.00001_25.mat
fileid=zeros(length(rawfn),1);  % init
for i=1:length(rawfn)
  this=strsh(rawfn{i},'t');
  i0=max([0 strfind(rawfn{i},filesep)])+1;
  fname=rawfn{i}(i0:end);
  fname=fname(1:end-4);  % strip trailing '.mat'
  lastdot=max(findstr(fname,'.'));
  thisid=fname(lastdot+1:end);  % example: '00001_2'
  id1=str2num(thisid(1:5));  % example: '00001_2' -> id1=1
  underscorei=findstr(thisid,'_');
  if(isempty(underscorei))
    id2=0;
    % id2=nan;  % optional override: discard any non-underscored files
  else
    id2=str2num(thisid(underscorei+1:end));
  end
  fileid(i)=id1*1000 + id2;  % unique ordered id
end
[~,isort]=sort(fileid);
igood=find(~isnan(fileid(isort)));
rawfn=rawfn(isort(igood));

% work through each raw mat-file, parsing the mat-file data into a struct
% and concatenating them into an overall dataset varibale named 'dopraw'.
% After this loading loop is complete, 'dopraw' will be an array of
% concatenated-data structs, one for each head.  Then all subsequent
% processing will be applied to each head (i.e. each element of 'dopraw')
% individually.
disp('Loading raw mat-files')
firstFileDone=0;  % init
tic
for ifile=1:length(rawfn)
  disp(['  ' num2str(ifile) ' of ' num2str(length(rawfn)) ': ' rawfn{ifile}])

  % load the mat-file
  rawmat=load(rawfn{ifile});

  % check to ensure the mat-file is non-empty before proceeding
  isgood=zeros(1,nnode);
  for idop=1:nnode
    isgood(idop)=isfield(rawmat.Data,['DragonDop' num2str(idop) '_HostTime']);
  end
  if(sum(~isgood)>0)
    this=dir(rawfn{ifile});
    warning([rawfn{ifile} ...
             ' (size = ' num2str(this.bytes/1000) 'kB) ' ...
             ' is missing DragonDop' num2str(find(~isgood),'%d,') ...
             ' skipping this file.'])
  else

    % parse the raw mat-file into human-readable variables
    doprawmat=unpackDDmat(rawmat,nnode);
    clear rawmat  % no longer needed

    for ihead=1:length(heads)

      % initialize a new 'thisdopraw' struct for storing data specific to this
      % head, and copy over some basic info common to all heads
      thisdopraw=struct;
      vname={'pingpairs','pingInterval','tau','r','f','etime'};
      for i=1:length(vname)
        thisdopraw=setfield(thisdopraw,vname{i},getfield(doprawmat,vname{i}));
      end

      % If multi-head mode was used, de-interleave the data into each head.
      % Otherwise if not multi-head, just peel off the beams for the single
      % head that was requested.  After this step, 'thisdopraw' will be an
      % array of doprawmat-style structs, one for each head.
      %
      % NOTE: The beam names are the ones we used in STONE 2025, as defined in the
      % DD software.  If using this code for other experiments, then you may need
      % to edit code in this block to match your specific beam name assignments.
      if(length(heads)>1)  % multi-head mode

        if(~isempty(findCellStr(heads,'Main')))
          error(['This code is currently only working for 2-head mode with Aux1+Aux2.  ' ...
                 'De-interleaving data when Main-head and Aux2 are both active would take a bit more effort: ' ...
                 'Reliable heuristics would need to be tested for detect the order of pings... TODO.'])
        end

        % choose the beam(s) we want based on the selected head, and only retain
        % those beams in this struct for this head
        if(strcmp(heads{ihead},'Aux1'))
          thisdopraw.beamname={'Aux_1H'}; %,'Aux_1L'};
        elseif(strcmp(heads{ihead},'Aux2'))
          thisdopraw.beamname={'Aux_2'};
        else
          error(['invalid head name ' heads{ihead} ', should never happen'])
        end
        ibeam=zeros(length(thisdopraw.beamname),1);  % init
        for i=1:length(thisdopraw.beamname)
          ibeam(i)=findCellStr(doprawmat.beamname,thisdopraw.beamname{i});
        end
        thisdopraw.Phase=doprawmat.Phase(:,:,:,ibeam);
        thisdopraw.Cor=doprawmat.Cor(:,:,:,ibeam);
        thisdopraw.Amp=doprawmat.Amp(:,:,:,ibeam);

        % Detect first ping for which this head was active.  De-interleaving
        % requires detecting the pings for which a given head is active, and
        % discarding pings for which it was not active.  For STONE, we start
        % sampling 5cm from the xdr so we see a bit of the initial ringing
        % from the transmit pulse, this can be used to reliably detect the
        % active pings.  After the first ping is detected, the remaining
        % pings are easily de-interleaved based on the known 1-2-1-2
        % switching order.  IMPORTANT, this needs to be done for each
        % mat-file, since occasionally a ping is dropped when crossing
        % between different mat-files.
        if(strcmp(heads{ihead},'Aux1'))
          ibeam=findCellStr(thisdopraw.beamname,'Aux_1H');
        elseif(strcmp(heads{ihead},'Aux2'))
          ibeam=findCellStr(thisdopraw.beamname,'Aux_2');
        else
          error('only implemented for Aux1 and Aux2')
        end
        ifreq=1;  % just use freq1 to find the active beam
        a0sum=zeros(length(heads),1);  % init, sum of 1st ping amplitudes
        for n0=1:length(heads)
          a0sum(n0) = sum(thisdopraw.Amp(1,n0:length(heads):end,ifreq,ibeam));
        end
        [~,firstpingn] = max(a0sum);  % detect position of first active ping that maximizes amp

        % discard non-active pings from this head, based on the detected first-ping
        thisdopraw.Phase=thisdopraw.Phase(:,firstpingn:length(heads):end,:,:);
        thisdopraw.Amp=thisdopraw.Amp(:,firstpingn:length(heads):end,:,:);
        thisdopraw.Cor=thisdopraw.Cor(:,firstpingn:length(heads):end,:,:);
        thisdopraw.etime=thisdopraw.etime(firstpingn:length(heads):end);

      else  % create 'thisdopraw'for single-head mode

        % determine which beam(s) to keep based on the head configuration (given as
        % user input), and only keep those beams
        if(strcmp(heads{1},'Main'))  % Main: main head with 5 beams
          beamlist = {'Beam_1','Beam_2', 'Beam_3', 'Beam_4', 'Beam_CL'};
        elseif(strcmp(heads{1},'Aux1'))  % Aux1: vertical aux beam with hi and lo-gain
          beamlist = {'Aux_1H'}; %,'Aux_1L'};
        elseif(strcmp(heads{1},'Aux2'))  % Aux2: horizontal aux beam
          beamlist = {'Aux_2'};
        end
        for j=1:length(beamlist)
          beamind(j)=findCellStr(doprawmat.beamname,beamlist{j});
        end
        vname={'Phase','Cor','Amp'};
        for j=1:length(vname)
          this=getfield(doprawmat,vname{j});
          thisdopraw=setfield(thisdopraw,vname{j},this(:,:,:,beamind));
        end
        thisdopraw.beamname=doprawmat.beamname(beamind);

      end  % if-else: creating 'thisdopraw' differently for single vs multi-head mode

      % append data to the overall dopraw struct, for file ifile and head ihead
      if(~firstFileDone)
        dopraw(ihead)=thisdopraw;
        if(ihead==length(heads))
          firstFileDone=1;
        end
      else
        dopraw(ihead)=concatDDstruct([dopraw(ihead) thisdopraw]);
      end
      clear thisdopraw  % no longer needed

    end  % loop over heads, variable 'ihead'

  end  % catch for empty-file
  clear doprawmat

end  % loop over raw mat-files, variable 'ifile'
disp(['Loaded ' num2str(length(rawfn)) ' files in ' num2str(round(toc)) ' seconds'])

% Now that dopraw is an array of heads, process each head one by one
for ihead=1:length(dopraw)  % for each head
  disp(['Postprocessing head ' heads{ihead} ' (' num2str(ihead) ' of ' num2str(length(dopraw)) ')'])

  % Apply beam velocity unwrapping using unwrap_beatAndLS
  disp('  Applying beam velocity unwrapping...')
  dopraw(ihead).Phase_raw = dopraw(ihead).Phase;  % back up original
  dopraw(ihead).Phase = unwrap_beatAndLS(dopraw(ihead).Phase, ...
                                         dopraw(ihead).f(:)', ...
                                         dopraw(ihead).tau, ...
                                         soundspeed, ...
                                         dopraw(ihead).Cor, ...
                                         [], opts_unwrap);

  % convert the data to uvw.  This uses beam2uvw if we are working with the
  % mean head (5 xdrs), or beam2u if using a single head.
  disp('  Converting beam vels to u,v,w...')
  [nz,nt,nf,nb]=size(dopraw(ihead).Phase);
  nave=1;  % nave=1 means no time-averaging (default)
  if(strcmp(heads{ihead},'Main'))  % Main is 5-beam head (u,v,w)
    [uvw,beamvel]=beam2uvwMFDOP_lsq(dopraw(ihead),nave);
  else  % aux beams
    [uvw,beamvel]=beam2uMFDOP_lsq(dopraw(ihead),nave);
    if(strcmp(heads{ihead},'Aux1'))  % Aux1 is vertical beam (w)
      uvw.w = uvw.U;
      uvw=rmfield(uvw,'U');
      uvw.wstd=uvw.Ustd;
      uvw=rmfield(uvw,'Ustd');
    elseif(strcmp(heads{ihead},'Aux2'))  % Aux2 is horizontal beam (-v)
      uvw.v = -uvw.U;
      uvw=rmfield(uvw,'U');
      uvw.vstd=uvw.Ustd;
      uvw=rmfield(uvw,'Ustd');
    else
      error(['Found invalid heads=' heads{ihead} ', should never happen'])
    end
  end

  % pack the results into a single struct for output.  These structs will
  % normally be saved as individual files.
  out=struct;
  out.dopraw=dopraw(ihead);
  out.uvw=uvw;
  out.beamvel=beamvel;
  out.rawfn=rawfn;
  out.headID=heads{ihead};
  out.soundspeed=soundspeed;
  out.opts_unwrap=opts_unwrap;
  out.comment = ['Created by loadMFDopSTONE.m, ' datestr(now)];
  ddop(ihead)=out;

end  % loop over each head
