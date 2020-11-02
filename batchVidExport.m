function batchVidExport(F)
%% BATCHVIDEXPORT    Export cropped/clipped trial videos for a set of aligned vids
%
%  BATCHVIDEXPORT;
%  BATCHVIDEXPORT(F);
%
%  --------
%   INPUTS
%  --------
%     F     :     (Optional) Cell array of file name strings. If not
%                    provided, will prompt to select the corresponding
%                    *_VideoScoring.mat file that contains 'meta',
%                    and 'subs' generated by GETVIDFILE/GETVIDOFFSET,
%                    and GETBLOCK, respectively.
%
%  --------
%   OUTPUT
%  --------
%  Creates a folder at the video location for each viewing angle. Each
%  folder contains trials for that recording session.
%
% By: Max Murphy  v1.0  2019-05-04  Original version (R2017a)

%% PARSE INPUT
if nargin < 1
   [fname,pname,~] = uigetfile('*_VideoScoring.mat','Select SCORING file',...
      pwd,'MultiSelect','on');
   if iscell(fname)
      F = cell(size(fname));
      for iF = 1:numel(fname)
         F{iF} = fullfile(pname,fname{iF});
      end
   else
      F = fullfile(pname,fname);
   end
end

if iscell(F) % Use recursion to iterate
   for iF = 1:numel(F)
      batchVidExport(F{iF});
   end
   return;
end

%%
fprintf(1,'----- %s -------\n',F);
iTrial = 1;
load(F,'meta','subs','roi');
trials = getTrials(subs); %#ok<*NODEF>
tStart = trials.t(diff([0,trials.data])>0);
tStop = trials.t(diff([0,trials.data])<0);
if numel(tStart)~=numel(tStop)
   if trials.data(1)>0 % If it started out as HIGH then remove first trial
      tStop(1) = [];
   end
   if trials.data(end)>0 % If ended as HIGH then remove last trial
      tStart(end) = [];
   end
   if numel(tStart)~=numel(tStop)
      error('Number of tStart (%d) and tStop (%d) unequal. Check data.',...
         tStart,tStop);
   end
end
save(F,'tStart','tStop','-append');

fStr = strsplit(meta.Name{1},'_'); 
pStr = [strjoin(fStr(1:5),'_') '_%s'];
fStr = [strjoin(fStr(1:5),'_') '_%s_Trial-%03d.MP4'];
flag = false;
tic;
[angles,~,angle_idx] = unique(meta.Angle);
fprintf(1,'Exporting trials for angle 000/%03g...\n\n',size(angles,1));
for iA = 1:numel(angles)
   m = meta(angle_idx==iA,:);
   if iA == 1
      b_str = repmat('\b',1,11);
      eval(['fprintf(1,''' b_str '%03g/%03g...\n'',iA,size(angles,1))']);
   else
      b_str = repmat('\b',1,28);
      eval(['fprintf(1,''' b_str '%03g/%03g...\n'',iA,size(angles,1))']);
   end
   outDir = fullfile(m.Folder{1},sprintf(pStr,angles{iA}));
   if exist(outDir,'dir')==0
      mkdir(outDir);
   end
   crop = roi.Crop{strcmpi(roi.Angle,angles{iA})};
   idx = 1;
   V = VideoReader(fullfile(m.Folder{idx},m.Name{idx}));
   
   fprintf(1,'Trial 000/%03g...\n',numel(tStart));
   for ii = 1:numel(tStart)
      b_str = repmat('\b',1,11);
      eval(['fprintf(1,''' b_str '%03g/%03g...\n'',ii,numel(tStart))']);
      fname = fullfile(outDir,sprintf(fStr,angles{iA},ii));
      v = VideoWriter(fname,'MPEG-4'); 
      v.FrameRate = m.fs(idx);
      v.Quality = 100;
      open(v);
      
      tmp = find(m.tStart <= tStart(ii) & m.tStop >= tStop(ii));
      if isempty(tmp)
         tmp = find(m.tStart <= tStart(ii),1,'last');
         if tmp~=idx
            idx = tmp;
            V = VideoReader(fullfile(m.Folder{idx},m.Name{idx}));
         end
         V.CurrentTime = tStart(ii) - m.tStart(idx);
         while V.hasFrame
            C = V.readFrame;
            writeVideo(v,C(crop(2):(crop(2)+crop(4)),crop(1):(crop(1)+crop(3)),:));
         end
         idx = find(m.tStop >= tStop(ii),1,'first');
         V = VideoReader(fullfile(m.Folder{idx},m.Name{idx}));
         while V.CurrentTime < (tStop(ii) - m.tStart(idx))
            C = V.readFrame;
            writeVideo(v,C(crop(2):(crop(2)+crop(4)),crop(1):(crop(1)+crop(3)),:));
         end
      else
         if tmp~=idx
            idx = tmp;
            V = VideoReader(fullfile(m.Folder{idx},m.Name{idx})); %#ok<*TNMLP>
         end
         V.CurrentTime = tStart(ii) - m.tStart(idx);
         while V.CurrentTime < (tStop(ii) - m.tStart(idx))
            C = V.readFrame;
            writeVideo(v,C(crop(2):(crop(2)+crop(4)),crop(1):(crop(1)+crop(3)),:));
         end
      end
      close(v);
   end
   
end

toc; 

end