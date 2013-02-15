
function mvpaa_diagnosticTemporalDenoising(aap, tempDist, oldSimil, Simil, Rfn)

mriname = aas_prepare_diagnostic(aap);

if aap.tasklist.currenttask.settings.diagnostic
    h = figure;
    
    subplot(2,2,1)
    imagescnan(oldSimil)
    caxis([-1 1])
    colorbar
    axis equal tight
    title('Old similarity matrix')
    
    subplot(2,2,2)
    imagescnan(tempDist)
    colorbar
    axis equal tight
    title('Temporal distance')
    
    subplot(2,2,3)
    imagescnan(Simil)
    caxis([-1 1])
    colorbar
    axis equal tight
    title('New similarity matrix')
    
    subplot(2,2,4)
    imagescnan(oldSimil-Simil)
    colorbar
    axis equal tight
    title('Difference')
    
    print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
        [mfilename '__' mriname '_' Rfn '.jpeg']));
    
    close(h)
end
