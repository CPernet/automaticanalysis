% AA module - Searchlight 1st level ==> THIS IS A FIRST LEVEL TASK
% You will need to make a local copy of this module into the same directory
%  as your user script, or somewhere else on your matlab path, and then modify it to
%  reflect the particular experiment you conducted
%
% Based on aa by Rhodri Cusack MRC CBU Mar 2006-Aug 2007
% Modified by Alejandro Vicente-Grabovetsky Dec-2008

function [aap,resp] = aamod_DMLT_searchlight_SPM(aap,task,subj)

resp='';

switch task
    case 'doit'
        mriname = aas_prepare_diagnostic(aap);
        
        fprintf('Working with data from participant %s. \n',aap.acq_details.subjects(subj).mriname)
        instreams = aap.tasklist.currenttask.inputstreams.stream;
                
        DMLout = []; EP = []; DMLT = [];
        load(aas_getfiles_bystream(aap,subj,'DMLT'), 'DMLout', 'EP', 'DMLT', 'M');
               
        % get sn mat file from normalisation
        if aap.tasklist.currenttask.settings.normalise == 1
            normMAT = aas_getfiles_bystream(aap,subj,'normalisation_seg_sn');
        end
        
        % Example BET mask
        Mimg = aas_getfiles_bystream(aap, subj, 'epiBETmask');
        % Brain mask!
        for a = 1:size(Mimg,1)
            if ~isempty(strfind(Mimg(a,:), 'brain_mask'))
                Mimg = deblank(Mimg(a,:));
                break
            end
        end
        
        % FWHM in millimetres
        FWHMmm = aap.tasklist.currenttask.settings.FWHM;
        
        V = spm_vol(Mimg);        
        
        %% GGM fit correction if necessary...
        Statistics = zeros([length(DMLT), V.dim]);
        
        if aap.tasklist.currenttask.settings.ggmfit == 1
            fprintf('GGMfit-ting T-values... \n')
            for c = 1:length(DMLout)
                % Only non-zero non-nan values of image...
                % DMLout{c}.centers is already defined in previous module
                
                P = DMLout{c}.model';
                P = P.accuracy;
                
                % First we try the ggm model (Gaussian/Gamma)
                ggmmix = ggmfit(P, 3, 'ggm');
                
                % If this does not work, we try with gmm (Gaussian)
                if ~isfinite(ggmmix.mus(1)) || ggmmix.mus(1) == 0 ...
                        || ~isfinite(ggmmix.sig(1)) || ggmmix.sig(1) == 0
                    aas_log(aap,0,'Error in ggm, mu and/or sigma are NaN, trying ggm with 2 mixtures...')
                    ggmmix = ggmfit(P, 2, 'ggm');
                    
                    if isnan(ggmmix.mus(1)) || isnan(ggmmix.sig(1))
                        aas_log(aap,1,'Error in ggm, mu and/or sigma are NaN')
                    end
                end
                                
                P = (P - ggmmix.mus(1)) ./ ggmmix.sig(1);
                
                % Correct the stats...
                Statistics(c, M) = P;
                
                if aap.tasklist.currenttask.settings.verbose
                    P_noGGM = DMLout{c}.model;
                    P_noGGM = P_noGGM.accuracy;
                    P_noGGM = P_noGGM - mean(P_noGGM);
                    
                    % Diagnostics
                    h = img2hist({P_noGGM, P}, [], 'Contrast distributions');
                    saveas(h, fullfile(aap.acq_details.root, 'diagnostics', ...
                        [mfilename '_' mriname '_' num2str(c) '.fig']), 'fig');
                    try close(h); catch; end
                end
            end
        else
            for c = 1:length(DMLout)
                % Correct the stats...
                P = DMLout{c}.model';
                P = P.accuracy;
                Statistics(c, M) = P - mean(P);
                
                if aap.tasklist.currenttask.settings.verbose
                    % Diagnostics
                    h = img2hist({Statistics(c, M)}, [], 'Contrast distributions');
                    saveas(h, fullfile(aap.acq_details.root, 'diagnostics', ...
                        [mfilename '_' mriname '_' num2str(c) '.fig']), 'fig');
                    try close(h); catch; end
                end
            end
        end
        
        %% WRITE .nii
        Clist = '';
        V.dt(1) = 16; % Save in a format that accepts NaNs and negative values...
        
        fprintf('Saving images... \n')
        for c = 1:length(DMLT)
            % Mean, median or beta
            V.fname = fullfile(aas_getsubjpath(aap,subj), sprintf('con_%04d.nii', c));
            Clist = strvcat(Clist, V.fname);
            spm_write_vol(V, squeeze(Statistics(c, :,:,:)));
            
            if aap.tasklist.currenttask.settings.verbose
                % Diagnostics
                spm_check_registration(V.fname);
                pause(1.0)
                try close(h); catch; end
            end
        end
        
        
        
        %% NORMALISE
        if aap.tasklist.currenttask.settings.normalise == 1
            
            fprintf('Normalising images... \n')
            
            normPars = aap.spm.defaults.normalise.write;
            normPars.prefix = ''; % We want to keep no prefix...
            
            % This automatically reslices images to warped size
            spm_write_sn(Clist, normMAT, normPars);
        end
        
        %% CREATE MASK
        % better than normalising original mask...
        V = spm_vol(Clist(1,:));
        Y = spm_read_vols(V);
        mask = Y~=0 & isfinite(Y);
        
        % Write out mask image containing only tested locations...
        V.fname = fullfile(aas_getsubjpath(aap,subj), 'mask.nii');
        V.dt(1) = 2;
        spm_write_vol(V, mask);
        
        %% SMOOTH IMAGES
        if FWHMmm > 0
            
            fprintf('Smoothing images... \n')
            for f = 1:size(Clist,1);
                Q = Clist(f,:);
                U = Clist(f,:); % No prefixes!
                spm_smooth(Q,U,FWHMmm);
            end
        end
        
        %% MASK SMOOTHED IMAGES!
        % Included mask to mask out untested data
        fprintf('NaNing untested voxels... \n')
                
        for f = 1:size(Clist,1)
            V = spm_vol(Clist(f,:));
            Y = spm_read_vols(V);
            if strfind(Clist(f,:), 'spmT')
                % Zero mask in statistics...
                Y(~mask) = NaN;
            elseif strfind(Clist(f,:), 'con')
                % NaN mask in statistics...
                Y(~mask) = NaN;
            end
            spm_write_vol(V, Y);
        end
                
        %% Modify SPM!
        % Load SPM used for this analysis...
        if any(strcmp(instreams, 'firstlevel_spm'))
            load(aas_getfiles_bystream(aap, subj, 'firstlevel_spm'));
            
            % Clear SPM.xCon
            SPM.xCon = [];
            
            % Set correct path
            SPM.swd = aas_getsubjpath(aap,subj);
            
            % Set world coordinates for visualisation...
            % ...which should already be found in the images...
            SPM.xVol.DMLout{c}.centers = V.mat;
            SPM.xVol.iM = inv(SPM.xVol.DMLout{c}.centers);
            
            % Size of the volume
            SPM.xVol.DIM = V.dim';
            
            % Smoothness of the volume...
            % ...Get the number of mm per voxel...
            mmVox = vox2mm(V);
            % ...then get the FWHM
            if FWHMmm < min(mmVox./2) % To avoid errors...
                FWHMmm = min(mmVox./2);
            end
            SPM.xVol.FWHM = [FWHMmm FWHMmm FWHMmm];
            SPM.xVol.FWHM = SPM.xVol.FWHM ./ mmVox;
            
            % Spm_resels_vol function
            % NOTE: This is probably not valid for FWE still, since the
            % searchlight procedure means each voxels is already "smoothed" to
            % some extent...
            SPM.xVol.R = spm_resels_vol( ...
                spm_vol(fullfile(aas_getsubjpath(aap,subj), 'con_0001.nii')), ...
                SPM.xVol.FWHM)';
            
            % Included voxels
            [X, Y, Z] = ind2sub(SPM.xVol.DIM',find(mask));
            SPM.xVol.XYZ = [X';Y';Z'];
            
            % Length of voxels in analysis
            SPM.xVol.S = length(X);
            
            % Filehandle of resels per voxel image (i.e. none!)
            SPM.xVol.VRpv = [];
            
            for c = 1:length(DMLT)
                % SPM.xCon (.name)
                SPM.xCon(c).name = DMLT(c).name;
                SPM.xCon(c).STAT = 'T';
                SPM.xCon(c).c = ones(size(SPM.xX.X,2),1);
                SPM.xCon(c).eidf = 1;
                SPM.xCon(c).Vcon = spm_vol(fullfile(aas_getsubjpath(aap,subj), sprintf('con_%04d.nii', c)));
            end
            
            % Save SPM
            save(fullfile(aas_getsubjpath(aap,subj), 'SPM.mat'), 'SPM');
        else
            fake_SPM(Slist, Clist, 1, aas_getsubjpath(aap,subj))
        end
        
        %% DESCRIBE OUTPUTS
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm', fullfile(aas_getsubjpath(aap,subj), 'SPM.mat'));
        aap=aas_desc_outputs(aap,subj,'firstlevel_cons', Clist);
end