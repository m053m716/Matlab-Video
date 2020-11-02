%% MAIN  Batch for running code related to ROC for rats doing audio task
clear; clc; close all force

%% Manually select video, ROI, and thresholds
meta = getVidFile;      % Select the first video file in GoPro "series"
name = strsplit(meta.Name{1},'_');
b = strjoin(name(1:5),'_');
name = name{1};
[block,subs] = getBlock(fullfile(defaults.paths('tank'),name,b));
% [block,subs] = getBlock;
roi = getSyncROI(meta); % Set the ROI and thresholds manually

%% Parse filename and save
fname = [meta.Animal{1} '_' ...           % Animal
   strrep(meta.Date{1},'-','_') '_' ...   % Recording Date
   meta.ID{1} '_' ...                     % Recording ID number
   'VideoScoring.mat'];                   % Video Scoring File Identifier

save(fname,'meta','roi','subs','-v7.3');

%% Get video offset
trials = getTrials(subs);
meta = getVidOffset(meta,trials);
save(fname,'meta','roi','subs','-v7.3');
str = {'Nose + Audio';'Bilateral Audio Cue + Reach'};

%% Run video exporting
[~,idx] = uidropdownbox('Select Recording Type','Recording Type:',str);
switch idx
   case 1
      batchVidExport(fname); % Warning: LONG; exports all trial vids
   case 2
      batchReachOnlyVidExport(fname); % Warning: LONG; exports all trial vids
   otherwise
      fprintf(1,'No selection.\n');
end
