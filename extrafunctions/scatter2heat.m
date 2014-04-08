% SCATTER2HEAT
% scatterMatrix = scatter2heat(X, Y, C, bins, transform)
% Plots a memory efficient scatterplot by creating a heatmap
% Adapted from mathematical.coffee at stackoverflow.com
%
% Inputs:
% X: x axis points of scatterplot
% Y: y axis points of scatterplot
% C: how to colour the points (if empty, the heatmap will contain number of
% points in that bin)
% bins: how many bins in each direction...
function [scatterMatrix, bins]= scatter2heat(X, Y, C, bins, transform)

if nargin < 4
    % Group into bins of 0.05
    bins = 20;
end
if nargin < 5
    % Group into bins of 0.05
    transform = '';
end
if length(bins) == 1
    bins = {bins, bins};
elseif length(bins) == 2
    if ~iscell(bins)
        bins = mat2cell(bins);
    end
else
    error('Not the right length of bins...')
end

% Create the bins
if length(bins{1}) == 1;
    bins{1} = linspace(min(X), max(X), bins{1});
end
if length(bins{2}) == 1; 
    bins{2} = linspace(min(Y), max(Y), bins{2});
end

% Work out which bin each X and Y is in (idxx, idxy)
[nx, idxx] = histc(X, bins{1});
[ny, idxy] = histc(Y, bins{2});

% Calculate mean (or number of points) in each direction
if nargin < 3 || isempty(C);
    scatterMatrix = accumarray([idxy idxx], ones(size(X))', [], @sum);
else
    scatterMatrix = accumarray([idxy idxx], C', [], @mean);
end

if ~isempty(transform)
    eval(['scatterMatrix = ' transform '(scatterMatrix);']);
end

% PLOT
imagesc(bins{1}, bins{2}, scatterMatrix)
set(gca, 'YDir', 'normal') % flip Y axis back to normal
colorbar