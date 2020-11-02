function export3Dvids(behaviorData)
%EXPORT3DVIDS Export 3D-reconstructed videos for trial data
%
%  export3Dvids(behaviorData);
%
% Inputs
%  behaviorData - Table
%
% Output
%  - none - Saves exported videos

mName = {'dig1_d';'dig1_p';'dig2_d';'dig2_p';'dig3_d';'dig3_p';'dig4_d';'dig4_p';'hand'};
cName = {'Left-A';'Left-B';'Left-C';'Right-A';'Right-B';'Right-C'};
base = 'C:\MyRepos\_M\190419 Box Audio ROC\allGP2_';

name = strsplit(behaviorData.Properties.Description,'_');
block = strjoin(name(1:5),'_');

for iB = 1:size(behaviorData,1)
   trial = behaviorData.Properties.RowNames{iB};

   load(fullfile(base,[block '_' trial '_StereoParams.mat']));

   %% EXTRACT DATA
   matched = struct;
   for ii = 1:numel(mName)
      for ik = 1:numel(cName)
         fname = fullfile(base,[block '_' cName{ik} '_' trial 'KinData.mat']);
         if exist(fname,'file')==0
            continue;
         end
         data = load(fname);
         x = data.x(:,ii);
         y = data.y(:,ii);
         iStart = min(find(~isnan(x),1,'first'),find(~isnan(y),1,'first'));
         iStop = max(find(~isnan(x),1,'last'),find(~isnan(y),1,'last'));
         x(iStart:iStop) = fillmissing(x(iStart:iStop),'pchip');
         y(iStart:iStop) = fillmissing(y(iStart:iStop),'pchip');
         x(isnan(x)) = 0;
         y(isnan(y)) = 0;
         matched.(mName{ii}).(strrep(cName{ik},'-','_')) = [x,y];
      end
   end

   %% TRIANGULATE
   worldPoints = cell(size(mName));
   for ii = 1:numel(mName)
      c = fieldnames(matched.(mName{ii}));
      n = size(matched.(mName{ii}).(c{1}),1);
%       tmp = nan(n,3,size(stereoData,1));
      worldPoints{ii} = nan(n,3,size(stereoData,1));
      for ik = 1:size(stereoData,1)
         c1 = strsplit(stereoData.cam1{ik},'_');
         c1 = strrep(c1{6},'-','_');
         c2 = strsplit(stereoData.cam2{ik},'_');
         c2 = strrep(c2{6},'-','_');
         matchedPoints1 = matched.(mName{ii}).(c1);
         matchedPoints2 = matched.(mName{ii}).(c2);
         worldPoints{ii}(:,:,ik) = triangulate(...
            matchedPoints1,matchedPoints2,stereoData.cal{ik});
      end
%       worldPoints{ii} = squeeze(nanmean(tmp,3));
   end

   %% PLOT
   % MARKER_COLOR = defaults.markerParams('color');
   % iStart = 324;
   % iStop = 375;
   %              
   % fig = plot3DSegments(worldPoints{1}(iStart:iStop,1),...
   %                      worldPoints{1}(iStart:iStop,2),...
   %                      worldPoints{1}(iStart:iStop,3),[],...
   %                      'MarkerFaceColor',MARKER_COLOR{1});
   %                   
   % for ii = 2:numel(worldPoints)
   %    fig = plot3DSegments(worldPoints{ii}(iStart:iStop,1),...
   %                      worldPoints{ii}(iStart:iStop,2),...
   %                      worldPoints{ii}(iStart:iStop,3),fig,...
   %                      'MarkerFaceColor',MARKER_COLOR{ii});
   % end

   %% TEST VIDEO
   t = (0:(size(worldPoints{1},1)-1))/240;
   frameTimes = [t(iStart) t(iStop)];
   w = cell(size(worldPoints));
   for ii = 1:numel(w)
      w{ii} = worldPoints{ii}(iStart:iStop,:,:);
   end
   V = cell(1,2);
   V{1} = VideoReader(fullfile(base,[stereoData.cam1{1} '.MP4'])); %#ok<*TNMLP>
   V{2} = VideoReader(fullfile(base,[stereoData.cam2{1} '.MP4']));
   
   iM = 0;
   movName = sprintf('%s_%s_v%03g.MP4',block,trial,iM);
   movOutDir = '3D-animations';
   if exist(movOutDir,'dir')==0
      mkdir(movOutDir);
   end
   while exist(fullfile(movOutDir,movName),'file')~=0
      iM = iM + 1;
      movName = sprintf('%s_%s_v%03g.MP4',block,trial,iM);
   end
   animateSingleReach(w,V,frameTimes,...
      'MOVIE_NAME',fullfile(movOutDir,movName));
end




end