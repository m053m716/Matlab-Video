function trials = getTrials(subs)
%% GETTRIALS   Get trials from digital SYNC signal
%
%  trials = GETTRIALS(subs);
%
%  --------
%   INPUTS
%  --------
%    subs      :     Subs struct returned by GETBLOCK.
%
%  --------
%   OUTPUT
%  --------
%   trials     :     Trial data struct that is HIGH when trial runs.
%
% By: Max Murphy  v1.0  2019-05-03  Original version (R2017a)

%%
trials = load(fullfile(subs.dig,[subs.name '_DIG_trialrunning.mat']),'data','fs');
trials.t = (0:(numel(trials.data)-1))/trials.fs;

end