function [an,ax,fig] = animateSingleReach(worldPoints,V,frameTimes,varargin)
%% ANIMATESINGLEREACH Make 3D rendering of a specific reach in world coords
%
%  [an,ax,fig] = ANIMATESINGLEREACH(worldPoints,V);
%  [an,ax,fig] = ANIMATESINGLEREACH(worldPoints,V,'NAME',value,...);
%
%  --------
%   INPUTS
%  --------
%  worldPoints    :     Struct of world 3D coordinates for each marker.
%
%     V           :     Cell array of video reader objects. First element
%                          is side video, second is front.
%
%  frameTimes     :     Time limits for frames corresponding to both
%                          videos.
%
%  varargin       :     (Optional) 'NAME', value input argument pairs.
%
%  --------
%   OUTPUT
%  --------
%    an           :     Cell array of animated line objects.
%
%    ax           :     Axes containing animated lines
%
%   fig           :     Handle to figure containing axes.
%
% By: Max Murphy  v1.0  10/05/2018 Original Version (R2017b)

%% DEFAULTS
COL = defaults.markerParams('color');
% COL = {[1 0 0]; ...
%        [1 0 0]; ...
%        [1 0 0]; ...
%        [0 0 1]; ...
%        [0 0 1]; ...
%        [0 0 1]; ...
%        [1 1 1]; ...
%        [0 0 0]}; % Make pellet black to block it from view
    
SEG = {[1 2 9]; ...
       [3 4 9]; ...
       [5 6 9]; ...
       [7 8 9]};
    
SEG_COL = COL([1,3,5,7]);

FPS = 120;

UB = 1.00;
LB = 0.00;

MAX_N_PTS = 3;
VIEW = [140 55;...
        30 30; ...
        30 -30];
TOL = 0.1;

FS = 240; % GoPro rate
ORD = 4; % Butterworth low pass filter order
WC = 15; % Cutoff (Hz) for low pass filter

CROP_POS = {[0 0 V{1}.Width V{1}.Height]; ...
            [0 0 V{2}.Width V{2}.Height]};

MOVIE_NAME = nan;

X_LIM = nan;
% X_LIM = [-10  5];
Y_LIM = nan;
% Y_LIM = [-15  5];
Z_LIM = nan;
% Z_LIM = [-25 10];

EXPORT_FRAMES = false;
IMTYPE = '.png';
         
%% PARSE VARARGIN
for iV = 1:2:numel(varargin)
   eval([upper(varargin{iV}) '=varargin{iV+1};']);
end

if ~isnan(MOVIE_NAME)
   close all force
end



%% BEGIN
fig = figure('Name','Animated Reach 3D',...
   'Units','Normalized',...
   'Position',[0.3 0.3 0.5 0.5],...
   'NumberTitle','off',...
   'Color','k');

%% GET WORLD POINTS IN [X,Y,Z] MATRIX FORM
% Each column is a different markers
[X,Y,Z] = w2xyz(worldPoints,FS,WC,ORD);
N = size(X,2);
M = size(X,1);
K = size(SEG,1);

[Xs,Ys,Zs] = w2seg(worldPoints,SEG,FS,WC,ORD);

%% CREATE AXES AND ANIMATED LINE OBJECT
ax = {axes(fig); axes(fig); axes(fig)};

ub = min(round(UB * M * N),M*N);
lb = max(round(LB * M * N),1);



for ii = 1:numel(ax)
   x = sort(X(:,:,ii),'ascend');
   y = sort(Y(:,:,ii),'ascend');
   z = sort(Z(:,:,ii),'ascend');

   if isnan(X_LIM)
      xlb = x(lb) - (TOL * (x(ub)-x(lb)));
      xub = x(ub) + (TOL * (x(ub)-x(lb)));
      xl = [xlb, xub];
   else
      xl = X_LIM;
   end

   if isnan(Y_LIM)
      ylb = y(lb) - (TOL * (y(ub)-y(lb)));
      yub = y(ub) + (TOL * (y(ub)-y(lb)));
      yl = [ylb, yub];
   else
      yl = Y_LIM;
   end

   if isnan(Z_LIM)
      zlb = z(lb) - (TOL * (z(ub)-z(lb)));
      zub = z(ub) + (TOL * (z(ub)-z(lb)));
      zl = [zlb, zub];
   else
      zl = Z_LIM;
   end
    
   ax{ii}.Color = 'k';
   ax{ii}.Units = 'Normalized';
   ax{ii}.Position = [0.33 0.15+(0.3 * (ii-1)) 0.33 0.25];
   ax{ii}.XLimMode = 'manual';
   ax{ii}.YLimMode = 'manual';
   ax{ii}.ZLimMode = 'manual';
   set(ax{ii},'Box','on');
   set(ax{ii},'XGrid','on');
   set(ax{ii},'YGrid','on');
   set(ax{ii},'ZGrid','on');
   set(ax{ii},'View',VIEW(ii,:));
   set(ax{ii},'XLim',xl);
   set(ax{ii},'YLim',yl);
   set(ax{ii},'ZLim',zl);
