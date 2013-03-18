% AA module - smoothing
% [aap,resp]=aamod_smooth(aap,task,subj,sess)
% Gaussian smoothing images, important for Gaussian Field Theory
% Kernel size determined by aap.spm_analysis.FWHM
% Rhodri Cusack MRC CBU Cambridge Jan 2006- Aug 2007
% Now once per session for improved performance when running in parallel

function [aap,resp]= aamod_ggmfit(aap,task,subj,sess)
resp='';

switch task
    case 'doit'
        
        % Is session specified in task header?
        if (isfield(aap.tasklist.currenttask.settings,'session'))
            sess = aap.tasklist.currenttask.settings.session;
        end
        
        streams=aap.tasklist.currenttask.inputstreams.stream;
        
        for streamind=1:length(streams)
            
            % Images to ggmfit
            if (exist('sess','var'))
                P = aas_getfiles_bystream(aap,subj,sess,streams{streamind});
            else
                P = aas_getfiles_bystream(aap,subj,streams{streamind});
            end
            
            % now ggmfit
            for p = 1:size(P,1)
                V = spm_vol(P(p,:));
                Y = spm_read_vols(V);
                
                % Only non-zero non-nan values of image...
                M = and(~isnan(Y), Y~=0);
                
                ggmmix = ggmfit(Y(M));
                Y(M) = (Y(M) - ggmmix.mus(1)) ./ ggmmix.sig(1);
                
                spm_write_vol(V,Y);
            end
            
            % Describe outputs
            if (exist('sess','var'))
                aap=aas_desc_outputs(aap,subj,sess,streams{streamind},P);
            else
                aap=aas_desc_outputs(aap,subj,streams{streamind},P);
            end
            
        end;
        % All done
        spm_progress_bar('Clear');
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;



