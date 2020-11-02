function obj = exportTrainingFrames(scoringFile,roi_dims)
%% EXPORTTRAININGFRAMES  Score video alignment of audio task in rat
%
%  EXPORTTRAININGFRAMES;
%  EXPORTTRAININGFRAMES(scoringFile);
%
%  --------
%   INPUTS
%  --------
%  scoringFile    :  (Optional) Scoring file name (char;
%                       "*_VideoScoring.mat")
%
%  roi_dims       :  (Optional) [x y width height]. Width and height are
%                       fixed.
%
%  --------
%   OUTPUT
%  --------
%  Creates a sub-folder with exported training frames and corresponding
%  labels in a file named Labels.csv
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

if nargin < 2
   roi_dims = [0 0 400 400];
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

if ~isfield(in,'behaviorData')
   error('Missing behaviorData table from %s.',scoringFile);
else
   idx = ~isnan(in.behaviorData.Grasp);
   tStart = tStart(idx);
   in.behaviorData = in.behaviorData(idx,:);
   for ii = 1:numel(F)
      F{ii} = F{ii}(idx);
   end
   if isfield(in,'exportedFrames')
      obj = vidDisplay(F,tStart,in.behaviorData,roi_dims,in.exportedFrames);
   else
      obj = vidDisplay(F,tStart,in.behaviorData,roi_dims);
   end
end

waitfor(obj.vidFig);
markerName = obj.markerName;
exportedFrames = obj.exportedFrames;
save(scoringFile,'markerName','exportedFrames','-append');

end