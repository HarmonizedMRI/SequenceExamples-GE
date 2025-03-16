function checktiming(seq)
% function checktiming(seq)
%
% Calls seq.checkTiming and prints results

fprintf([seq.getDefinition('Name') ': performing timing check... ']);

[ok, error_report] = seq.checkTiming;

if (ok)
    fprintf(['passed\n']);
else
    fprintf('failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end
