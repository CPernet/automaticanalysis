% MVPAA_SIMILARITY - Obtain the similarities for our data points
% Pattern (Volumes * Pattern length)

function Similarity = mvpaa_similarity(aap, Pattern)

% Similaritylate across voxels to find the similarity of voxel patterns
% across conditions.
% Distance metrics are inverted (less negative distances are closer)

switch aap.tasklist.currenttask.settings.similarityMetric
    case 'Pearson'
        % This is *much* faster than corr...
        Similarity = corrcoef(Pattern');
    case 'Spearman'
        % Get Spearman correlations
        Similarity = corr(Pattern', 'type', 'Spearman');
    case 'Euclid'
        % Get Euclidian distance
        Similarity = -squareform(pdist_complex(Pattern, 'euclidean'));
    case 'sEuclid'
        % Get Euclidian distance (standardised)
        Similarity = -squareform(pdist_complex(Pattern, 'seuclidean'));
    case 'Mahalanobis'
        % Get Mahalanobis distance
        dbstop if warning % If matrix is close to singular or badly scaled, we may see NaNs...
        Similarity = -squareform(pdist_complex(Pattern, 'mahalanobis'));
    otherwise
        error('Incorrect metric of (dis)similarity between patterns');
end