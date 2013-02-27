% AA module - MVPaa 1st level (Searchlight based)
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011

function [aap,resp] = aamod_MVPaa_brain_1st(aap,task,subj)

resp='';

switch task
    case 'doit'
        %% PLAN
        % A) Much better way of specifying masks! Maskstreams, manually selected...
        
        %% PREPARATIONS...
        aap.subj = subj;
        mriname = aas_prepare_diagnostic(aap);
        
        % Statistics types
        switch aap.tasklist.currenttask.settings.statsType
            case {'GLM', 'fullGLM'}
                aap.tasklist.currenttask.settings.tests = {'beta', 't-value', 'p-value', 'SE'};
            case 'ranksum'
                aap.tasklist.currenttask.settings.tests = {'median', 't-value (est)', 'p-value'};
            otherwise
                aas_log(aap, 1, 'Unknown type of statistics!')
        end
        
        fprintf('Working with MVPaa_data from participant %s. \n', mriname)
        
        %% GET CONTRASTS
        aap = mvpaa_loadContrasts(aap);
        
        %% GET fMRI DATA AND SETTINGS
        MVPaa_data = []; MVPaa_settings = [];
        load(aas_getfiles_bystream(aap, subj, 'MVPaa_data'));
        load(aas_getfiles_bystream(aap, subj, 'MVPaa_settings'));
        
        % Settings are vectors indexing each fMRI image on:
        % condition, block, session
        aap.tasklist.currenttask.settings.conditionNum = MVPaa_settings.conditionNum;
        aap.tasklist.currenttask.settings.blockNum = MVPaa_settings.blockNum;
        aap.tasklist.currenttask.settings.sessionNum = MVPaa_settings.sessionNum;
        
        % MASK DATA (using segmentation masks, for instance...)
        MVPaa_data = mvpaa_maskData(aap, MVPaa_data);
        
        % Label the similarity matrix according to condition, block, session comparisons
        % This "structures" similarity data to allow us to test hypotheses on observation similiarity values
        aap = mvpaa_structureSimilarity(aap);
        % Structure the contrast matrices based on the above
        aap = mvpaa_structureContrasts(aap);
        
        %% DENOISING
        % Motion denoising for similarity data cleanup!
        motionDenoising = mvpaa_motionDenoising_prepare(aap);
        % Temporal denoising for similarity data cleanup!
        temporalDenoising = mvpaa_temporalDenoising_prepare(aap);
        
        %% ROI SPHERE (x-y-z indices)
        [ROIx ROIy ROIz] = mvpaa_makeSphere(aap);
        
        brainSize = [size(MVPaa_data, 2) size(MVPaa_data, 3) size(MVPaa_data, 4)];
        ROInum = brainSize(1) .* brainSize(2) .* brainSize(3);            
        
        aap.tasklist.currenttask.settings.brainSize = brainSize;
        
        %% ANALYSIS!
        
        % Create output arrays...
        Statistics = NaN(ROInum, ...
            length(aap.tasklist.currenttask.settings.contrasts), ...
            length(aap.tasklist.currenttask.settings.tests));
        
        % Loop the routine over all ROIs
        reverseStr = ''; % for displaying % progress
        ROIcheck = round(ROInum/100);
        
        for r = 1:ROInum %#ok<BDSCI>
            [indROI voxels] = mvpaa_buildROI(r, [ROIx ROIy ROIz], brainSize);
            
            Pattern = mvpaa_extraction(aap, MVPaa_data, indROI);
            
            if isempty(Pattern); continue; end % Not enough data for MVPaa?
            
            % Compute similarities of the the MVPaa_data
            Similarity = mvpaa_similarity(aap, Pattern);
            
            % DENOISING
            % Remove effects related to subject motion (if info available)
            Similarity = mvpaa_Denoising(Similarity, motionDenoising);
            
            % Remove effects related to temporal proximity... (if temp. info available)
            Similarity = mvpaa_Denoising(Similarity, temporalDenoising);
            
            % Get statistics for similarity values
            Statistics(r,:,:) = mvpaa_statistics(aap, Similarity);
            
            % Display the progress at each complete %
            if rem(r, ROIcheck) == 0
                reverseStr = aas_progress_text(r, ROInum, reverseStr, sprintf('ROI %d / %d...', r, ROInum));
            end
        end
        
        % DIAGNOSTIC DISPLAY OF T-VALUES FOR EACH CON
        mvpaa_diagnosticSearchlight(aap, Statistics);
        
        %% DESCRIBE OUTPUTS
        MVPaa_settings = aap.tasklist.currenttask.settings;
        save(fullfile(aas_getsubjpath(aap,subj), 'MVPaa_1st.mat'), ...
            'Statistics', 'MVPaa_settings')
        aap=aas_desc_outputs(aap,subj,'MVPaa_1st', fullfile(aas_getsubjpath(aap,subj), 'MVPaa_1st.mat'));
end