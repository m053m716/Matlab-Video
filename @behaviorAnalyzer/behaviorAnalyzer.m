classdef behaviorAnalyzer < handle
   %BEHAVIORANALYZER Class for doing trial-aligned behavioral analyses
   %   Detailed explanation goes here
   
   properties (Access = public)
      behaviorData
      animal
      block
   end
   
   properties (Access = private)
   end
   
   properties (Hidden = true)
   end
   
   methods
      % Class constructor
      function obj = behaviorAnalyzer(varargin)
         %BEHAVIORANALYZER Class constructor
         %  
         %  obj = BEHAVIORANALYZER();
         %  obj = BEHAVIORANALYZER(behaviorData);
         %  obj = BEHAVIORANALYZER(behaviorData,blockfolder);
         %
         % By: Max Murphy  v1.0  2019-05-16 Original version (R2017a)
         
         switch numel(varargin)
            case 0
               obj.parseBlockInfo;
               in  = load(fullfile(defaults.paths('current'),...
                  [obj.block '_VideoScoring.mat']));
               if ~isfield(in,'behaviorData')
                  error('behaviorData not yet scored.');
               else
                  obj.parseBehaviorData(in.behaviorData);
               end
            case 1
               if isa(varargin{1},'behaviorAnalyzer')
                  obj.animal = varargin{1}.animal;
                  obj.block = varargin{1}.block;
                  obj.parseBehaviorData(varargin{1}.behaviorData);
               else
                  obj.parseBlockInfo;
                  obj.parseBehaviorData(varargin{1});
               end
            case 2
               obj.parseBehaviorData(varargin{1});
               [obj.animal,obj.block,~] = fileparts(varargin{2});
            otherwise
               error('Invalid number of input arguments.');
         end
         
      end
      
      % Parse behavior data to be used in trial alignment
      function parseBehaviorData(obj,behaviorData)
         subset = ~isnan(behaviorData.Grasp) & ~isinf(behaviorData.Grasp);
         obj.behaviorData = behaviorData(subset,:);
      end
      
      % Parse block/animal info for this behavior analysis
      function parseBlockInfo(obj,force)
         if nargin < 2
            force = false;
         end
         
         if isempty(obj.animal) || force
            F = dir(fullfile(defaults.paths('tank'),'R*'));
            [~,idx] = uidropdownbox('Select RAT','Select rat:',{F.name}.');
            obj.animal = fullfile(F(idx).folder,F(idx).name);
         end
         
         if isempty(obj.block) || force
            F = dir(fullfile(obj.animal,'R*'));
            [~,idx] = uidropdownbox('Select BLOCK','Select block:',{F.name}.');
            obj.block = F(idx).name;
         end
      end
   end
   
end

