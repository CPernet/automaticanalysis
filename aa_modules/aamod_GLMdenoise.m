% AA module - first level statistics
% **********************************************************************
% You should no longer need to change this module - you may just
% modify the .xml or model in your user script
% **********************************************************************
% Based on original by FIL London and Adam Hampshire MRC CBU Cambridge Feb 2006
% Modified for aa by Rhodri Cusack MRC CBU Mar 2006-Aug 2007
% Thanks to Rik Henson for various suggestions

function [aap,resp]=aamod_GLMdenoise(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        memtic
        
        % Stimulus Duration in seconds...
        stimdur = aap.tasklist.currenttask.settings.stimdur;
        % Options for GLMdenoise
        opt = aap.tasklist.currenttask.settings.opt;
        optFN = fieldnames(opt);
        for o = 1:length(optFN)
            if isempty(opt.(optFN{o}))
               opt = rmfield(opt, optFN{o});
            end
        end
        
        % Prepare basic SPM model...
        [SPM, anadir, files, allfiles, model, modelC] = aas_firstlevel_model_prepare(aap, subj);
        TR = SPM.xY.RT;
        
        gd_data = cell(1, length(aap.acq_details.selected_sessions));
        for s = 1:length(aap.acq_details.selected_sessions);
            sess = aap.acq_details.selected_sessions(s);
            aas_log(aap, 0,  sprintf('Loading gd_data and model of sess %d', sess));
            
            % Get gd_data
            V = spm_vol(files{sess}(1,:));
            gd_data{s} = single(nan(V.dim(1), V.dim(2), V.dim(3), size(files{sess},1)));
            for f = 1:size(files{sess},1)
                gd_data{s}(:,:,:,f) = spm_read_vols(spm_vol(files{sess}(f,:)));
            end
        end
        
        memtoc
        
        switch aap.tasklist.currenttask.settings.GDmode
            case ''
                aas_log(aap, 1, 'You must specify the GDmode parameter, which sets how we use GLMdenoise')
            case 'onsets'
                hrfmodel = 'assume';
                hrfknobs = [];
                
                clear SPM
                
                if isempty(stimdur)
                    aas_log(aap, 1, 'You should specify the stimulus duration (in seconds) in your recipe');
                end
                
                gd_design = cell(1, length(aap.acq_details.selected_sessions));
                for s = 1:length(aap.acq_details.selected_sessions);
                    sess = aap.acq_details.selected_sessions(s);
                    
                    % Set up model
                    gd_ons = cell(1, length(model{sess}.event));
                    for e = 1:length(model{sess}.event)
                        ons = (model{sess}.event(e).ons - 1) * TR; % in seconds & -1 to be in same coordinate system as GLMdenoise
                        dur = ceil(model{sess}.event(e).dur * TR ./ stimdur); % in seconds / stimulus duration
                        dur(dur == 0) = 1;
                        
                        gd_ons{e} = [];
                        for o = 1:length(ons)
                            for d = 1:dur(o);
                                gd_ons{e} = [gd_ons{e}; ons(o) + (d - 1) * stimdur];
                            end
                        end
                    end
                    
                    gd_design{s} = gd_ons;
                end
                                                
            case 'SPMdesign'
                hrfmodel = 'assume';
                hrfknobs = 1;
                
                if isempty(stimdur)
                    aas_log(aap, 0, 'Stimdur is set to TR');
                    stimdur = TR;
                end
                
                % Get all the nuisance regressors...
                [movementRegs, compartmentRegs, physiologicalRegs, spikeRegs] = ...
                    aas_firstlevel_model_nuisance(aap, subj, files);
                
                %% Set up CORE model
                
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
                
                %%%%%%%%%%%%%%%%%%%
                %% DESIGN MATRIX %%
                %%%%%%%%%%%%%%%%%%%
                
                SPM.xY.P = allfiles;
                SPMdes = spm_fmri_spm_ui(SPM);
                
                % DIAGNOSTIC
                mriname = aas_prepare_diagnostic(aap, subj);
                try
                    saveas(1, fullfile(aap.acq_details.root, 'diagnostics', ...
                        [mfilename '__' mriname '.fig']));
                catch
                end
                
                %%%%%%%%%%%%%%%%%%%
                %% GLMdenoise    %%
                %%%%%%%%%%%%%%%%%%%
                
                chunks = [0 cumsum(SPMdes.nscan)];
                gd_design = cell(size(SPMdes.Sess));
                
                for s = 1:length(SPMdes.Sess);
                    rows = (chunks(s) + 1):chunks(s+1);
                    cols = SPMdes.Sess(s).col;
                    cols = cols(ismember(cols, cols_interest));
                    
                    gd_design{s} = SPMdes.xX.X(rows, cols);
                    
                end
        end
        
        cd(anadir); % So that figures are printed to the right location
        [gd_results, gd_data] = ... % gd_denoisedData; DEBUG!
                    GLMdenoisedata(gd_design, gd_data, stimdur, TR, hrfmodel, hrfknobs, opt, 'figures');
        
        %[gd_resultsALT, gd_denoisedDataALT] = ...
        %   GLMdenoisedata(gd_design, gd_data, stimdur, TR, 'assume', [], struct('numpcstotry',0), 'figuresALT');
        
        %{
        %% Inspect figures
        
        % GLMdenoisedata writes out a number of figures illustrating the various
        % computations that are performed.  It is useful to browse through these
        % figures to check sanity.  Here we highlight the most useful figures,
        % but there are additional figures (all figures are described in the
        % documentation in GLMdenoisedata.m.).
        
        % 'MeanVolume.png' shows the mean across all volumes.
        % This is useful as a frame of reference.
        figure;
        imagesc(imread('figures/MeanVolume.png'),[0 255]);
        colormap(gray);
        axis equal tight off;
        title('Mean volume');
        %%
        
        % 'FinalModel.png' shows the R^2 of the final model fit.  The color range is
        % 0% to 100% (but is nonlinear; see the color bar).  These R^2 values are not
        % cross-validated (thus, even voxels with no signal have positive R^2 values).
        figure;
        imagesc(imread('figures/FinalModel.png'),[0 255]);
        colormap(hot);
        axis equal tight off;
        cb = colorbar;
        set(cb,'YTick',linspace(0,255,11),'YTickLabel',round((0:.1:1).^2 * 100));
        title('Final model R^2 (not cross-validated)');
        %%
        
        % 'NoisePool.png' shows which voxels were used for the noise pool.  Assuming
        % the default parameters, the noise pool consists of voxels whose (1) mean
        % intensity is greater than one-half of the 99th percentile of mean intensity
        % values and (2) cross-validated R^2 value is less than 0%.  Notice that
        % the noise pool omits voxels near the top of the slice because the raw
        % signal level is relatively low there (due to the distance from the RF coil).
        figure;
        imagesc(imread('figures/NoisePool.png'),[0 255]);
        colormap(gray);
        axis equal tight off;
        title('Noise pool');
        %%
        
        % 'HRF.png' shows the initial HRF guess (red) and the final HRF estimate (blue).
        % Full flexibility is given to the HRF estimate, so the noisiness of the HRF
        % estimate gives an indication of the SNR level in the gd_data.  In this case,
        % the HRF estimate looks very nice, suggesting that the gd_data have good SNR.
        % The first point in the HRF coincides with the onset of a condition (which is
        % denoted by 1s in the design matrix).  The granularity of the HRF reflects
        % the sampling rate (TR) of the gd_data.
        figure;
        imageactual('figures/HRF.png');
        %%
        
        % 'PCcrossvalidationXX.png' shows cross-validated R^2 values corresponding
        % to different numbers of PCs.  The color range is 0% to 100%.  Here we show
        % the initial model (no PCs) and the final model (number of PCs selected by
        % the code).  Notice that because of cross-validation, most voxels are black,
        % indicating cross-validated R^2 values that are 0% or less.  Also, notice
        % that there is some gain in cross-validation performance in the middle of the
        % slices.  The most effective way to view and interpret these figures
        % is to flip between them in quick succession, and this is easiest to do
        % in your operating system (not in MATLAB).
        figure;
        set(gcf,'Units','points','Position',[100 100 900 325]);
        subplot(1,2,1);
        imagesc(imread('figures/PCcrossvalidation00.png'),[0 255]);
        colormap(hot);
        axis equal tight off;
        cb = colorbar;
        set(cb,'YTick',linspace(0,255,11),'YTickLabel',round((0:.1:1).^2 * 100));
        title('Initial model (PC = 0) cross-validated R^2');
        subplot(1,2,2);
        imagesc(imread(sprintf('figures/PCcrossvalidation%02d.png',gd_results.pcnum)));
        colormap(hot);
        axis equal tight off;
        cb = colorbar;
        set(cb,'YTick',linspace(0,255,11),'YTickLabel',round((0:.1:1).^2 * 100));
        title(sprintf('Final model (PC = %d) cross-validated R^2',gd_results.pcnum));
        %%
        
        % 'PCscatterXX.png' shows scatter plots of the cross-validation performance of the
        % initial model (no PCs) against the performance of individual models with
        % different numbers of PCs.  Here we show the scatter plot corresponding to
        % the final model (number of PCs selected by the code).  Voxels that were
        % used to determine the optimal number of PCs are shown in red; other voxels
        % are shown in green.  This figure shows that adding PCs produces a clear and
        % consistent improvement in cross-validation performance.
        figure;
        imageactual(sprintf('figures/PCscatter%02d.png',gd_results.pcnum));
        %%
        
        % 'PCselection.png' illustrates how the number of PCs was selected.  The median
        % cross-validated R^2 value across a subset of the voxels (marked as red
        % in the scatter plots) is plotted as a line, and the selected number
        % of PCs is marked with a circle.  Assuming the default parameters,
        % the code chooses the minimum number of PCs such that the improvement
        % relative to the initial model is within 5% of the maximum improvement.
        % This is a slightly conservative selection strategy, designed to avoid
        % overfitting and to be robust across different datasets.
        figure;
        imageactual('figures/PCselection.png');
        %%
        
        %% Inspect outputs
        
        % The outputs of GLMdenoisedata are contained in
        % the variables 'gd_results' and 'gd_denoisedData'.
        % Here we do some basic inspections of the outputs.
        
        % Select a voxel to inspect.  This is done by finding voxels that have
        % cross-validated R^2 values between 0% and 5% under the initial model (no PCs),
        % and then selecting the voxel that shows the largest improvement when
        % using the final model.
        ix = find(gd_results.pcR2(:,:,:,1) > 0 & gd_results.pcR2(:,:,:,1) < 5);
        improvement = gd_results.pcR2(:,:,:,1+gd_results.pcnum) - gd_results.pcR2(:,:,:,1);
        [mm,ii] = max(improvement(ix));
        ix = ix(ii);
        [xx,yy,zz] = ind2sub(gd_results.inputs.datasize{1}(1:3),ix);
        
        % Inspect amplitude estimates for the example voxel.  The first row shows gd_results
        % obtained from the GLMdenoisedata call that does not involve global noise regressors;
        % the second row shows gd_results obtained from the regular GLMdenoisedata call.
        % The left panels show amplitude estimates from individual bootstraps, whereas
        % the right panels show the median and 68% interval across bootstraps (this
        % corresponds to the final model estimate and the estimated error on the
        % estimate, respectively).
        figure;
        set(gcf,'Units','points','Position',[100 100 700 500]);
        for p=1:2
            if p==1
                ampboots = squeeze(gd_resultsALT.models{2}(xx,yy,zz,:,:));  % conditions x boots
                amp = flatten(gd_resultsALT.modelmd{2}(xx,yy,zz,:));        % 1 x conditions
                ampse = flatten(gd_resultsALT.modelse{2}(xx,yy,zz,:));      % 1 x conditions
            else
                ampboots = squeeze(gd_results.models{2}(xx,yy,zz,:,:));     % conditions x boots
                amp = flatten(gd_results.modelmd{2}(xx,yy,zz,:));           % 1 x conditions
                ampse = flatten(gd_results.modelse{2}(xx,yy,zz,:));         % 1 x conditions
            end
            n = length(amp);
            subplot(2,2,(p-1)*2 + 1); hold on;
            plot(ampboots);
            straightline(0,'h','k-');
            xlabel('Condition number');
            ylabel('BOLD signal (% change)');
            title('Amplitude estimates (individual bootstraps)');
            subplot(2,2,(p-1)*2 + 2); hold on;
            bar(1:length(amp),amp,1);
            errorbar2(1:length(amp),amp,ampse,'v','r-');
            if p==1
                ax = axis; axis([0 n+1 ax(3:4)]); ax = axis;
            end
            xlabel('Condition number');
            ylabel('BOLD signal (% change)');
            title('Amplitude estimates (median and 68% interval)');
        end
        for p=1:2
            subplot(2,2,(p-1)*2 + 1); axis(ax);
            subplot(2,2,(p-1)*2 + 2); axis(ax);
        end
        %%
        
        % Compare SNR before and after the use of global noise regressors.
        % To focus on voxels that related to the experiment, we select voxels with
        % cross-validated R^2 values that are greater than 0% under the initial model.
        % To ensure that the SNR values reflect only changes in the noise level,
        % we ignore the SNR computed in each individual GLMdenoisedata call and
        % re-compute SNR, holding the numerator (the signal) constant across the
        % two calls.  (Note: GLMdenoisedata automatically writes out a figure that
        % shows a before-and-after SNR comparison (SNRcomparebeforeandafter.png).
        % What is shown in this script does the comparison manually just for sake
        % of example.)
        ok = gd_results.pcR2(:,:,:,1) > 0;
        signal = mean([gd_results.signal(ok) gd_resultsALT.signal(ok)],2);
        snr1 = signal ./ gd_resultsALT.noise(ok);
        snr2 = signal ./ gd_results.noise(ok);
        figure; hold on;
        scatter(snr1,snr2,'r.');
        ax = axis;
        mx = max(ax(3:4));
        axissquarify;
        axis([0 mx 0 mx]);
        xlabel('SNR before');
        ylabel('SNR after');
        %%
        
        % An alternative to using the GLM estimates provided by GLMdenoisedata is
        % to use 'gd_denoisedData', which contains the original time-series gd_data but
        % with the component of the gd_data that is estimated to be due to the global
        % noise regressors subtracted off.  Here we inspect the denoised gd_data for
        % the same example voxel examined earlier.  Note that the gd_data components
        % that are present in 'gd_denoisedData' can be customized (see opt.denoisespec
        % in GLMdenoisedata.m).  The default parameters leave in the estimated baseline
        % signal drift, which explains the drift in the plotted time-series.
        figure; hold on;
        set(gcf,'Units','points','Position',[100 100 700 250]);
        data1 = flatten(gd_data{1}(xx,yy,zz,:));
        data2 = flatten(gd_denoisedData{1}(xx,yy,zz,:));
        n = length(data1);
        h1 = plot(data1,'r-');
        h2 = plot(data2,'b-');
        ax = axis; axis([0 n+1 ax(3:4)]);
        legend([h1 h2],{'Original' 'Denoised'});
        xlabel('Time point');
        ylabel('MR signal');
        %%
        %}
        
        memtoc
        
        %% SAVE DENOISED DATA TO DISC
        for s = 1:length(aap.acq_details.selected_sessions);
            sess = aap.acq_details.selected_sessions(s);
            
            for f = 1:size(files{sess},1)
                V = spm_vol(files{sess}(f,:));
                Y = gd_data{s}(:,:,:,f);
                spm_write_vol(V,Y);
            end
            
            aap=aas_desc_outputs(aap,subj,sess, 'epi', files{sess});
        end
        
        memtoc
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end