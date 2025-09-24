function sout=strsh(sin,x)
%
% sout=strsh(sin,x)
%
% String processing ala shell.  For example, shell $i:e returns the filename
% extension; strsh(i,'e') does the same thing.  The implemented options
% are:
%
%   h: head
%   t: tail
%   e: extension
%   r: opposite of e
%
% Multiple arguments can be given for 'x', and they will be interpreted
% in sequence.  For example,
%
%   >> strsh('mydir/subdir.123/out.dat','hrt')
%
% would return 'subdir'
%
% Given cell-array input, will apply 'x' to each string in the cell
% array, and return an updated cell array
%

% although cell-array input is a "bonus feature", it is easier to treat
% everything as cell-array input
if(~iscell(sin))
  sinarray={sin};
else
  sinarray=sin;
end
clear sin

for n=1:length(sinarray)
  sin=sinarray{n};

  if(~isstr(sin) | ~isstr(x))
    error('input arguments must be strings')
  end

  % multi-character input
  if(length(x)>1)
    for i=1:length(x)
      sin=strsh(sin,x(i));
    end
    sout=sin;
  else

  % one-character input
  switch x
   case 'h'
    if(~isempty(strfind(sin,'/')))
      [a,b]=strtok(fliplr(sin),'/');
      sout=fliplr(b(2:end));
    else
      sout=sin;
    end
   case 't'
    if(~isempty(strfind(sin,'/')))
      [a,b]=strtok(fliplr(sin),'/');
      sout=fliplr(a);
    else
      sout=sin;
    end
   case 'r'
    if(~isempty(strfind(sin,'.')))
      [a,b]=strtok(fliplr(sin),'.');
      sout=fliplr(b(2:end));
    else
      sout=sin;
    end
   case 'e'
    if(~isempty(strfind(sin,'.')))
      [a,b]=strtok(fliplr(sin),'.');
      sout=fliplr(a);
    else
      sout=sin;
    end
   otherwise
    error(['invalid option ' x])
  end

  end  % gate for single-operation input
  
  sinarray{n}=sout;
end  % loop over cell-array elements
sout=sinarray;

% for non cell-array inputs, convert output to non cell-array
if(length(sout)==1)
  sout=sout{1};
end
