function [tvec,indexmap]=findgapsDD(tvec1raw,dt)
%
% [tvec,indexmap]=findgapsDD(tvec1raw,dt)
%
% Reads a non-uniform sampled DD time vector tvec1raw, and gathers the info
% needed to pad the data to create a uniform-sampled version.
%
% INPUTS:
%
% tvec1raw = 1d vector of timestamps in matlab datenum format.  Typically
% gotten from a DragonDop Step2 data file.
%
% dt = Desired sampling rate, in seconds.  Note, this can be calculated from
% the DD StepTwo data using the following formula:
%
%  >> dt = ddop.Dopmeta.PingInterval*(ddop.Dopmeta.PingPairs+1);
%
% OUTPUTS:
%
% tvec = uniformily sampled time vector that encompasses the full time
% period of data collection.
%
% indexmap = indexes needed to create padded data matrices.  For example, if
% you have an array Phase of size [nrange,ntime] and you want to create a
% uniformily-sampled version of Phase, do the following:
%
%  >> PhasePadded = nan(size(Phase,1),length(tvec));  % init as NaN
%  >> PhasePadded(:,indexmap) = Phase;  % insert the non-NaN data
%

% % TEST-CODE: hard-coded inputs
% basedir='/home/ibbisin0/shared/dragonx2022/DATASHARE_INTERNAL/StepTwo_FiveMinuteChunks_RawData/20220903A';
% fn=fileList_ls([basedir '/*.mat']);
% ddop=load(fn{80});  % pick an example that has gaps
% tvec1raw=ddop.Dop.tvec1;  % matlab datenum
% dt = ddop.Dopmeta.PingInterval*(ddop.Dopmeta.PingPairs+1);

% create an index map that converts from the nonuniformily sampled tvec1raw
% into a constant sampling rate tvec1.  This is similar to matlab's
% intersect(), but with a finite tolerance.
indexmap = [1:length(tvec1raw)]';  % init
gapind = find(diff(tvec1raw)*24*3600 > dt*1.1);  % locate gaps (10% tolerance)
for i=1:length(gapind)
  gaplen = round(diff(tvec1raw(gapind(i)+[0:1]))*24*3600/dt);
  indexmap(gapind(i)+1:end) = indexmap(gapind(i)+1:end) + gaplen-1;
end
nt=max(indexmap);  % new padded timeseries length
tvec1 = tvec1raw(1) + ([1:nt]'-1)*dt/24/3600;  % padded timeseries time vector

% Sanity Check: Convert tvec1raw to a padded version, and check that what we
% get agrees with the perfectly-uniform 'tvec1' to within tolerance
tvec1pad = nan*tvec1;  % init
tvec1pad(indexmap) = tvec1raw;  % insert originals
ind=find(~isnan(tvec1pad));
if(max(abs(tvec1pad(ind)-tvec1(ind)))>dt*0.9)
  error('Intersection code failed to produce a corrected padded time vector, should never happen')
end
