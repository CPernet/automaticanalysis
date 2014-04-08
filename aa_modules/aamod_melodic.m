% AA module
% Runs MELODIC on all sessions of each single subject
% This automatically transforms the 3D data into 4D data as well
% [NOTE: This function may become obsolete later on]

function [aap,resp]=aamod_melodic(aap,task,subj,sess)

resp='';

switch task
    
    case 'report'
        
    case 'doit'
        
        mriname = aas_prepare_diagnostic(aap, subj);
        sessPth = aas_getsesspath(aap,subj,sess);
        cd(sessPth)
        
        %% retrieve TR from DICOM header
        % TR is manually specified (not recommended as source of error)
        if isfield(aap.tasklist.currenttask.settings,'TR') && ...
                ~isempty(aap.tasklist.currenttask.settings.TR)
            TR =aap.tasklist.currenttask.settings.TR;
        else
            % Get TR from DICOM header
            DICOMHEADERS=load(aas_getfiles_bystream(aap,subj,sess,'epi_dicom_header'));
            try
                TR = DICOMHEADERS.DICOMHEADERS{1}.volumeTR;
            catch
                % [AVG] This is for backwards compatibility!
                TR = DICOMHEADERS.DICOMHEADERS{1}.RepetitionTime/1000;
            end
        end
        
        % Let us use the native space...
        EPIimg = aas_getfiles_bystream(aap,subj,sess,'epi');
        
        % Do we already have a mask?
        BETimg = aas_findstream(aap, 'mask', subj);
        if isempty(BETimg)
            % Create mask that ignores everything that is not a number...
            V = spm_vol(EPIimg);
            Y = spm_read_vols(V(1));
            M = Y ~= 0 | ~isfinite(Y);
            Mimg = fullfile(sessPth, 'mask.nii');
            V(1).fname = Mimg;
            spm_write_vol(V(1), M);
        else
            Mimg = BETimg;
            M = spm_read_vols(spm_vol(Mimg));
        end
        if size(Mimg, 1) > 1
            aas_log(aap, false, 'More than one masking image found, using first!')
            Mimg = Mimg(1,:); 
        end
        aas_log(aap, false, sprintf('Mask contains %d voxels', sum(M(:))));
        clear M
        
        %% CONCATENATE THE DATA...
        data4D = aas_3d4dmerge(aap, sessPth, mriname, EPIimg);
                
        [pth, fn, ext] = fileparts(data4D);
        data4Dsmoothed = fullfile(pth, ['s' fn ext]);
        
        %% SMOOTH (IF REQUIRED)
        if ~isempty(aap.tasklist.currenttask.settings.FWHM)
            fprintf('Smoothing with a %0.4f FWHM kernel\n', aap.tasklist.currenttask.settings.FWHM);
            
            FSLcommand = sprintf('fslmaths %s -kernel gauss %0.7f -fmean %s', ...
                data4D, ...
                aap.tasklist.currenttask.settings.FWHM / sqrt(8*log(2)), ... % Convert FWHM to sigma...
                data4Dsmoothed);
            disp(FSLcommand)
            [junk, w] = aas_runfslcommand(aap, FSLcommand);
            disp(w);
        else
            data4Dsmoothed = data4D;
        end
        
        %% RUN MELODIC
        fprintf('\nRunning MELODIC\n')
        
        outDir = fullfile(sessPth, 'MELODIC');
        if ~exist(outDir, 'dir')
            mkdir(outDir)
        end
        
        FSLcommand = sprintf('melodic -i %s %s -o %s -m %s --tr=%0.4f', ...
            data4Dsmoothed, ...
            aap.tasklist.currenttask.settings.MELODICoptions, ...
            outDir, ...
            Mimg, ...
            TR);
        disp(FSLcommand)
        [junk, w] = aas_runfslcommand(aap, FSLcommand);
        disp(w);
        
        %% DESCRIBE OUTPUTS
        %
        % MAKE A SEPARATE FUNCTION OF THIS SOMETIME?
        melodicFiles = [];
        fldrDir = genpath(outDir);
        % Then recurse inside each directory until you run out of paths
        while ~isempty(strtok(fldrDir, ':'))
            % Get each of the directories made by gendir
            [fldrCurr fldrDir] = strtok(fldrDir, ':');
            % Check it's not a .svn folder
            D = aa_dir(fldrCurr);
            for d = 1:length(D)
                if ~D(d).isdir
                    melodicFiles = strvcat(melodicFiles, fullfile(fldrCurr, D(d).name));
                else
                    % It is an invisible folder
                end
            end
        end
        %}
        
        aap=aas_desc_outputs(aap,subj,sess,'melodic', melodicFiles);
        
        % Delete original 4D file once we finish!
        delete(data4D)
        try delete(data4Dsmoothed); catch; end
        
        % Delete mask if this is one we created...
        if isempty(BETimg)
            delete(Mimg);
        end
        
end