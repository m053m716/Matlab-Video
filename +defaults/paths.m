function out = paths(type)
%PATHS Default paths associated with this project 
%   Detailed explanation goes here

switch lower(type)
   case 'tank'
      out = 'P:\Rat\BilateralReach\Audio';
   case 'current'
      out = 'D:\MATLAB\Projects\Kalman-Thesis-Sync';
   case 'spikes'
      out = '_wav-sneo_CAR_Spikes';
   otherwise
      out = [];
end


end

