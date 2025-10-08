function quicklook_MFDopSTONE_MainHead(ddop)
%
% quicklook_MFDopSTONE_MainHead(ddop)
%
% Generates a quick plot of MFDop main-head data from STONE 2025, for
% checking data quality
%
% INPUT:
%
% ddop = single-element MFDop data struct in format produced by
% loadMFDopSTONE.m
%

Cthresh=40;
ustdThresh=.2;

% plotting params
uscale=[-1 1]*2;
vscale=[-1 1]*.5;
wscale=[-1 1]*.05;
intensityScaleLog=[-5 -3];  % used for log10((r*amp)^2)
corscale=[60 100];
rbed=.07;  % distance from xdr to floor
zlim=[-.05 .8];  % vertical axis limits
dtskip=1;  % decimate in time for plotting

% % TEMPORARY: At time of writing, a bug in beam2uvw causes us to drop one
% % point.  Pad to fill.
% warning('padding uvw to account for bug in beam2uvw')
% vname={'u','v','w','ustd','vstd','wstd'};
% for i=1:length(vname)
%   this=getfield(ddop.uvw,vname{i});
%   this(:,end+1)=this(:,end);
%   ddop.uvw=setfield(ddop.uvw,vname{i},this);
% end
% ddop.uvw.etime(end+1)=ddop.uvw.etime(end);

% check inputs
if(length(ddop)>1)
  error('This code only accepts a single struct of data from the main head.  You tried to pass in an array of structs.')
end
if(~strcmp(ddop.headID,'Main'))
  error(['This code requires data from the main head.  You passed in a struct ' ...
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
ubad = ddop.uvw.ustd>ustdThresh;
vbad = ddop.uvw.wstd>ustdThresh;
wbad = ddop.uvw.wstd>ustdThresh;
ddop.uvw.u(ubad | uvwbad)=nan;
ddop.uvw.v(vbad | uvwbad)=nan;
ddop.uvw.w(wbad | uvwbad)=nan;

% define some handy variables
tsec=ddop.uvw.etime-ddop.uvw.etime(1);
z=ddop.uvw.r-rbed;
indz=find(zlim(1)<=z&z<=zlim(2));
indt=1:dtskip:length(tsec);
ibeamCL=findCellStr(ddop.dopraw.beamname,'Beam_CL');
ifreq=1;  % just show freq1 data as representative
scaledIntensity = ( ddop.dopraw.r.*ddop.dopraw.Amp(:,:,ifreq,ibeamCL) ).^2;

% detect free surface and blank out all data above that level.  In reality
% this is probably the lowermost surface of the bubble plume, not the actual
% free surface.
[nz,nt]=size(scaledIntensity);
sthresh=.05;
for n=1:nt
  thisThresh=sthresh;
  thisk=[];  % init
  while(isempty(thisk) & thisThresh>.001)
    thisk=min(find(scaledIntensity(:,n)>thisThresh));
    thisThresh=thisThresh*.8;  % if we didn't find it, relax the tolerance
  end
  if(isempty(thisk))
    if(n==1)
      ksurf(n)=1;  % didn't find it
    else
      ksurf(n)=ksurf(n-1);
    end
  else
    ksurf(n)=thisk;
  end
end
% ksurf=round(medfilt1(ksurf,50));
mask=ones(size(scaledIntensity));
for n=1:length(ksurf)
  mask(ksurf(n)+1:end,n)=nan;
end

% make some plots
clf
splotlist(1)=subplot(511);  % u
pcolor(tsec(indt),z(indz),ddop.uvw.u(indz,indt).*mask(indz,indt)),sf
caxis(uscale)
title('u [m/s]')
splotlist(2)=subplot(512);  % v
pcolor(tsec(indt),z(indz),ddop.uvw.v(indz,indt).*mask(indz,indt)),sf
caxis(vscale)
title('v [m/s]')
splotlist(3)=subplot(513);  % w
pcolor(tsec(indt),z(indz),ddop.uvw.w(indz,indt).*mask(indz,indt)),sf
caxis(wscale)
title('w [m/s]')
splotlist(4)=subplot(514);  % scaled intensity
pcolor(tsec(indt),z(indz),log10(scaledIntensity(indz,indt)).*mask(indz,indt)),sf
caxis(intensityScaleLog)
title('Psuedo-Conc. (Log-Scale) [-]')
splotlist(5)=subplot(515);  % correl
pcolor(tsec(indt),z(indz),ddop.dopraw.Cor(indz,indt,ifreq,ibeamCL).*mask(indz,indt)),sf
caxis(corscale)
title('Correlation [-]')
for i=1:5
  subplot(5,1,i)
  ylim(zlim)
  ylabel('+z [m]')
  colorbar
end
linkaxes(splotlist, 'xy');
