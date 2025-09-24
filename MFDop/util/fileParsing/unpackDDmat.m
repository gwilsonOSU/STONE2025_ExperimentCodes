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
% instead of 4 (e.g., Blasstex, or Arch Cape).
%

if(~exist('nnode'))
  nnode=4;
end

%------------------------------------
% config info
%------------------------------------

% constants shared across all units
ddop.pingpairs    = double(ddopraw.Config.Unit1_pingPairsPerEnsemble);
ddop.pingInterval = double(ddopraw.Config.Unit1_pingInterval);
ddop.tau          = double(ddopraw.Config.Unit1_pulseLength);
ddop.r            = double(ddopraw.Data.DragonDop1_Range)';

% get list of enabled frequencies
unit=1;
for pulse=1:4
  thisunitpulse=['Unit' num2str(unit) '_pulses_' num2str(pulse)];
  enabled(pulse) = getfield(ddopraw.Config,[thisunitpulse '_enabled']);
  f(pulse)       = getfield(ddopraw.Config,[thisunitpulse '_frequency']);
end
ddop.f     =f(enabled==1);

% get list of beam names
for unit=1:nnode
  for input=1:2
    thisunitinputs = ['Unit' num2str(unit) '_inputs_' num2str(input)];
    beamname{unit,input}  = strrep(getfield(ddopraw.Config,[thisunitinputs '_name']),' ','_');
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
    for ib=1:nb  % for each beam on this pitaya
      beamname=ddop.beamname{ib,ip};
      for ifs=1:length(fstr)  % for each freq
        thisvar=getfield(ddopraw.Data,[ddname '_' vname{iv} '_' beamname '_' fstr{ifs}]);
        thisdata(:,:,ifs,ib,ip)=double(thisvar(1:nt,:))';
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
