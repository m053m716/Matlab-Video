classdef kinCurator < handle
   %% KINCURATOR  Class to display simultaneous GoPro vids
   %   
   %  obj = KINCURATOR; % Prompts for _VideoScoring.mat file with UI
   %  obj = KINCURATOR('R19-54_2019_05_08_1_VideoScoring.mat');
   %
   % By: Max Murphy v1.0  2019-05-20 Original version (R2017a)
   
   properties (Access = public)
      name         % recording name    
      curationData % table pointing to various files
      F            % cell array of current trial video and kinematic data
   end
   
   properties (Access = private)
      vidPanel % panel container for videos to separate from "time" axes
      V           % VideoReader array
      
      t_ax           % "time" axes allowing click-to-scroll
      trial_lab      % label handle for text indicating which trial
      
      t              % vector of time indices for 
      t_line         % current time handle for line that shows the time
      ax             % array of handles to axes for videos
      img            % array of handles to images with video frames
      curAx          % index of currently clicked-on axis
      
      cutStart       % line indicating start of "cutting"
      cutStop        % line indicating stop of "cutting"
      
      pThresh= -1    % probability threshold
      zoomState=1    % zoom "state" for time axis
      zoomLims=[0 3;...
         -0.5 0.5;...   % zoom limit modifiers for zooming in/out
         -0.15 0.15];
      XY=1           % 1 --> x is plotted; 2 --> y is plotted
      invXY=2
      kin            % struct for kinematics handles
      marker         % markerless tracking indicator points
      markerParams   % marker name cell string array
      markerRadioButton    % individual radio buttons for markers
      markerButtonGroup    % handle to marker tracking radio button group
      
      sfx
   end
   
   properties (Hidden = true)
      vidFig         % handle to main (video) figure
      labFig         % handle to labeling radio button figure
      helpFig        % handle to the "help" figure popup
      trial          % current trial index
      label          % index to current marker label
      time           % current time index
      
      
   end
   
   methods
      % Constructor for KINCURATOR object
      function obj = kinCurator(curationData)
         obj.name = strsplit(curationData.vid{1},'_');
         obj.name = strjoin(obj.name(1:5),'_');
         obj.curationData = curationData;
         
         % Initialize the graphics
         obj.initVidFig;
         obj.initTimeAxis;
         obj.initTrialLabels;
         obj.setCurrentTrial(curationData.trial(1));
         
            
         % Initialize labeling table and tracking
         obj.markerParams = defaults.markerParams();
         obj.initLabFig;
            
         % Initialize time axes
         obj.initTrialData;
         
      end
      
      % Change the label for a given "markerless labeling" marker
      function changeLabel(obj,src,~)
         obj.markerRadioButton{src.UserData}.String = src.String;
         obj.markerParams(src.UserData).name = src.String;
      end
      
      % Close all extra HUD windows
      function closeWindows(obj)         
         if ~isempty(obj.labFig)
            if isvalid(obj.labFig)
               close(obj.labFig);
            end
         end
         
         if ~isempty(obj.helpFig)
            if isvalid(obj.helpFig)
               close(obj.helpFig);
            end
         end

      end
      
      % Convert imPoint label values to pixel coordinates
      function out = convertImPoint2Pixel(obj,in,vidIdx,axType)
         switch lower(axType)
            case 'x'
               out = round(in .* obj.V{vidIdx}.Width) + 1;
            case 'y'
               out = round(in .* obj.V{vidIdx}.Height) + 1;
            otherwise
               error('Invalid axes type: %s',axType);
         end
      end
      
      % Convert pixel coordinates to values for imPoint for labels
      function out = convertPixel2ImPoint(obj,in,vidIdx,axType)
         switch lower(axType)
            case 'x'
               out = (in-1) ./ obj.V{vidIdx}.Width;
            case 'y'
               out = (in-1) ./ obj.V{vidIdx}.Height;
            otherwise
               error('Invalid axes type: %s',axType);
         end
      end
      
      % Convert pixel coordinates to formatted values for time axes
      function out = convertPixel2TimeAx(obj,in,vidIdx,axType)
         p = obj.F(vidIdx).data.p;
         
         switch lower(axType)
            case 'x'
               xMax = max(obj.F(vidIdx).data.x(p >= obj.pThresh));
               xMin = min(obj.F(vidIdx).data.x(p >= obj.pThresh));

               out = ((in-xMin+1)./(xMax - xMin));
            case 'y'
               yMax = max(obj.F(vidIdx).data.y(p >= obj.pThresh));
               yMin = min(obj.F(vidIdx).data.y(p >= obj.pThresh));

               out = ((in-yMin+1)./(yMax - yMin));
            otherwise
               error('Invalid axes type: %s',axType);
         end
      end
      
      % Convert formatted time axes values back to pixel coordinates
      function out = convertTimeAx2Pixel(obj,in,vidIdx,axType)
         switch lower(axType)
            case 'x'
               out = round(in .* (obj.V{vidIdx}.Width)) + 1;
            case 'y'
               out = round(in .* (obj.V{vidIdx}.Height)) + 1;
            otherwise
               error('Invalid axes type: %s',axType);
         end
      end
      
      % Get marker positions for all markers in a specific video
      function [x,y] = getMarkerPosition(obj,vidIdx,timeIdx)
         x = struct;
         y = struct;
         x.orig = obj.F(vidIdx).data.x(timeIdx,:);
         x.norm = (x.orig-1)/obj.V{vidIdx}.Width;
         y.orig = obj.F(vidIdx).data.y(timeIdx,:);
         y.norm = (y.orig-1)/obj.V{vidIdx}.Height;
      end
      
      % Initialize the "markerless labeling" window
      function initLabFig(obj)
         if ~isempty(obj.labFig)
            if isvalid(obj.labFig)
               return;
            end
         end
         
         obj.labFig = figure('Name','Labeling Info',...
            'MenuBar','none',...
            'NumberTitle','off',...
            'ToolBar','none',...
            'Units','Normalized',...
            'Position',[0.8 0.1 0.15 0.8],...
            'Color','w',...
            'WindowKeyPressFcn',@obj.keyPressLabFig,...
            'DeleteFcn',@obj.keyPressVidFigRevert);
         
         [y,h] = uiGetVerticalSpacing(numel(obj.markerParams));
         scl = 0.75;
         obj.markerButtonGroup = uibuttongroup(obj.labFig,...
            'Units','Normalized',...
            'Position',[0.175 0 0.825 scl],...
            'BackgroundColor','w',...
            'ForegroundColor','k',...
            'SelectionChangedFcn',@obj.updateLabelID);
         obj.markerRadioButton = cell(size(obj.markerParams));
         for ii = 1:numel(obj.markerParams)
            obj.markerRadioButton{ii} = uicontrol(...
               obj.markerButtonGroup,'Style','radiobutton',...
               'Units','Normalized',...
               'BackgroundColor','w',...
               'ForegroundColor','k',...
               'FontWeight','bold',...
               'HorizontalAlignment','right',...
               'UserData',ii,...
               'Min',0,...
               'Max',1,...
               'Position',[0.1 y(ii) 0.075 h]);
         end
         
         for ii = 1:numel(obj.markerParams)
            uicontrol(obj.labFig,'Style','edit',...
               'Units','Normalized',...
               'BackgroundColor','w',...
               'HorizontalAlignment','left',...
               'ForegroundColor',obj.markerParams(ii).color,...
               'FontName','Arial',...
               'FontWeight','bold',...
               'String',obj.markerParams(ii).name,...
               'FontSize',14,...
               'Position',[0.40 y(ii)*scl 0.45 h],...
               'Callback',@obj.changeLabel);
         end
         
         
         for ii = 1:numel(obj.markerParams)
            annotation(obj.labFig,'ellipse',[0.05 y(ii)*scl 0.1 h],...
               'Color',obj.markerParams(ii).color,...
               'FaceColor',obj.markerParams(ii).color,...
               'Units','Normalized');
         end
         
         for ii = 1:numel(obj.img)
            obj.img{ii}.ButtonDownFcn = @obj.placeLabelMarker;
         end
         obj.initLabMarkers;
         obj.label = 1;
         
         uicontrol(obj.labFig,...
            'Style','popupmenu',...
            'Units','Normalized',...
            'BackgroundColor','w',...
            'ForegroundColor','k',...
            'FontName','Arial',...
            'FontSize',16,...
            'String',{'x';'y'},...
            'Position',[0.25 y(end)*scl+0.05 0.5 0.1],...
            'Callback',@obj.setXYPlot);
         
         obj.vidFig.WindowKeyPressFcn = @obj.keyPressLabFig;
         [data,fs] = defaults.sfx('camera');
         obj.sfx = audioplayer(data,fs);
      end
      
      % Initialize the labeling marker objects
      function initLabMarkers(obj)
         fcn = makeConstrainToRectFcn('impoint',[0 1],[0 1]);
         if isempty(obj.marker)
            obj.marker = cell(numel(obj.F),1);
         end
         
         
         for ii = 1:numel(obj.F)
            x = obj.F(ii).data.x(1,:);
            y = obj.F(ii).data.y(1,:);

            if isempty(obj.marker{ii})
               obj.marker{ii} = cell(size(obj.markerParams));
               for ik = 1:numel(obj.markerParams)
                  obj.marker{ii}{ik} = impoint(obj.ax{ii},...
                     x(ik),y(ik),'PositionConstraintFcn',fcn);
                  setColor(obj.marker{ii}{ik},obj.markerParams(ik).color);
               end
            else
               for ik = 1:numel(obj.markerParams)
                  setPosition(obj.marker{ii}{ik},x(ik),y(ik));
               end
            end
            c = get(obj.ax{ii},'Children');
            for ic = 1:numel(c)
               if strcmp(c(ic).Tag,'impoint')
                  set(c(ic),'PickableParts','none');
               end
            end
         end
         
      end
      
      % Initialize trial-specific data for time-axes at top
      function initTrialData(obj,newVid)
         if nargin < 2
            newVid = false;
         end
         if isempty(obj.kin)
            obj.kin = struct('pt',cell(size(obj.F)),...
               'line',cell(size(obj.F)));
         end
         for ii = 1:numel(obj.kin)
            if isempty(obj.kin(ii).pt) || newVid
               
               p = obj.F(ii).data.p;
               x = obj.F(ii).data.x;
               x(p < obj.pThresh) = nan;
               x = obj.convertPixel2TimeAx(x,ii,'x');
               y = obj.F(ii).data.y;
               y(p < obj.pThresh) = nan;
               y = obj.convertPixel2TimeAx(y,ii,'y');
               
               if isempty(obj.kin(ii).pt)
                  obj.kin(ii).pt = cell(numel(obj.markerParams),2);
                  for ik = 1:numel(obj.markerParams)
                     obj.kin(ii).pt{ik,1} = scatter(obj.t_ax,...
                        obj.t{ii},x(:,ik),'filled',...
                        'Marker',obj.markerParams(ik).shape,...
                        'SizeData',8,...
                        'MarkerFaceColor',obj.markerParams(ik).color,...
                        'MarkerEdgeColor',obj.markerParams(ik).color,...
                        'Visible','off');
                     obj.kin(ii).pt{ik,2} = scatter(obj.t_ax,...
                        obj.t{ii},y(:,ik),'filled',...
                        'Marker',obj.markerParams(ik).shape,...
                        'SizeData',8,...
                        'MarkerFaceColor',obj.markerParams(ik).color,...
                        'MarkerEdgeColor',obj.markerParams(ik).color,...
                        'Visible','off');
                     if ii == obj.curAx
                        obj.kin(ii).pt{ik,obj.XY}.Visible = 'on';
                     end
                  end 
               else
                  for ik = 1:numel(obj.markerParams)
                     set(obj.kin(ii).pt{ik,1},...
                        'XData',obj.t{ii},...
                        'YData',x(:,ik));
                     set(obj.kin(ii).pt{ik,2},...
                        'XData',obj.t{ii},...
                        'YData',y(:,ik));
                  end
               end
            end
            
