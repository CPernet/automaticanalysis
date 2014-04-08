% AA module - smoothing
% [aap,resp]=aamod_smooth(aap,task,subj,sess)
% Gaussian smoothing images, important for Gaussian Field Theory
% Kernel size determined by aap.spm_analysis.FWHM
% Rhodri Cusack MRC CBU Cambridge Jan 2006- Aug 2007
% Now once per session for improved performance when running in parallel

function [aap,resp]=aamod_smooth(aap,task,subj,sess)
resp='';

switch task
    case 'doit'
        
        % Is session specified in task header?
        if (isfield(aap.tasklist.currenttask.settings,'session'))
            sess = aap.tasklist.currenttask.settings.session;
        end
        
        streams=aap.tasklist.currenttask.inputstreams.stream;
        
        for streamind=1:length(streams)
            
            % Images to smooth
            if (exist('sess','var'))
                P = aas_getfiles_bystream(aap,subj,sess,streams{streamind});
            else
                P = aas_getfiles_bystream(aap,subj,streams{streamind});
            end
            
            %% TEMPORARY SOLUTION FOR 4D PROBLEM
            bigFile = false; % Boolean for 4D EPIimg, to cope with 32 bit SPM...
            if isfield(aap.options, 'NIFTI4D') && aap.options.NIFTI4D % 4D
                info4D = aa_dir(P);
                if info4D.bytes > 2*10^9
                    bigFile = true;
                end
            end
            
            if bigFile == true
                P4d = P;
                
                % ...instead we split them for now
                Vo = spm_file_split(P);
                P = cell2strvcat({Vo.fname});
            end
            %%
            
            % now smooth
            s   = aap.tasklist.currenttask.settings.FWHM;
            n   = size(P,1);
            
            spm_progress_bar('Init',n,'Smoothing','Volumes Complete');
            outputfns=[];
            for imnum = 1:n
                Q = deblank(P(imnum,:));
                [pth,nam,xt,nm] = spm_fileparts(deblank(Q));
                fn=['s' nam xt nm];
                U = fullfile(pth,fn);
                outputfns=strvcat(outputfns,U);
                % Ignore .hdr files from this list...
                if isempty(strfind(P(n,:), '.hdr'))
                    spm_smooth(Q,U,s);
                    spm_progress_bar('Set',imnum);
                end
            end
            
            %% TEMPORARY SOLUTION FOR 4D PROBLEM
            if bigFile == true
                [pth, nme, ext] = fileparts(P4d);
                P4d = fullfile(pth, ['s' nme ext]);
                
                spm_file_merge(P, P4d);
                
                % Delete old 3D files
                for k=1:size(P,1);
                    delete(deblank(P(k,:)));
                end
                outputfns = P4d;
            end
            %%
            
            % Describe outputs
            if (exist('sess','var'))
                aap=aas_desc_outputs(aap,subj,sess,streams{streamind},outputfns);
            else
                aap=aas_desc_outputs(aap,subj,streams{streamind},outputfns);
            end
            
        end;
        % All done
        spm_progress_bar('Clear');
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;