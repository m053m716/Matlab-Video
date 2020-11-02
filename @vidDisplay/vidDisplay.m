classdef vidDisplay < handle
   %% VIDDISPLAY  Class to display simultaneous GoPro vids
   %   
   %  obj = VIDDISPLAY; % Prompts for _VideoScoring.mat file with UI
   %  obj = VIDDISPLAY('R19-54_2019_05_08_1_VideoScoring.mat');
   %
   % By: Max Murphy v1.0  2019-05-15 Original version (R2017a)
   
   properties (Access = public)
      name % recording name
      behaviorData   % behavior data table
      labelingData   % cell array of table for labels for each video           
   end
   
   properties (Access = private)
      vidPanel % panel container for videos to separate from "time" axes
      conFig   % handle to "control" figure -> press o
      roiFig   % handle to "roi" figure -> press r
      labFig   % handle to "label" figure -> press l
      helpFig  % handle to "help" figure -> press h
      HUD         % Labels of data for this trial
      F           % cell array of video file structs
      V           % VideoReader array
      
      t_ax           % "time" axes allowing click-to-scroll
      trial_lab      % label handle for text indicating which trial
      mData          % marker data array for "completion" of scoring a trial
      t_min          % minimum time value
      t              % current time handle for line that shows the time
      ax             % array of handles to axes for videos
      img            % array of handles to images with video frames
      labelingData_tmp % cell array for current labels
      markerData     % cell array of cell arrays of impoint for label handles
      roi            % [x,y] cell array for each imrect box
      fw             % "fixed width" of ROI box (pixels)
      fh             % "fixed height" of ROI box (pixels)
      label          % index of current markerless tracking label
      curLab         % handle to current label button group for radio btn
      labRad         % radio button handles
      tmp_roi        % temporary holder for ROI position when updating
      roi_is_locked  % boolean flag for whether the roi is locked or not
      roiBox         % handle to roi imrect array
      curAx          % current axes index
      sfx            % camera "shutter" sound
      
   end
   
   properties (Hidden = true)
      vidFig         % handle to main (video) figure
      trial          % current trial index
      slice          % Current "slice" corresponding to this frame
      labCol         % label colors array
      markerName     % marker name cell string array
      Forelimb       % 0 -> left; 1 -> right
      Lag            % lag of this trial based on LED illumination
      Locate         % timing of locating the pellet (paw leaving floor and beginning reach)
      Aim            % timing of first "aim" when he reaches out of box initially, this trial
      Grasp          % timing of first beginning to close digits, this trial
      Contact        % timing of first contact with pellet or platform, this trial
      Retract        % timing of retraction of paw from platform, this trial
      Supinate       % timing of supination (inside of box), this trial
      PelletSuccess  % 0 -> dropped pellet or didn't touch it; 1 -> retrieved successfully to mouth
      DoorSuccess    % 0 -> wrong door; 1 -> correct door approached
      exportedFrames % Struct with frames that were exported
      exportParams   % Parameters for exporting training data
   end
   
   methods
      % Constructor for VIDDISPLAY object
      function obj = vidDisplay(F,tStart,behaviorData,roi_dims,exportedFrames)
         obj.F = F;
         obj.name = strsplit(F{1}(1).name,'_');
         obj.name = strjoin(obj.name(1:5),'_');
         obj.vidFig = figure('Name','Video Display',...
            'MenuBar','none',...
            'NumberTitle','off',...
            'ToolBar','none',...
            'Units','Normalized',...
            'Position',[0.05 0.1 0.725 0.8],...
            'Color','w',...
            'WindowKeyPressFcn',@obj.keyPressVidFig,...
            'WindowButtonDownFcn',@obj.wbdcb,...
            'DeleteFcn',@obj.mainFigDeleteFcn);
         obj.vidPanel = uipanel(obj.vidFig,...
            'BackgroundColor','w',...
            'Units','Normalized',...
            'Position',[0 0 1 0.9],...
            'BorderWidth',0.5);

         obj.ax = uiPanelizeAxes(obj.vidPanel,numel(F));
         for ii = 1:numel(obj.ax)
            obj.ax{ii}.UserData = ii;
            obj.ax{ii}.YDir = 'reverse';
            obj.ax{ii}.Box = 'on';
            obj.ax{ii}.XColor = 'w';
            obj.ax{ii}.YColor = 'w';
            obj.ax{ii}.LineWidth = 5;
         end
         obj.curAx = 1;
         
         obj.img = cell(size(obj.ax));
         for ii = 1:numel(obj.ax)
            obj.img{ii} = imagesc(obj.ax{ii},[0 1],[0 1],0);
            obj.img{ii}.UserData = ii;
         end
      
         obj.t_ax = axes(obj.vidFig,'Units','Normalized',...
            'YTick',[],...
            'YLim',[0 1],...
            'XTick',[],...
            'XLim',[0 1],...
            'Color',[0.94 0.94 0.94],...
            'NextPlot','ReplaceChildren',...
            'Position',[0 0.9 1 0.1],...
            'UserData',nan,...
            'ButtonDownFcn',@obj.skipToFrame);
         
         obj.trial = 1;
         obj.trial_lab = uicontrol(obj.vidFig,...
            'Style','edit',...
            'Units','Normalized',...
            'Position',[0.20 0.925 0.10 0.05],...
            'String','1',...
            'FontName','Arial',...
            'FontSize',18,...
            'ForegroundColor',[0 0 0],...
            'BackgroundColor',[1 1 1],...
            'Callback',@obj.setCurrentTrial);
         
         
         obj.t_min = inf;
         obj.t = line(obj.t_ax,[0 0],[0 1],'LineStyle','--',...
            'LineWidth',1.5,'Color','k','ButtonDownFcn',@obj.skipToFrame);
         
         % If more than two arguments provided, then behaviorData was found
         % so that should be loaded and used, setting the first trial to
         % the most recent unscored trial.
         if nargin > 2
            if istable(behaviorData)
               obj.behaviorData = behaviorData;
               g = obj.behaviorData.Grasp; % Put the most-recent unscored trial
               tmp = find(isnan(g),1,'first');
               if isempty(tmp) % If all have been scored, then start at 1
                  obj.trial = 1;
               else
                  obj.trial = tmp;
               end
            else
               obj.initBehaviorData(tStart,behaviorData);
            end
         else
            obj.initBehaviorData(tStart);
         end
         
         uicontrol(obj.vidFig,...
            'Style','text',...
            'Units','Normalized',...
            'Position',[0.30 0.925 0.05 0.05],...
            'String',sprintf('/ %g',size(obj.behaviorData,1)),...
            'FontName','Arial',...
            'FontSize',18,...
            'ForegroundColor',[0 0 0],...
            'BackgroundColor',[1 1 1]);
         
         % Set the behaviorData row names as the trial labels, which may
         % not be consecutive depending on how scoring was previously done
         % and whether it is the training data exporter or the video scorer
         rowNames = cell(size(obj.F{1}));
         for iR = 1:numel(rowNames)
            tmp = strsplit(F{1}(iR).name(1:end-4),'_');
            rowNames{iR} = tmp{end};
         end
         obj.behaviorData.Properties.RowNames = rowNames;
         obj.openVid;
         
         % If 4-5 arguments, then it is the training data exporter
         if nargin < 4
            obj.initConFig;
         else
            obj.roi = cell(size(obj.F));
            obj.fw = roi_dims(3); % Fixed width
            obj.fh = roi_dims(4); % Fixed height
            for iR = 1:numel(obj.roi)
               obj.fw = min(obj.fw,obj.V{iR}.Width);
               obj.fh = min(obj.fh,obj.V{iR}.Height);
               obj.roi{iR} = roi_dims(1:2);
            end
            % Initialize cropping objects and lock/unlock/export fig
            obj.roi_is_locked = false;
            obj.initRoiFig;
            obj.initRoiBoxes;
            obj.exportParams = defaults.exportParams();
            
            % Initialize labeling table and tracking
            obj.markerName = defaults.markerParams('name');
            obj.labCol = defaults.markerParams('color');
            if nargin < 5            
               obj.labelingData = obj.initLabelingData;
               N = numel(obj.markerName);
               obj.labelingData_tmp = obj.initLabelingData(N);
            else
               obj.readExportedTrainingFrames(exportedFrames);
            end
            obj.initLabFig;
            
         end
         
         % Initialize time axes
         obj.initProps;
      end
      
      % Change the label for a given "markerless labeling" marker
      function changeLabel(obj,src,~)
         obj.labRad{src.UserData}.String = src.String;
         obj.markerName{src.UserData} = src.String;
      end
      
      % Check that the current markerless labeling is ready to export
      function [flag,exportFolder] = checkReadyToExport(obj,t,axIdx)
         frame = obj.F{axIdx}(obj.trial).name;
         idx_t = find(obj.exportedFrames{axIdx}.t == t);
         idx_f = find(strcmp(obj.exportedFrames{axIdx}.name,frame));
         flag = any(ismember(idx_t,idx_f));
         if flag
            exportFolder = [];
            return;
         end
         obj.exportedFrames{axIdx}.t = [obj.exportedFrames{axIdx}.t; t];               
         obj.exportedFrames{axIdx}.name = [obj.exportedFrames{axIdx}.name;...
            frame];
         [~,f,~] = fileparts(frame);
         f = strsplit(f,'_');
         f = strjoin(f(1:6),'_');
         exportFolder = fullfile(obj.exportParams.base,f);
         if exist(exportFolder,'dir')==0
            mkdir(exportFolder)   
         end
      end
      
      % Close all extra HUD windows
      function closeHUD(obj)
         if ~isempty(obj.conFig)
            if isvalid(obj.conFig)
               close(obj.conFig);
            end
         end
         
         if ~isempty(obj.roiFig)
            if isvalid(obj.roiFig)
               close(obj.roiFig);
            end
         end
         
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

      % Export the labeled images for this frame, from all angles
      function exportLabeledFrames(obj,~,~)
         allGood = true;
         for ii = 1:numel(obj.ax)
            allGood = allGood && (~any(isnan(obj.labelingData_tmp{ii}.X)));
         end
         t = obj.t.XData(1);
         if allGood
            
            if exist(obj.exportParams.base,'dir')==0
               mkdir(obj.exportParams.base);
            end
            if isempty(obj.exportedFrames)
               obj.exportedFrames = cell(size(obj.labelingData));
               for ii = 1:numel(obj.ax)
                  obj.exportedFrames{ii} = struct('name',[],'t',[]);
               end
            end
            for ii = 1:numel(obj.ax)
               % Don't export "NaN" lags (non-interested cameras)
               if isnan(obj.behaviorData.Lag(obj.trial,ii))
                  continue;
               end
               
               [flag,exportFolder] = obj.checkReadyToExport(t,ii);
               if flag
                  fprintf(1,'Exported image and labeling already exists for %s: %s (%gs)\n',...
                     obj.name,obj.behaviorData.Properties.RowNames{obj.trial},t);
                  fprintf(1,'->\tNo new data exported or saved.\t<-\n');
                  return;
               end
               tmp = obj.exportTempLabeling(ii);
               fname = sprintf('train_img-%07g.PNG',tmp.Slice(end));
               x = [obj.roi{ii}(1), obj.roi{ii}(1)+obj.fw];
               y = [obj.roi{ii}(2), obj.roi{ii}(2)+obj.fh];
               if x(1) < 1
                  x(2) = x(2) - x(1) + 1;
                  x(1) = 1;
               end
               if x(2) > obj.V{ii}.Width
                  x(1) = x(1) - (x(2) - obj.V{ii}.Width);
                  x(2) = obj.V{ii}.Width;
               end
               if y(1) < 1
                  y(2) = y(2) - y(1) + 1;
                  y(1) = 1;
               end
               if y(2) > obj.V{ii}.Height
                  y(1) = y(1) - (y(2) - obj.V{ii}.Height);
                  y(2) = obj.V{ii}.Height;
               end
               
               A = obj.img{ii}.CData(y(1):y(2),x(1):x(2),:);
               imwrite(A,fullfile(exportFolder,fname));
               
               % Concatenate this table with the total labeling table
               obj.labelingData{ii} = [obj.labelingData{ii}; tmp];
               
               % Overwrite existing labels file
               fname = fullfile(exportFolder,'Labels.csv');
               if exist(fname,'file')~=0
                  delete(fname);
               end
               writetable(obj.labelingData{ii},fname);
            end
            
            N = numel(obj.markerName);
            obj.labelingData_tmp = obj.initLabelingData(N);
            play(obj.sfx);
            fprintf(1,'--> Exported image and labeling for %s: %s (%gs)<--\n',...
               obj.name,obj.behaviorData.Properties.RowNames{obj.trial},t);
            
         else
            fprintf(1,'Not all labeling completed for %s: %s (%gs)\n',...
              obj.name,obj.behaviorData.Properties.RowNames{obj.trial},t);
         end
      end

      % Export temporary labeling
      function out = exportTempLabeling(obj,axIdx)
         out = obj.labelingData_tmp{axIdx};
         
         % Remove any that are above or to the left of the bounding box
         out.X = out.X - obj.roi{axIdx}(1);
         out.Y = out.Y - obj.roi{axIdx}(2);
         subset = (out.X <= 0) | (out.Y <= 0);

         out.X(subset) = 1;
         out.Y(subset) = 1;
         
         % Also, remove any points that are below or to the right of the
         % bounding box
         subset = (out.X > obj.fw) | (out.Y > obj.fh);
         out.X(subset) = 1;
         out.Y(subset) = 1;
      end
      
      % Get string for lags and update selected cameras
      function str = getMultiViewString(obj,markerName)
         str = '';
         for ii = 1:numel(obj.(markerName))
            txt = num2str(obj.(markerName){ii}.XData(1),'%.3g');
            if strcmpi(txt,'nan')
               txt = 'x';
               obj.ax{ii}.XColor = 'w';
               obj.ax{ii}.YColor = 'w';
            else
               obj.ax{ii}.XColor = 'm';
               obj.ax{ii}.YColor = 'm';
            end
            str = [str, txt '|']; %#ok<AGROW>
         end
         str(end) = [];
      end
      
      % Initialize the behavior data table for scoring time events
      function initBehaviorData(obj,tStart,str)
         Trial = reshape(tStart,numel(tStart),1);
         Lag = zeros(numel(Trial),numel(obj.ax)); %#ok<*PROPLC>
         Locate = nan(size(Trial));
         Aim = nan(size(Trial));
         Grasp = nan(size(Trial));
         Contact = nan(size(Trial));
         Retract = nan(size(Trial));
         Supinate = nan(size(Trial));
         Forelimb = zeros(size(Trial));
         DoorSuccess = zeros(size(Trial));
         PelletSuccess = zeros(size(Trial));
         obj.behaviorData = table(Trial,Lag,Locate,Aim,Grasp,Contact,Retract,Supinate,DoorSuccess,PelletSuccess,Forelimb);
         obj.behaviorData.Properties.UserData = [0,0,1,1,1,1,1,1,4,4,5];
         if nargin > 2
            obj.behaviorData.Properties.Description = str;
         end
         obj.curAx = 1;
      end
      
      % Initialize the "controller" figure window
      function initConFig(obj)
         if ~isempty(obj.conFig)
            if isvalid(obj.conFig)
               return;
            end
         end
         
         obj.conFig = figure('Name','Scoring Display',...
            'MenuBar','none',...
            'NumberTitle','off',...
            'ToolBar','none',...
            'Units','Normalized',...
            'Position',[0.8 0.1 0.15 0.8],...
            'Color','w',...
            'WindowKeyPressFcn',@obj.keyPressConFig,...
            'DeleteFcn',@obj.keyPressVidFigRevert);
         str = obj.behaviorData.Properties.VariableNames;
         [y,h] = uiGetVerticalSpacing(numel(str));
         for ii = 1:numel(str)
            uicontrol(obj.conFig,'Style','text',...
               'Units','Normalized',...
               'BackgroundColor','w',...
               'ForegroundColor','k',...
               'FontWeight','bold',...
               'HorizontalAlignment','right',...
               'FontName','Arial',...
               'FontSize',14,...
               'String',str{ii},...
               'Position',[0.01 y(ii) 0.5 h]);
         end
         
         obj.HUD = cell(size(str));
         for ii = 1:numel(str)
            obj.HUD{ii} = uicontrol(obj.conFig,'Style','text',...
               'Units','Normalized',...
               'BackgroundColor','w',...
               'HorizontalAlignment','left',...
               'ForegroundColor',[0.15 0.15 0.15],...
               'FontName','Arial',...
               'String',num2str(obj.behaviorData.(str{ii})(obj.trial)),...
               'FontSize',14,...
               'Position',[0.6 y(ii) 0.3 h]);
         end
         
         obj.vidFig.WindowKeyPressFcn = @obj.keyPressConFig;
         
      end
      
      % Initialize the labeling data table for exporting training data
      function T = initLabelingData(obj,N)
         if nargin < 2
            N = 0;
         end
         
         Area = zeros(N,1);
         Mean = ones(N,1);
         Min = ones(N,1);
         Max = ones(N,1);
         X = nan(N,1);
         Y = nan(N,1);
          
         T = cell(1,numel(obj.F));
         for ii = 1:numel(obj.F)
            if isempty(obj.labelingData)
               slice = 0;
            elseif size(obj.labelingData{ii},1)==0
               slice = 1;
            else
               slice = obj.labelingData{ii}.Slice(end) + 1;
            end
            Marker = (1:N).' + (slice-1)*N;
            Slice = ones(N,1) * slice; 
            T{ii} = table(Marker,Area,Mean,Min,Max,X,Y,Slice);
         end
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
            'Position',[0.8 0.1 0.15 0.375],...
            'Color','w',...
            'WindowKeyPressFcn',@obj.keyPressLabFig,...
            'DeleteFcn',@obj.keyPressVidFigRevert);
         obj.markerName = defaults.markerParams('name');
         [y,h] = uiGetVerticalSpacing(numel(obj.markerName));
         obj.curLab = uibuttongroup(obj.labFig,...
            'Units','Normalized',...
            'Position',[0.175 0 0.825 1],...
            'BackgroundColor','w',...
            'ForegroundColor','k',...
            'SelectionChangedFcn',@obj.updateLabelID);
         obj.labRad = cell(size(obj.markerName));
         for ii = 1:numel(obj.markerName)
            obj.labRad{ii} = uicontrol(obj.curLab,'Style','radiobutton',...
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
         
         obj.labCol = defaults.markerParams('color');
         for ii = 1:numel(obj.labCol)
            uicontrol(obj.labFig,'Style','edit',...
               'Units','Normalized',...
               'BackgroundColor','w',...
               'HorizontalAlignment','left',...
               'ForegroundColor',obj.labCol{ii},...
               'FontName','Arial',...
               'FontWeight','bold',...
               'String',obj.markerName{ii},...
               'FontSize',14,...
               'Position',[0.40 y(ii) 0.45 h],...
               'Callback',@obj.changeLabel);
         end
         
         
         for ii = 1:numel(obj.labCol)
            annotation(obj.labFig,'ellipse',[0.05 y(ii) 0.1 h],...
               'Color',obj.labCol{ii},...
               'FaceColor',obj.labCol{ii},...
               'Units','Normalized');
         end
         
         for ii = 1:numel(obj.img)
            obj.img{ii}.ButtonDownFcn = @obj.placeLabelMarker;
         end
         obj.initLabMarkers;
         obj.label = 1;
         
         obj.vidFig.WindowKeyPressFcn = @obj.keyPressLabFig;
         
      end
      
      % Initialize the labeling marker objects
      function initLabMarkers(obj)
         fcn = makeConstrainToRectFcn('impoint',[0 1],[0 1]);
         if isempty(obj.markerData)
            obj.markerData = cell(numel(obj.roi),1);
         end
         
         for ii = 1:numel(obj.roi)
            x = obj.labelingData{ii}.X(obj.labelingData{ii}.Slice==obj.trial)/obj.V{ii}.Width;
            if numel(x) ~= numel(obj.markerName)
               x = nan(1,numel(obj.markerName));
            end
            y = obj.labelingData{ii}.Y(obj.labelingData{ii}.Slice==obj.trial)/obj.V{ii}.Height;
            if numel(y) ~= numel(obj.markerName)
               y = nan(1,numel(obj.markerName));
            end
            if isempty(obj.markerData{ii})
               obj.markerData{ii} = cell(size(obj.labCol));
               for ik = 1:numel(obj.labCol)
                  obj.markerData{ii}{ik} = impoint(obj.ax{ii},...
                     x(ik),y(ik),'PositionConstraintFcn',fcn);
                  setColor(obj.markerData{ii}{ik},obj.labCol{ik});
               end
            else
               for ik = 1:numel(obj.labCol)
                  setPosition(obj.markerData{ii}{ik},x(ik),y(ik));
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
      
      % Initialize time-axes properties for different scroll items
      function initProps(obj)
         obj.mData = nan(1,6);
         if isempty(obj.Lag)
            obj.Lag = cell(1,numel(obj.ax));
         end
         mStyle = defaults.markerParams('shape');
         for ii = 1:numel(obj.ax)
            l = obj.behaviorData.Lag(obj.trial,ii);
            if ~isa(obj.Lag{ii},'matlab.graphics.primitive.Line')
               obj.Lag{ii} = line(obj.t_ax,[l l],[0 1],'LineStyle','-',...
                  'LineWidth',2,'Color',[0.4 1.0 0.4],...
                  'Marker',mStyle{ii},...
                  'ButtonDownFcn',@obj.skipToFrame);
            else
               obj.Lag{ii}.XData = [l l];
            end
            if isnan(l)
               obj.ax{ii}.XColor = 'w';
               obj.ax{ii}.YColor = 'w';
            else
               obj.ax{ii}.XColor = 'm';
               obj.ax{ii}.YColor = 'm';
            end
         end

         
         obj.mData(1) = obj.behaviorData.Locate(obj.trial);
         if ~isa(obj.Locate,'matlab.graphics.primitive.Line')
            obj.Locate = line(obj.t_ax,[obj.mData(1) obj.mData(1)],[0 1],'LineStyle','-',...
               'LineWidth',1.5,'Color',[1.0 0.4 0.4],'ButtonDownFcn',@obj.skipToFrame);
         else
            obj.Locate.XData = [obj.mData(1) obj.mData(1)];
         end
         
         obj.mData(2) = obj.behaviorData.Aim(obj.trial);
         if ~isa(obj.Aim,'matlab.graphics.primitive.Line')
            obj.Aim = line(obj.t_ax,[obj.mData(2) obj.mData(2)],[0 1],'LineStyle','-',...
               'LineWidth',1.5,'Color',[0.7 0.1 0.7],'ButtonDownFcn',@obj.skipToFrame);
         else
            obj.Aim.XData = [obj.mData(2) obj.mData(2)];
         end
         
         obj.mData(3) = obj.behaviorData.Grasp(obj.trial);
         if ~isa(obj.Grasp,'matlab.graphics.primitive.Line')
            obj.Grasp = line(obj.t_ax,[obj.mData(3) obj.mData(3)],[0 1],'LineStyle','-',...
               'LineWidth',1.5,'Color',[0.8 0.1 0.1],'ButtonDownFcn',@obj.skipToFrame);
         else
            obj.Grasp.XData = [obj.mData(3) obj.mData(3)];
         end
         
         obj.mData(4) = obj.behaviorData.Contact(obj.trial);
         if ~isa(obj.Contact,'matlab.graphics.primitive.Line')
            obj.Contact = line(obj.t_ax,[obj.mData(4) obj.mData(4)],[0 1],'LineStyle','-',...
               'LineWidth',1.5,'Color',[0.7 0.7 0.1],'ButtonDownFcn',@obj.skipToFrame);
         else
            obj.Contact.XData = [obj.mData(4) obj.mData(4)];
         end
         
         obj.mData(5) = obj.behaviorData.Retract(obj.trial);
         if ~isa(obj.Retract,'matlab.graphics.primitive.Line')
            obj.Retract = line(obj.t_ax,[obj.mData(5) obj.mData(5)],[0 1],'LineStyle','-',...
               'LineWidth',1.5,'Color',[1.0 0.4 0.4],'ButtonDownFcn',@obj.skipToFrame);
         else
            obj.Retract.XData = [obj.mData(5) obj.mData(5)];
         end
         
         obj.mData(6) = obj.behaviorData.Supinate(obj.trial);
         if ~isa(obj.Supinate,'matlab.graphics.primitive.Line')
            obj.Supinate = line(obj.t_ax,[obj.mData(6) obj.mData(6)],[0 1],'LineStyle','-',...
               'LineWidth',1.5,'Color',[0.9 0.3 0.3],'ButtonDownFcn',@obj.skipToFrame);
         else
            obj.Supinate.XData = [obj.mData(6) obj.mData(6)];
         end
         
         trialnum = strsplit(obj.behaviorData.Properties.RowNames{obj.trial},'-');
         trialnum = str2double(trialnum{2});
         obj.trial_lab.String = sprintf('%s',trialnum);
         
         if any(isnan(obj.mData))
            obj.t_ax.Color = [0.94 0.94 0.94];
         else
            obj.t_ax.Color = [0.54 0.54 0.94];
         end
         obj.Forelimb = obj.behaviorData.Forelimb(obj.trial);
         obj.DoorSuccess = obj.behaviorData.DoorSuccess(obj.trial);
         obj.PelletSuccess = obj.behaviorData.PelletSuccess(obj.trial);
         
      end
      
      % Initialize the cropping ROI imrect objects
      function initRoiBoxes(obj)
         fcn = makeConstrainToRectFcn('imrect',[0 1],[0 1]);
         obj.roiBox = cell(numel(obj.roi),1);
         for iR = 1:numel(obj.roi)               
            pos_sc = [obj.roi{iR}(1)/obj.V{iR}.Width,...
               obj.roi{iR}(2)/obj.V{iR}.Height,...
               obj.fw/obj.V{iR}.Width,...
               obj.fh/obj.V{iR}.Height];
            obj.roiBox{iR} = imrect(obj.ax{iR},pos_sc); 
            setPositionConstraintFcn(obj.roiBox{iR},fcn); 
            addNewPositionCallback(obj.roiBox{iR},@(p)obj.updateROIparams(p));
            setResizable(obj.roiBox{iR},false);
         end
      end
      
      % Initialize the "roi" figure window
      function initRoiFig(obj)
         if ~isempty(obj.roiFig)
            if isvalid(obj.roiFig)
               return;
            end
         end
         
         obj.roiFig = figure('Name','ROI/Export Info',...
            'MenuBar','none',...
            'NumberTitle','off',...
            'ToolBar','none',...
            'Units','Normalized',...
            'Position',[0.8 0.65 0.15 0.25],...
            'Color','w',...
            'WindowKeyPressFcn',@obj.keyPressRoiFig,...
            'DeleteFcn',@obj.keyPressVidFigRevert);
         
         uicontrol(obj.roiFig,'Style','pushbutton',...
            'Units','Normalized',...
            'Position',[0.1 0.5 0.8 0.4],...
            'ForegroundColor','k',...
            'BackgroundColor',[0.25 0.25 1.0],...
            'FontName','Arial',...
            'FontSize',24,...
            'String','Export',...
            'Callback',@obj.exportLabeledFrames);
         
         h = uicontrol(obj.roiFig,'Style','pushbutton',...
               'Units','Normalized',...
               'Position',[0.1 0.1 0.8 0.4],...
               'ForegroundColor','k',...
               'BackgroundColor',[1.0 0.25 1.0],...
               'FontName','Arial',...
               'FontSize',24,...
               'Callback',@obj.lockUnlockROI);
         if obj.roi_is_locked
            h.String = 'Unlock';
            h.BackgroundColor = [0.25 1.0 0.25];
         else
            h.String = 'Lock';
            h.BackgroundColor = [1.0 0.25 1.0];
         end
         
         [data,fs] = defaults.sfx('camera');
         obj.sfx = audioplayer(data,fs);
         
      end
      
      % Shortcut keys for "controller" window for video scoring
      function keyPressConFig(obj,~,evt)
         fs = obj.V{1}.FrameRate;
         ts = obj.t.XData(1);
         switch evt.Key
            case 'a' % next frame
               if obj.V{1}.CurrentTime >= (2/fs)
                  for ii = 1:numel(obj.V)
                     obj.V{ii}.CurrentTime = obj.V{ii}.CurrentTime - (2/fs);
                  end
                  obj.refreshImageFrame();
               end
            case 'd' % previous frame
               if obj.V{1}.CurrentTime < (obj.t_min - (1/fs))
                  obj.refreshImageFrame();
               end
               
            case 's' % previous trial
               if ismember('alt',evt.Modifier)
                  if isempty(obj.behaviorData.Properties.Description)
                     [fname,pname] = uigetfile('*_VideoScoring.mat',...
                        'Select VIDEOSCORING file',pwd);
                     if fname == 0
                        disp('No file selected. BehaviorData not saved.');
                        return;
                     else
                        obj.behaviorData.Properties.Description = fullfile(pname,fname);
                     end
                  end
                  behaviorData = obj.behaviorData;
                  save(behaviorData.Properties.Description,'behaviorData','-append');
                  disp('BehaviorData saved successfully!');
               else
                  obj.setCurrentTrial(obj.trial-1,nan);
               end
            case 'w' % next trial
               obj.setCurrentTrial(obj.trial+1,nan);
               
            case 'h'
               obj.openHelpFig;
               
            case 'q' % Left trial
               obj.Forelimb = 0;
            
            case 'e' % Right trial
               obj.Forelimb = 1;
            
            case {'0','numpad0'} % Lag
               obj.updateMarker('Lag',ts,obj.curAx);
               
            case {'1','numpad1'} % Locate/sniff
               obj.updateMarker('Locate',ts);
               
            case {'2','numpad2'} % Aim
               obj.updateMarker('Aim',ts);
               
            case {'3','numpad3'} % Grasp
               obj.updateMarker('Grasp',ts);
               
            case {'4','numpad4'} % Contact
               obj.updateMarker('Contact',ts);
               
            case {'5','numpad5'} % Retract
               obj.updateMarker('Retract',ts);
               
            case {'6','numpad6'} % Supinate
               obj.updateMarker('Supinate',ts);
               
            case {'7','numpad7'} % Toggle DoorSuccess
               obj.updateToggle('DoorSuccess');
            case {'8','numpad8'} % Toggle PelletSuccess
               obj.updateToggle('PelletSuccess');
            case {'9','numpad9'} % Toggle Left (0) / Right (1)
               obj.updateToggle('Forelimb');
            case 'escape'
               close(obj.conFig);
               obj.vidFig.WindowKeyPressFcn = @obj.keyPressVidFig;
            case 'multiply'
               obj.updateMarker('Locate',inf);
               obj.updateMarker('Aim',inf);
               obj.updateMarker('Grasp',inf);
               obj.updateMarker('Contact',inf);
               obj.updateMarker('Retract',inf);
               obj.updateMarker('Supinate',inf);
            case 'divide'
               obj.updateMarker('Locate',nan);
               obj.updateMarker('Aim',nan);
               obj.updateMarker('Grasp',nan);
               obj.updateMarker('Contact',nan);
               obj.updateMarker('Retract',nan);
               obj.updateMarker('Supinate',nan);
         end
      end
      
      % Shortcut keys for "markerless labeling" window
      function keyPressLabFig(obj,~,evt)
         fs = obj.V{1}.FrameRate;
         ts = obj.t.XData(1);

         switch evt.Key
            case 'a' % next frame
               if obj.V{1}.CurrentTime >= (2/fs)
                  for ii = 1:numel(obj.V)
                     obj.V{ii}.CurrentTime = obj.V{ii}.CurrentTime - (2/fs);
                  end
                  obj.refreshImageFrame();
               end
            case 'd' % previous frame
               if obj.V{1}.CurrentTime < (obj.t_min - (1/fs))
                  obj.refreshImageFrame();
               end
               
            case 's' % previous trial
               if ismember('alt',evt.Modifier)
                  behaviorData = obj.behaviorData;
                  mtb(behaviorData);
               else
                  obj.setCurrentTrial(obj.trial-1,nan);
               end
            case 'w' % next trial
               obj.setCurrentTrial(obj.trial+1,nan);  
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
         end
         
         obj.updateLabelID(nan,evt);
         
      end
      
      % Shortcut keys for "roi" window
      function keyPressRoiFig(obj,~,evt)
         fs = obj.V{1}.FrameRate;
         ts = obj.t.XData(1);
         switch evt.Key
            case 'a' % next frame
               if obj.V{1}.CurrentTime >= (2/fs)
                  for ii = 1:numel(obj.V)
                     obj.V{ii}.CurrentTime = obj.V{ii}.CurrentTime - (2/fs);
                  end
                  obj.refreshImageFrame();
               end
            case 'd' % previous frame
               if obj.V{1}.CurrentTime < (obj.t_min - (1/fs))
                  obj.refreshImageFrame();
               end
               
            case 's' % previous trial
               if ismember('alt',evt.Modifier)
                  behaviorData = obj.behaviorData;
                  mtb(behaviorData);
               else
                  obj.setCurrentTrial(obj.trial - 1,nan);
               end
            case 'w' % next trial
               obj.setCurrentTrial(obj.trial + 1,nan);
               
            
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
               close(obj.roiFig);
               obj.vidFig.WindowKeyPressFcn = @obj.keyPressVidFig;
         end
         
         obj.updateLabelID(nan,evt);
      end
      
      % Shortcut keys for main window when no other windows present
      function keyPressVidFig(obj,~,evt)
         fs = obj.V{1}.FrameRate;
         ts = obj.t.XData(1);
         switch evt.Key
            case 'a' % next frame
               if obj.V{1}.CurrentTime >= (2/fs)
                  for ii = 1:numel(obj.V)
                     obj.V{ii}.CurrentTime = obj.V{ii}.CurrentTime - (2/fs);
                  end
                  obj.refreshImageFrame();
               end
            case 'd' % previous frame
               if obj.V{1}.CurrentTime < (obj.t_min - (1/fs))
                  obj.refreshImageFrame();
               end
               
            case 's' % previous trial
               if ismember('alt',evt.Modifier)
                  if isempty(obj.behaviorData.Properties.Description)
                     [fname,pname] = uigetfile('*_VideoScoring.mat',...
                        'Select VIDEOSCORING file',pwd);
                     if fname == 0
                        disp('No file selected. BehaviorData not saved.');
                        return;
                     else
                        obj.behaviorData.Properties.Description = fullfile(pname,fname);
                     end
                  end
                  behaviorData = obj.behaviorData;
                  save(behaviorData.Properties.Description,'behaviorData','-append');
                  disp('BehaviorData saved successfully!');
               else
                  obj.setCurrentTrial(obj.trial - 1,nan);
               end
            case 'w' % next trial
               obj.setCurrentTrial(obj.trial + 1,nan);
            case 'h'
               obj.openHelpFig;
               
            case {'c','o'}
               obj.initConFig;
               
            case 'l'
               obj.initLabFig;
               
            case 'r'
               obj.initRoiFig;
               
            case 'escape'
               close(obj.vidFig);
         end
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
      
      % Lock/Unlock ROI selection for cropping the exported frames
      function lockUnlockROI(obj,src,~)
         if isempty(obj.roi)
            return;
         end
         
         if ~isa(obj.roiBox{1},'imrect')
            return;
         end
         
         if obj.roi_is_locked
            % Unlock it and set string option to set back to Locked
            src.String = 'Lock';
            src.BackgroundColor = [1.0 0.25 1.0];
            obj.initRoiBoxes;
            obj.roi_is_locked = false;
         else
            src.String = 'Unlock';
            src.BackgroundColor = [0.25 1.0 0.25];
            for ii = 1:numel(obj.roi)
               delete(obj.roiBox{ii});
            end
            obj.roi_is_locked = true;
         end
            
      end
      
      % Close all other windows when main figure is closed
      function mainFigDeleteFcn(obj,src,~)
         obj.closeHUD;
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
             'numPad0:      Lag'; ...
             'numPad1:      Sniff/Locate'; ...
             'numPad2:      Aim'; ...
             'numPad3:      Grasp'; ...
             'numPad4:      Contact'; ...
             'numPad5:      Retract'; ...
             'numPad6:      Supinate'; ...
             'numPad7:      Toggle Door Success'; ...
             'numPad8:      Toggle Pellet Success'; ...
             'numPad9:      Toggle Forelimb'};
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
         obj.t_min = inf;
         for ii = 1:numel(obj.F)
            obj.V{ii} = VideoReader(fullfile(...
               obj.F{ii}(obj.trial).folder,...
               obj.F{ii}(obj.trial).name)); %#ok<TNMLP>
            obj.t_min = min(obj.t_min,obj.V{ii}.Duration);
            obj.img{ii}.CData = readFrame(obj.V{ii});
         end
         obj.t_ax.XLim = [0 obj.V{1}.Duration];
         obj.t.XData = [0,0];
         obj.initProps;
         obj.updateHUD;
      end
      
      % Place the label marker on the image where clicked
      function placeLabelMarker(obj,src,~)
         if ~isa(src,'matlab.graphics.primitive.Image')
            return;
         end
         if ~obj.roi_is_locked
            return;
         end
         p = src.Parent;
         pos = p.CurrentPoint;
         if isinf(obj.label)
            for ii = 1:numel(obj.markerName)
               setPosition(obj.markerData{obj.curAx}{ii},...
                  pos(1,1),pos(1,2));
               obj.labelingData_tmp{obj.curAx}.X(ii) = ...
                  round(pos(1,1) * obj.V{obj.curAx}.Width);
               obj.labelingData_tmp{obj.curAx}.Y(ii) = ...
                  round(pos(1,2) * obj.V{obj.curAx}.Height);
            end
         elseif isnan(obj.label)
            for ik = 1:numel(obj.ax)
               for ii = 1:numel(obj.markerName)
                  setPosition(obj.markerData{ik}{ii},0,0);
                  obj.labelingData_tmp{ik}.X(ii) = 1;
                  obj.labelingData_tmp{ik}.Y(ii) = 1;
               end
            end
         else
            setPosition(obj.markerData{obj.curAx}{obj.label},...
                  pos(1,1),pos(1,2));
            obj.labelingData_tmp{obj.curAx}.X(obj.label) = ...
               round(pos(1,1) * obj.V{obj.curAx}.Width);
            obj.labelingData_tmp{obj.curAx}.Y(obj.label) = ...
               round(pos(1,2) * obj.V{obj.curAx}.Height);
         end
      end  
      
      % Read previously-saved training
      function readExportedTrainingFrames(obj,exportedFrames)
         obj.labelingData = cell(size(exportedFrames));
         for ii = 1:numel(exportedFrames)
            f = strsplit(exportedFrames{ii}.name(1,:),'_');
            f = strjoin(f(1:6),'_');
            b = fullfile(obj.exportParams.base,f);
            obj.labelingData{ii} = readtable(fullfile(b,'Labels.csv'));
         end
         obj.exportedFrames = exportedFrames;
         N = numel(obj.markerName);
         obj.labelingData_tmp = obj.initLabelingData(N);
      end
      
      % Refresh the current image frame
      function refreshImageFrame(obj)
         obj.t.XData = [obj.V{1}.CurrentTime, obj.V{1}.CurrentTime];
         for ii = 1:numel(obj.F)
            obj.img{ii}.CData = readFrame(obj.V{ii});
         end
      end
      
      % Set the current trial
      function setCurrentTrial(obj,newTrial,~)
         if isa(newTrial,'matlab.ui.control.UIControl')
            newTrial = str2double(newTrial.String);
            if isnan(newTrial)
               return;
            end
         end

         if (newTrial ~= obj.trial)
            if (newTrial <= size(obj.behaviorData,1)) && ...
                  (newTrial > 0)
               obj.trial = newTrial;
               obj.openVid;
               obj.trial_lab.String = num2str(obj.trial);
            end
         end
      end
      
      % Jump to a frame based on clicking the "time-axes"
      function skipToFrame(obj,src,~)
         % Make sure we are looking at the axes:
         if ~isa(src,'matlab.graphics.axis.Axes')
            src = src.Parent;
         end
         
         new_t = src.CurrentPoint(1,1);
         obj.t.XData = [new_t,new_t];
         for ii = 1:numel(obj.F)
            obj.V{ii}.CurrentTime = new_t;
         end
         refreshImageFrame(obj);
      end
      
      % Update the HUD for scoring time events (grasp/reach/etc)
      function updateHUD(obj)
         str = obj.behaviorData.Properties.VariableNames;
         for ii = 1:numel(obj.HUD)
            if strcmpi(str{ii},'Lag')
               obj.HUD{ii}.String = obj.getMultiViewString(str{ii});
            else
               obj.HUD{ii}.String = num2str(obj.behaviorData.(str{ii})(obj.trial));
            end
         end
      end
      
      % Update the ID for a given markerless label
      function updateLabelID(obj,~,evt)
         if strcmpi(evt.EventName,'WindowKeyPress')
            
            if strcmpi(evt.Key,'multiply')
               if (~isinf(obj.label)) && (~isnan(obj.label))
                  obj.labRad{obj.label}.Value = 0;
               end
               obj.label = inf;
               
            elseif strcmpi(evt.Key,'subtract')
               if (~isnan(obj.label)) && (~isinf(obj.label))
                  obj.labRad{obj.label}.Value = 0;
               end
               obj.label = nan;
               obj.placeLabelMarker(obj.img{1},nan);
            else
               lab_id = str2double(evt.Key(end));
               if (~isnan(lab_id))
                  obj.labRad{min(lab_id+1,numel(obj.labRad))}.Value = 1;
                  obj.label = min(lab_id+1,numel(obj.labRad));
               end
            end
         else
            obj.label = evt.NewValue.UserData;
         end
      end
      
      % Update the marker position for a given video time scoring event
      function updateMarker(obj,markerName,ts,vidIdx)
         if nargin < 4
            vidIdx = 1;
            if obj.(markerName).XData(1) == ts
               ts = nan;
            end
            obj.(markerName).XData = [ts,ts];
            obj.behaviorData.(markerName)(obj.trial,vidIdx) = ts;
            idx = find(ismember(obj.behaviorData.Properties.VariableNames,...
               markerName),1,'first');
            obj.HUD{idx}.String = num2str(ts);
            obj.mData(idx) = ts;
            if any(isnan(obj.mData))
               obj.t_ax.Color = [0.94 0.94 0.94];
            else
               obj.t_ax.Color = [0.54 0.54 0.94];
            end
         else
            if obj.(markerName){vidIdx}.XData(1) == ts
               ts = nan;               
            end
            obj.(markerName){vidIdx}.XData = [ts,ts];
            idx = find(ismember(obj.behaviorData.Properties.VariableNames,...
               markerName),1,'first');
            str = obj.getMultiViewString(markerName);
            
            obj.HUD{idx}.FontSize = 10;
            obj.HUD{idx}.String = str;
         end
         
      end
      
      % Toggle the state of a true/false (left/right etc.) scoring item
      function updateToggle(obj,toggleName)
         if obj.(toggleName)==0
            obj.(toggleName)=1;
         else
            obj.(toggleName)=0;
         end
         obj.behaviorData.(toggleName)(obj.trial) = obj.(toggleName);
         idx = find(ismember(obj.behaviorData.Properties.VariableNames,...
            toggleName),1,'first');
         obj.HUD{idx}.String = num2str(obj.(toggleName));
      end
      
      % Update the ROI parameters for cropping the exported training frames
      function updateROIparams(obj,p)
         obj.tmp_roi = [round(p(1) * obj.V{obj.curAx}.Width),...
            round(p(2) * obj.V{obj.curAx}.Height)];
      end
      
      % Window button down callback:
      function wbdcb(obj,src,~)
         tmp = get(gca,'UserData');
         if isempty(tmp)
            return;
         elseif isnan(tmp)
            return;
         else
            obj.curAx = tmp;
            for ii = 1:numel(obj.ax)
               obj.ax{ii}.LineWidth = 5;
            end
            obj.ax{tmp}.LineWidth = 8;
         end
         src.WindowButtonUpFcn = @obj.wbucb;
      end
      
      % Window button up callback: 
      function wbucb(obj,src,~)
         if isempty(obj.roi)
            src.WindowButtonUpFcn = [];
%             src.WindowButtonDownFcn = [];
            return;
         end
         if ~obj.roi_is_locked
            obj.roi{obj.curAx} = obj.tmp_roi;
         end
         src.WindowButtonUpFcn = [];
      end
      
      
   end
   
   
   
end

