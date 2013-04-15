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
        mvpaa_diagnosticParameters(aap)
        
        fprintf('Working with MVPaa_data from participant %s. \n', mriname)
        
        %% GET CONTRASTS
        aap = mvpaa_loadContrasts(aap);
        
        %% GET SETTINGS
        MVPaa_settings = [];
        load(aas_getfiles_bystream(aap, subj, 'MVPaa_settings'));
        % Settings are vectors indexing each fMRI image on:
        % condition, block, session (and the number of observations...)
        aap.tasklist.currenttask.settings.conditionNum = MVPaa_settings.conditionNum;
        aap.tasklist.currenttask.settings.blockNum = MVPaa_settings.blockNum;
        aap.tasklist.currenttask.settings.sessionNum = MVPaa_settings.sessionNum;
        
        %% DENOISING
        % Motion denoising for similarity data cleanup!
        aap.tasklist.currenttask.settings.motionDenoising = mvpaa_motionDenoising_prepare(aap);
        % Temporal denoising for similarity data cleanup!
        aap.tasklist.currenttask.settings.temporalDenoising = mvpaa_temporalDenoising_prepare(aap);
        
        %% DATA STRUCTURING...
        % Label the similarity matrix according to condition, block, session comparisons
        % This "structures" similarity data to allow us to test hypotheses on observation similiarity values
        aap = mvpaa_structureSimilarity(aap);
        % Structure the contrast matrices based on the above
        aap = mvpaa_structureContrasts(aap);
        
        %% GET MASK
        segMask = mvpaa_getMask(aap);
        
        %% GET fMRI DATA & CHUNK IT
        MVPaa_obj = matfile(aas_getfiles_bystream(aap, subj, 'MVPaa_data'));
        
        chunkDim = aap.tasklist.currenttask.settings.chunking;
        brainSize = size(MVPaa_obj,'MVPaa_data'); brainSize(1) = [];
        
        aap.tasklist.currenttask.settings.brainSize = brainSize;
        Statistics = NaN(brainSize(1), brainSize(2), brainSize(3), ...
            length(aap.tasklist.currenttask.settings.contrasts), ...
            length(aap.tasklist.currenttask.settings.tests));
        
        % Only use locations where there is data...
        if ~isempty(segMask)
            brainLimit = matrixLimits(segMask, ...
                aap.tasklist.currenttask.settings.ROIradius);            
        else
            brainLimit = matrixLimits(squeeze(MVPaa_obj.MVPaa_data(1, :,:,:)), ...
                aap.tasklist.currenttask.settings.ROIradius);   
        end
        
        chunkSplit = zeros(chunkDim + 1, 3);
        for c = 0:chunkDim
            for d = 1:3
                chunkSplit(c + 1, d) = ...
                floor((brainLimit{d}(2) - brainLimit{d}(1) + 1) * c / chunkDim) + brainLimit{d}(1) - 1;
            end
        end
        
        chunks = cell(chunkDim.^3, 1);
        
        indx = 0;
        % Chunking...
        for x = 1:size(chunkSplit,1) - 1
            for y = 1:size(chunkSplit,1) - 1
                for z = 1:size(chunkSplit,1) - 1     
                    indx = indx+1;
                    chunks{indx} = {...
                        chunkSplit(x,1) + 1 : chunkSplit(x+1,1), ...
                        chunkSplit(y,2) + 1 : chunkSplit(y+1,2), ...
                        chunkSplit(z,3) + 1 : chunkSplit(z+1,3)};
                end
            end
        end
        
        Statistics_cell = cell(chunkDim.^3);
        switch aap.tasklist.currenttask.settings.parallelisation
            case 'serial'
                % Linear way of doing things...
                for c = 1:size(chunks,1);
                    fprintf('\nWorking on chunk %d/%d\n', c, size(chunks,1));
                    Statistics_cell{c} = mvpaa_brain_1st(aap, MVPaa_obj, chunks{c}, segMask);
                end
            case 'torque'
                cell_aap = cell(chunkDim.^3, 1);
                cell_MVPaa_obj = cell(chunkDim.^3, 1);
                cell_segMask = cell(chunkDim.^3, 1);
                for c = 1:size(chunks,1);
                    cell_aap{c} = aap;
                    cell_MVPaa_obj{c} = MVPaa_obj;
                    cell_segMask{c} = segMask;
                end
                
                Statistics_cell = qsubcellfun(@mvpaa_brain_1st, ...
                cell_aap, cell_MVPaa_obj, chunks, cell_segMask, ...
                'memreq', 1024^3, ... % NOT DYNAMIC YET!!!
                'timreq', 1.5*60*60); % Time!
        end
        
        % Assign results to macro-structure
        for c = 1:size(chunks,1);
            Statistics(chunks{c}{1}, chunks{c}{2}, chunks{c}{3}, :, :) = ...
                reshape(Statistics_cell{c}, [length(chunks{c}{1}), length(chunks{c}{2}), length(chunks{c}{3}), size(Statistics,4), size(Statistics,5)]);
        end
        %Reshape macro-structure
        Statistics = reshape(Statistics, [brainSize(1)*brainSize(2)*brainSize(3), size(Statistics,4), size(Statistics,5)]);
        
        % DIAGNOSTIC DISPLAY OF T-VALUES FOR EACH CON
        %try mvpaa_diagnosticSearchlight(aap, Statistics); catch; end
        
        %% DESCRIBE OUTPUTS
        MVPaa_settings = aap.tasklist.currenttask.settings;
        save(fullfile(aas_getsubjpath(aap,subj), 'MVPaa_1st.mat'), '-v7.3', ...
            'Statistics', 'MVPaa_settings')
        aap=aas_desc_outputs(aap,subj,'MVPaa_1st', fullfile(aas_getsubjpath(aap,subj), 'MVPaa_1st.mat'));
end