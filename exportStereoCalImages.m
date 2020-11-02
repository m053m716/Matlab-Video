function exportStereoCalImages(behaviorData,nImg)
%% EXPORTSTEREOCALIMAGES   Exports sets of images from each trial video
%
%  EXPORTSTEREOCALIMAGES(behaviorData);
%
%  --------
%   INPUTS
%  --------
%  behaviorData   :     Table generated from SCOREAUDIOTRIALS.
%
%     nImg        :     (Optional) # images to export for each calibration
%
% By: Max Murphy  v1.0  2019-05-21  Original version (R2017a)

%% PARSE INPUT
if nargin < 1
   [fName,pName,~] = uigetfile('*_VideoScoring.mat',...
      'Select VIDEO SCORING file','..');

   if fName == 0
      disp('Scoring canceled.');
      obj = [];
      return;
   end
   
   scoringFile = fullfile(pName,fName);
   load(scoringFile,'behaviorData');
end

if nargin < 2
   nImg = 10; % Default of 10 exported images
end

EXTRA_PATH = 'K:\Rat\Video\Audio Discrimination Task\post-surg';
OFFSET = 0.6; % seconds to offset
SKIP = 5; % every 5th frame

%% LOAD TABLE WITH NAMES OF VIEWS AND GET NAME
in = load(behaviorData.Properties.Description,'meta','roi');
name = strsplit(behaviorData.Properties.Description,'_');
name = strjoin(name(1:5),'_');

%% EXPORT IMAGES AT START OF EVERY TRIAL
for ii = 1:size(behaviorData,1)
   trial = behaviorData.Properties.RowNames{ii};
   for ik = 1:size(behaviorData.Lag,2)
      if isnan(behaviorData.Lag(ii,ik))
         continue;
      end
      
      m = in.meta(ismember(in.meta.Angle,in.roi.Angle{ik}),:);
      vidIdx = find((m.tStart <= behaviorData.Trial(ii)) & ...
         (m.tStop > behaviorData.Trial(ii)),1,'first');
      
      
      
      fname = fullfile(m.Folder{vidIdx},m.Name{vidIdx});      
      if exist(fname,'file')==0
         fname = fullfile(EXTRA_PATH,m.Name{vidIdx});
      end
      
      str = [name '_' in.roi.Angle{ik} '_' trial];

      t = behaviorData.Trial(ii)+behaviorData.Lag(ii,ik)-m.tStart(vidIdx);
      
      V = VideoReader(fname); %#ok<*TNMLP>
      
      V.CurrentTime = t+OFFSET;
      outdir = fullfile(pwd,'cal',[str '_stereo-cal']);
      if exist(outdir,'dir')==0
         mkdir(outdir);
      end
      
      for iImg = 1:(nImg*SKIP + 1)
         I = readFrame(V);
         if rem(iImg,SKIP)==1
            outname = sprintf('%s_%03g.PNG',str,iImg);
            imwrite(I,fullfile(outdir,outname));
         end
      end     
      
   end
end
clear V

end