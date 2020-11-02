function obj = scoreAudioTrials(scoringFile)
%% SCOREAUDIOTRIALS  Score video alignment of audio task in rat
%
%  SCOREAUDIOTRIALS;
%  SCOREAUDIOTRIALS(scoringFile);
%
%  --------
%   INPUTS
%  --------
%  scoringFile    :  (Optional) Scoring file name (char;
%                       "*_VideoScoring.mat")
%
%  --------
%   OUTPUT
%  --------
%  behaviorData   :  Generates a "behaviorData" table for behavioral
%                       alignment.
%
% By: Max Murphy  v1.0  2019-05-06  Original version (R2017a)

%%
if nargin < 1
   [fName,pName,~] = uigetfile('*_VideoScoring.mat',...
      'Select VIDEO SCORING file','..');

   if fName == 0
      disp('Scoring canceled.');
      obj = [];
      return;
   end
   
   scoringFile = fullfile(pName,fName);

end
in = load(scoringFile);
if isfield(in,'tStart')
   tStart = in.tStart;
else
   error('Missing tStart variable from %s.',scoringFile);
end

if isfield(in,'meta')
   m = in.meta((in.meta.Index==0),:); 
else
   error('Missing meta table from %s.',scoringFile);
end

F = cell(1,size(m,1));
for ii = 1:numel(F)
   name = m.Name{ii}(1:(end-6));
   F{ii} = dir(fullfile(m.Folder{ii},name,[name '*.MP4']));
end

if isfield(in,'behaviorData')
   in.behaviorData.Properties.Description = scoringFile;
   obj = vidDisplay(F,tStart,in.behaviorData);
else
   obj = vidDisplay(F,tStart,scoringFile);
end

% Now save via alt+s
% waitfor(obj.vidFig);
% behaviorData = obj.behaviorData;
% save(scoringFile,'behaviorData','-append');


end