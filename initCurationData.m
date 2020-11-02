function curationData = initCurationData(scoringFile,extractedDir)
%% INITCURATIONDATA  Initialize curation data for a given recording
%
%  curationData = INITCURATIONDATA();
%  curationData = INITCURATIONDATA(scoringFile);
%  curationData = INITCURATIONDATA(scoringFile,extractedDir);
%
% By: Max Murphy  v1.0  2019-05-20  Original version (R2017a)

%%
if nargin < 1
   [fName,pName,~] = uigetfile('*_VideoScoring.mat',...
      'Select VIDEO SCORING file',...
      pwd);

   if fName == 0
      disp('Scoring canceled.');
      obj = [];
      return;
   end
   
   scoringFile = fullfile(pName,fName);
else
   [pName,fName,ext] = fileparts(scoringFile);
   fName = [fName,ext];
end
name = strsplit(fName,'_');
name = strjoin(name(1:5),'_');


if nargin < 2
   extractedDir = uigetdir(pName,'Select folder with DEEPCUT csvs');
   if extractedDir == 0
      disp('Script canceled.');
      return;
   end
end
v = dir(fullfile(extractedDir,[name '*.MP4']));

vid = cell(numel(v),1);
csv = cell(numel(v),1);
tab = cell(numel(v),1);
kin = cell(numel(v),1);
trial = nan(numel(v),1);
cam = cell(numel(v),1);

folder = repmat({v(1).folder},numel(v),1);

for ii = 1:numel(v)
   f_id = strsplit(v(ii).name(1:end-4),'_');
   cam{ii} = f_id{6};
   tmp = strsplit(f_id{7},'-');
   trial(ii) = str2double(tmp{2});
   f_id = strjoin(f_id(1:7),'_');
   F = dir(fullfile(v(ii).folder,[f_id '*.csv']));
   
   vid{ii} = v(ii).name;
   csv{ii} = F.name;
   tab{ii} = [f_id 'KinTab.mat'];
   kin{ii} = [f_id 'KinData.mat'];
   
   
   T = importDLC(fullfile(folder{ii},csv{ii}));
   save(fullfile(folder{ii},tab{ii}),'T','-v7.3');
   data = viewTrialKinematicMarkers(T);
   save(fullfile(folder{ii},kin{ii}),'-struct','data');
end

curationData = table(trial,cam,folder,vid,csv,tab,kin);
curationData = sortrows(curationData);
save(scoringFile,'curationData','-append');
end