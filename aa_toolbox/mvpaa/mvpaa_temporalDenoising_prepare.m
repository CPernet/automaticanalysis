% Converts temporal information vectors (of scans/events) into temporal
% matrices that can be used to:
% 1) denoise the similarity matrix data
% 2) inform the temporal denoising (IN DEVELOPMENT!)

function temporalDenoising = mvpaa_temporalDenoising_prepare(aap)

if ~isempty(aap.tasklist.currenttask.settings.temporal)
    
    temporalDenoising = mvpaa_Denoising_prepare(aap, ...
        aap.tasklist.currenttask.settings.temporal.vector, ...
        aap.tasklist.currenttask.settings.temporalDenoisingMode, ...
        aap.tasklist.currenttask.settings.temporal.transform);
    
    mvpaa_diagnosticDenoising(aap, 'temporal', temporalDenoising)
    
else
    temporalDenoising = [];
end
