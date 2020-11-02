function fixScoringFileFormat(scoringFile)
%% FIXSCORINGFILEFORMAT  Fix behaviorData table etc. for scoring file
%
%  FIXSCORINGFILEFORMAT;
%  FIXSCORINGFILEFORMAT(scoringFile);
%
% By: Max Murphy  v1.0  2019  Original version (R2017a)

%%
if nargin < 1
   scoringFile = uigetfile('*_VideoScoring.mat','Select SCORING file',pwd);
   if scoringFile == 0
      disp('No file selected. Script canceled.'); return;
   end
end

filesUpdated = false;

in = load(scoringFile);
if isfield(in,'behaviorData')
   if size(in.behaviorData.Lag,2)~=size(in.roi,1)
      lag = repmat(in.behaviorData.Lag,1,size(in.roi,1));
      switch size(in.roi,1)
         case 4
            lag(in.behaviorData.Forelimb==0,3:4) = nan;
            lag(in.behaviorData.Forelimb==1,1:2) = nan;
         case 6
            lag(in.behaviorData.Forelimb==0,4:6) = nan;
            lag(in.behaviorData.Forelimb==1,1:3) = nan;
         case 7
            lag(in.behaviorData.Forelimb==0,4:6) = nan;
            lag(in.behaviorData.Forelimb==1,1:3) = nan;
         otherwise
            error('Weird number of cameras. Not sure how to parse handedness.');
      end
      
      in.behaviorData.Lag = lag;
      
      filesUpdated = true;
      save(scoringFile,'-struct','in');
      fprintf(1,'%s BEHAVIORDATA:LAG updated.\n',scoringFile);
   end
end

if isfield(in,'meta')
   meta = in.meta;
   metaWasUpdated = false;
   for ii = 1:size(meta,1)
      if exist(fullfile(meta.Folder{ii},meta.Name{ii}(1:end-6)),'dir')==0
         f = uigetdir(meta.Folder{ii},'Select parent folder of extracted sub-folders');
         if f == 0
            disp('meta table not updated.');
            break;
         elseif exist(fullfile(f,meta.Name{ii}(1:end-6)),'dir')==0
            error('Selected folder does not contain extracted trial sub-folders.');
         else
            metaWasUpdated = true;
            meta.Folder(ii:end) = repmat({f},numel(meta.Folder(ii:end)),1);
         end
      end
   end
   if metaWasUpdated
      in.meta = meta;
      filesUpdated = true;
      save(scoringFile,'-struct','in');
      fprintf(1,'%s META updated.\n',scoringFile);
   end
end

if ~filesUpdated
   fprintf(1,'Nothing to update.\n');
end
end