end

an = cell(N,numel(ax));
seg = cell(K,numel(ax));

%% INITALIZE ANIMATED LINES
for ii = 1:numel(ax)
   for iN = 1:N
      an{iN,ii} = animatedline(ax{ii},X(1,iN,ii),Y(1,iN,ii),Z(1,iN,ii),...
         'Color',COL{iN},...
         'LineWidth',2,...
         'MaximumNumPoints',MAX_N_PTS);   
   end
end

for ii = 1:numel(ax)
   for iK = 1:K
      seg{iK,ii} = animatedline(ax{ii},Xs{iK,ii}(1,:),Ys{iK,ii}(1,:),Zs{iK,ii}(1,:),...
         'Color',SEG_COL{iK},...
         'LineWidth',1.5,...
         'LineStyle',':',...
         'Marker','sq',...
         'MarkerFaceColor',SEG_COL{iK},...
         'MarkerSize',20,...
         'MaximumNumPoints',numel(SEG{iK}));
   end
end


im_ax = cell(2,1);
im_ax{1} = axes('Units','Normalized',...
   'Position',[0 0 0.3 1],...
   'XTick',[],...
   'XLim',[0 1],...
   'XLimMode','Manual',...
   'YTick',[],...
   'YLim',[0 1],...
   'YLimMode','Manual',...
   'YDir','reverse',...
   'NextPlot','replacechildren');

im_ax{2} = axes('Units','Normalized',...
   'Position',[0.7 0 0.3 1],...
   'XTick',[],...
   'XLim',[0 1],...
   'XLimMode','Manual',...
   'YTick',[],...
   'YLim',[0 1],...
   'YLimMode','Manual',...
   'YDir','reverse',...
   'NextPlot','replacechildren');


for iV = 1:numel(V)
   V{iV}.CurrentTime = frameTimes(1);
end
updateImages(im_ax,V,CROP_POS);

if ~isnan(MOVIE_NAME)
   [filepath,mname,~] = fileparts(MOVIE_NAME);
   if exist(filepath,'dir')==0
      if ~isempty(filepath)
         mkdir(filepath);
      end
   end
   vid = VideoWriter(MOVIE_NAME,'MPEG-4');
   exportImdir = fullfile(filepath,mname);
   if (exist(exportImdir,'dir')==0) && (EXPORT_FRAMES)
      mkdir(exportImdir);
   end
   open(vid);
   vidFrame = getframe(fig);
   writeVideo(vid,vidFrame);
end

%% ANIMATE THE LINES
iFrame = 2;
while (V{1}.CurrentTime <= frameTimes(2)) && ...
      (V{2}.CurrentTime <= frameTimes(2)) && ...
      (iFrame <= M)
   for ii = 1:numel(ax)
      for iN = 1:N
         addpoints(an{iN,ii},X(iFrame,iN,ii),Y(iFrame,iN,ii),Z(iFrame,iN,ii));
      end

      for iK = 1:K
         addpoints(seg{iK,ii},Xs{iK,ii}(iFrame,:),Ys{iK,ii}(iFrame,:),Zs{iK,ii}(iFrame,:));      
      end
   end
   
   cur_Im = updateImages(im_ax,V,CROP_POS);
   if (exist('exportImdir','var')~=0) && (EXPORT_FRAMES)
      for ii = 1:numel(cur_Im)
         imwrite(cur_Im{ii},fullfile(exportImdir,...
            sprintf('%s-%d-train-img-%03g%s',mname,ii,iFrame,IMTYPE)));
      end      
   end
   
   
   drawnow limitrate
   
   if isnan(MOVIE_NAME)
      pause(1/FPS);
   else
      vidFrame = getframe(fig);
      writeVideo(vid,vidFrame);
   end
   iFrame = iFrame + 1;
end

if ~isnan(MOVIE_NAME)
   close(vid);
