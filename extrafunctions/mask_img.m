function mask_img(Mimg, fns)

if ischar(Mimg)
    % Load mask
    M = spm_read_vols(spm_vol(Mimg));
end

if ischar(fns)
    fns = strvcat2cell(fns);
end

for f = 1:length(fns)
    % Load image
    V = spm_vol(fns{f});
    Y = spm_read_vols(V);
    
    if isempty(Mimg)
        % Set things that are 0 to NaN
        Y(Y==0) = NaN;
    elseif all(size(M) == size(Y))
        % Mask image
        Y(~M) = NaN;
    elseif any(size(M) ~= size(Y))
        error('Mask and image to be masked are not of the same size!')
    end
    
    % Write image back...
    spm_write_vol(V,Y);
end