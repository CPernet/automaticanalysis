% AA module - MVPaa 1st level (ROI based)
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011

function [aap,resp] = aamod_MVPaa_brain_1st(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        aap.subj = subj;
        
        %% PREPARATIONS...
        
        mriname = aas_prepare_diagnostic(aap);
        
        fprintf('Working with data from participant %s. \n', mriname)
        
        % Get the contrasts for this subject...
        aap = mvpaa_loadContrasts(aap);
        
        % Create a spherical masking matrix...
        ROIsphere = mvpaa_makeSphere(aap.tasklist.currenttask.settings.ROIradius);
        ROIind = find(ROIsphere==1);
        [Bx By Bz] = ind2sub(size(ROIsphere), ROIind);
        % base indices
        Bx = Bx - aap.tasklist.currenttask.settings.ROIradius - 1;
        By = By - aap.tasklist.currenttask.settings.ROIradius - 1;
        Bz = Bz - aap.tasklist.currenttask.settings.ROIradius - 1;
        
        % Which tests will we use?
        if ~isempty(findstr(aap.tasklist.currenttask.settings.statsType, 'GLM'))
            aap.tasklist.currenttask.settings.tests = {'beta', 't-value', 'p-value', 'SE'};
        elseif ~isempty(findstr(aap.tasklist.currenttask.settings.statsType, 'ttest'))
            aap.tasklist.currenttask.settings.tests = {'mean', 't-value', 'p-value', 'SE', 'normality'};
        elseif ~isempty(findstr(aap.tasklist.currenttask.settings.statsType, 'signrank'))
            aap.tasklist.currenttask.settings.tests = {'median', 't-value (est)', 'p-value'};
        end
        
        %% ANALYSIS!
        
        % Load the data into a single big structure...
        [aap data] = mvpaa_loadData(aap);
        
        brainSize = [size(data{1,1,1}, 1) size(data{1,1,1}, 2) size(data{1,1,1}, 3)];
        
        ROInum = brainSize(1) .* brainSize(2) .* brainSize(3);
        
        % Create output arrays...
        Stats = NaN(ROInum, ...
            length(aap.tasklist.currenttask.settings.contrasts), ...
            length(aap.tasklist.currenttask.settings.tests));
        
        % Loop the routine over all ROIs
        reverseStr = ''; % for displaying progress
        ROIcheck = round(ROInum/100);
        for r = 1:ROInum %#ok<BDSCI>
            
            [x y z] = ind2sub(brainSize, r);
            [indROI voxels] = mvpaa_buildROI([x y z], ...
                [Bx By Bz], brainSize);
            
            Betas = mvpaa_extraction(aap, data, indROI);
            
            if isempty(Betas)
                continue
            end
            
            % Get the residuals
            Resid = mvpaa_shrinkage(aap, Betas);
            
            % Compute similarities of the the data
            Simil = mvpaa_similarity(aap, Resid);
            
            % Remove effects related to temporal proximity... (if temp. info available)
            Simil = mvpaa_temporalDenoising(aap, Simil);
            
            % Restructure (and normalise?) similarity scores...
            Simil = mvpaa_restructureSimil(aap, Simil);
            
            % Get statistics for similarity values
            Stats(r,:,:) = mvpaa_statistics(aap, Simil);
            
            % Display the progress at each complete %
            if rem(r, ROIcheck) == 0
                reverseStr = aas_progress_text(r, ROInum, reverseStr, sprintf('ROI %d / %d...', r, ROInum));
            end
        end
        
        % DIAGNOSTIC DISPLAY OF T-VALUES FOR EACH CON
        mvpaa_diagnosticSearchlight(aap, Stats);
        
        %% DESCRIBE OUTPUTS
        aap.tasklist.currenttask.settings.brainSize = brainSize;
        EP = aap.tasklist.currenttask.settings;
        save(fullfile(aas_getsubjpath(aap,subj), [mriname '.mat']), ...
            'Stats', 'EP')
        aap=aas_desc_outputs(aap,subj,'MVPaa', fullfile(aas_getsubjpath(aap,subj), [mriname '.mat']));
end