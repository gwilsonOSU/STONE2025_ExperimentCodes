function out=concatDDstruct(ddop)
%
% out=concatDDstruct(ddop)
%
% Concatenate ddop structs created by unpackDDmat.m.  ASSUMES the ddop
% structs share common settings, range bins, etc.  Only the time is assumed
% to change from one struct to the next.
%
% INPUT: ddop is an array of structs produced by unpackDDmat.m
%

out=ddop(1);
for i=2:length(ddop)
  out=setfield(out,'etime',cat(1,out.etime,ddop(i).etime));
  for fld={'Phase','Cor','Amp','PhaseRaw'}
    if(isfield(out,fld))
      fld=cell2mat(fld);
      out=setfield(out,fld,cat(2,getfield(out,fld),getfield(ddop(i),fld)));
    end
  end
end

% re-sort the fields in time order, in case the input structs were not
% time-ordered.  Also remove duplicates.
[~,indt]=sort(out.etime,'ascend');
[~,iu]=unique(out.etime(indt));
indt=indt(iu);
out.etime=out.etime(indt);
for fld={'Phase','Cor','Amp','PhaseRaw'}
  if(isfield(out,fld))
    fld=cell2mat(fld);
    this=getfield(out,fld);
    out=setfield(out,fld,this(:,indt,:,:));
  end
end
