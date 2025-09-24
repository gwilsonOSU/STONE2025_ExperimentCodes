function [uvwstruct,beamvelstruct]=beam2uMFDOP_lsq(data,nave)
%
% [uvwstruct,beamvelstruct] = beam2uMFDOP(data,nave)
%
% Computes a single-beam multi-freq beam velocity into an overall estimated
% velocity, using weighted averaging.  This is the equivalent of
% beam2uvwMFDop_lsq.m, but for the much simpler case of a single beam where
% there is geometry to worry about.  Instead all we are doing is a weighted
% average over frequencies.
%
% INPUTS:
%
% data = struct in format used for STONE2025, containing the following:
%   data.etime(timestep,1) = epoch time stamps.  This isn't really used though.
%   data.r(rangebin,1) = range bins (m)
%   data.f(freq,1)     = frequencies (MHz)
%   data.pingInterval  = ping interval (s)
%   data.beamname      = cell-array of xdr names, e.g. "Beam_CH" or "Beam1"
%   data.Phase(rangebin,timestep,freq,beam) = per-beam phases (rads), +'ve towards MFDop
%   data.Cor(rangebin,timestep,freq,beam)   = per-beam correls, used for weighting
%
% nave = number of bins to average in time, must be an odd number.
% Recommend to use nave=1 for STONE 2025, but if velocities are too noisy we
% could consider increasing nave to 3 or 5 to add some filtering.
%
%
% OUTPUT:
%
% The script produces two structs 'uvwstruct' and 'beamvelstruct', which we
% normally append to our main data struct before saving it to disk.  They
% contains the following variables:
%
%   uvwstruct.U = velocity, +'ve towards xdr (m/s)
%
%   uvwstruct.Ustd = Estimated error values for U (m/s), used as an metric
%   for data quality.
%
%   beamvels = low-level struct for the individual beams and their
%   individual freqs.  These are not normally needed for analysis, but are
%   sometimes useful.
%
%   beamvelstruct.beamname = names of each beam.  These are designed to
%   match the input data.beamname
%
%   beamvelstruct.vb = beam velocities (m/s) for each beam
%
%   beamvelstruct.ambv = beam ambiguity velocities (m/s) used for
%   calculations
%

% check optional inputs
if(nargin==1)  % nave not provided
  nave=1;  % default
end
if(mod(nave,2)==0)
  error(['Input ''nave'' must be an odd number'])
end

%-------------------------------------------------
% Ambiguity velocities
%-------------------------------------------------

[nz,nt,nf,nb]=size(data.Phase);

% sound speed (m/s)
cw=1500;

% amb vel for a single beam, with size [nbins,nfreq]
ambv=zeros(nf,1);  % init
for j = 1:nf
  omega = 2*pi*data.f(j);
  lambda = cw/data.f(j);
  k = 2*pi/lambda;
  ambv(j) = cw./(4*data.f(j)*data.pingInterval);
end

% convert phases to velocities, array of size [nbins,ntime,nfreq,nbeams],
% with velocity positive towards the xdr (convention used by this script).
for j=1:nf
  vb(:,:,j,:) = pi\data.Phase(:,:,j,:)*ambv(j);
  r2(:,:,j,:) = data.Cor(:,:,j,:)/100;
end

%-------------------------------------------------
% perform weighted average to get overall beam velocity and its error stdev
%-------------------------------------------------

% reshape data to match treatment of different frequencies as independent
% data points
[nz,nt,nf,nb]=size(vb);
vb  =permute(reshape(vb  ,[nz nt nf*nb]),[3 1 2]);
r2  =permute(reshape(r2  ,[nz nt nf*nb]),[3 1 2]);

% estimate beam velocity stdev
phsstd=sqrt(-2*log(r2));
vbstd=nan*phsstd;  % init
for j=1:nf
  vbstd(j,:,:)=phsstd(j,:,:)*ambv(j)/pi;
end
clear phsstd

% calculate weighted-averaged velocity for each output point
n2start = (nave-1)/2+1;
n2end = nt-n2start+1;
nbincenters=n2start:nave:n2end;
nbins=length(nbincenters);
uvw=nan(nz,nbins);  % init
uvwstd=nan(nz,nbins);  % init
parfor bini=1:nbins
  if(floor(bini/nbins*10)>floor((bini-1)/nbins*10))
    disp(['checkpoint ' num2str(floor(bini/nbins*10)) ' of 10'])
  end
  indt=nbincenters(bini)+[-((nave-1)/2):((nave-1)/2)];  % time bins
  for n1=1:nz
    vbdata=vb(:,n1,indt);
    wgt=1./vbstd(:,n1,indt).^2;
    ind=find(~isnan(vbdata.*wgt));
    if(isempty(ind))  % no valid points
      uvw(n1,bini)=nan;
      uvwstd(n1,bini)=nan;
    else
      vbdata=vbdata(ind);
      wgt=wgt(ind);
      uvw(n1,bini) = sum(wgt.*vbdata)./sum(wgt);
      uvwstd(n1,bini) = sqrt(1./sum(wgt));
    end
  end
end

%-------------------------------------------------
% outputs
%-------------------------------------------------

%   uvwstruct.U = velocity, +'ve towards xdr (m/s)
uvwstruct.U=uvw;

%   uvwstruct.Ustd = Estimated error values for U (m/s), used as an metric
%   for data quality.
uvwstruct.Ustd=uvwstd;

% uvwstruct time and range
uvwstruct.etime=data.etime(nbincenters);
uvwstruct.r=data.r;

% Note: We revert to original beam ordering for output in beamvelstruct, so
% it matches what the user expects.  Here are the beamvel outputs:
%
%   beamvelstruct.beamname = names of each beam.  These are designed to
%   match the input data.beamname
%
%   beamvelstruct.vb = beam velocities (m/s) for each beam
%
%   beamvelstruct.ambv = beam ambiguity velocities (m/s) used for
%   calculations
%
%   beamvels.A = irrelevant, placeholder added for consistency with beam2uvw
beamvelstruct.beamname=data.beamname;
beamvelstruct.vb   = reshape(permute(vb  ,[2 3 1]),[nz nt nf nb]);
beamvelstruct.ambv = ambv;
beamvelstruct.A='A matrix not used for single beam data';
