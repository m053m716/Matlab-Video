function meta = getVidFile(first_vid_fname,varargin)
%GETVIDFILE  Returns metadata table for a related set of videos
%
%  meta = GETVIDFILE();
%  --> Select video using default parameters
%
%  meta = GETVIDFILE(first_vid_fname); 
%  --> Skip video selection UI
%
%  meta = GETVIDFILE('','NAME',value,...);  
%  --> Use video selection UI, set optional parameters.
%
%  meta = GETVIDFILE(first_vid_fname,'NAME',value,...);
%  --> Change default parameters and skip UI selection.
%
%  --------
%   INPUTS
%  --------
%  first_vid_fname  :(optional) '' by default. Can be specified as a char
%                       array that indicates the full filename of a video
%                       of interest from the recording session using the
%                       syntax: 
%                       fullfile('folder/with/all/videos',...
%                          '[AnimalID]_[yyyy]_[mm]_[dd]_...*.[filetype]');
%  
%  varargin    :     (optional) 'NAME' value input argument pairs.
%                    --> To still select first_vid_fname from UI, enter
%                        first argument as '' 
%
%  --------
%   OUTPUT
%  --------
%    meta      :     Table with video metadata, where each row contains
%                       data relating to a single video from a set of
%                       videos related to a full behavioral recording of
%                       interest.

%% Default parameters
params.default_search_path = 'K:\Rat\Video\Audio Discrimination Task\post-surg';
params.valid_extensions = {'*_Right-A_0.MP4','Right Camera Videos Only';...
                           '*_0.MP4','First Video Only';...
                           '*.MP4;*.mp4;*.avi','Video Files (*.mp4,*.avi)';...
                           '*.*','All Files (*.*)'};       
params.selection_ui_title = 'Select VIDEO file';

%% Parse inputs
% For first input, assign empty value if not specified
if nargin < 1
   first_vid_fname = '';
end

% For varargin, match 'name', value input pairs (case-insensitive)
for iV = 1:2:numel(varargin)
   if isfield(lower(varargin{iV}),params)
      params.(lower(varargin{iV})) = varargin{iV+1};
   end
end

%% Allow selection of video
if isempty(first_vid_fname)
   [fileName,pathName,~] = uigetfile(params.valid_extensions,...
                                     params.selection_ui_title,...
                                     params.default_search_path);

   if fileName == 0
      error(['nigeLab:' mfilename ':noSelection'],...
             'No video file selected.');
   end
   first_vid_fname = fullfile(pathName,fileName);
end

%% Parse experiment info from file name
[pname,fName,ext] = fileparts(first_vid_fname);

strInfo = strsplit(fName,'_');
Animal = strInfo{1};
t = datetime(str2double(strjoin(strInfo(2:4),'')),...
   'ConvertFrom','yyyymmdd');
Date = datestr(t,'yyyy-mm-dd');
ID = strInfo{5};

%% Find all other videos in the same folder related to this recording
F = dir(fullfile(pname,[strjoin(strInfo(1:5),'_') '*' ext]));

%% Make sure file names are sorted in ascending order by video index
fname = {F.name}.';
c = cellfun(@(C)regexp(C,'_(?<index>\d+)\.','tokens'),fname);
idx = cellfun(@str2double,c);
[~,iF] = sort(idx,'ascend');
fname = fname(iF);

%% Initialize metadata table and loop to extract data of interest
meta = makeMetaTable(numel(fname),pname,fname,Animal,Date,ID);
fprintf(1,'Extracting video metadata...000%%\n');
for iF = 1:numel(fname)
   % Surely there is a faster way than this:
   V = VideoReader(fullfile(pname,fname{iF})); %#ok<*TNMLP>
   [~,f,~] = fileparts(fname{iF});
   strInfo = strsplit(f,'_');
   
   % Parse "view angle" and video index from known naming convention
   meta.Angle{iF} = strInfo{6};
   meta.Index(iF) = str2double(strInfo{7});
   
   % Get the framerate and frame dimensions from VideoReader
   meta.fs(iF) = V.FrameRate;      
   meta.Height(iF) = V.Height;
   meta.Width(iF) = V.Width;
   
   % Get the start time of the previous video index for THIS camera (could
   % have multiple cameras on the same associated recording session)
   if meta.Index(iF) > 0
      prevIndexElements = meta.Index == (meta.Index(iF)-1);
      sameCamElements = strcmpi(meta.Angle,meta.Angle{iF});
      meta.tStart(iF) = meta.tStop(prevIndexElements & sameCamElements);
   else
      % If first instance of vid for this camera
      meta.tStart(iF) = 0;
   end
   
   % Each GoPro video from a given camera is "chunked" into several parts
   % due to filesize limits. Set "tStop" to indicate approximate start time
   % of next video in sequence, which can be synchronized properly later.
   meta.tStop(iF) = meta.tStart(iF) + V.Duration;
   
   % To make sure this object doesn't stay in memory:
   delete(V);
   
   % Update Command Window with completion status
   pct = floor(iF/numel(fname) * 100);
   fprintf(1,'\b\b\b\b\b%03g%%\n',pct);
end


%% Helper functions

   function meta = makeMetaTable(N,pname,fname,Animal,Date,ID)
      % MAKEMETATABLE  Initialize the "metadata" table for N videos
      %
      %  N      :  Total number of videos
      %  pname  :  Folder (char array)
      %  fname  :  Video filename (char array)
      %  Animal :  Animal identifier (char array)
      %  Date   :  Char array in format 'yyyy-mm-dd'
      %  ID     :  Recording ID (for multiple recordings on same day)
      
      Folder = repmat({pname},N,1);
      Name = fname;
      Animal = repmat({Animal},N,1);
      Date = repmat({Date},N,1);
      ID = repmat({ID},N,1);
      Angle = cell(N,1);
      Index = nan(N,1);
      fs = nan(N,1);
      Height = nan(N,1);
      Width = nan(N,1);
      tStart = nan(N,1);
      tStop = nan(N,1);

      meta = table(Folder,Name,Animal,Date,ID,Angle,Index,fs,Height,Width,tStart,tStop);
      
   end

end