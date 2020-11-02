function roi = getSyncThreshold(meta,roi)
%% GETSYNCTHRESHOLD  Get threshold for LED in automated way
%
%  roi = getSyncROI(meta);
%  roi = GETSYNCTHRESHOLD(meta,roi);
%
% By: Max Murphy  v1.0  2019-04-25   Original version R2017a

%%
u = unique(meta.Angle);

ROI_RGB = cell(size(meta,1),1);
tic;
for iU = 1:numel(u)
   fprintf(1,'Getting ROI averages for %s...\n',u{iU});
   idx = find(strcmpi(meta.Angle,u{iU}));
   f = meta.Name(idx);
   p = meta.Folder(idx);
   roiIdx = find(strcmpi(roi.Angle,u{iU}));
   
   pos = roi.Position{roiIdx}; %#ok<*FNDSB>
   
   for iF = 1:numel(f)
      fprintf(1,'\n-->\t%s\n',f{iF});
      V = VideoReader(fullfile(p{iF},f{iF})); %#ok<TNMLP>
      rgb = nan(V.NumberOfFrames,3); %#ok<VIDREAD>
      V = VideoReader(fullfile(p{iF},f{iF})); %#ok<TNMLP>
      iFrame = 1;
      while V.hasFrame
         C = V.readFrame;
         rgb(iFrame,:) = channelAvg(pos,C);
         iFrame = iFrame + 1;

      end

      for k = 1:3
         roi.Thresh{roiIdx}(k) = median(rgb(:,k)) + 2 * rms(rgb(:,k));
      end
      ROI_RGB{idx(iF)} = rgb;
   end
end
meta.ROI_RGB = ROI_RGB;
toc;

   function mu = channelAvg(pos,I)
      if size(I,3) > 1
         mu = nan(1,size(I,3));
         for iMu = 1:numel(mu)
            mu(iMu) = channelAvg(pos,I(:,:,iMu));
         end
         return;
      end
      mu = mean(mean(I(round(pos(2)):round((pos(2)+pos(4))),...
         round(pos(1)):round((pos(1)+pos(3))))));
   end


end