%             if isempty(obj.kin(ii).line)
%                obj.kin(ii).line = cell(size(obj.markerParams));
%                for ik = 1:numel(obj.markerParams)
%                   
%                end
%             end
         end
      end
      
      % Initialize time-axes at top, in general
      function initTimeAxis(obj)
         obj.t_ax = axes(obj.vidFig,'Units','Normalized',...
            'YTick',[],...
            'YLim',[0 1],...
            'XTick',[],...
            'XLim',[0 1],...
            'Color',[0.94 0.94 0.94],...
            'NextPlot','add',...
            'Position',[0 0.9 1 0.1],...
            'UserData',nan,...
            'ButtonDownFcn',@obj.skipToFrame);
         obj.t_line = line(obj.t_ax,[0 0],[0 1],'LineStyle','--',...
            'LineWidth',1.5,'Color','k','ButtonDownFcn',@obj.skipToFrame); 
         obj.cutStart = line(obj.t_ax,[nan nan],[0.1 0.9],...
            'LineWidth',1.0,...
            'Color',[0.25 0.25 0.25],...
            'LineStyle','-.');
         obj.cutStop = line(obj.t_ax,[nan nan],[0.1 0.9],...
            'LineWidth',1.0,...
            'Color',[0.25 0.25 0.25],...
            'LineStyle',':');
      end
      
      % Initialize the labels of the current trial and trial selector edit
      function initTrialLabels(obj)
         obj.trial_lab = uicontrol(obj.vidFig,...
            'Style','edit',...
            'Units','Normalized',...
            'Position',[0.20 0.925 0.10 0.05],...
            'String',num2str(obj.curationData.trial(1)),...
            'FontName','Arial',...
            'FontSize',18,...
            'ForegroundColor',[0 0 0],...
            'BackgroundColor',[1 1 1],...
            'Callback',@obj.setCurrentTrial);
         uicontrol(obj.vidFig,...
            'Style','text',...
            'Units','Normalized',...
            'Position',[0.30 0.925 0.05 0.05],...
            'String',sprintf('/ %g',max(obj.curationData.trial)),...
            'FontName','Arial',...
            'FontSize',18,...
            'ForegroundColor',[0 0 0],...
            'BackgroundColor',[1 1 1]);
      end
      
      % Initialize the vid (main) figure
      function initVidFig(obj)
         obj.vidFig = figure('Name','Kinematics Curator',...
            'MenuBar','none',...
            'NumberTitle','off',...
            'ToolBar','none',...
            'Units','Normalized',...
            'Position',[0.05 0.1 0.725 0.8],...
            'Color','w',...
            'Pointer','cross',...
            'WindowKeyPressFcn',@obj.keyPressVidFig,...
            'WindowButtonDownFcn',@obj.wbdcb,...
            'DeleteFcn',@obj.mainFigDeleteFcn);
         obj.vidPanel = uipanel(obj.vidFig,...
            'BackgroundColor','w',...
            'Units','Normalized',...
            'Position',[0 0 1 0.9],...
            'BorderWidth',0.5);

         obj.ax = uiPanelizeAxes(obj.vidPanel,...
            sum(obj.curationData.trial==obj.curationData.trial(1)));
         obj.curAx = 1;
         for ii = 1:numel(obj.ax)
            obj.ax{ii}.UserData = ii;
            obj.ax{ii}.YDir = 'reverse';
            obj.ax{ii}.Box = 'on';
            if ii == obj.curAx
               obj.ax{ii}.XColor = 'm';
               obj.ax{ii}.YColor = 'm';
            else
               obj.ax{ii}.XColor = 'w';
            	obj.ax{ii}.YColor = 'w';
            end
            obj.ax{ii}.XTick = [];
            obj.ax{ii}.YTick = [];
            obj.ax{ii}.LineWidth = 5;
         end
         
         obj.img = cell(size(obj.ax));
         for ii = 1:numel(obj.ax)
            obj.img{ii} = imagesc(obj.ax{ii},[0 1],[0 1],0);
            obj.img{ii}.UserData = ii;
         end
      end
      
      % Shortcut keys for "markerless labeling" window
      function keyPressLabFig(obj,~,evt)
         fs = obj.V{1}.FrameRate;
         ts = obj.t_line.XData(1);

         switch lower(evt.Key)
            case {'a','leftarrow'} % previous frame

               for ii = 1:numel(obj.V)
                  obj.V{ii}.CurrentTime = obj.V{ii}.CurrentTime - (2/fs);
               end
               obj.refreshImageFrame();

            case {'d','rightarrow'} % next frame

               obj.refreshImageFrame();
               
            case 's' % previous trial
               if ismember('alt',evt.Modifier)
                  obj.saveTrialScoring;
               else
                  trials = obj.curationData.trial;
                  trialIdx = find(trials < obj.trial,1,'last');
                  obj.setCurrentTrial(trials(trialIdx),nan);
               end
            case 'w' % next trial
               trials = obj.curationData.trial;
               trialIdx = find(trials > obj.trial,1,'first');
               obj.setCurrentTrial(trials(trialIdx),nan);
            case 'h'
               str = {...
                   'a/d:                advance/retreat frame'; ...
                   'w/s:                next/previous trial'; ...
                   'numPad0:      place dig1_d marker on click'; ...
                   'numPad1:      place dig1_p marker on click'; ...
                   'numPad2:      place dig2_d marker on click'; ...
                   'numPad3:      place dig2_p marker on click'; ...
                   'numPad4:      place dig3_d marker on click'; ...
                   'numPad5:      place dig3_p marker on click'; ...
                   'numPad6:      place dig4_d marker on click'; ...
                   'numPad7:      place dig4_p marker on click'; ...
                   'numPad8:      place hand marker on click'; ...
                   'numPad*:      place all markers on click'; ...
                   'numPad-:      move all markers out of bounds'};
               obj.openHelpFig(str);
               
            case 'escape'
               close(obj.labFig);
               obj.vidFig.WindowKeyPressFcn = @obj.keyPressVidFig;
            case 'add'
               obj.updateZoomState(obj.zoomState + 1);
            case 'subtract'
               obj.updateZoomState(obj.zoomState - 1);
         end
         
         obj.updateLabelID(nan,evt);
         
      end

      % Shortcut keys for main window when no other windows present
      function keyPressVidFig(obj,~,evt)
         fs = obj.V{1}.FrameRate;
         ts = obj.t_line.XData(1);
         switch lower(evt.Key)
            case {'a','leftarrow'} % previous frame

               for ii = 1:numel(obj.V)
                  obj.V{ii}.CurrentTime = obj.V{ii}.CurrentTime - (2/fs);
               end
               obj.refreshImageFrame();

            case {'d','rightarrow'} % next frame
               obj.refreshImageFrame();
               
            case 's' % previous trial
               if ismember('alt',evt.Modifier)
                  obj.saveTrialScoring;
               else
                  trials = obj.curationData.trial;
                  trialIdx = find(trials < obj.trial,1,'last');
                  obj.setCurrentTrial(trials(trialIdx),nan);
               end
            case 'w' % next trial
               trials = obj.curationData.trial;
               trialIdx = find(trials > obj.trial,1,'first');
               
               obj.setCurrentTrial(trials(trialIdx),nan);
            case 'h'
               obj.openHelpFig;
               
            case {'l','o'}
               obj.initLabFig;
               
            case 'escape'
               close(obj.vidFig);
            case 'add'
               obj.updateZoomState(obj.zoomState + 1);
            case 'subtract'
               obj.updateZoomState(obj.zoomState - 1);
         end
         
         obj.updateLabelID(nan,evt);
      end
      
      % Return the main figure shortcut keys to the defaults
      function keyPressVidFigRevert(obj,src,~)
         obj.vidFig.WindowKeyPressFcn = @obj.keyPressVidFig;
         if strcmp(get(gcbo,'Name'),'Labeling Info')
            for ii = 1:numel(obj.img)
               obj.img{ii}.ButtonDownFcn = [];
            end
         end
         delete(src);
      end
      
      % Close all other windows when main figure is closed
      function mainFigDeleteFcn(obj,src,~)
         obj.closeWindows;
         delete(src);
      end
      
      % Open a help figure with list of main figure shortcut keys
      function openHelpFig(obj,str)
         if ~isempty(obj.helpFig)
            if isvalid(obj.helpFig)
               return;
            end
         end
         
         if nargin < 2
            str = {'a/d:                advance/retreat frame'; ...
             'w/s:                next/previous trial'; ...
             'numPad0:      dig1_d'; ...
             'numPad1:      dig1_p'; ...
             'numPad2:      dig2_d'; ...
             'numPad3:      dig2_p'; ...
             'numPad4:      dig3_d'; ...
             'numPad5:      dig3_p'; ...
             'numPad6:      dig4_d'; ...
             'numPad7:      dig4_p'; ...
             'numPad8:      hand'};
         end
         
         obj.helpFig = figure('Name','Help: Keyboard Shortcuts',...
            'MenuBar','none',...
            'NumberTitle','off',...
            'ToolBar','none',...
            'Units','Normalized',...
            'Position',[0.3 0.3 0.4 0.4],...
            'Color','k',...
            'WindowKeyPressFcn',@obj.shortKey);
         
         uicontrol(obj.helpFig,'Style','text',...
            'Units','Normalized',...
            'Position',[0.1 0.1 0.8 0.8],...
            'HorizontalAlignment','left',...
            'String', str,...
            'ForegroundColor','w',...
            'BackgroundColor','k',...
            'FontName','Arial',...
            'FontSize',14);
      end

      % Open the video file for current trial
      function openVid(obj)
         obj.V = cell(1,numel(obj.F));
         t_max = -inf;
         obj.t = cell(size(obj.V));
         obj.time = ones(numel(obj.F),1);
         for ii = 1:numel(obj.F)
            obj.V{ii} = VideoReader(fullfile(...
               obj.F(ii).folder,...
               obj.F(ii).name)); %#ok<TNMLP>
            t_max = max(t_max,obj.V{ii}.Duration);
            obj.t{ii} = linspace(0,obj.V{ii}.Duration,size(obj.F(ii).data.x,1));
            obj.img{ii}.CData = readFrame(obj.V{ii});
            obj.ax{ii}.XLabel.String = obj.F(ii).cam;
            obj.ax{ii}.XLabel.Color = [0 0 0];
         end
         obj.zoomState = 1;
         obj.t_ax.XLim = [0 t_max];
         obj.zoomLims(1,:) = obj.t_ax.XLim;
         obj.t_line.XData = [0,0];
         obj.initTrialData(true);
      end
      
      % Place the label marker on the image where clicked
      function placeLabelMarker(obj,src,~)
         if ~(isa(src,'matlab.graphics.primitive.Image') || isempty(src))
            return;
         end
         if isempty(src)
            for ik = 1:numel(obj.ax)
               [x,y] = obj.getMarkerPosition(ik,obj.time(ik));
               for ii = 1:numel(obj.markerParams)
                  setPosition(obj.marker{ik}{ii},x.norm(ii),y.norm(ii));
               end
            end
         else
            p = src.Parent;
            pos = p.CurrentPoint;
            if isinf(obj.label)
               for ii = 1:numel(obj.markerParams)
                  setPosition(obj.marker{obj.curAx}{ii},...
                     pos(1,1),pos(1,2));
                  xp = obj.convertImPoint2Pixel(pos(1,1),obj.curAx,'x');
                  yp = obj.convertImPoint2Pixel(pos(1,2),obj.curAx,'y');
                  obj.F(obj.curAx).data.x(obj.time(obj.curAx),ii) = xp;
                  obj.F(obj.curAx).data.y(obj.time(obj.curAx),ii) = yp;
                  obj.updateScatter(xp,yp,obj.curAx,ii);
                     
               end
            elseif isnan(obj.label)
               for ik = 1:numel(obj.ax)
                  for ii = 1:numel(obj.markerParams)
                     setPosition(obj.marker{ik}{ii},0,0);
                     obj.F(ik).data.x(obj.time(ik),ii) = 1;
                     obj.F(ik).data.y(obj.time(ik),ii) = 1;
                     obj.updateScatter(1,1,ik,ii);
                  end
               end
            else
               setPosition(obj.marker{obj.curAx}{obj.label},...
                     pos(1,1),pos(1,2));
               xp = obj.convertImPoint2Pixel(pos(1,1),obj.curAx,'x');
               yp = obj.convertImPoint2Pixel(pos(1,2),obj.curAx,'y');
               
               obj.F(obj.curAx).data.x(obj.time(obj.curAx),obj.label) = xp;
               obj.F(obj.curAx).data.y(obj.time(obj.curAx),obj.label) = yp;
               
               obj.updateScatter(xp,yp,obj.curAx,obj.label);
            end
         end
      end  
      
      % Refresh the current image frame
      function refreshImageFrame(obj)
         for ii = 1:numel(obj.V)
            obj.V{ii}.CurrentTime = max(obj.V{ii}.CurrentTime,0);
            obj.V{ii}.CurrentTime = min(obj.V{ii}.CurrentTime,...
               obj.V{ii}.Duration - (1/obj.V{ii}.FrameRate));
         end
         
         obj.t_line.XData = [obj.V{1}.CurrentTime, obj.V{1}.CurrentTime];
         obj.time = nan(size(obj.F));
         for ii = 1:numel(obj.V)
            [~,obj.time(ii)] = min(abs(obj.t{ii}-obj.V{ii}.CurrentTime));
            obj.img{ii}.CData = readFrame(obj.V{ii});
         end
         obj.placeLabelMarker([],nan);
      end
      
      % Save scoring for this trial
      function saveTrialScoring(obj)
         for ii = 1:numel(obj.F)
            data = obj.F(ii).data;
            save(fullfile(obj.F(ii).folder,obj.F(ii).file),'-struct','data');
         end
         play(obj.sfx);
         disp('Save success!');
      end
      
      % Set the current trial
      function setCurrentTrial(obj,newTrial,~)
         if isempty(newTrial)
            return;
         end
         
         if isa(newTrial,'matlab.ui.control.UIControl')
            newTrial = str2double(newTrial.String);
            if isnan(newTrial)
               return;
            end
         end
         
         if isempty(obj.trial)
            obj.trial = inf;
         end

         if (newTrial ~= obj.trial)
            idx = find(obj.curationData.trial==newTrial);
            if isempty(idx)
               return;
            else
               obj.trial = newTrial;
            end
            
            f = obj.curationData.folder(idx);
            if exist(f{1},'dir')==0
               for ii = 1:numel(f)
                  pInfo = strsplit(f{ii},'\');
                  f{ii} = fullfile(pwd,pInfo{end});
               end
            end
            vidName = obj.curationData.vid(idx);
            dataFile = obj.curationData.kin(idx);
            cam = obj.curationData.cam(idx);
            kinematicData = cell(numel(idx),1);
            for ii = 1:numel(idx)
               kinematicData{ii} = load(fullfile(f{ii},dataFile{ii}));
            end
            
            obj.F = struct('folder',f,...
               'name',vidName,...
               'cam',cam,...
               'file',dataFile,...
               'data',kinematicData);
            

            obj.openVid;
            obj.trial_lab.String = num2str(obj.trial);

         end
      end
      
      % Set the end of data to "nan" out
      function setDataCroppingEnd(obj,src,~)
         obj.cutStop.XData = ones(1,2).*src.CurrentPoint(1,1);
         
         h = fill(obj.t_ax,...
            [obj.cutStart.XData obj.cutStop.XData],...
            [0.1 0.9 0.9 0.1],...
            [0.1 0.1 0.1],...
            'EdgeColor','none',...
            'FaceColor',[0.1 0.1 0.1],...
            'FaceAlpha',0.5);
         for ii = 1:numel(obj.F)
            if obj.cutStop.XData(1) > obj.cutStart.XData(1)
               idx = find((obj.t{ii} >= obj.cutStart.XData(1)) & (obj.t{ii} <= obj.cutStop.XData(1)));
            elseif obj.cutStop.XData(1) < obj.cutStart.XData(1)
               idx = find((obj.t{ii} >= obj.cutStop.XData(1)) & (obj.t{ii} <= obj.cutStart.XData(1)));
            end

            obj.F(ii).data.x(idx,:) = nan;
            obj.F(ii).data.y(idx,:) = nan;
         end
         pause(1.5);
         delete(h);
         set(src,'ButtonDownFcn',@obj.skipToFrame);
         set(obj.vidFig,'Pointer','cross');
         obj.cutStart.XData = nan(1,2);
         obj.cutStop.XData = nan(1,2);
         obj.initTrialData(true);
      end
      
      % Set threshold for "seeing" points 
      function setProbThresh(obj,p)
         obj.pThresh = p;
         obj.initTrialData;
      end
      
      % Set whether X or Y is plotted
      function setXYPlot(obj,src,~)
         obj.XY = src.Value; % x --> 1; y --> 2
         obj.invXY = 3 - obj.XY;
         for ik = 1:numel(obj.markerParams)
            obj.kin(obj.curAx).pt{ik,obj.XY}.Visible = 'on';
            obj.kin(obj.curAx).pt{ik,obj.invXY}.Visible = 'off';
         end
      end
      
      % Jump to a frame based on clicking the "time-axes"
      function skipToFrame(obj,src,~)
         % Make sure we are looking at the axes:
         if ~isa(src,'matlab.graphics.axis.Axes')
            src = src.Parent;
         end
         
         switch src.Parent.SelectionType
            case 'alt'
               obj.cutStart.XData = ones(1,2).*src.CurrentPoint(1,1);
               set(src,'ButtonDownFcn',@obj.setDataCroppingEnd);
               set(obj.vidFig,'Pointer','crosshair');
            case 'normal'
               new_t = src.CurrentPoint(1,1);
               obj.t_line.XData = [new_t,new_t];
               for ii = 1:numel(obj.F)
                  obj.V{ii}.CurrentTime = new_t;
               end
               refreshImageFrame(obj);
            otherwise
               fprintf(1,'No function set for %s.\n',src.Parent.SelectionType);
         end
         
      end
      
      % Update the ID for a given markerless label
      function updateLabelID(obj,~,evt)
         if strcmpi(evt.EventName,'WindowKeyPress')
            
            if strcmpi(evt.Key,'multiply')
               if (~isinf(obj.label)) && (~isnan(obj.label))
                  obj.markerRadioButton{obj.label}.Value = 0;
               end
               obj.label = inf;
               
            elseif strcmpi(evt.Key,'divide')
               if (~isnan(obj.label)) && (~isinf(obj.label))
                  obj.markerRadioButton{obj.label}.Value = 0;
               end
               obj.label = nan;
               obj.placeLabelMarker(obj.img{1},nan);
            else
               lab_id = str2double(evt.Key(end));
               if (~isnan(lab_id))
                  obj.markerRadioButton{min(lab_id+1,numel(obj.markerRadioButton))}.Value = 1;
                  obj.label = min(lab_id+1,numel(obj.markerRadioButton));
               end
            end
         else
            obj.label = evt.NewValue.UserData;
         end
      end
      
      % Update a point on the time-axes scatter overlay
      function updateScatter(obj,x,y,vidIdx,labIdx)
         xn = obj.convertPixel2TimeAx(x,vidIdx,'x');
         yn = obj.convertPixel2TimeAx(y,vidIdx,'y');
         obj.kin(vidIdx).pt{labIdx,1}.XData(obj.time(vidIdx)) = xn;
         obj.kin(vidIdx).pt{labIdx,2}.YData(obj.time(vidIdx)) = yn;
      end
      
      % Update the zoom state of time-axes
      function updateZoomState(obj,newZoomState)         
         if (newZoomState > 0) && (newZoomState <= size(obj.zoomLims,1))
            obj.zoomState = newZoomState;
         end
         
         if obj.zoomState==1
            obj.t_ax.XLim = obj.zoomLims(1,:);
         else
            obj.t_ax.XLim = obj.zoomLims(obj.zoomState,:) + obj.t_line.XData;
         end
         
      end
      
      % Window button down callback:
      function wbdcb(obj,~,~)
         tmp = get(gca,'UserData');
         if isempty(tmp)
            return;
         elseif isnan(tmp)
            return;
         else
            obj.curAx = tmp;
            for ii = 1:numel(obj.ax)
               if ii==obj.curAx
                  obj.ax{ii}.XColor = 'm';
                  obj.ax{ii}.YColor = 'm';
                  for ik = 1:numel(obj.markerParams)
%                      obj.kin(obj.curAx).line{ik,obj.XY}.Visible = 'on';
%                      obj.kin(obj.curAx).line{ik,obj.invXY}.Visible = 'off';
                     obj.kin(ii).pt{ik,obj.XY}.Visible = 'on';
                     obj.kin(ii).pt{ik,obj.invXY}.Visible = 'off';
                  end
               else
                  obj.ax{ii}.XColor = 'w';
                  obj.ax{ii}.YColor = 'w';
                  for ik = 1:numel(obj.markerParams)
%                      obj.kin(obj.curAx).line{ik,1}.Visible = 'off';
%                      obj.kin(obj.curAx).line{ik,2}.Visible = 'off';
                     obj.kin(ii).pt{ik,1}.Visible = 'off';
                     obj.kin(ii).pt{ik,2}.Visible = 'off';
                  end
               end
               
            end
         end
      end      
      
   end
   
   
   
end

