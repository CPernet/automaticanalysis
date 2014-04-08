
%AA_DIR Automatic Analysis List directory helper.
% Works just like dir but excludes invisible files defined as...
%   * things starting with '.'

function D = aa_dir(dirPath)

D = dir(dirPath);

notInvisible = cellfun(@(x) x(1) ~= '.', {D.name});

D = D(notInvisible);