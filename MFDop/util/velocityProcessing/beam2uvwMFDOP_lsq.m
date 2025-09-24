function [uvwstruct,beamvelstruct]=beam2uvwMFDOP_lsq(data,nave,pitch_rot,roll_rot,yaw_rot)
%
% [uvwstruct,beamvelstruct] = beam2uvwMFDOP(data,nave,[pitch_rot,roll_rot,yaw_rot])
%
% Computes velocity components from beam velocities, using
% least-squares-fit as in Gilcoto et al. (JTECH, 2009).
%
% NOTE: Assumes beam geometry and naming convention used for STONE 2025.
% Code comments below include a diagram of the expected beam naming
% conventions and their orientation.
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
% OPTIONAL-INPUTS: 
%
% pitch_rot and roll_rot are the rotation angles (in degrees) applied in
% the xdr1-2 beam plane and the xdr5-6 beam plane, respectively (i.e., the
% pitch and roll angles).  Default is zero.
%
% yaw_rot: output vels will be rotated by 'yaw_rot' degrees about the +z axis (i.e.,
% rotated ccw when viewed from above).  Default is yaw_rot=0.  Note, the code
% already assumes an 'X-type' MFDop mounting configuration for yaw_rot=0, and
% the input 'yaw_rot' is a rotation relative to that default orientation.
%
% OUTPUT:
%
% The script produces two structs 'uvwstruct' and 'beamvelstruct', which we
% normally append to our main data struct before saving it to disk.  They
% contains the following variables:
%
%   uvwstruct.{u,v,w} = Cartesian velocities in STONE coordinate system
%                       (x = shoreward, y = cross-tank, z = up)
%
%   uvwstruct.{ustd,vstd,wstd} = Estimated error values for u,v,w, used as
%   an metric for data quality.
%
%   beamvels = low-level struct for the individual beams.  These are not
%   normally needed for analysis, but are sometimes useful.
%
%   beamvelstruct.beamname = names of each beam.  These are designed to
%   match the input data.beamname
%
%   beamvelstruct.vb = beam velocities (m/s) for each beam
%
%   beamvelstruct.ambv = beam ambiguity velocities (m/s) used for
%   calculations
%
%   beamvels.A = matrix used for converting between beamvel and uvw

% check optional inputs
if(nargin==1)  % nave not provided
  nave=1;  % default
end
if(mod(nave,2)==0)
  error(['Input ''nave'' must be an odd number'])
end
if(nargin<3)  % rotations not provided as input
  % warning('not applying pitch and roll angles')
  pitch_rot=0;
  roll_rot=0;
  yaw_rot=0;
end

%-------------------------------------------------
% Extract variables from the input data struct, adopting the conventions
% used by this script.
%-------------------------------------------------

