function ind = findCellStr(c,s)
%
% ind = findCellStr(c,s)
%
% finds occurrences of string 's' in cell array of strings 'c'
%

ind=[];
for i=1:length(c)
  if(strcmp(c{i},s))
    ind=[ind i];
  end
end