end


   function [X,Y,Z] = w2xyz(w,fs,wc,ord)
      [b,a] = butter(ord,wc/(fs/2),'low');
      
%       f = fieldnames(w);
%       X = nan(size(w.(f{1}),1),numel(f));
%       Y = nan(size(w.(f{1}),1),numel(f));
%       Z = nan(size(w.(f{1}),1),numel(f));
      X = nan(size(w{1},1),numel(w),size(w{1},3));
      Y = nan(size(w{1},1),numel(w),size(w{1},3));
      Z = nan(size(w{1},1),numel(w),size(w{1},3));

      for iW = 1:size(w{1},3)
         xo = w{9}(1,1,iW);
         yo = w{9}(1,2,iW);
         zo = w{9}(1,3,iW);

         for iF = 1:numel(w)
   %          X(:,iF) = filtfilt(b,a,w.(f{iF})(:,1));
   %          Y(:,iF) = filtfilt(b,a,w.(f{iF})(:,2));
   %          Z(:,iF) = filtfilt(b,a,w.(f{iF})(:,3));
   %          X(:,iF) = w.(f{iF})(:,1);
   %          Y(:,iF) = w.(f{iF})(:,2);
   %          Z(:,iF) = w.(f{iF})(:,3);

   %          X(:,iF) = filtfilt(b,a,w{iF}(:,1));
   %          Y(:,iF) = filtfilt(b,a,w{iF}(:,2));
   %          Z(:,iF) = filtfilt(b,a,w{iF}(:,3));

            X(:,iF,iW) = sgolayfilt(w{iF}(:,1,iW),3,21);
            Y(:,iF,iW) = sgolayfilt(w{iF}(:,2,iW),3,21);
            Z(:,iF,iW) = sgolayfilt(w{iF}(:,3,iW),3,21);
   %          X(:,iF) = w{iF}(:,1);
   %          Y(:,iF) = w{iF}(:,2);
   %          Z(:,iF) = w{iF}(:,3);

         end
         X(:,:,iW) = (X(:,:,iW) - xo);
         Y(:,:,iW) = -(Y(:,:,iW) - yo);
         Z(:,:,iW) = (Z(:,:,iW) - zo);
      end
      
   end

   function [Xs,Ys,Zs] = w2seg(w,seg_labs,fs,wc,ord)
      [b,a] = butter(ord,wc/(fs/2),'low');
      
      Xs = cell(numel(seg_labs),size(w{1},3));
      Ys = cell(numel(seg_labs),size(w{1},3));
      Zs = cell(numel(seg_labs),size(w{1},3));
      
      for iW = 1:size(w{1},3)
         xo = w{9}(1,1,iW);
         yo = w{9}(1,2,iW);
         zo = w{9}(1,3,iW);


         for iSeg = 1:numel(seg_labs)
            for iSegN = 1:numel(seg_labs{iSeg})

   %             Xs{iSeg} = [Xs{iSeg}, ...
   %                filtfilt(b,a,w{seg_labs{iSeg}(iSegN)}(:,1) - xo)];
   %             Ys{iSeg} = [Ys{iSeg}, ...
   %                filtfilt(b,a,-(w{seg_labs{iSeg}(iSegN)}(:,2) - yo))];
   %             Zs{iSeg} = [Zs{iSeg}, ...
   %                filtfilt(b,a,w{seg_labs{iSeg}(iSegN)}(:,3) - zo)];

               Xs{iSeg,iW} = [Xs{iSeg,iW}, ...
                  sgolayfilt(w{seg_labs{iSeg}(iSegN)}(:,1,iW) - xo,3,21)];
               Ys{iSeg,iW} = [Ys{iSeg,iW}, ...
                  sgolayfilt(-(w{seg_labs{iSeg}(iSegN)}(:,2,iW) - yo),3,21)];
               Zs{iSeg,iW} = [Zs{iSeg,iW}, ...
                  sgolayfilt(w{seg_labs{iSeg}(iSegN)}(:,3,iW) - zo,3,21)];
            end      
         end
      end
      
   end

   function J = updateImages(im_ax,v,crop_pos)
      J = cell(2,1);
      for iIm = 1:2
         I = readFrame(v{iIm});
         J{iIm} = imcrop(I,crop_pos{iIm});
         if iIm == 1
            image(im_ax{iIm},[0 1],[0 1],J{iIm});
         else
            image(im_ax{iIm},[0 1],[0 1],J{iIm});
         end
      end
   end

end