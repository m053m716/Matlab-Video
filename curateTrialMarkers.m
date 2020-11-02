function obj = curateTrialMarkers(scoringFile)
%% CURATETRIALMARKERS   Curate DLC labeling and fix/interpolate output
%
%  CURATETRIALMARKERS(scoringFile)
%
%  --------
%   INPUTS
%  --------
%  scoringFile    :     File with '_VideoScoring.mat' ending that contains
%                          the video scoring data for this recording.
%
%  --------
%   OUTPUT
%  --------
%  UI for curating the markers and setting them correctly.
%
% By: Max Murphy  v1.0  2019-05-20  Original version (R2017a)

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

in = load(fullfile(scoringFile));

%%
if ~isfield(in,'curationData')
   curationData = initCurationData(scoringFile);    
else
   curationData = in.curationData;
end

obj = kinCurator(curationData);

end