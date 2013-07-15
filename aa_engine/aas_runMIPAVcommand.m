function [s w]=aas_runMIPAVcommand(aap, MIPAVcommand, analysisDir, restartTimes)
if nargin < 4
    restartTimes = 3;
end

% Now try to run the JIST stuff...
MIPAVpth = aap.directory_conventions.MIPAVdir;
% Setup alias
aliasString = sprintf(['alias mipavjava="%s' ...
    '/jre/bin/java -classpath %s' ...
    '/plugins/:%s' ...
    '/:`find %s' ...
    '/ -name  \\*.jar ' ...
    ' | sed ''s#%s' ...
    '/#:%s' ...
    '/#'' | tr -d ''\\n'' | sed ''s/^://''`"'], ...
    MIPAVpth, MIPAVpth, MIPAVpth, MIPAVpth, MIPAVpth, MIPAVpth);

% Write alias...
aliasPth = fullfile(analysisDir,'mipavjava_alias.sh');
fid = fopen(aliasPth, 'w');
fwrite(fid, aliasString);
fprintf(fid, '\n');
% Make sure aliases are exanded (can be useable in matlab)
fprintf(fid, 'shopt -s expand_aliases');
fprintf(fid, '\n');
% Set Java to headless (so we don't get graphics errors)
%fprintf(fid, 'JAVA_OPTS=''-Djava.awt.headless=true''');
%fprintf(fid, 'java -Djava.awt.headless=true');
fclose(fid);
setenv('BASH_ENV',aliasPth); setenv('MATLAB_SHELL','/bin/bash')

disp(aliasString)
disp(MIPAVcommand)
% Run the JIST tools...

% MIPAV may fail for no *apparent* reason, so let's give it another chance...
boo = 1;
while boo > 0    
    if boo > restartTimes
        aas_log(aap, true, 'Ran MIPAV command %d times; all FAILED', boo - 1 )
    end
    
    [s w] = unix(MIPAVcommand, '-echo');
    
    if s==1
        disp(w);
        error('Some MIPAV ERROR');
    end
    
    if ~isempty(strfind(w, 'FAILED'))
        boo = boo + 1;
    else
        boo = 0;
    end
end

% Let us save the output of the command
% Write alias...
outputPth = fullfile(analysisDir,'mipav_output.txt');
fid = fopen(outputPth, 'w');
fwrite(fid, w);
fclose(fid);

delete(aliasPth)