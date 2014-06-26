% AA module - MVPaa 1st level (M based)
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011

function [aap,resp] = aamod_DMLT_searchlight_1st(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        %% PREPARATIONS
        warning off
        % Add toolbox path...
        addpath(genpath(aap.directory_conventions.DMLTdir));
        
        mriname = aas_prepare_diagnostic(aap,subj);
        fprintf('Working with data from participant %s. \n', mriname)
        
        %% ANALYSIS
        
        aap.subj = subj;
        
        % Load the data into a single big structure...
        [aap, data] = mvpaa_loadData(aap);
        
        % Get mask
        Mimg = aas_findstream(aap, 'mask', subj);
        
        if ~isempty(Mimg)            
            [Mpth, Mfn, Mext] = fileparts(deblank(Mimg));
            
            % Extract betas from each: M, voxel, condition, subblock, session
            V = spm_vol(fullfile(Mpth, [Mfn Mext]));
            M = uint8(spm_read_vols(V));
        else
            Mimg = aas_findstream(aap, 'rois', subj);
            
            if ~isempty(Mimg)
                M = 0;
                
                for m = 1:size(Mimg,1)
                    [Mpth, Mfn, Mext] = fileparts(deblank(Mimg(m,:)));
                    
                    % Extract betas from each: M, voxel, condition, subblock, session
                    V = spm_vol(fullfile(Mpth, [Mfn Mext]));
                    M = M + uint8(spm_read_vols(V));
                end
                M = M > 0;
            else
                Mfn = '';
                
                M = squeeze(data(1,:,:,:));
                M = isfinite(M) & M ~= 0;
            end
        end
        
        % Get the contrasts for this subject...
        DMLT = mvpaa_loadDMLT(aap, subj);
        
        DMLout = cell(1, length(DMLT));
        
        % Check that the M size is equal to the data size
        dataSize = size(data);
        
        if any(size(M) ~= dataSize(2:4));
            aas_log(aap, true, 'Your M size is different from your data size!');
        end
        
        % Trick for non-binary Ms...
        if length(unique(M))>2
            M = M > 0;
        end
        
        voxels = sum(M(:));
        
        % Get rid of NaNs in data...
        M = and(M, ~isnan(squeeze(data(1,:,:,:))));
        voxelsReal = sum(M(:));
        
        % M to linear index...
        M = find(M);
        
        fprintf('\t M = %s; vox. = %d (%d)\n', Mfn, voxelsReal, voxels)
        
        X = mvpaa_extraction(aap, data, M);
        
        for c = 1:length(DMLT)
            % If we input it as a string to make it work in aa qsub...
            if ischar(DMLT(c).object)
                DMLT(c).object = eval(DMLT(c).object);
            end
            
            % Get the DMLT object...
            DMLTtemp = dml.searchlight(...
                'step', aap.tasklist.currenttask.settings.step, ...
                'radius', aap.tasklist.currenttask.settings.radius, ...
                'indims', dataSize(2:4), ...
                'mask', M, ...
                'verbose', aap.tasklist.currenttask.settings.verbose, ...
                'stats', {aap.tasklist.currenttask.settings.stats}, ...
                'validator', DMLT(c).object);
            
            Y = DMLT(c).vector(aap.tasklist.currenttask.settings.conditionNum);
            
            % Remove NaNs
            X = X(~isnan(Y), :);
            Y = Y(~isnan(Y))';
            
            % The crucial line that calls the DMLT object train method
            tic
            DMLTtemp = DMLTtemp.train(X,Y);
            toc
            
            DMLout{c} = DMLTtemp;
        end
        
        %% DESCRIBE OUTPUTS
        EP = aap.tasklist.currenttask.settings;
        save(fullfile(aas_getsubjpath(aap,subj), 'DMLT.mat'), ...
            'DMLout', 'EP', 'DMLT', 'M')
        aap=aas_desc_outputs(aap,subj,'DMLT', fullfile(aas_getsubjpath(aap,subj), 'DMLT.mat'));
end