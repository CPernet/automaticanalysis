function SPMversion = aas_spmVersion
SPMversion = spm('Version');

% Remove SPM bit
SPMversion = strrep(SPMversion, 'SPM', '');
% Remove release number
SPMversion = strtok(SPMversion, ' ');
% Get number in version...
SPMversion = sscanf(SPMversion, '%d');

end