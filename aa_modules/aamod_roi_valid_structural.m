function [aap,resp] = aamod_roi_valid_structural(aap,task)

% AAMOD_ROI_VALID Look for valid ROIs (with non-NaN values across subjects)
%
% INPUT options [defaults if not set in xml file]:
%  inputstreams
%   .stream{1}    = ROI data stream for input [roidata_epi]
%  AbsVoxThr      = Threshold min N voxels [10]
%  SubjRemoveStat = Central tendency statistic for subject threshold [mode]
%  SubjRemoveThr  = Variability statistic multiplier for subject threshold []
%  ROIRemoveThr   = Threshold (subject count) for ROI removal [0]
%
% OUTPUT:
%  outputstreams
%   .stream{1}   = ROI valid list [roivalid]
%
% by Jason Taylor (09/Aug/2013)

resp='';

switch task
    
    case 'domain'
        resp='study';
        
    case 'description'
        resp='Find valid ROIs across subjects';
        
    case 'doit'
        
        instream = aap.tasklist.currenttask.inputstreams.stream{1};
        outstream = aap.tasklist.currenttask.outputstreams.stream{1};
        
        try AbsVoxThr      = aap.tasklist.currenttask.settings.AbsVoxThr;      catch, AbsVoxThr      = 10; end
        try SubjRemoveStat = aap.tasklist.currenttask.settings.SubjRemoveStat; catch, SubjRemoveStat = 0.8; end
        try SubjRemoveThr  = aap.tasklist.currenttask.settings.SubjRemoveThr;  catch, SubjRemoveThr  = 3;  end
        try ROIRemoveThr   = aap.tasklist.currenttask.settings.ROIRemoveThr;   catch, ROIremoveThr   = 0;  end
        
        % Do it:
        ValidROI = struct();
        Nv       = [];
        Mm       = [];
        ROIval   = [];
        
        
        for subjind = 1:length(aap.acq_details.subjects),
            
            % Load ROI file for subject/session:
            ROIfname = aas_getfiles_bystream(aap,subjind,instream);
            load(ROIfname);
            % Get number of valid voxels in each ROI:
            Nv(subjind,:) = [ROI.Nvox_data];
            Mm(subjind,:) = [ROI.mean];
            
        end
        
        [pth stem fext] = fileparts(ROIfname);
        invalidroi = isnan(Mm)|Nv<AbsVoxThr;
        ROIval = [ROI.ROIval];
        Nr = length(ROIval);
        
        
        % Remove bad subjects before removing ROIs:
        
        switch SubjRemoveStat,
            case 'mode'
                % Keep only if N(invalid) is mode or less:
                scrit = mode(sum(invalidroi,2));
            case 'median'
                % Keep only if N(invalid) is median+Thr*IQR or less:
                scrit = median(sum(invalidroi,2));
                scrit = scrit + SubjRemoveThr*iqr(sum(invalidroi,2));
            case 'mean'
                % Keep only if N(invalid) is mean+Thr*STD or less:
                scrit = mean(sum(invalidroi,2));
                scrit = scrit + SubjRemoveThr*std(sum(invalidroi,2));
        end
        
        % Find rubbish subjects:
        s2ignore = sum(invalidroi,2)>scrit;
        
        % Find ROIs to ignore (ignoring rubbish subjects):
        r2ignore = sum(invalidroi(~s2ignore,:))>ROIRemoveThr;
        
        % Session Summary:
        ValidROI.sessname          = '';
        ValidROI.ROIval            = ROIval(~r2ignore);
        ValidROI.ROIind            = setdiff(1:length(ROI),find(r2ignore));
        ValidROI.ROIind2ignore     = find(r2ignore);
        ValidROI.Subjind           = setdiff(1:length(aap.acq_details.subjects),find(s2ignore));
        ValidROI.Subjind2ignore    = find(s2ignore);
        ValidROI.AbsVoxThr         = AbsVoxThr;
        ValidROI.SubjRemoveStat    = SubjRemoveStat;
        ValidROI.SubjRemoveThr     = SubjRemoveThr;
        ValidROI.SubjRemoveCritVal = scrit;
        ValidROI.ROIRemoveThr      = ROIRemoveThr;
        
        % plot imagesc:
        %f=spm_figure('FindWin'); spm_figure('Clear',f);
        %imagesc(invalidroi); colormap gray;
        [pth,nm] = fileparts(ROIfname);
        ind=strfind(pth,'/');
        ind=ind(end)-1; % remove subject, session
        pth = pth(1:ind);
        %outfile = fullfile(pth,sprintf('imagesc_ValidROI_%s.png',ValidROI.sessname));
        %print(f,'-dpng',outfile);
        %aap = aas_desc_outputs(aap,sprintf('imagesc_%s_%s',ValidROI.sessname,outstream),outfile);
        
        
        % describe output (in aamod dir):
        outfile = fullfile(pth,'ValidROI.mat');
        save(outfile,'ValidROI');
        aap = aas_desc_outputs(aap,outstream,outfile);
        
end
