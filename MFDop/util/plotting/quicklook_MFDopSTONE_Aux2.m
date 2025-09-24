function quicklook_MFDopSTONE_Aux2(ddop)
%
% quicklook_MFDopSTONE_Aux2(ddop)
%
% Generates a quick plot of MFDop Aux2 (horizontal beam) data from STONE 2025,
% for checking data quality
%
% INPUT:
%
% ddop = single-element MFDop data struct in format produced by
% loadMFDopSTONE.m
%

Cthresh=40;
ustdThresh=.2;

% plotting params
vscale=[-1 1]*.05;
intensityScaleLog=[-7 -4];  % used for log10((r*amp)^2)
corscale=[60 100];
rlim=[0 1];  % range axis limits
dtskip=1;  % decimate in time for plotting

% TEMPORARY: At time of writing, a bug in beam2uvw causes us to drop one
% point.  Pad to fill.
if(length(ddop.uvw.etime) == length(ddop.dopraw.etime)-1)
  warning('padding uvw to account for bug in beam2uvw')
  vname={'v','vstd'};
  for i=1:length(vname)
    this=getfield(ddop.uvw,vname{i});
    this(:,end+1)=this(:,end);
    ddop.uvw=setfield(ddop.uvw,vname{i},this);
  end
  ddop.uvw.etime(end+1)=ddop.uvw.etime(end);
end

% check inputs
if(length(ddop)>1)
  error('This code only accepts a single struct of data from the Aux2 head.  You tried to pass in an array of structs.')
end
if(~strcmp(ddop.headID,'Aux2'))
  error(['This code requires data from the Aux2 head.  You passed in a struct ' ...
         'containing data with headID = ' ddop.headID]);
end
if(length(ddop.dopraw.etime)~=length(ddop.uvw.etime))
  error('This code doesn''t yet support data that used nave>1.  You will need to edit the code to handle this case.')
end

% high-grade all data based on correlation from center beam.  TODO, for now
% we assume the data were processed with nave=1 (as an argument to
% beam2uvw), so that the raw beam velocities have the same number of
% timesteps as the uvw velocities.
ddop.beamvel.vb(ddop.dopraw.Cor<Cthresh)=nan;
uvwbad = (max(max(ddop.dopraw.Cor,[],4),[],3)<Cthresh);
vbad = ddop.uvw.vstd>ustdThresh;
ddop.uvw.v(vbad | uvwbad)=nan;

% set r-range based on collected data
rlim=rlim+ddop.uvw.r(1);

% define some handy variables
tsec=ddop.uvw.etime-ddop.uvw.etime(1);
indr=find(rlim(1)<=ddop.uvw.r&ddop.uvw.r<=rlim(2));
indt=1:dtskip:length(tsec);
ibeam=findCellStr(ddop.dopraw.beamname,'Aux_2');
ifreq=1;  % just show freq1 data as representative
scaledIntensity = ( ddop.dopraw.r.*ddop.dopraw.Amp(:,:,ifreq,ibeam) ).^2;

% make some plots
clf
splotlist(1)=subplot(311);  % v
pcolor(tsec(indt),ddop.uvw.r(indr),ddop.uvw.v(indr,indt)),sf
caxis(vscale)
title('v [m/s]')
splotlist(2)=subplot(312);  % scaled intensity
pcolor(tsec(indt),ddop.uvw.r(indr),log10(scaledIntensity(indr,indt))),sf
caxis(intensityScaleLog)
title('Psuedo-Conc. (Log-Scale) [-]')
splotlist(3)=subplot(313);  % correl
pcolor(tsec(indt),ddop.uvw.r(indr),ddop.dopraw.Cor(indr,indt,ifreq,ibeam)),sf
caxis(corscale)
title('Correlation [-]')
for i=1:3
  subplot(3,1,i)
  ylim(rlim)
  ylabel('y [m]')
  colorbar
  % set(gca,'ydir','rev')
end
linkaxes(splotlist, 'xy');
