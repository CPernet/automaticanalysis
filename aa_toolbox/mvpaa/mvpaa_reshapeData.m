% MVPAA Reshape Data
% Automatically attempts to reshape data, based on the data and parameters you have...
%% [OBSOLETED @@@] better reshape during extraction/shrinkage

function [aap data sessionNum, blockNum, conditionNum] = ...
    mvpaa_reshapeData(aap, data, sessionNum, blockNum, conditionNum)

if aap.tasklist.currenttask.settings.mergeSessions == 0
    keyboard
    
    % USE RESHAPE FUNCTION!
    
    Ndata = reshape(data
    
    Rdata = nan(length(unique(conditionNum)), ...
        length(unique(blockNum)), ...
        length(unique(sessionNum)), ...
        size(data,2), size(data,3), size(data,4));
    
    for d = 1:length(conditionNum)
        % Set the correct locations for Rdata points
        Rdata(conditionNum(d), blockNum(d), sessionNum(d), :,:,:) = data(d,:,:,:);
    end
    % Reshaped data cell structure
    data = Rdata;
elseif aap.tasklist.currenttask.settings.mergeSessions == 1
    aas_log(aap,false, ['All sessions merged into a single meta-session, ' ... 
        'you still can use normal machinery, but proceed with caution'])
    
    % Again, let's check how many unique sessions we have...
    % Firstly, let's create a composite number...
    compositeNum = sessionNum * 10^6 + blockNum;
    % And an index for it...
    compositeIndx = unique(compositeNum);
    % Then we create a new set of blocks, that span the entire
    [junk, blockNum] = ismember(compositeNum, compositeIndx);
    
    Rdata = nan(length(unique(conditionNum)), ...
        length(unique(blockNum)), ...
        1, ...
        size(data,2), size(data,3), size(data,4));
    
    for d = 1:length(conditionNum)
        % Set the correct locations for Rdata points
        Rdata(conditionNum(d), blockNum(d), 1, :,:,:) = data(d,:,:,:);
    end
    
    % Reshaped data cell structure
    data = Rdata;
else
    aas_log(aap,false, 'You will need to specify the contrast matrix for the entire design');
    
    conditionNum = 1:length(conditionNum);
    blockNum = ones(size(conditionNum));
    sessionNum = ones(size(conditionNum));
end