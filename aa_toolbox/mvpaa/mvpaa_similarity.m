% MVPAA_CORRELATION - Simillate the betas/spmTs
% R - betas/spmTs (or residuals of betas/spmTs)

function [Simil] = mvpaa_similarity(aap, Resid)

% Rename settings to keep easier track...
EP = aap.tasklist.currenttask.settings;

%% R ==> (voxels, EP.conditions, EP.blocks, EP.sessions)]
sResid = reshape(Resid, [size(Resid,1), ...
    EP.conditions ...
    * EP.blocks ...
    * EP.sessions]);

% Set missing data to NaN here...
missed = all(sResid == 0, 1);
sResid(:,missed) = NaN;

% Simillate across voxels to find the similarity of voxel patterns
% across conditions.
if strcmp('Pearson', EP.corrType)
    % This is *much* faster than corr...
    Simil = corrcoef(sResid);
elseif strcmp('Spearman', EP.corrType)
    % Get Spearman correlations
    Simil = corr(sResid, 'type', 'Spearman');
elseif strcmp('Euclid', EP.corrType);
    % Get Euclidian distance
    Simil = squareform(pdist_complex(sResid', 'euclidean'));
elseif strcmp('sEuclid', EP.corrType);
    % Get Euclidian distance (standardised)
    Simil = squareform(pdist_complex(sResid', 'seuclidean'));
elseif strcmp('Mahalanobis', EP.corrType);
    % Get Mahalanobis distance
    dbstop if warning % If matrix is close to singular or badly scaled, we may see NaNs...
    Simil = squareform(pdist_complex(sResid', 'mahalanobis'));
else
    error('Incorrect metric of (dis)similarity between patterns');
end
