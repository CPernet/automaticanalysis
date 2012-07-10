% AA module
% Runs EPI slicing after BET
% aamod_realign should be run before running this module

function [aap,resp]=aamod_bet_tSNR(aap,task,subj)

resp='';

switch task
    case 'summary'
        subjpath=aas_getsubjpath(subj);
        resp=sprintf('Align %s\n',subjpath);
        
    case 'report'
        
    case 'doit'
        
        % Get images...        
        betEPIimg = aas_getfiles_bystream(aap,subj,'epiBETmask');
        [betEPIpth, betEPIfn, betEPIext] = fileparts(betEPIimg);
        
        % Select the SNR images...
        sessions = aap.tasklist.currenttask.settings.sessions;
        if isempty(sessions);
            sessions = aap.acq_details.selected_sessions;
        end
        tSNR = 0;
        % ...add session tSNRs...
        for sess = sessions
            V = spm_vol(aas_getfiles_bystream(aap,subj,sess,'tSNR'));
            tSNR = tSNR + spm_read_vols(V);
        end
        % ... and average.
        tSNR = tSNR ./ length(sessions);
        
        % Mask the tSNR image...
        fprintf('Masking the tSNR EPI with %s \n', aap.tasklist.currenttask.settings.maskBrain)
        % Get mask...
        M =[];
        for m = 1:size(betEPIimg,1)
            if ~isempty(strfind(betEPIimg(m,:), aap.tasklist.currenttask.settings.maskBrain))
                M = spm_read_vols(spm_vol(deblank(betEPIimg(m,:))));
                M = M > 0;
                break
            end
        end
        if isempty(M)
            aas_log(aap,true,'We do not have a mask!')
        end
        tSNR = tSNR .* M;
        SNRimg = fullfile(betEPIpth, ['tSNR_' betEPIfn betEPIext]);
        V.fname = SNRimg;
        
        if strcmp(aap.tasklist.currenttask.settings.transform, 'none')
            spm_write_vols(V,tSNR);
        elseif strcmp(aap.tasklist.currenttask.settings.transform, 'ANTS')
            % For ANTS we want to do an inverse transform then scale it
            % from 0 to 1
            % First invert!
            tSNR = -tSNR;
            % Then find out maximum and minimum
            tSNRvals = tSNR(tSNR<0);
            tSNRmax = max(tSNRvals);
            tSNRmin = min(tSNRvals);
            tSNR(tSNR<0) = (tSNRvals - tSNRmin) ./ (tSNRmax - tSNRmin);
            
            % Write the image...
            spm_write_vols(V,tSNR);
            
            keyboard % @@@@@@
            rescale4coreg(SNRimg)
            % @@@ 95 % porcentile? square distribution?
        else
            aas_log(aap, true, ['No such transform exists in' mfilename ' module'])
        end
        
        % Save graphical output to common diagnostics directory
        if ~exist(fullfile(aap.acq_details.root, 'diagnostics'), 'dir')
            mkdir(fullfile(aap.acq_details.root, 'diagnostics'))
        end
        mriname = strtok(aap.acq_details.subjects(subj).mriname, '/');
        
        % Show image of tSNR
        spm_check_registration(tSNRimg)
        
        spm_orthviews('reposition', [0 0 0])
        
        try figure(spm_figure('FindWin', 'Graphics')); catch; figure(1); end;
        set(gcf,'PaperPositionMode','auto')
        print('-djpeg','-r75',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
        
        %% Diagnostic VIDEO of masks
        if aap.tasklist.currenttask.settings.diagnostic
            
            Ydims = {'X', 'Y', 'Z'};
            for d = 1:length(Ydims)
                aas_image_avi( SNRimg, ...
                    deblank(betEPIimg(m,:)), ...
                    fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                    d, ... % Axis
                    [800 600], ...
                    1); % Rotations
            end
            try close(2); catch; end
        end
        
        %% DESCRIBE OUTPUTS!
        aap=aas_desc_outputs(aap,subj,'tSNR',SNRimg);
end
