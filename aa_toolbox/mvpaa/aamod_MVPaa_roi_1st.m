% AA module - MVPaa 1st level (ROI based)
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011

function [aap,resp] = aamod_MVPaa_roi_1st(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        aap.subj = subj;
        
        %% PREPARATIONS
        
        mriname = aas_prepare_diagnostic(aap);        
        fprintf('Working with data from participant %s. \n', mriname)
        
        % Get the contrasts for this subject...
        aap = mvpaa_loadContrasts(aap);
        
        %% Load the ROIs from which to extract the data
        ROIimg = aas_getfiles_bystream(aap,subj,'rois');
        
        % Which tests will we use?
        if ~isempty(findstr(aap.tasklist.currenttask.settings.statsType, 'GLM'))
            aap.tasklist.currenttask.settings.tests = {'beta', 't-value', 'p-value', 'SE'};
        elseif ~isempty(findstr(aap.tasklist.currenttask.settings.statsType, 'ttest'))
            aap.tasklist.currenttask.settings.tests = {'mean', 't-value', 'p-value', 'SE', 'normality'};
        elseif ~isempty(findstr(aap.tasklist.currenttask.settings.statsType, 'signrank'))
            aap.tasklist.currenttask.settings.tests = {'median', 't-value (est)', 'p-value'};
        end        
        
        %% ANALYSIS
        
        % Load the data into a single big structure...
        [aap data] = mvpaa_loadData(aap);
        
        ROInum = size(ROIimg,1);
        
        % Create output arrays...
        Stats = NaN(ROInum, ...
            length(aap.tasklist.currenttask.settings.contrasts), ...
            length(aap.tasklist.currenttask.settings.tests));
        meanSimil = NaN(ROInum, ...
            aap.tasklist.currenttask.settings.conditions, ...
            aap.tasklist.currenttask.settings.conditions);
        
        ROIname = {};
        % Loop the routine over all ROIs
        for r = 1:ROInum
            [Rpth Rfn Rext] = fileparts(deblank(ROIimg(r,:)));
            ROIname = [ROIname Rfn];
            
            % Extract betas from each: ROI, voxel, condition, subblock, session
            ROI = uint8(spm_read_vols(spm_vol(fullfile(Rpth, [Rfn Rext]))));
            
            % Check that the ROI size is equal to the data size
            if any(size(ROI) ~= size(data{1,1,1}));
                aas_log(aap, true, 'Your ROI size is different from your data size!');
            end
            
            % Trick for non-binary ROIs...
            if length(unique(ROI))>2
                ROI = ROI > 0;
            end
            voxels = sum(ROI(:));
            
            % ROI to linear index...
            ROI = find(ROI);
            
            Betas = mvpaa_extraction(aap, data, ROI);
            
            fprintf('\t ROI = %s; vox. = %d (%d)\n',Rfn, sum(~isnan(data{1,1,1}(ROI))), voxels)
            
            if isempty(Betas)
                aas_log(aap, false, sprintf('Not enough voxels in ROI, minimum is %i, you have %i', ...
                    aap.tasklist.currenttask.settings.minVoxels, sum(~isnan(data{1,1,1}(ROI)))));
                continue
            end
            
            % Get the residuals
            Resid = mvpaa_shrinkage(aap, Betas);
            
            % Compute similarities of the the data
            Simil = mvpaa_similarity(aap, Resid);            
            
            % Remove effects related to temporal proximity... (if temp. info available)
            Simil = mvpaa_temporalDenoising(aap, Simil, Rfn);

            % Restructure (and normalise?) similarity scores...
            Simil = mvpaa_restructureSimil(aap, Simil);
            
            % Get statistics for similarity values
            [Stats(r,:,:), meanSimil(r, :,:)] = mvpaa_statistics(aap, Simil);
            
            %% DATA DIAGNOSTICS...
            mvpaa_diagnosticCorrelation(aap, r, Rfn, Resid, Simil, meanSimil)
        end
        aap.tasklist.currenttask.settings.ROIname = ROIname;
        
        %% DESCRIBE OUTPUTS
        EP = aap.tasklist.currenttask.settings;
        save(fullfile(aas_getsubjpath(aap,subj), [mriname '.mat']), ...
            'meanSimil', 'Stats', 'EP')
        aap=aas_desc_outputs(aap,subj,'MVPaa', fullfile(aas_getsubjpath(aap,subj), [mriname '.mat']));
end