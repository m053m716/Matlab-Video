function getStereoCalibration(behaviorData,outDir)
%% GETSTEREOCALIBRATION    Recover camera pair stereo parameters
%
%  GETSTEREOCALIBRATION;
%  GETSTEREOCALIBRATION(behaviorData);
%  GETSTEREOCALIBRATION(behaviorData,outDir);

%%
SQUARE_SIZE = 2.79; % mm

if nargin < 1
   [fName,pName,~] = uigetfile('*_VideoScoring.mat',...
      'Select VIDEO SCORING file','..');

   if fName == 0
      disp('Scoring canceled.');
      obj = [];
      return;
   end
   
   scoringFile = fullfile(pName,fName);
   load(scoringFile,'behaviorData');
else
   scoringFile = behaviorData.Properties.Description;
end

in = load(scoringFile,'roi');

%%
if nargin < 2
   outDir = uigetdir(pwd,'Select OUTPUT folder');
   if outDir == 0
      disp('No folder selected. Script canceled.');
      return;
   end
end
%%
name = strsplit(scoringFile,'_');
name = strjoin(name(1:5),'_');
searchDir = fullfile(pwd,'cal');

tic;
for ii = 1:size(behaviorData,1)
   idx = find(~isnan(behaviorData.Lag(ii,:)));
   idx_comb = nchoosek(idx,2);
   trial = behaviorData.Properties.RowNames{ii};
   cal = cell(size(idx_comb,1),1);
   cam1 = cell(size(cal));
   cam2 = cell(size(cal));
   for ik = 1:size(idx_comb,1)
      
      cam1{ik} = [name '_' in.roi.Angle{idx_comb(ik,1)} '_' trial];
      cam2{ik} = [name '_' in.roi.Angle{idx_comb(ik,2)} '_' trial];
      % Define images to process
      F1 = dir(fullfile(searchDir,[cam1{ik} '_stereo-cal'],[cam1{ik} '*.PNG']));
      F2 = dir(fullfile(searchDir,[cam2{ik} '_stereo-cal'],[cam2{ik} '*.PNG']));
      imageFileNames1 = cell(numel(F1),1);
      imageFileNames2 = cell(numel(F2),1);
      
      for ij = 1:numel(imageFileNames1)
         imageFileNames1{ij} = fullfile(F1(ij).folder,F1(ij).name);
         imageFileNames2{ij} = fullfile(F2(ij).folder,F2(ij).name);
      end

      % Detect checkerboards in images
      [imagePoints, boardSize] = detectCheckerboardPoints(imageFileNames1, imageFileNames2);

      % Generate world coordinates of the checkerboard keypoints
      squareSize = SQUARE_SIZE;  % in units of 'millimeters'
      worldPoints = generateCheckerboardPoints(boardSize, squareSize);

      % Read one of the images from the first stereo pair
      I1 = imread(imageFileNames1{1});
      [mrows, ncols, ~] = size(I1);

      % Calibrate the camera
      cal{ik} = estimateCameraParameters(imagePoints, worldPoints, ...
         'EstimateSkew', true, 'EstimateTangentialDistortion', false, ...
         'NumRadialDistortionCoefficients', 2, 'WorldUnits', 'millimeters', ...
         'InitialIntrinsicMatrix', [], 'InitialRadialDistortion', [], ...
         'ImageSize', [mrows, ncols]);

   end
   stereoData = table(cam1,cam2,cal);
   stereoData.Properties.Description = trial;
   save(fullfile(outDir,[name '_' trial '_StereoParams.mat']),...
      'stereoData','-v7.3');
end
toc;

end
