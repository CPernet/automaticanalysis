% MVPAA Load Data
% Automatically attempts to load data, based on the model you have...

function [aap data] = mvpaa_loadData(aap, subj)

%% Determine which conditions we have in our model
[SPM conditionNum sessionNum blockNum conditionNamesUnique nuisanceNum] = mvpaa_determineFactors(aap, subj);

fprintf('\nThis experiment contains (truly) \n\t%d conditions\n\t%d blocks\n\t%d sessions', ...
    length(unique(conditionNum)), ...
    length(unique(blockNum)), ...
   length(unique(sessionNum)))
fprintf('\n(%d Nuisance variables)\n\n', sum(nuisanceNum))

% Check if the number of conditions and blocks is equal across the two sessions...
[equalConditions, equalBlocks] = mvpaa_checkFactors(aap, conditionNum, sessionNum, blockNum);

%% Do we grey/white/CSF matter mask the data?
% Get segmentation masks we wish to use, if any
segMask = mvpaa_getSegmentations(aap, subj);

%% Load actual images!
data = mvpaa_loadImages(aap, subj, SPM, segMask, ...
    sessionNum, blockNum, conditionNum, conditionNamesUnique);

%% Reshape data?
[aap data sessionNum, blockNum, conditionNum] = ...
    mvpaa_reshapeData(aap, data, sessionNum, blockNum, conditionNum);

%% Save parameters to aa structure
aap.tasklist.currenttask.settings.conditions = length(unique(conditionNum));
aap.tasklist.currenttask.settings.blocks = length(unique(blockNum));
aap.tasklist.currenttask.settings.sessions = length(unique(sessionNum));

fprintf('\nThis experiment contains (to the purpose of MVPaa) \n\t%d conditions\n\t%d blocks\n\t%d sessions', ...
    aap.tasklist.currenttask.settings.conditions, ...
    aap.tasklist.currenttask.settings.blocks, ...
    aap.tasklist.currenttask.settings.sessions)
