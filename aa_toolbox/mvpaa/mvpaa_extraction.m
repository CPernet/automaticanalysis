% MVPAA Extraction
% Extracts ROI data from aap.tasklist.currenttask.settingsIs

function Pattern = mvpaa_extraction(aap, data, indROI)

% We only want the indices that are not NaN
indROI = indROI(~isnan(data(1,indROI)));
voxels = length(indROI);

% Check that it's worth to extract data
if voxels > aap.tasklist.currenttask.settings.minVoxels
    % Get all betas quickly
    Pattern = data(:,indROI);
else
    Pattern = [];
end