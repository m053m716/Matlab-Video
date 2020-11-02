function [data,fs] = sfx(fname)
%% SFX Load sound effects
%
%  [data,fs] = defaults.sfx; % prompted from UI
%  [data,fs] = defaults.sfx(fname); % give full filename or part of
%                                   % filename
%
%  Specify fname as 'none' to mute the sfx.
%
%  By: Max Murphy v1.0  2019-05-14  Original version (R2017a)

%%
if nargin < 1
   [fname,pname,ext] = uigetfile({'*.wav','*.mp3','*.mp4','*.m4a'},...
      'Select AUDIO file',pwd);
   if fname == 0
      disp('No file selected.');
      return;
   else
      fname = fullfile(pname,fname,ext);
   end
else
   if strcmpi(fname,'none')
      data = zeros(1,10);
      fs = 44100;
      return;
   end
   
   [p,f,ext] = fileparts(fname);
   if isempty(p)
      p = mfilename('fullpath');
      p = strsplit(p,filesep);
      p = strjoin(p(1:(end-1)),filesep);
   end
   
   if isempty(ext)
      F = dir(fullfile(p,[f '*']));
      if numel(F) > 1
         error('Too many files match query: %s',f);
      elseif numel(F) < 1
         error('No file found matching query: %s',fname);
      else
         fname = fullfile(F.folder,F.name);
      end
   end
end

[data,fs] = audioread(fname);


end