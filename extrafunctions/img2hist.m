% This function loads an image (or matrix), and plots a histogram from it
function h = img2hist(fn, bins, name)

% Get image or matrix...
if ischar(fn)
   Y = spm_read_vols(spm_vol(fn));
else
   Y = fn;
   clear img
end

% Linearise and remove NaNs
Y = Y(~isnan(Y));
Y = Y(Y~=0);

% Parameters for histogram
if nargin < 2 || isempty(bins)
    aMax = ceil(max(abs(Y)));
    bins =  -aMax:(aMax/100):aMax;
end
if nargin < 3
    name = 'Image';
end

% Draw figure
h = figure;
set(h, 'Position', [0 0 1000 600])
hist(Y, bins)
xlabel('Value')
ylabel('N of voxels')

% T-value of deviation from mean
[h,p,ci,stats] = ttest(Y);

title(sprintf('%s: mean %0.2f, median %0.2f, effect T is: %0.2f', ...
        name, mean(Y), median(Y), stats.tstat))