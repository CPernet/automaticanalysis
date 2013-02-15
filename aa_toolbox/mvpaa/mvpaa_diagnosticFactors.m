% MVPAA Check factors
% Automatically checks conditions/blocks in each session
function mvpaa_diagnosticFactors(aap, conditionNum, sessionNum, blockNum)

mriname = aas_prepare_diagnostic(aap);

%% DIAGNOSTIC...
h = figure;
hold on
plot(conditionNum, 'r')
plot(blockNum, 'g')
plot(sessionNum, 'b')
legend('Condition', 'Block', 'Session')

print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
    [mfilename '__' mriname '.jpeg']));

close(h);