
function Simil = mvpaa_temporalDenoising(aap, Simil, Rfn)

if nargin < 3
    Rfn = '';
end

sessionNum = aap.tasklist.currenttask.settings.sessionNum;

sessionOwn = round(sqrt(sessionNum' * sessionNum) .* mvpaa_label2cont(sessionNum,0));
sessionOwn(sessionOwn < 0) = NaN;

oldSimil = Simil;

%% Remove effects related to temporal proximity...
if ~isempty(aap.tasklist.currenttask.settings.temporal)
    
    % Do a number of things to the temporal info...
    temporalM = aap.tasklist.currenttask.settings.temporal;
    if ~iscell(temporalM)
        temporalM = {temporalM};
    end
    
    tempDist = 0;
    for p = 1:length(temporalM)
        tempDist = tempDist + temporalM{p};
    end
    
    for sess = unique(sessionNum)        
        % Use only a subset of cells...
        affectedCells = ~isnan(tempDist) & sessionOwn == sess;
        
        % Create predictor matrices...
        dat = Simil(affectedCells);
        pred = [];
        for p = 1:length(temporalM)
            % Balance these around 0
            tmpP = temporalM{p}(affectedCells);
            tmpP = tmpP - mean(tmpP);
            tmpP = mvpaa_balanceCont(tmpP, 0);
            % Add to predictor array
            pred = [pred, tmpP];
        end
        
        % Fit the predictors to the GLM...
        [bb,dev,stats] = glmfit(pred,dat);
        dat = dat - (bb(1) * ones(size(dat)));
        % Subtract effect from the data...
        for p = 1:length(temporalM)
            dat = dat - (bb(p+1) * pred(:,p));
        end
        
        % Remove effect of temporal differences from data...
        Simil(affectedCells) = dat;
        
        %disp(stats.t)
        %disp(bb)
    end
    
    %aas_log(aap, 0, 'Temporal denoising completed')
    
    mvpaa_diagnosticTemporalDenoising(aap, tempDist, oldSimil, Simil, Rfn)
end
