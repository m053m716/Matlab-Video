function reExportKinData(scoringFile)
%% REEXPORTKINDATA   Re-exports kinematic data after curation (for re-training)
%
%  REEXPORTKINDATA;
%  REEXPORTKINDATA(scoringFile);
%
% By: Max Murphy  v1.0  2019-05-24  Original version (R2017a)

%% DEFAULTS
OUT_DIR = 'reTrainingData';

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
end

in = load(fullfile(scoringFile));

if ~isfield(in,'curationData')
   error('Data for this scoringFile (%s) has not yet been curated.',scoringFile);  
elseif ~isfield(in,'markerName')
   error('markerName variable is missing from scoringFile (%s).',scoringFile);
else
   markerName = in.markerName;
   curationData = in.curationData;
end

%% SMOOTH & INTERPOLATE DATA BETWEEN START & STOP POINTS
% Note: you should make sure in the curation to remove any "bad" labels
% that occur prior to or after the continuous reach segment of interest,
% otherwise erroneous points will be added connecting these markers through
% time.
if exist(OUT_DIR,'dir')==0
   mkdir(OUT_DIR);
end

fig = figure('Name','ROI Adjuster',...
   'Units','Normalized',...
   'Position',[0.3 0.3 0.5 0.5],...
   'Color','w');
ax = axes(fig,'Units','Normalized','Position',[0 0 1 1],...
   'XTick',[],'YTick',[],'YDir','reverse','NextPlot','replacechildren');

tic;
for ii = 1:size(curationData,1)
   [~,name,~] = fileparts(curationData.vid{ii});
   f = curationData.folder{ii};
   if exist(f,'dir')==0
      f = strsplit(f,'\');
      f = fullfile(pwd,f{end});
      curationData.folder{ii} = f;
   end
   data = load(fullfile(curationData.folder{ii},curationData.kin{ii}));
   iStart = find(~isnan(data.x(:,1)),1,'first');
   iStop = find(~isnan(data.x(:,1)),1,'last');
   X = nan(numel(markerName),iStop - iStart + 1);
   Y = nan(size(X));
   Slice = repmat(1:(iStop-iStart+1),numel(markerName),1);
   Slice = reshape(Slice,numel(Slice),1);
   Marker = (1:numel(Slice)).';
   Area = zeros(size(Marker));
   Mean = ones(size(Marker));
   Min = ones(size(Marker));
   Max = ones(size(Marker));
   for ik = 1:numel(markerName)
      X(ik,:) = fillmissing(data.x(iStart:iStop,ik),'pchip');
      X(ik,:) = sgolayfilt(X(ik,:),3,21);
      Y(ik,:) = fillmissing(data.y(iStart:iStop,ik),'pchip');
      Y(ik,:) = sgolayfilt(Y(ik,:),3,21);
   end
   X = reshape(X,numel(X),1);
   Y = reshape(Y,numel(Y),1);
   
   
   V = VideoReader(fullfile(curationData.folder{ii},curationData.vid{ii}));  %#ok<*TNMLP>
   t = linspace(0,V.Duration-(1/V.FrameRate),size(data.x,1));
   V.CurrentTime = t(iStart);
   C = readFrame(V);
   im = image(ax,C);
   roi = imrect(ax,[1 1 511 511]);
   roi.setResizable(false);
   fcn = makeConstrainToRectFcn('imrect',[1 V.Width],[1 V.Height]);
   roi.setPositionConstraintFcn(fcn);
   setColor(roi,'r');
   wait(roi);
   setColor(roi,'k');
   pos = getPosition(roi);
   
   X = X - pos(1);
   Y = Y - pos(2);
   idx = (X < 1) | (Y < 1) | (X > 507) | (Y > 507);
   X(idx) = 1;
   Y(idx) = 1;
   
   Labels = table(Marker,Area,Mean,Min,Max,X,Y,Slice);
   out_dir = fullfile(OUT_DIR,name);
   if exist(out_dir,'dir')==0
      mkdir(out_dir);
   end
   iCount = 0;
   while (V.CurrentTime <= t(iStop))
      imwrite(imcrop(C,pos),fullfile(out_dir,sprintf('%s_train-img-%03g.PNG',name,iCount)));
      C = readFrame(V);
      im.CData = C;
      drawnow;
      iCount = iCount + 1;
   end
   writetable(Labels,fullfile(out_dir,'Labels.csv'));
   delete(im);
   delete(roi);
end
delete(fig);
toc;

end