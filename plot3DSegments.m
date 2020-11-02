function fig = plot3DSegments(X,Y,Z,fig,varargin)
%% PLOT3DSEGMENTS    Plot segments in 3D
%
%  fig = PLOT3DSEGMENTS(X,Y,Z);
%  fig = PLOT3DSEGMENTS(X,Y,Z,fig);
%  fig = PLOT3DSEGMENTS(X,Y,Z,'NAME',value,...);
%
% By: Max Murphy  v1.0  10/02/2018  Original version (R2017b)

%% DEFAULTS
MARKER = 'o';
MARKERFACECOLOR = 'm';
MARKERSIZE = 5;
LINEWIDTH = 2;
LINESTYLE = ':';
COLOR = 'k';
MARKEREDGECOLOR = 'none';

TITLE = '3D-Reconstruction';
TITLE_SIZE = 16;
FONT = 'Arial';

XLABEL = 'X (mm)';
YLABEL = 'Y (mm)';
ZLABEL = 'Z (mm)';
LABEL_SIZE = 14;

%% PARSE VARARGIN
for iV = 1:2:numel(varargin)
   eval([upper(varargin{iV}) '=varargin{iV+1};']);
end

%% MAKE FIGURE AND PLOT
if exist('fig','var')==0
   fig = figure('Name','World-Coordinates',...
      'Units','Normalized',...
      'Position',[0.2 0.2 0.5 0.5],...
      'Color','w',...
      'NumberTitle','off');
   new_fig = true;
elseif ~isa(fig,'matlab.ui.Figure')
   fig = figure('Name','World-Coordinates',...
      'Units','Normalized',...
      'Position',[0.2 0.2 0.5 0.5],...
      'Color','w',...
      'NumberTitle','off');
   new_fig = true;
else
   new_fig = false;
   figure(fig);
   hold on;
end
   
plot3(X,Y,Z,...
   'Marker',MARKER,...
   'MarkerFaceColor',MARKERFACECOLOR,...
   'MarkerSize',MARKERSIZE,...
   'LineWidth',LINEWIDTH,...
   'LineStyle',LINESTYLE,...
   'Color',COLOR,...
   'MarkerEdgeColor',MARKEREDGECOLOR);

if new_fig
   xlabel(XLABEL,'FontName',FONT,'FontSize',LABEL_SIZE,'Color',COLOR);
   ylabel(YLABEL,'FontName',FONT,'FontSize',LABEL_SIZE,'Color',COLOR);
   zlabel(ZLABEL,'FontName',FONT,'FontSize',LABEL_SIZE,'Color',COLOR);

   title(TITLE,...
      'FontName',FONT,...
      'FontSize',TITLE_SIZE,...
      'Color',COLOR);
end

end