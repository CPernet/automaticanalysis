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
        aas_log(aap,false,sprintf('%d subjects',nsub));
        
        SPMts2fn = aas_getfiles_bystream(aap,'secondlevel_spmts');
        SPM2fn = aas_getfiles_bystream(aap,'secondlevel_spm');
        
        % Get data for each subject...
        for subj = 1:nsub
            SPMfn{subj}=aas_getfiles_bystream(aap,subj,'firstlevel_spm');
            
            % Get the confiles in order...
            % try first to get Cons, then Ts, then Fs
            conFn{subj} = aas_findstream(aap,'firstlevel_cons', subj);
            if isempty(conFn{subj})
                conFn{subj} = aas_findstream(aap,'firstlevel_spmts', subj);
            end
            if isempty(conFn{subj})
                conFn{subj} = aas_findstream(aap,'firstlevel_spmfs', subj);
            end
        end
        
        for n = 1:size(SPM2fn, 1)
            % PLAN:
            % run randomise on data
            pth = fileparts(deblank(SPM2fn(n, :)));
            mergedData = fullfile(pth, 'dataMerged.nii');
            unmergedData = '';
            for subj = 1:nsub
                mask_img([], conFn{subj}(n, :), 0)
                unmergedData = [unmergedData conFn{subj}(n, :) ' '];
            end
            
            FSLmerge = ['fslmerge -t ' mergedData ' ' unmergedData];
            [s, w] = aas_runfslcommand(aap, FSLmerge);
            %disp(w);
            
            % We force variance smoothing currently
            fprintf('Running randomise on contrast %d\n', n)
            FSLrandomise = ['randomise -i ' mergedData ' -o ' fullfile(pth, 'fslT') ' -1 -T -v 5'];
            [s, w] = aas_runfslcommand(aap, FSLrandomise);
            %disp(w);            
            
        end
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end



