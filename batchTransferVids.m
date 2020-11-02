function batchTransferVids(startDir,endDir,storeDir)
%% BATCHTRANSFERVIDS    Copy a batch of videos to be transferred for extraction
%
%  BATCHTRANSFERVIDS(startDir,endDir)
%
%  --------
%   INPUTS
%  --------
%  startDir    :     Start location of folders with extracted "trial"
%                       videos (typically C:\Temp)
%
%  endDir      :     End location for transfer (such as portable drive)
%                       (typically E:\Data Transfer\vids)
%
%  storeDir    :     (Optional) Server location for "trial" videos.
%                          (default: K:\Rat\Video\Audio Discrimination
%                          Task\extracted) if not otherwise specified
%
% By: Max Murphy  v1.0  2019-05-20  Original version (R2017a)

%% PARSE INPUT
if nargin < 3
   storeDir = 'K:\Rat\Video\Audio Discrimination Task\extracted';
end

if exist(startDir,'dir')==0
   error('Invalid start directory: %s',startDir);
end

if exist(endDir,'dir')==0
   error('Invalid end directory: %s',endDir);
end

%% START TRANSFER

tic;
folderF = dir(fullfile(startDir,'R19*'));
h = waitbar(0,'Please wait, copying files for extraction...');
for iF = 1:numel(folderF)
   fileF = dir(fullfile(folderF(iF).folder,folderF(iF).name,...
      [folderF(iF).name '*.MP4']));
   for ii = 1:numel(fileF)
      copyfile(fullfile(fileF(ii).folder,fileF(ii).name),...
         fullfile(endDir,fileF(ii).name));
      waitbar((iF-1)/numel(folderF) + (ii/numel(fileF))/numel(folderF),h);
   end
   movefile(fullfile(fileF(ii).folder),fullfile(storeDir));
end
delete(h);
disp('File transfer complete!');
toc;

end