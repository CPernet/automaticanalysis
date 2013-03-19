% AA module - realignment
% [aap,resp]=aamod_realign(aap,task,subj)
% Motion correction of EPI images (a.k.a. realignment) using SPM5
% Rhodri Cusack MRC CBU 2004-6 based on original by Matthew Brett
% Modified by Rik Henson 2006-8 to accept reslice "which" option
% 	(plus more defaults can be passed)

function [aap,resp]=aamod_realign(aap,task,subj)

resp='';

switch task
    case 'description'
        resp='SPM5 realignment';
    case 'summary'
        resp='Done SPM5 realignment\n';
    case 'report'
        mvmean=[];
        mvmax=[];
        mvstd=[];
        mvall=[];
        nsess=length(aap.acq_details.sessions);
        
        qq=[];
        for sess=1:nsess
            % New style, retrieve all the files in a stream
            imfn=aas_getimages_bystream(aap,subj,sess,'epi');
            
            imV=spm_vol(imfn);
            mv=[];
            for k=1:length(imV)
                tmp=spm_imatrix(imV(k).mat);
                mv=[mv;tmp(1:6)];
            end
            if (sess==1)
                firstscan=mv(1,:);
            end
            mv=mv-repmat(firstscan,[size(mv,1) 1]);
            
            mv(:,4:6)=mv(:,4:6)*180/pi; % convert to degrees!
            mvmean(sess,:)=mean(mv);
            mvmax(sess,:)=max(mv);
            mvstd(sess,:)=std(mv);
            mvall=[mvall;mv];
        end
        
        aap.report.html=strcat(aap.report.html,'<h3>Movement maximums</h3>');
        aap.report.html=strcat(aap.report.html,'<table cellspacing="10">');
        aap.report.html=strcat(aap.report.html,sprintf('<tr><td align="right">Sess</td><td align="right">x</td><td align="right">y</td><td align="right">z</td><td align="right">rotx</td><td align="right">roty</td><td align="right">rotz</td></tr>',sess));
        for sess=1:nsess
            aap.report.html=strcat(aap.report.html,sprintf('<tr><td align="right">%d</td>',sess));
            aap.report.html=strcat(aap.report.html,sprintf('<td align="right">%8.3f</td>',mvmax(sess,:)));
            aap.report.html=strcat(aap.report.html,sprintf('</tr>',sess));
        end
        aap.report.html=strcat(aap.report.html,'</table>');
        
        aap=aas_report_addimage(aap,fullfile(aas_getsubjpath(aap,subj),'diagnostic_aamod_realign.jpg'));
        
    case 'doit'
        % Get realignment defaults
        defs = aap.spm.defaults.realign;
        
        % Flags to pass to routine to calculate realignment parameters
        % (spm_realign)
        reaFlags = struct(...
            'quality', defs.estimate.quality,...  % estimation quality
            'fwhm', defs.estimate.fwhm,...        % smooth before calculation
            'rtm', defs.estimate.rtm,...          % whether to realign to mean
            'interp', defs.estimate.interp,...    % interpolation type
            'wrap', defs.estimate.wrap,...        % wrap in (x) y (z)
            'sep', defs.estimate.sep...          % interpolation size (separation)
            );
        
        % Flags to pass to routine to create resliced images
        % (spm_reslice)
        resFlags = struct(...
            'interp', defs.write.interp,...       % interpolation type
            'wrap', defs.write.wrap,...           % wrapping info (ignore...)
            'mask', defs.write.mask,...           % masking (see spm_reslice)
            'which', aap.tasklist.currenttask.settings.reslicewhich,...     % what images to reslice
            'mean', aap.tasklist.currenttask.settings.writemean);           % write mean image
        
        clear imgs;
        for sess = aap.acq_details.selected_sessions %
            % get files from stream
            imgs(sess) = {aas_getimages_bystream(aap,subj,sess,'epi');};
        end
        
        % [AVG] This will ensure that any printing commands of SPM are done in the subject directory...
        cd(aas_getsubjpath(aap,subj))
        
        % Run the realignment
        spm_realign(imgs);
        
        if (~isdeployed)
            % Save graphical output
            try figure(spm_figure('FindWin', 'Graphics')); catch; figure(1); end
            print('-djpeg','-r150',fullfile(aas_getsubjpath(aap,subj),'diagnostic_aamod_realign'));
        end
        
        % Run the reslicing
        spm_reslice(imgs, resFlags);
        
        %% Describe outputs
        movPars = {};
        for sess = aap.acq_details.selected_sessions
            aas_log(aap,0,sprintf('Working with session %s', sess))
            
            rimgs=[];
            for k=1:size(imgs{sess},1);
                [pth nme ext]=fileparts(imgs{sess}(k,:));
                
                % If we don't reslice the images after realignment, don't
                % change the prefix of the images in our output stream
                %   - cwild 03/06/12
                if aap.tasklist.currenttask.settings.reslicewhich == 0            
                    rimgs=strvcat(rimgs,fullfile(pth,[nme ext]));
                else
                    rimgs=strvcat(rimgs,fullfile(pth,['r' nme ext]));
                end
            end
            sessdir=aas_getsesspath(aap,subj,sess);
            aap = aas_desc_outputs(aap,subj,sess,'epi',rimgs);
            
            % Get the realignment parameters...
            fn=dir(fullfile(pth,'rp_*.txt'));
            outpars = fullfile(pth,fn(1).name); 
            % Add it to the movement pars...
            movPars = [movPars outpars];
            
            aap = aas_desc_outputs(aap,subj,sess,'realignment_parameter', outpars);
            
            if find(sess==aap.acq_details.selected_sessions) == 1 % [AVG!]
                % mean only for first session
                fn=dir(fullfile(pth,'mean*.nii'));
                aap = aas_desc_outputs(aap,subj,'meanepi',fullfile(pth,fn(1).name));
            end
        end
        
        %% DIAGNOSTICS
        mriname = aas_prepare_diagnostic(aap,subj);
        
        aas_realign_graph(movPars)
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '_MP.jpeg']));
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end