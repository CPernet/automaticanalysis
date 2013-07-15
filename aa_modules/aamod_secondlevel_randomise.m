% AA module - second level statistics
% Only runs if all contrasts present in same order in all subjects at first
% level. If so, makes model with basic t-test for each of contrasts.
% Second-level model from Rik Henson
% Modified for aa by Rhodri Cusack May 2006
%

function [aap,resp]=aamod_secondlevel_randomise(aap,task)

resp='';

switch task
    case 'doit'
        
        nsub = length(aap.acq_details.subjects);
        options = aap.tasklist.currenttask.settings.options;
        
        aas_log(aap,false, sprintf('%d subjects',nsub));
        aas_log(aap, false, sprintf('Will run randomise with options: %s', options));
             
        conFn = cell(1, nsub);
        
        % Get the stream we want to run randomise on
        streams = aap.tasklist.currenttask.inputstreams.stream{:};
        
        % Get data for each subject...
        for subj = 1:nsub            
            % Get the confiles in order...
            conFn{subj} = aas_findstream(aap, streams, subj);
            
            % Get rid of .hdr files if these exist...
            for n = size(conFn{subj}, 1):-1:1
                [pth, nme, ext] = fileparts(deblank(conFn{subj}(n,:)));
                if strcmp(ext, '.hdr')
                    conFn{subj}(n,:) = [];
                end
            end
            
            % We need equal numbers of images across subjects...
            if subj > 1 && size(conFn{subj}, 1) ~= size(conFn{subj - 1}, 1)
                aas_log(aap, true, 'Different number of contrasts across subjects!');
            else
                V = spm_vol(deblank(conFn{subj}(1,:)));
                img_size = V.dim(1) * V.dim(2) * V.dim(3);
            end
        end
        
        fprintf('Merge data for all subjects\n')
        aapCell = cell(1, size(conFn{1}, 1));
        FSLrandomiseCell = cell(1, size(conFn{1}, 1));
        mergedData = cell(1, size(conFn{1}, 1));
        maskData = cell(1, size(conFn{1}, 1));
        
        pth = aas_getstudypath(aap);
        
        for n = 1:size(conFn{1}, 1)
            fprintf('Merging data for contrast %d\n', n)
            
            mergedData{n} = fullfile(pth, sprintf('dataMerged_%04d.nii', n));
            unmergedData = '';
            for subj = 1:nsub
                mask_img([], conFn{subj}(n, :), 0)
                unmergedData = [unmergedData conFn{subj}(n, :) ' '];
            end
            
            FSLmerge = ['fslmerge -t ' mergedData{n} ' ' unmergedData];
            [s, w] = aas_runfslcommand(aap, FSLmerge);
            
            % maskData
            V = spm_vol(mergedData{n});
            Y = spm_read_vols(V);
            V = V(1);
            maskData{n} = fullfile(pth, sprintf('mask_%04d.nii', n));
            V.fname = maskData{n};
            M = all(Y ~= 0, 4);
            spm_write_vol(V, M);
            
            aapCell{n} = aap;
            FSLrandomiseCell{n} = ['randomise -i ' mergedData{n} ' -m ' maskData{n} ' -o ' ... 
                fullfile(pth, sprintf('fslT_%04d', n)) ' -1 ' options];
        end        
        
        switch aap.tasklist.currenttask.settings.parallel
            case {'none', 'serial'}
                for n = 1:conFn{1}
                    fprintf('Running randomise on contrast %d\n', n)
                    
                    [s, w] = aas_runfslcommand(aap, FSLrandomise{n});
                end
            case 'torque'
                memreq = 4 * 64 * img_size * length(conFn);
                timreq = 4 * 3600;
                aas_log(aap, false, sprintf('Submitting jobs with %0.2f MB and %0.2f hours', ...
                    memreq/(1024^2), timreq/3600))
                
                [s, w] = qsubcellfun(@aas_runfslcommand, ...
                    aapCell, FSLrandomiseCell, ...
                    'memreq', memreq, ...
                    'timreq', timreq, ...
                    'stack', 1 ...
                    );
        end
        
        fprintf('Clean up merged data\n')
        for n = 1:size(conFn{1}, 1)
            delete(mergedData{n});
            delete(maskData{n});
        end
        
        %% DECLARE OUTPUTS
        fsltfns = '';
        allfslts=dir(fullfile(pth, 'fslT_*'));
        for f=1:length(allfslts);
            fsltfns=strvcat(fsltfns,fullfile(pth, allfslts(f).name));
        end
        aap=aas_desc_outputs(aap,'secondlevel_fslts', fsltfns);
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end



