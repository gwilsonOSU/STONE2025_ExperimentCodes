function ddop=unpackDDmat(ddopraw,nnode)
%
% ddop=unpackDDmat(ddopraw,[nnode])
%
% helper function to unpack data from DragonDop mat-file into a struct that
% is managable for analysis... not nearly as robust as the file-parsing code
% JH wrote for Arch Cape, but is a bit less unwieldy to work with.
%
% can use concatDDstruct.m to concatenate these structs together, for
% loading lots of mat-files.
%
% OPTIONAL: set nnode to the number of red pitaya nodes used in the system.
% This is for back-compatiblity with older data where we used 3 nodes
% instead of 4 (e.g., Blasstex, or Arch Cape). The function automatically
% handles different field naming conventions based on active beam configuration.
%

if(~exist('nnode'))
  nnode=4;
end

node_list = 1:nnode;

%------------------------------------
% config info
%------------------------------------

% constants shared across all units
if(nnode>1)
  fld_pingPairsPerEnsemble='Unit1_pingPairsPerEnsemble';
  fld_pingInterval='Unit1_pingInterval';
  fld_pulseLength='Unit1_pulseLength';
else
  fld_pingPairsPerEnsemble='pingPairsPerEnsemble';
  fld_pingInterval='pingInterval';
  fld_pulseLength='pulseLength';
end


ddop.pingpairs    = double(getfield(ddopraw.Config,fld_pingPairsPerEnsemble));
ddop.pingInterval = double(getfield(ddopraw.Config,fld_pingInterval));
ddop.tau          = double(getfield(ddopraw.Config,fld_pulseLength));
ddop.r            = double(ddopraw.Data.DragonDop1_Range)';

% get list of enabled frequencies
for pulse=1:4
  if(nnode>1)
    unit=1;
    thisunitpulse=['Unit' num2str(unit) '_pulses_' num2str(pulse) '_'];
  else
    thisunitpulse=['pulses_' num2str(pulse) '_'];
  end
  enabled(pulse) = getfield(ddopraw.Config,[thisunitpulse 'enabled']);
  f(pulse)       = getfield(ddopraw.Config,[thisunitpulse 'frequency']);
end
ddop.f     =f(enabled==1);

% get list of beam names
for unit=1:nnode
  for input=1:2
    if(nnode>1)
      thisunitinputs = ['Unit' num2str(unit) '_inputs_' num2str(input) '_'];
    else
      thisunitinputs = ['inputs_' num2str(input) '_'];
    end
    beamname{unit,input}  = strrep(getfield(ddopraw.Config,[thisunitinputs 'name']),' ','_');
  end
end
ddop.beamname=beamname';

% time
nts=nan(nnode,1);
for n=1:nnode
  vname=['DragonDop' num2str(n) '_TimeStamp'];
  nts(n)=length(getfield(ddopraw.Data,vname));
end
nt=min(nts);
ddop.etime=ddopraw.Data.DragonDop1_TimeStamp(1:nt);

clearvars -except ddopraw ddop

%------------------------------------
% matrix info
%------------------------------------

for j=1:length(ddop.f)
  fstr{j}=[num2str(round(ddop.f(j)/1000)) 'kHz'];
end
vname={'Phase','Cor','Amp'};
nt=length(ddop.etime);
nr=length(ddop.r);
nf=length(ddop.f);
[nb,np]=size(ddop.beamname);  % #beam/pitaya, #pitayas
for iv=1:length(vname)
  thisdata=zeros(nr,nt,nf,nb,np);  % init
  for ip=1:np  % for each pitaya
    ddname=['DragonDop' num2str(ip)];

    % Check how many beams are active on this node
    active_beams_on_node = 0;
    for ib_check=1:nb
      if isfield(ddopraw.Config, ['Unit' num2str(ip) '_inputs_' num2str(ib_check) '_active'])
        if getfield(ddopraw.Config, ['Unit' num2str(ip) '_inputs_' num2str(ib_check) '_active']) == 1
          active_beams_on_node = active_beams_on_node + 1;
        end
      end
    end

    for ib=1:nb  % for each beam on this pitaya
      beamname_full=ddop.beamname{ib,ip};
      for ifs=1:length(fstr)  % for each freq
        % Use different naming convention based on number of active beams
        if active_beams_on_node == 1
          % Single beam active: omit beam name from field
          fieldname = [ddname '_' vname{iv} '_' fstr{ifs}];
        else
          % Multiple beams active: include beam name
          fieldname = [ddname '_' vname{iv} '_' beamname_full '_' fstr{ifs}];
        end

        if isfield(ddopraw.Data, fieldname)
          thisvar=getfield(ddopraw.Data,fieldname);
          thisdata(:,:,ifs,ib,ip)=double(thisvar(1:nt,:))';
        else
          % Fill with zeros if field doesn't exist
          thisdata(:,:,ifs,ib,ip)=zeros(nr,nt);
        end
      end
    end
  end
  ddop=setfield(ddop,vname{iv},thisdata);
end

% reorder beams
ddop.beamname=reshape(ddop.beamname,[nb*np 1]);
ddop.Phase=reshape(ddop.Phase,[nr nt nf nb*np]);
ddop.Cor  =reshape(ddop.Cor  ,[nr nt nf nb*np]);
ddop.Amp  =reshape(ddop.Amp  ,[nr nt nf nb*np]);
