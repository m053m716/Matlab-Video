function [block,subs] = getBlock(block)
%% GETBLOCK   Get block path information
%
%  block = GETBLOCK;
%  block = GETBLOCK(block); % No UI selection
%  [block,subs] = GETBLOCK;
%
%  --------
%   INPUTS
%  --------
%   block      :     (optional; char) Full path to recording BLOCK folder.
%
%  --------
%   OUTPUT
%  --------
%   block      :     Full path to recording BLOCK folder
%
%   subs       :     Struct containing sub-directories for the block.
%
% By: Max Murphy  v1.0  2019-05-03  Original version (R2017a)

%%
if nargin < 1
   block = uigetdir('P:\Rat\BilateralReach\Audio',...
      'Select recording BLOCK');

   if block == 0
      disp('No BLOCK selected. GETACCELEROMETRYDATA canceled.');
      return;
   end
end

%%
name = strsplit(block,filesep);
name = name{end};

%%
subs.name = name;
subs.raw = fullfile(block,[name '_RawData']);
subs.car = fullfile(block,[name '_FilteredCAR']);
subs.filt = fullfile(block,[name '_Filtered']);
subs.dig = fullfile(block,[name '_Digital']);

end
