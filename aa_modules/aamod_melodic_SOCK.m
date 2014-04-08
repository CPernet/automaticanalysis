% AA module
% Runs MELODIC on all sessions of each single subject
% This automatically transforms the 3D data into 4D data as well
% [NOTE: This function may become obsolete later on]

function [aap,resp]=aamod_melodic_SOCK(aap,task,subj,sess)

resp='';

switch task
    
    case 'report'
        
    case 'doit'
        
        mriname = aas_prepare_diagnostic(aap, subj);
        sessPth = aas_getsesspath(aap,subj,sess);
        cd(sessPth)
        
        % Let us use the native space...
        EPIimg = aas_getfiles_bystream(aap,subj,sess,'epi');
        
        %% CONCATENATE THE DATA...
        data4D = aas_3d4dmerge(aap, sessPth, mriname, EPIimg);
                
        [pth, fn, ext] = fileparts(data4D);
        data4Dfiltered = fullfile(pth, ['d' fn ext]);
        
        outDir = fullfile(sessPth, 'MELODIC');
        cd(fullfile(outDir, 'stats'))
        
        %% MASKING
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
        
        %% RUN SOCK
        % SOCK should be in the matlab path for this to work...
        path_SOCK = fileparts(which('SOCK'));
        addpath(genpath(path_SOCK))
        
        SOCK_main([outDir, filesep], 1, path_SOCK);
        
        % Get components
        IC = [];
        load(fullfile(outDir, 'IC.mat'))
                
        %% FILTER COMPONENTS
        fprintf('\nRunning RegFilt\n')
        
        filteredComponents = sprintf('%d ', IC.artifacts);
        FSLcommand = sprintf('fsl_regfilt -i %s -d %s -o %s -m %s -f %s -v --debug', ...
            data4D, ...
            fullfile(outDir, 'melodic_mix'), ...
            data4Dfiltered, ...
            Mimg, ...
            filteredComponents(1:end-1));
        disp(FSLcommand)
        [junk, w] = aas_runfslcommand(aap, FSLcommand);
        disp(w);
        
        %% Find filtered components...
        % Get all probability maps and frequencies
        C = dir(fullfile(outDir, 'stats', 'probmap_*.nii'));
        
        % Read output and get components that are filtered
        compClean = IC.non_artifacts;        
        compFiltered = IC.artifacts;
        compAll = sort([compClean compFiltered]);
        
        % Save the identities of the filtered and clean components...
        save(fullfile(sessPth, 'components.mat'), 'compClean', 'compFiltered')
        
        % Average probability maps and spectra of filtered components
        probmapFiltered = 0;
        spectFiltered = 0;
        for c = compFiltered
            % Pmap
            V = spm_vol(fullfile(outDir, 'stats', sprintf('probmap_%d.nii', c)));
            probmapFiltered = probmapFiltered + spm_read_vols(V);
            % Spectrum
            spectFiltered = spectFiltered + load(fullfile(outDir, 'report', sprintf('f%d.txt', c)));
        end
        probmapFiltered = probmapFiltered/length(compFiltered);
        spectFiltered = spectFiltered/length(compFiltered);
        
        % Save probmap
        V.fname = fullfile(sessPth, 'probmap_Filtered.nii');
        spm_write_vol(V, probmapFiltered);
        % Save and plot spectrum
        save(fullfile(sessPth, 'spect_Filtered.mat'), 'spectFiltered');
        
        % Average probability maps and spectra of filtered components
        probmapClean = 0;
        spectClean = 0;
        for c = compClean
            % Pmap
            V = spm_vol(fullfile(outDir, 'stats', sprintf('probmap_%d.nii', c)));
            probmapClean = probmapClean + spm_read_vols(V);
            % Spectrum
            spectClean = spectClean + load(fullfile(outDir, 'report', sprintf('f%d.txt', c)));
        end
        probmapClean = probmapClean/length(compFiltered);
        spectClean = spectClean/length(compClean);
        
        % Save probmap
        V.fname = fullfile(sessPth, 'probmap_Clean.nii');
        spm_write_vol(V, probmapClean);
        % Save and plot spectrum
        save(fullfile(sessPth, 'spect_Clean.mat'), 'spectClean');
        
        %% DECOMPOSE FILTERED DATA INTO IMAGES
        M = 0;
        
        if size(EPIimg,1) == 1
            dEPIimg = data4Dfiltered;
        else
            [junk, w]=aas_runfslcommand(aap, ...
                sprintf('fslsplit %s', ...
                data4Dfiltered));
            
            dEPIimg = cell(size(EPIimg,1), 1);
            for e = 1:size(EPIimg,1)
                [pth, nme, ext] = fileparts(EPIimg(e,:));
                dEPIimg{e} = fullfile(pth, ['d' nme ext]);
                
                movefile(sprintf('vol%04d.nii', e-1), dEPIimg{e})
                
                V = spm_vol(EPIimg(e,:));
                Y = spm_read_vols(V); % not denoised data...
                
                dY = spm_read_vols(spm_vol(dEPIimg{e}));
                
                M = M + abs(Y - dY);
                
                V.fname = dEPIimg{e};
                spm_write_vol(V, dY);
            end
            V.fname = fullfile(pth, 'MELODIC_noise.nii');
            spm_write_vol(V, M);
            
            % Delete filtered 4D file once we finish, since we split it...
            delete(data4Dfiltered)
        end
        
        %% DIAGNOSTIC spectrum
        
        h = figure;
        hold on
        plot(spectClean, 'ob');
        plot(spectFiltered, 'or');
        axis tight
        legend({sprintf('Clean (%d)', length(compClean)), sprintf('Filtered (%d)', length(compFiltered))})
        maxX = 100/(TR*2);
        ticksX = get(gca, 'xtick') * maxX / length(spectFiltered);
        set(gca, 'xticklabel', ticksX);
        xlabel('Frequency (in Hz/100')
        ylabel('Power')
        title('Mean powerspectrum of timecourses')
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '_Spectrum_' aap.acq_details.sessions(sess).name '.jpeg']));
        close(h);
        
        %% DIAGNOSTIC series
        try
            h = img2deltaseries(EPIimg, dEPIimg, {'Raw', 'Denoised', 'Delta'});
            
            print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '_Series_' aap.acq_details.sessions(sess).name '.jpeg']));
            close(h);
        catch
            aas_log(aap,false, 'Normal calls to spm_read_vols may fail with files greater than 2GB')
        end
        %% DESCRIBE OUTPUTS!
        
        % Delete original 4D file once we finish!
        delete(data4D)
        
        % Delete mask if this is one we created...
        if isempty(BETimg)
            delete(Mimg);
        end
        
        aap=aas_desc_outputs(aap,subj,sess,'epi', dEPIimg);        
end