% Reorder beam variables, following the order of beams assumed used by this
% script
beamname_orig = data.beamname;  % save for defining the final output struct
desiredbeam={'Beam_1','Beam_2','Beam_3','Beam_4','Beam_CL'};
ind=zeros(5,1);  % init
for i=1:length(desiredbeam)
  thisind=findCellStr(data.beamname,desiredbeam{i});
  if(isempty(thisind))
    error(['Required beam name ''' desiredbeam{i} ''' not found in data struct.'])
  end
  ind(i)=thisind;
end
data.beamname=data.beamname(ind);
data.Phase=data.Phase(:,:,:,ind);
data.Cor=data.Cor(:,:,:,ind);
data.Amp=data.Amp(:,:,:,ind);

%-------------------------------------------------
% Ambiguity velocities
%-------------------------------------------------

[nz,nt,nf,nb]=size(data.Phase);

% sound speed (m/s)
cw=1500;

% L are the fundamental geometry quantities: distance between xdrc and
% outboard xdr.  For STONE 2025 we used the "ShortDop" lab geometry
L1c = 10e-2;
L2c = L1c;
L3c = L1c;
L4c = L1c;

% calculate amb vels, with size [nbins,nfreq,nbeams]
alfa1c = acos((L1c/2)./data.r);
thetaHalf1c = pi/2 - alfa1c;
alfa2c = acos((L2c/2)./data.r);
thetaHalf2c = pi/2 - alfa2c;
alfa3c = acos((L3c/2)./data.r);
thetaHalf3c = pi/2 - alfa3c;
alfa43 = acos((L4c/2)./data.r);
thetaHalf4c = pi/2 - alfa43;
ambv=zeros(nz,nf,nb);  % init
for j = 1:nf
  omega = 2*pi*data.f(j);
  lambda = cw/data.f(j);
  k = 2*pi/lambda;
  ambv(:,j,1) = pi./(2*k*data.pingInterval*cos(thetaHalf1c));  % Beam_1
  ambv(:,j,2) = pi./(2*k*data.pingInterval*cos(thetaHalf2c));  % Beam_2
  ambv(:,j,3) = pi./(2*k*data.pingInterval*cos(thetaHalf4c));  % Beam_3
  ambv(:,j,4) = pi./(2*k*data.pingInterval*cos(thetaHalf3c));  % Beam_4
  ambv(:,j,5) = cw./(4*data.f(j)*data.pingInterval)*ones(nz,1);  % center beam
end

% this script expects ambv to have same size as vb, so repeat it in time
% then permute to make size [nbins,ntime,nfreq,nbeams]
ambv=permute(repmat(ambv,[1 1 1 nt]),[1 4 2 3]);

% convert phases to velocities, array of size [nbins,ntime,nfreq,nbeams],
% with velocity positive towards the xdr (convention used by this script).
vb = pi\data.Phase.*ambv;
r2 = data.Cor/100;

%-------------------------------------------------
% define beam2uvw transformation matrix A
%-------------------------------------------------

% Beam geometry conventions used by DragonDop for STONE 2025 (axes are
% roughly sketched...), with beam names assigned in DragonDop software.
% NOTE, the software beam names differed from the numbers stamped on the OSU
% xdr arms, in particular 3 and 4 are swapped.  This was done so that
% Blasstex (Duck) 2022 data had the same beam naming convention as DragonX
% (Arch Cape) 2022 data.  See log books.
%
% This is the view looking DOWN from above the floor-mounted MFDop, where
% the wave direction (+x) is up and to the right in the diagram.  The labels
% indicated on each outboard xdr in the diagram are what is stamped on the
% OSU MFDop arms, and they also correspond to the beam names defined in DD
% software: This is documented in the logbook on page 87.  Note we used the
% 'X' style of deployment configuration, and an "upside-down" MFDop compared
% to how we deploy it in the field; the flume coordinate axes are indicated
% in the upper right in this diagram.
%
%               (1004)             (+y)   (+x, shoreward)
%               (Beam_4)            \    /
%                 |                  \  /
%                 |                   \/  (flume coords)
%  (1003)-------(CL)-------(1005)
%  (Beam_3)       |        (Beam_2)
%                 |                   --------|-
%                 |                  (+x')    |
%               (1006)                        |  (instrument coords)
%               (Beam_1)                      |
%                                             |(+y')
%
% To define the matrix that converts uvw to beam velocities, we will
% iniitally work in the primed coordinate system (x',y') indicated in the
% lower right of the above diagram.  Note in this coordinate system, both +z
% and +z' are facing out of the page.  We then rotate the velocities
% (u',v',w') ccw by +45 degrees about the +z' axis, then negate, to convert
% to the flume (unprimed x,y,z) coordinates as indicated in the upper right.
%

% instrument geometry
theta0_1 = (14)*pi/180; % at r0, alpha = 2*halfangle
theta0_2 = (14)*pi/180; % at r0, alpha = 2*halfangle    
theta0_3=theta0_1;   % treating beam3 equiv to beam1
theta0_4=theta0_2;   % treating beam4 equiv to beam2
sin1 = sin(theta0_1/2);
cos1 = cos(theta0_1/2);
sin2 = sin(theta0_2/2);
cos2 = cos(theta0_2/2);
sin3 = sin(theta0_3/2);
cos3 = cos(theta0_3/2);
sin4 = sin(theta0_4/2);
cos4 = cos(theta0_4/2);

warning('Beam geometry needs careful re-checking as of 2025-09-12, errors are likely!')

% Define the matrix A which converts world velocities (u,v,w) to beam
% velocities.  For now assume no pitch/roll (they will be incorporated later
% as an additional rotation, see below).  Note, positive beam velocities are
% "towards" the xdr by convention.
%
% Note the geometry sketched above.  Here we define:
%
%    beamvel = [beam1,beam2,beam3,beam4,beamC] = A*[u v w]
%
% To get A, we start by defining A0 in the more natural "instrument"
% coordinates (x',y',z') as indicated in the above diagram.  Then we apply a
% 45 degree rotation and negate to bring it into the flume (x,y,z)
% coordinate system.  To double check the beam geometry math, it is useful
% to look at Hay2012a Fig 1 and Eqns 14-15.  Remember, a positive beam
% velocity means _towards_ the transducer.
%
%
%               (1004)             (+y)   (+x, shoreward)
%               (Beam_4)            \    /
%                 |                  \  /
%                 |                   \/  (flume coords)
%  (1003)-------(CL)-------(1005)
%  (Beam_3)       |        (Beam_2)
%                 |                   --------|-
%                 |                  (+x')    |
%               (1006)                        |  (instrument coords)
%               (Beam_1)                      |
%                                             |(+y')
%
A0=[0     +sin1  +cos1;  % vel_beam1 (+v' is towards beam1)
    -sin2  0     +cos2;  % vel_beam2 (+u' is away from beam2)
    +sin3  0     -cos3;  % vel_beam3 (+u' is towards beam3)
    0     -sin4  +cos4;  % vel_beam4 (+v' is away from beam4)
    0      0     -1   ]; % vel_CL (+w' is away from center beam)
R=[cosd(-45) -sind(-45) 0;
   sind(-45)  cosd(-45) 0;
   0          0       1];  % R is a 45 degree horizontal rotation about +z
A = -A0*R';  % rotate and negate to get (x',y',z') -> (x,y,z)

%-------------------------------------------------
% Apply rotations for pitch, roll, yaw. This accounts for any measured
% offsets from a perfect deployment geometry.  If no such measurments are
% available, assume pitch=roll=yaw=0.
%-------------------------------------------------

% **TODO: If we need to do pitch and roll, we will need the matlab package
% for vrrotvec.  For now this feature is disabled with a warning, since we
% probably won't use it for STONE 2025.  Once the package is installed, can
% simply uncomment the block below and delete the warning message.
%
% **TODO: pitch and roll code is copied from Blasstex, need to check the
% geometry and possibly redefine the rotation matrices for STONE, if using
% this feature.
if(pitch_rot~=0 | roll_rot~=0)
  warning('pitch and roll rotation requires vrrotvec, the needed matlab package not installed as of 2025-09-12, for now this feature is DISABLED!!!  See TODO comment in code.')
  warning('Need to redefine pitch_rot and roll_rot based on STONE geometry, if using this feature.  Existing code is legacy code from Blasstex, needs updating for STONE.')
end
% 
% % construct unit vector normal to xdr plane.  Note, +'ve angle convention is
% % "tilted upwards in the +x (or, +y) direction" (cf. rotAnglesMFDOP.m)
% unitvec_pitch=[cosd(pitch_rot),0,sind(pitch_rot)]';
% unitvec_roll=[0,cosd(roll_rot),sind(roll_rot)]';
% n=cross(unitvec_pitch,unitvec_roll);
% 
% % construct a matrix which rotates the xdr-plane-normal-vector into the unit
% % vertical vector
% R=vrrotvec2mat(vrrotvec([0 0 1]',n));
% 
% % apply this rotation to the existing beam2uvw matrix A.  Idea here is
% % ur=R*u ==> u=R'*ur, where ur is velocity in horiz. rotated coordinates.
% % And, by definition, vb=A*u.  Hence, (A*R')*ur=vb.
% A=A*R';

% yaw_rot: the matrix R is applied to the horizontal velocities, uvwr=R*uvw,
% meaning output is rotated by 'yaw_rot' degrees about the +z axis (i.e.,
% rotated ccw when viewed from above)
R=[cosd(yaw_rot) -sind(yaw_rot) 0;
   sind(yaw_rot)  cosd(yaw_rot) 0;
   0          0         1];
A=A*R';

%-------------------------------------------------
% perform least-squares fit to u,v,w
%-------------------------------------------------

% treat observations at different frequencies as independent, meaning the
% matrix A must be repeated for each frequency band
A=permute(repmat(A,[1 1 nf]),[3 1 2]);

% reshape data to match treatment of different frequencies as independent
% data points
[nz,nt,nf,nb]=size(vb);
vb  =permute(reshape(vb  ,[nz nt nf*nb]),[3 1 2]);
r2  =permute(reshape(r2  ,[nz nt nf*nb]),[3 1 2]);
ambv=permute(reshape(ambv,[nz nt nf*nb]),[3 1 2]);
A=reshape(A,[nf*nb 3]);

% estimate beam velocity stdev
phsstd=sqrt(-2*log(r2));
vbstd=phsstd.*ambv/pi;
clear phsstd

% % test code: forget about weighting
% warning('not using weighted lsq')
% vbstd=ones(size(vbstd));

% calculate weighted-least-squares.  Be careful about dropouts (NaNs),
% which can cause singular transfer matrices.  To guard against this, only
% accept data for which there are at least three independent beams being
% used, and use pinv() when doing matrix inversion.
%
% NOTE: This loop can run in parfor if your system can handle it.
tic
n2start = (nave-1)/2+1;
n2end = nt-n2start+1;
Arep=repmat(A,[nave 1]);  % repeat A for binning in time
nbincenters=n2start:nave:n2end;
nbins=length(nbincenters);
uvw=nan(3,nz,nbins);  % init
uvwstd=nan(3,nz,nbins);  % init
parfor bini=1:nbins
  if(floor(bini/nbins*10)>floor((bini-1)/nbins*10))
    disp(['checkpoint ' num2str(floor(bini/nbins*10)) ' of 10'])
          % num2str(round(toc)) ' seconds elapsed'])
  end
  indt=nbincenters(bini)+[-((nave-1)/2):((nave-1)/2)];  % indexes for binning in time
  for n1=1:nz

    Ceinv=[];  % init
    vbdata=[];  % init
    ambvdata=[];
    for nn=1:length(indt)  % concatenate bins in time
      Ceinv=blkdiag(Ceinv,diag(1./vbstd(:,n1,indt(nn)).^2));
      vbdata=cat(1,vbdata,vb(:,n1,indt(nn)));
      ambvdata=cat(1,ambvdata,ambv(:,n1,indt(nn)));
    end
    ind=find(~isnan(vbdata));
    if(isempty(ind))
      uvwstd(:,n1,bini)=nan(3,1);
      uvw(:,n1,bini)=nan(3,1);
    else
      coef=Arep(ind,:)'*Ceinv(ind,ind);
      Cvinv=pinv(coef*Arep(ind,:));
      uvwstd(:,n1,bini)=sqrt(diag(Cvinv));
      uvw(:,n1,bini)=Cvinv*coef*vbdata(ind);
    end

    % % test code: tried to detect wraps based on outliers, this doesn't help.
    % vbpred=Arep*uvw(:,n1,bini);
    % nwrap = round((vbpred-vbdata)./ambvdata);
    % vbdata=vbdata+nwrap.*ambvdata;
    % uvw(:,n1,bini)=Cvinv*coef*vbdata;

  end
end

%-------------------------------------------------
% outputs
%-------------------------------------------------

% reshape back to normal.  Note frequency bins have been lumped together as
% separate observations, so they no longer appear as dimemsions
uvw=permute(reshape(uvw,[3 nz nbins]),[2 3 1]);
uvwstd=permute(reshape(uvwstd,[3 nz nbins]),[2 3 1]);

%   uvwstruct.{u,v,w} = Cartesian velocities in STONE coordinate system
%                       (x = shoreward, y = cross-tank, z = up)
uvwstruct.u=uvw(:,:,1);
uvwstruct.v=uvw(:,:,2);
uvwstruct.w=uvw(:,:,3);

%   uvwstruct.{ustd,vstd,wstd} = Estimated error values for u,v,w, used as
%   an metric for data quality.
uvwstruct.ustd=uvwstd(:,:,1);
uvwstruct.vstd=uvwstd(:,:,2);
uvwstruct.wstd=uvwstd(:,:,3);

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
%   beamvels.A = matrix used for converting between beamvel and uvw
beamvelstruct.beamname=beamname_orig;
beamvelstruct.vb   = reshape(permute(vb  ,[2 3 1]),[nz nt nf nb]);
beamvelstruct.ambv = reshape(permute(ambv,[2 3 1]),[nz nt nf nb]);
beamvelstruct.A=permute(reshape(A,[nf nb 3]),[2 1 3]);
ind=zeros(length(beamvelstruct.beamname),1);  % init
for i=1:length(beamvelstruct.beamname)
  thisind=findCellStr(data.beamname,beamvelstruct.beamname{i});
  ind(i)=thisind;
end
beamvelstruct.vb   = beamvelstruct.vb(:,:,:,ind);
beamvelstruct.ambv = beamvelstruct.ambv(:,:,:,ind);
beamvelstruct.A    = beamvelstruct.A(ind,:,:);
