function [data,fig] = viewTrialKinematicMarkers(T)
%% VIEWTRIALKINEMATICMARKERS  View kinematic markers for a given trial 
%
%  [data,fig] = VIEWTRIALKINEMATICMARKERS(T);
%
%  --------
%   INPUTS
%  --------
%     T     :     Data table from DeepLabCut for a single kinematics trial.
%
%  --------
%   OUTPUT
%  --------
%    fig    :     Handle to figure that is plotted on.
%
% By: Max Murphy  v1.0  2019-05-16  Original version (R2017a)

%%
m = T.Properties.VariableNames(2:end);

if nargout > 1
   fig = figure('Name','Kinematic Tracking Preview',...
      'Units','Normalized',...
      'Position',[0.2 0.2 0.5 0.5],...
      'Color','w');
end

nMarker = numel(m)/3;
nRow = floor(sqrt(nMarker));
nCol = ceil(nMarker/nRow);

iCount = 0;
x = nan(size(T,1),nMarker);
y = nan(size(T,1),nMarker);
p = nan(size(T,1),nMarker);

axxMax = -inf;
axyMax = -inf;
axxMin = inf;
axyMin = inf;
for ii = 1:3:numel(m)
   iCount = iCount + 1;
   x(:,iCount) = T.(m{ii});
   y(:,iCount) = T.(m{ii+1});
   p(:,iCount) = T.(m{ii+2});
   x(p(:,iCount)<=0.1,iCount) = nan;
   y(p(:,iCount)<=0.1,iCount) = nan;
   pStart = find(p(:,iCount) > 0.1,1,'first');
   pStop = find(p(:,iCount) > 0.1,1,'last');
   x(pStart:pStop,iCount) = fillmissing(x(pStart:pStop,iCount),'pchip');
   y(pStart:pStop,iCount) = fillmissing(y(pStart:pStop,iCount),'pchip');
   
   
   if nargout > 1
      subplot(nRow,nCol,iCount);
      txt = strsplit(m{ii},'_');
      txt = strjoin(txt(1:2),'_');
      title(txt,'FontName','Arial','FontSize',14,'Color','k');
      comet3((pStart:pStop)/240,x(pStart:pStop,iCount),y(pStart:pStop,iCount));
      view([-10 20]);
      str = strsplit(m{ii},'_');
      title(strjoin(str(1:2),'_'));
      xl = get(gca,'YLim');
      yl = get(gca,'ZLim');
      axxMax = max(axxMax,xl(2));
      axyMax = max(axyMax,yl(2));
      axxMin = min(axxMin,xl(1));
      axyMin = min(axyMin,yl(1));
   end
end

if nargout > 1
   for ii = 1:iCount
      subplot(nRow,nCol,ii);
      set(gca,'YLim',[axxMin axxMax]);
      set(gca,'ZLim',[axyMin axyMax]);
   end
end

data = struct;
data.x = x;
data.y = y;
data.p = p;

end