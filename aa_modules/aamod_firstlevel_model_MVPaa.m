% AA module - first level statistics
% This module is based on the work by Mumford, Turner, Ashby & Poldrack,
% 2012, Neuroimage 59 (2012)
% Essentially, this makes a separate model for each regressor, allowing to
% model events such that the betas extracted are less correlated with one
% another, theoretically improving power in the MVPA analysis
% Meant to be used for rapid event-related designs
% **********************************************************************
% You should no longer need to change this module - you may just
% modify the .xml or model in your user script
% **********************************************************************
% Based on original by FIL London and Adam Hampshire MRC CBU Cambridge Feb 2006
% Modified for aa by Rhodri Cusack MRC CBU Mar 2006-Aug 2007
% Thanks to Rik Henson for various suggestions

function [aap,resp]=aamod_firstlevel_model_MVPaa(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        % Get subject directory
        cwd=pwd;
        
        % Prepare basic SPM model...
        [SPM, anadir, files, allfiles, model, modelC] = aas_firstlevel_model_prepare(aap, subj);
        
        % Get all the nuisance regressors...
        [movementRegs, compartmentRegs, physiologicalRegs, spikeRegs] = ...
            aas_firstlevel_model_nuisance(aap, subj, files);
        
        %% Set up CORE model
        coreSPM = SPM;
        cols_nuisance=[];
        cols_interest=[];
        currcol=1;
        
        sessnuminspm=0;
        
        for sess = aap.acq_details.selected_sessions
            sessnuminspm=sessnuminspm+1;
            
            % Settings
            SPM.nscan(sessnuminspm) = size(files{sess},1);
            SPM.xX.K(sessnuminspm).HParam = aap.tasklist.currenttask.settings.highpassfilter;
            
            % Set up model
            [SPM, cols_interest, cols_nuisance, currcol] = ...
                aas_firstlevel_model_define(aap, sess, sessnuminspm, SPM, model, modelC, ...
                cols_interest, cols_nuisance, currcol, ...
                movementRegs, compartmentRegs, physiologicalRegs, spikeRegs);
        end
        
        cd (anadir)
        
        SPM.xY.P = allfiles;
        SPMdes = spm_fmri_spm_ui(SPM);
        
        %% DIAGNOSTIC
        mriname = aas_prepare_diagnostic(aap, subj);
        try
            saveas(1, fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '.fig']));
        catch
        end
        
        % now check real covariates and nuisance variables are
        % specified correctly
        SPMdes.xX.iG=cols_nuisance;
        SPMdes.xX.iC=cols_interest;
        
        % Turn off masking if requested
        if ~aap.tasklist.currenttask.settings.firstlevelmasking
            SPMdes.xM.I=0;
            SPMdes.xM.TH=-inf(size(SPMdes.xM.TH));
        end
        
        spm_unlink(fullfile('.', 'mask.img')); % avoid overwrite dialog
        SPMest = spm_spm(SPMdes);
        
        %% REDO MODEL WITH Mumford/Poldrak method...
        
        % Find out how large the model{sess} should be (per session)
        eventNumber = [];
        sessNumber = [];
        for sess = aap.acq_details.selected_sessions
            eventNumber = [eventNumber 1:size(model{sess}.event,2)];
            sessNumber = [sessNumber sess*ones(1,size(model{sess}.event,2))];
        end
        sessRegs = 1:max(eventNumber);
        
        Tmodel{sess} = cell(size(model));
        
        for n = sessRegs
            % Make temporary directory inside folder
            Tanadir = (fullfile(anadir, sprintf('temp_%03d', n)));
            
            try rmdir(Tanadir); catch; end
            mkdir(Tanadir)
            
            cols_nuisance=[];
            cols_interest=[];
            sessnuminspm=1;
            currcol=1;
            rSPM = coreSPM;
            
            for sess = aap.acq_details.selected_sessions
                
                rSPM.nscan(sessnuminspm) = size(files{sess},1);
                rSPM.xX.K(sessnuminspm).HParam = aap.tasklist.currenttask.settings.highpassfilter;
                
                % * Get noise regressor numbers
                noiseRegs = eventNumber(sessNumber == sess);
                if ismember(n, noiseRegs)
                    noiseRegs(n) = [];
                end
                
                % No need to check model{sess} again, did already before...
                Tmodel{sess} = model{sess};
                Tmodel{sess}.event = [];
                % Event names, rather simple...
                Tmodel{sess}.event(1).name = 'Noise';
                % I don't see a way to do parameteric stuff here
                Tmodel{sess}.event(1).parametric = [];
                % Easy to set up the Regressor event
                try
                    Tmodel{sess}.event(2).ons = model{sess}.event(n).ons;
                    Tmodel{sess}.event(2).dur = model{sess}.event(n).dur;
                    Tmodel{sess}.event(2).name = 'Reg';
                    Tmodel{sess}.event(2).parametric = [];
                catch
                    % If we can't model that event... don't model it
                end
                % Trickier for the Noise event
                Tons = [];
                Tdur = [];
                for r = noiseRegs
                    % Make sure we don't include the modelled regressor in
                    % the noise regressor
                    Tons = [Tons; model{sess}.event(r).ons(:)];
                    Tdur = [Tdur; model{sess}.event(r).dur(:)];
                end
                
                % Sort the onsets, and apply same reordering to durations
                [Tons, ind]=sort(Tons);
                if (length(Tdur)>1)
                    Tdur=Tdur(ind);
                end
                Tmodel{sess}.event(1).ons = Tons;
                Tmodel{sess}.event(1).dur = Tdur;
                
                rSPM.Sess(sessnuminspm).C.C = [];
                rSPM.Sess(sessnuminspm).C.name = {};
                
                [rSPM, cols_interest, cols_nuisance, currcol] = aas_firstlevel_model_define(aap, sess, sessnuminspm, rSPM, Tmodel, modelC, ...
                    cols_interest, cols_nuisance, currcol, ...
                    movementRegs, compartmentRegs, physiologicalRegs, spikeRegs);

            end
            cd(Tanadir)
            
            % DEBUG
            %{
            if n == 1
                subplot(3,1,1); plot(SPMdes.xX.X(1:100,1:sessRegs(end))); title('Normal model')
                subplot(3,1,2); plot(rSPMdes.xX.X(1:100,1:2)); title('New model')
                subplot(3,1,3); plot([SPMdes.xX.X(1:100,1) sum(SPMdes.xX.X(1:100,2:sessRegs(end)),2)]); title('Old model, summed')
            end
            %}
            
            rSPM.xY.P = allfiles;
            rSPMdes = spm_fmri_spm_ui(rSPM);
            
            % now check real covariates and nuisance variables are
            % specified correctly
            rSPMdes.xX.iG=cols_nuisance;
            rSPMdes.xX.iC=cols_interest;
            
            % Turn off masking if requested
            if ~aap.tasklist.currenttask.settings.firstlevelmasking
                SPMdes.xM.I=0;
                SPMdes.xM.TH=-inf(size(SPMdes.xM.TH));
            end
            
            spm_unlink(fullfile('.', 'mask.img')); % avoid overwrite dialog
            rSPMest = spm_spm(rSPMdes);
            
            % After this, move the betas to correct location
            % Find the regressors we wish to move...
            % They contain the string Reg...
            nOrig = find(~cellfun('isempty', strfind(rSPMest.xX.name, 'Reg')));
            
            % determined by the number of regressors per session in SPMest
            nDest = SPMest.xX.iC(eventNumber==n);
            
            % Now move the actual files
            for f = 1:length(nOrig)
                unix(['mv ' fullfile(Tanadir, sprintf('beta_%04d.img', nOrig(f))) ...
                    ' ' fullfile(anadir, sprintf('beta_%04d.img', nDest(f)))]);
                unix(['mv ' fullfile(Tanadir, sprintf('beta_%04d.hdr', nOrig(f))) ...
                    ' ' fullfile(anadir, sprintf('beta_%04d.hdr', nDest(f)))]);
            end
        end
        cd(anadir)
        unix('rm -rf temp_*');
        
        %% Describe outputs
        cd (cwd);
        
        % Describe outputs
        %  firstlevel_spm
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm',fullfile(anadir,'SPM.mat'));
        
        %  firstlevel_betas (includes related statistical files)
        allbetas=dir(fullfile(anadir,'beta_*'));
        betafns=[];
        for betaind=1:length(allbetas);
            betafns=strvcat(betafns,fullfile(anadir,allbetas(betaind).name));
        end
        if ~aap.tasklist.currenttask.settings.firstlevelmasking
            otherfiles={'ResMS.hdr','ResMS.img','RPV.hdr','RPV.img'};
        else
            otherfiles={'mask.hdr','mask.img','ResMS.hdr','ResMS.img','RPV.hdr','RPV.img'};
        end
        for otherind=1:length(otherfiles)
            betafns=strvcat(betafns,fullfile(anadir,otherfiles{otherind}));
        end
        aap=aas_desc_outputs(aap,subj,'firstlevel_betas',betafns);
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end